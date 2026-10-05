extends RefCounted
## 只读知识投影与行动适用性。选择目标不写入知识、位置、AP 或回合状态。
## 正式定义、正式快照、开发预览分开保存；返回的对象都是深拷贝。

signal settled_changed(before: Dictionary, after: Dictionary, receipt_id: String)

const ACTIONS: Array[String] = ["talk", "investigate", "conceal", "move"]
const KIND_NAMES := {"person": "人物", "place": "地点", "object": "物件", "anomaly": "异常"}
var preview_enabled: bool = false
var _live_definitions: Dictionary = {}
var _live_snapshot: Dictionary = {}
var _preview_definitions: Dictionary = {}
var _preview_snapshot: Dictionary = {}


func _init() -> void:
	_live_definitions = _index(_read("res://data/targets.json").get("targets", []))
	_live_snapshot = _read("res://data/initial_knowledge.json")
	var preview := _read("res://preview_data/workbench.json")
	if preview.get("preview_only", false):
		_preview_definitions = _index(preview.get("targets", []))
		_preview_snapshot = preview


func _read(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


func _index(entries: Array) -> Dictionary:
	var result := {}
	for entry in entries:
		result[entry.id] = entry.duplicate(true)
	return result


func set_preview(enabled: bool) -> void:
	preview_enabled = enabled


func set_live_data(definitions: Array, snapshot: Dictionary) -> bool:
	# 未来由正式剧情/存档适配层调用；禁止把预览快照当作正式资料接入。
	if snapshot.get("preview_only", false):
		return false
	_live_definitions = _index(definitions)
	_live_snapshot = snapshot.duplicate(true)
	return true


func get_snapshot() -> Dictionary:
	return _snapshot().duplicate(true)


func _snapshot() -> Dictionary:
	return _preview_snapshot if preview_enabled else _live_snapshot


func _definitions() -> Dictionary:
	return _preview_definitions if preview_enabled else _live_definitions


func is_known(target_id: String) -> bool:
	return _definitions().has(target_id) and _snapshot().get("known_targets", {}).has(target_id)


func current_location_id() -> String:
	return _snapshot().get("current_location_id", "")


func current_location_name() -> String:
	var target_id := current_location_id()
	return _definitions()[target_id].name if is_known(target_id) else "未知"


func objective() -> String:
	return _snapshot().get("objective", "尚无已接入的目标记录。")


func visible_targets(kind: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for target_id in _definitions():
		if is_known(target_id) and (kind.is_empty() or _definitions()[target_id].kind == kind):
			result.append(target_view(target_id))
	return result


func target_view(target_id: String) -> Dictionary:
	if not is_known(target_id):
		return {}
	var definition: Dictionary = _definitions()[target_id]
	var record: Dictionary = _snapshot().known_targets[target_id]
	var view := {
		"id": target_id, "kind": definition.kind, "kind_name": KIND_NAMES.get(definition.kind, "目标"),
		"name": definition.name, "avatar": definition.get("avatar", "◇"),
		"identity": "身份尚未了解" if definition.kind == "person" else "暂无已知说明",
		"safety": "尚无已知安全状态", "attitude": "尚未了解", "belief": "尚未了解", "cooperation": "尚未了解",
		"description": "", "communication": "", "latest_status": "暂无新的已知状态", "issues": [], "clues": [],
		"has_lead": false, "marker_requires_lead": definition.get("marker_requires_lead", false), "location_id": "", "location_label": "当前位置未知", "place_status": "",
	}
	# 仅投影已发现事实；未发现事实不进入详情、列表、提示或行动判定。
	for fact in definition.get("facts", []):
		if fact.id not in record.get("fact_ids", []):
			continue
		if fact.field in ["issues", "clues"]:
			view[fact.field].append(fact.text)
			if fact.field == "clues" and fact.get("investigable", false):
				view.has_lead = true
		elif fact.field in ["identity", "attitude", "belief", "cooperation", "description", "communication", "safety"]:
			view[fact.field] = fact.text
		if record.get("latest_fact_id", "") == fact.id:
			view.latest_status = fact.text
	if not record.get("investigation_open", true):
		view.has_lead = false
	if definition.kind == "place":
		view.location_id = target_id
		view.location_label = definition.name
		view.place_status = place_status(target_id)
	else:
		var location: Dictionary = record.get("known_location", {})
		var place_id: String = location.get("place_id", "")
		if is_known(place_id) and _definitions()[place_id].kind == "place":
			view.location_id = place_id
			view.location_label = _definitions()[place_id].name
			if not location.get("detail", "").is_empty():
				view.location_label += " · " + location.detail
	return view.duplicate(true)


func place_status(target_id: String) -> String:
	if not is_known(target_id):
		return ""
	if target_id == current_location_id():
		return "当前所在地"
	var route: Dictionary = _snapshot().get("known_routes", {}).get(target_id, {})
	if not route.has("reachable"):
		return "已知 · 可达性未知"
	var reachable: bool = route.reachable and (not route.has("from_ids") or current_location_id() in route.from_ids)
	return "已知 · 可到达" if reachable else "已知 · 不可到达"


func known_route_reason(target_id: String, source: String = "@actual") -> String:
	var location := current_location_id() if source == "@actual" else source
	if not is_known(target_id):
		return "尚未发现该地点"
	if target_id == location:
		return "你已在此地"
	var route: Dictionary = _snapshot().get("known_routes", {}).get(target_id, {})
	if route.has("from_ids") and location not in route.from_ids:
		return "从当前所在地尚无已知可达路线。"
	return route.get("reason", "尚未掌握可达路线")


func action_options(target_id: String, planned_location: String = "@actual") -> Dictionary:
	var options := {}
	for action in ACTIONS:
		options[action] = {"eligible": false, "reason": "请先选择已知目标"}
	var view := target_view(target_id)
	if view.is_empty():
		return options
	var location := current_location_id() if planned_location == "@actual" else planned_location
	var distance_reason := ""
	if view.location_id.is_empty():
		distance_reason = "目标当前位置未知，不能安排现场互动"
	elif location.is_empty():
		distance_reason = "玩家当前位置未接入，不能安排现场互动"
	elif view.location_id != location:
		distance_reason = "目标在异地，需先到达该地点"
	options.talk.reason = "交谈只适用于已认识的人物"
	if view.kind == "person":
		options.talk = {"eligible": distance_reason.is_empty(), "reason": distance_reason if not distance_reason.is_empty() else "可以选择交流；是否合作以已知范围为准"}
	options.investigate.reason = "尚无已发现的明确调查线索或异常"
	if view.has_lead:
		options.investigate = {"eligible": distance_reason.is_empty(), "reason": distance_reason if not distance_reason.is_empty() else "已有明确线索，可选择调查"}
	if not view.has_lead and not view.clues.is_empty():
		options.investigate.reason = "已知线索当前未开放继续调查。"
	options.conceal.reason = "隐匿适用条件尚未配置"
	options.move.reason = "移动仅对地点开放"
	if view.kind == "place":
		if target_id == location:
			options.move.reason = "已经在此地"
		else:
			var route: Dictionary = _snapshot().get("known_routes", {}).get(target_id, {})
			options.move = {"eligible": route.get("reachable", false) == true, "reason": known_route_reason(target_id, location)}
			if route.has("from_ids") and location not in route.from_ids:
				options.move = {"eligible": false, "reason": "从计划位置尚无已知可达路线"}
	var record: Dictionary = _snapshot().known_targets[target_id]
	if record.has("allowed_actions"):
		for action in ACTIONS:
			if action not in record.allowed_actions:
				options[action] = {"eligible": false, "reason": "当前人物状态不允许此行动。"}

	return options


func apply_resolved_location(location_id: String) -> bool:
	# 仅供整批结算完成后调用；规划与查看不能调用此入口。
	if not is_known(location_id) or _definitions()[location_id].kind != "place":
		return false
	_snapshot()["current_location_id"] = location_id
	return true


func reset_preview() -> void:
	_preview_snapshot = _read("res://preview_data/workbench.json")


func apply_settled_snapshot(snapshot: Dictionary, receipt_id: String = "") -> bool:
	# 仅供结算/次日适配层提交完整快照，不能由回顾视图调用。
	if snapshot.is_empty() or snapshot.get("preview_only", false) != preview_enabled:
		return false
	var before := get_snapshot()
	if preview_enabled:
		_preview_snapshot = snapshot.duplicate(true)
	else:
		_live_snapshot = snapshot.duplicate(true)
	if not receipt_id.is_empty():
		settled_changed.emit(before, get_snapshot(), receipt_id)
	return true
