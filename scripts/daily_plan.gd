extends RefCounted
## 每日唯一计划所有者。预算与卡牌占用均从完整行动列表派生。
signal changed
signal submitted(payload: Dictionary)

const BUDGET := 3
const ACTION_NAMES := {"talk": "交谈", "investigate": "调查", "conceal": "隐匿", "move": "移动"}
const SCALE_NAMES := {"personal": "个人", "group": "群体"}
var day: int = 1
var knowledge: RefCounted
var _entries: Array[Dictionary] = []
var _used_ideas: Array[String] = []
var event_blocked := false
var _locked := false
var _resolved := false
var _serial := 0
var _request_id := ""
var _profile := "formal"
var _ideas: Dictionary = {}
var _locked_validation: Dictionary = {}


func _init(source: RefCounted, profile: String = "formal") -> void:
	knowledge = source
	_profile = profile
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ideas.json"))
	for idea in data.ideas:
		_ideas[idea.id] = idea


func entries() -> Array[Dictionary]:
	return _entries.duplicate(true)


func is_locked() -> bool:
	return _locked


func is_resolved() -> bool:
	return _resolved


func request_id() -> String:
	return _request_id


func reserved_ap() -> int:
	var total := 0
	for entry in _entries:
		total += entry.ap_cost
	return total


func remaining_ap() -> int:
	return BUDGET - reserved_ap()


func idea_name(idea_id: String) -> String:
	return _ideas.get(idea_id, {}).get("name", "无卡")


func obtained_ideas() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for idea_id in knowledge.get_snapshot().get("acquired_ideas", []):
		if _ideas.has(idea_id):
			result.append(_ideas[idea_id].duplicate(true))
	return result


func idea_status(idea_id: String, except_index: int = -1) -> Dictionary:
	if idea_id in _used_ideas:
		return {"state": "used", "label": "今日已使用", "reason": "这张思想今日已使用，下一天重置。"}
	var slot := 0
	for index in range(_entries.size()):
		if index != except_index and _entries[index].idea_id == idea_id:
			var position := _slot_name(slot)
			return {"state": "planned", "label": "已安排 · " + position, "reason": "这张思想已安排在%s，请先修改原计划。" % position}
		slot += _entries[index].ap_cost
	return {"state": "available", "label": "可安排", "reason": "今日尚未安排"}


func local_belief(idea_id: String) -> String:
	# 只读取实际所在地，绝不使用计划位置。
	return knowledge.get_snapshot().get("idea_beliefs", {}).get(knowledge.current_location_id(), {}).get(idea_id, "未知")


func group_access() -> Dictionary:
	return knowledge.get_snapshot().get("group_access", {"unlocked": false, "known_reason": "尚未得知组织条件。"}).duplicate(true)


func cost_for(draft: Dictionary) -> int:
	if draft.get("behavior", "") != "move":
		return 1
	var cost: Variant = knowledge.get_snapshot().get("known_routes", {}).get(draft.get("target_id", ""), {}).get("ap_cost", 0)
	return int(cost) if (cost is float or cost is int) and float(cost) == float(int(cost)) and int(cost) in [1, 2, 3] else 0


func planned_location_before(index: int = -1) -> String:
	var position: String = knowledge.current_location_id()
	var limit := _entries.size() if index < 0 else mini(index, _entries.size())
	for i in range(limit):
		var entry := _entries[i]
		var checked := _check_entry(entry, position, {})
		if checked.errors.is_empty() and entry.behavior == "move":
			position = entry.target_id
	return position


func _slot_name(index: int) -> String:
	return ["行动一", "行动二", "行动三"][clampi(index, 0, 2)]


func _check_entry(entry: Dictionary, position: String, occupied: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var action: String = entry.get("behavior", "")
	var target: String = entry.get("target_id", "")
	var scale: String = entry.get("scale", "personal")
	var idea_id: String = entry.get("idea_id", "")
	var options: Dictionary = knowledge.action_options(target, position)
	if not ACTION_NAMES.has(action):
		errors.append("请选择交谈、调查、隐匿或移动。")
	elif not options[action].eligible:
		errors.append(options[action].reason)
	if not SCALE_NAMES.has(scale):
		errors.append("规模不适用。")
	elif scale == "group" and not group_access().get("unlocked", false):
		errors.append(group_access().get("known_reason", "群体条件尚未满足。"))
	var cost := cost_for(entry)
	if cost == 0:
		errors.append("移动 AP 成本尚未配置，不能加入计划。")
	if not idea_id.is_empty():
		if idea_id not in knowledge.get_snapshot().get("acquired_ideas", []) or not _ideas.has(idea_id):
			errors.append("尚未获得这张思想卡。")
		elif action not in _ideas[idea_id].allowed_behaviors:
			errors.append("%s与思想卡的组合尚未定义，请选择无卡。" % ACTION_NAMES.get(action, "该行为"))
		if idea_id in _used_ideas:
			errors.append("这张思想今日已使用，下一天重置。")
		if occupied.has(idea_id):
			errors.append("这张思想已安排在%s，请先修改原计划。" % occupied[idea_id])
	return {"errors": errors, "ap_cost": cost}


func validate(plan_entries: Variant = null) -> Dictionary:
	if plan_entries == null:
		if _locked:
			return _locked_validation.duplicate(true)
		plan_entries = _entries
	var result: Array[Dictionary] = []
	var all_errors: Array[String] = []
	var occupied := {}
	var position: String = knowledge.current_location_id()
	var total := 0
	var last_move := -1
	for index in range(plan_entries.size()):
		var entry: Dictionary = plan_entries[index]
		var checked := _check_entry(entry, position, occupied)
		# 已加入行动的预算按保存的成本保留；配置变更不能暗中退款。
		var cost: int = entry.get("ap_cost", checked.ap_cost)
		if cost != checked.ap_cost:
			checked.errors.append("行动成本配置已变化，请替换此行动。")
		var dependency := "此行动依赖前面的移动成功。" if last_move >= 0 else ""
		result.append({"index": index, "slot": total, "cost": cost, "errors": checked.errors, "dependency": dependency, "location_before": position})
		for error in checked.errors:
			all_errors.append("%s：%s" % [_slot_name(total), error])
		if not entry.get("idea_id", "").is_empty():
			occupied[entry.idea_id] = _slot_name(total)
		if entry.behavior == "move" and checked.errors.is_empty():
			position = entry.target_id
			last_move = index
		total += cost
	if total > BUDGET:
		all_errors.append("超过每日 3 AP 预算。")
	return {"valid": all_errors.is_empty(), "errors": all_errors, "items": result, "total_ap": total, "planned_location": position}


func candidate(draft: Dictionary, replace_index: int = -1) -> Dictionary:
	if _locked or event_blocked:
		return {"valid": false, "errors": ["今日计划已锁定。"]}
	var entry := draft.duplicate(true)
	entry["ap_cost"] = cost_for(entry)
	var proposed: Array = entries()
	if replace_index >= 0:
		if replace_index >= proposed.size():
			return {"valid": false, "errors": ["待替换行动已经不存在。"]}
		proposed[replace_index] = entry
	else:
		proposed.append(entry)
	return validate(proposed)


func put(draft: Dictionary, replace_index: int = -1) -> Dictionary:
	var check := candidate(draft, replace_index)
	if not check.valid:
		return check
	var entry := draft.duplicate(true)
	entry.ap_cost = cost_for(entry)
	entry.target_name = knowledge.target_view(entry.target_id).name
	entry.behavior_name = ACTION_NAMES[entry.behavior]
	entry.scale_name = SCALE_NAMES[entry.scale]
	entry.idea_name = idea_name(entry.idea_id)
	if replace_index >= 0:
		_entries[replace_index] = entry
	else:
		_entries.append(entry)
	changed.emit()
	return check


func remove(index: int) -> bool:
	if event_blocked or _locked or index < 0 or index >= _entries.size():
		return false
	_entries.remove_at(index)
	# 可以留下因删除前置移动而失效的计划，但必须重新校验并禁止提交。
	changed.emit()
	return true


func reorder(index: int, offset: int) -> bool:
	var destination := index + offset
	if event_blocked or _locked or index < 0 or index >= _entries.size() or destination < 0 or destination >= _entries.size():
		return false
	var entry := _entries[index]
	_entries.remove_at(index)
	_entries.insert(destination, entry)
	changed.emit()
	return true


func submit() -> Dictionary:
	var checked := validate()
	if event_blocked or _locked or not checked.valid:
		return {}
	_locked_validation = checked.duplicate(true)
	_locked = true
	_serial += 1
	_request_id = "%s:%d:%d" % [_profile, day, _serial]
	var payload := {"request_id": _request_id, "day": day, "preview_only": _profile == "preview", "entries": entries(), "initial_location": knowledge.current_location_id(), "budget": BUDGET}
	changed.emit()
	submitted.emit(payload.duplicate(true))
	return payload


func mark_resolved(token: String, consumed_ideas: Array) -> bool:
	if not _locked or _resolved or token != _request_id:
		return false
	var planned: Array[String] = []
	for entry in _entries:
		if not entry.idea_id.is_empty():
			planned.append(entry.idea_id)
	for idea_id in consumed_ideas:
		if idea_id not in planned:
			return false
	_used_ideas.assign(consumed_ideas)
	_resolved = true
	changed.emit()
	return true


func start_day(new_day: int, force_restart: bool = false) -> bool:
	if not force_restart and (_locked and not _resolved):
		return false
	if not force_restart and new_day <= day:
		return false
	if new_day < 1 or new_day > 10:
		return false
	day = new_day
	_entries.clear()
	_used_ideas.clear()
	_locked = false
	_resolved = false
	_request_id = ""
	_locked_validation.clear()
	changed.emit()
	return true


func describe(draft: Dictionary) -> String:
	var target: Dictionary = knowledge.target_view(draft.get("target_id", ""))
	if target.is_empty() or not ACTION_NAMES.has(draft.get("behavior", "")):
		return "先选择目标与行为。"
	var description := ""
	var snapshot: Dictionary = knowledge.get_snapshot()
	for rule in snapshot.get("planning_rules", {}).get("descriptions", []):
		if rule.target_id == target.id and rule.behavior == draft.behavior and rule.scale == draft.scale and rule.idea_id == draft.idea_id:
			var known: Array = snapshot.known_targets[target.id].get("fact_ids", [])
			var allowed := true
			for fact_id in rule.get("required_fact_ids", []):
				allowed = allowed and fact_id in known
			if allowed:
				description = rule.text
	if description.is_empty():
		match draft.behavior:
			"talk": description = "尝试了解对方的看法与合作意愿，不保证获得帮助。"
			"investigate": description = "沿已发现的线索继续观察，可能获得新的理解。"
			"move": description = "尝试前往已知地点；后续依赖行动以移动成功为前提。"
			"conceal": description = "隐匿规则尚未配置。"
	if not draft.get("idea_id", "").is_empty() and not description.contains(idea_name(draft.idea_id)):
		description += "\n使用思想：" + idea_name(draft.idea_id) + "。"
	if not target.communication.is_empty() and draft.behavior == "talk":
		description += "\n" + target.communication
	if not target.issues.is_empty():
		description += "\n已知注意事项：" + "；".join(target.issues)
	return description
