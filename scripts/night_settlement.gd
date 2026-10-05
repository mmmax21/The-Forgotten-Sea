extends RefCounted
## 固定流水线只执行一次；适配器仅返回暂存数据，统一提交后 UI 才接收快照。
signal batch_requested(payload: Dictionary)
signal batch_ready(receipt: Dictionary)
signal morning_ready(receipt: Dictionary)
const PreviewActions = preload("res://scripts/settlement/preview_actions.gd")
const STEPS = [
	["actions", "执行玩家行动"],
	["direct", "更新直接受影响的 NPC 与群体"],
	["spread", "处理 NPC、群体内部及跨地区传播"],
	["ideas", "更新思想状态与意识场"],
	["reality", "检查现实阈值与可用规则"],
	["offscreen", "更新玩家不在场地区"],
	["kingdom", "计算王国反制与警戒"],
	["tomorrow", "登记次日事件"]
]
const CATEGORIES = ["actions", "people", "world", "kingdom"]
var _requests: Dictionary = {}
var _jobs: Dictionary = {}
var _receipts: Dictionary = {}
var _history: Dictionary = {"formal": [], "preview": []}
var _adapters: Dictionary = {"formal": {}, "preview": {}}
var _morning_adapters: Dictionary = {}
var _morning: Dictionary = {}

func set_adapter(stage: String, adapter: Callable, preview := false) -> bool:
	if stage not in STEPS.map(func(step): return step[0]):
		return false
	_adapters[_profile(preview)][stage] = adapter
	return true

func set_morning_adapter(adapter: Callable, preview := false) -> void:
	_morning_adapters[_profile(preview)] = adapter

func _profile(preview: bool) -> String:
	return "preview" if preview else "formal"

func submit(payload: Dictionary, preview_config: Dictionary = {}, world: Dictionary = {}) -> bool:
	var token: String = payload.get("request_id", "")
	if token.is_empty() or _requests.has(token) or int(payload.get("day", 0)) not in range(1, 11):
		return false
	_requests[token] = payload.duplicate(true)
	var snapshot := world.duplicate(true)
	if snapshot.is_empty():
		snapshot = {"current_location_id": payload.get("initial_location", ""), "preview_only": payload.preview_only}
	if snapshot.get("preview_only", false) != payload.preview_only:
		_requests.erase(token)
		return false
	_jobs[token] = {"request": payload.duplicate(true), "world": snapshot, "records": [], "consumed_ideas": [], "next_events": [], "steps": [], "cursor": 0, "status": "queued", "config": preview_config.duplicate(true)}
	batch_requested.emit(payload.duplicate(true))
	_run.call_deferred(token)
	return true

func _run(token: String) -> void:
	var job: Dictionary = _jobs[token]
	if job.status != "queued":
		return
	job.status = "running"
	var profile := _profile(job.request.preview_only)
	while job.cursor < STEPS.size():
		var step: Array = STEPS[job.cursor]
		var result: Dictionary
		var context := {"request": job.request.duplicate(true), "world": job.world.duplicate(true), "next_events": job.next_events.duplicate(true)}
		if _adapters[profile].has(step[0]):
			var value: Variant = _adapters[profile][step[0]].call(context)
			result = value if value is Dictionary else {"status": "pending", "message": "适配器没有返回有效的结构化结果。"}
		elif step[0] == "actions":
			if job.request.entries.is_empty():
				result = {"status": "complete", "records": []}
			elif job.request.preview_only and job.config.get("enabled", false):
				result = PreviewActions.execute(context, job.config)
			else:
				result = {"status": "pending", "message": "正式行动效果判定尚未接入。计划已锁定，等待行动适配器或完整批次回执；尚未执行后续阶段。"}
		else:
			result = {"status": "unimplemented"}
		if result.get("status", "pending") not in ["complete", "unimplemented"]:
			_pause(token, result.get("message", "当前步骤规则待确认。"))
			return
		if result.status == "unimplemented" and (result.has("world") or not result.get("records", []).is_empty() or not result.get("next_events", []).is_empty() or not result.get("consumed_ideas", []).is_empty()):
			_pause(token, "未接入步骤不能返回实际效果；请检查适配器。")
			return
		if result.has("world"):
			if result.world.get("preview_only", false) != job.request.preview_only:
				_pause(token, "结算资料来源不一致，未写入世界。")
				return
			job.world = result.world.duplicate(true)
		job.records.append_array(result.get("records", []).duplicate(true))
		job.consumed_ideas.append_array(result.get("consumed_ideas", []).duplicate(true))
		job.next_events.append_array(result.get("next_events", []).duplicate(true))
		job.steps.append({"id": step[0], "name": step[1], "status": result.status})
		job.cursor += 1
	_finish(token)

func _pause(token: String, message: String) -> void:
	_jobs[token].status = "pending"
	# 不公开部分行动结果，也不把部分状态交给 UI。
	batch_ready.emit({"request_id": token, "day": _requests[token].day, "preview_only": _requests[token].preview_only, "status": "needs_rule", "message": message, "sections": _empty_sections(), "steps": _jobs[token].steps.duplicate(true)})

func resume(token: String) -> bool:
	# 仅供规则适配器接入后调用，回顾导航不调用此方法。
	if not _jobs.has(token) or _jobs[token].status != "pending":
		return false
	_jobs[token].status = "queued"
	_run.call_deferred(token)
	return true

func _finish(token: String) -> bool:
	var job: Dictionary = _jobs[token]
	var expected: Array = []
	for entry in job.request.entries:
		if not entry.idea_id.is_empty():
			expected.append(entry.idea_id)
	var unique: Array = []
	for idea in job.consumed_ideas:
		if idea not in expected or idea in unique:
			_pause(token, "整批回执的思想消耗与锁定计划不一致，未写入世界。")
			return false
		unique.append(idea)
	var sections := _public_sections(job.records, job.world)
	# 同一行为即使没有公开结果，也保留顺序和已知目标，不猜测成功或失败。
	var actions: Array = []
	for index in range(job.request.entries.size()):
		var matching: Array = sections.actions.filter(func(record): return record.get("action_index", -1) == index)
		if matching.is_empty():
			var entry: Dictionary = job.request.entries[index]
			matching = [{"action_index": index, "title": "%s · %s" % [entry.target_name, entry.behavior_name], "happened": "本次没有可公开的行动结果记录。", "reason": "", "direction": "等待后续已知报告；不能由此推断行动成功或失败。"}]
		actions.append_array(matching)
	sections.actions = actions
	var result := {"request_id": token, "day": job.request.day, "preview_only": job.request.preview_only, "status": "complete", "sections": sections, "steps": job.steps.duplicate(true), "consumed_ideas": unique, "final_location": job.world.get("current_location_id", ""), "message": "本次已接入步骤已完成；未接入系统单独列明。"}
	job.status = "complete"
	_receipts[token] = result.duplicate(true)
	_history[_profile(job.request.preview_only)].append(token)
	batch_ready.emit(result.duplicate(true))
	return true

func complete_batch(token: String, result: Dictionary) -> bool:
	# 外部整批解析器兼容入口；必须给出固定八步的结构化回执，不能传演示字符串。
	if not _jobs.has(token) or _receipts.has(token) or _jobs[token].status == "running":
		return false
	if result.get("preview_only", false) != _requests[token].preview_only:
		return false
	if result.get("movement_failed", false) and result.get("dependency_ap_policy", "pending") == "pending":
		_pause(token, "移动失败：依赖行动的 AP 规则待确认，保持锁定。")
		return false
	var steps: Array = result.get("steps", [])
	if steps.size() != STEPS.size():
		return false
	for index in range(STEPS.size()):
		if steps[index].get("id", "") != STEPS[index][0] or steps[index].get("status", "") not in ["complete", "unimplemented"]:
			return false
	var world: Dictionary = result.get("world", _jobs[token].world)
	if world.get("preview_only", false) != _requests[token].preview_only:
		return false
	_jobs[token].world = world.duplicate(true)
	_jobs[token].records = result.get("records", []).duplicate(true)
	_jobs[token].steps = []
	for index in range(STEPS.size()):
		_jobs[token].steps.append({"id": STEPS[index][0], "name": STEPS[index][1], "status": steps[index].status})
	_jobs[token].consumed_ideas = result.get("consumed_ideas", []).duplicate(true)
	_jobs[token].next_events = result.get("next_events", []).duplicate(true)
	_jobs[token].cursor = STEPS.size()
	return _finish(token)

func _empty_sections() -> Dictionary:
	return {"actions": [], "people": [], "world": [], "kingdom": []}

func _known_field(field: Variant, world: Dictionary) -> String:
	if not field is Dictionary or field.get("visibility", "hidden") != "known":
		return ""
	for fact in field.get("requires", []):
		if fact.get("fact_id", "") not in world.get("known_targets", {}).get(fact.get("target_id", ""), {}).get("fact_ids", []):
			return ""
	return str(field.get("text", ""))

func _public_sections(records: Array, world: Dictionary) -> Dictionary:
	var sections := _empty_sections()
	for record in records:
		if record.get("visibility", "hidden") != "known" or record.get("category", "") not in CATEGORIES:
			continue
		var happened := _known_field(record.get("happened", {}), world)
		if happened.is_empty():
			continue
		# 白名单投影：分数、隐藏条件、私有状态、次日秘密事件均不进入回顾数据。
		sections[record.category].append({"action_index": record.get("action_index", -1), "title": str(record.get("title", "")), "happened": happened, "reason": _known_field(record.get("reason", {}), world), "direction": _known_field(record.get("direction", {}), world)})
	return sections

func receipt(token: String) -> Dictionary:
	return _receipts.get(token, {}).duplicate(true)

func history(preview := false) -> Array:
	var results: Array = []
	for token in _history[_profile(preview)]:
		results.append(receipt(token))
	return results

func clear_history(preview := false) -> void:
	_history[_profile(preview)].clear()

func committed_world(token: String, morning := false) -> Dictionary:
	if morning:
		return _morning.get(token, {}).get("world", {}).duplicate(true) if _morning.get(token, {}).get("status", "") == "complete" else {}
	return _jobs[token].world.duplicate(true) if _receipts.has(token) else {}

func begin_next_day(token: String) -> bool:
	if not _receipts.has(token) or _requests[token].day >= 10 or _morning.has(token):
		return false
	_morning[token] = {"status": "queued"}
	_run_morning.call_deferred(token)
	return true

func _run_morning(token: String) -> void:
	if _morning[token].status != "queued":
		return
	_morning[token].status = "running"
	var job: Dictionary = _jobs[token]
	var profile := _profile(job.request.preview_only)
	var context := {"day": job.request.day + 1, "world": job.world.duplicate(true), "events": job.next_events.duplicate(true), "preview_only": job.request.preview_only}
	var result: Dictionary = {"status": "complete", "world": context.world}
	if _morning_adapters.has(profile):
		var value: Variant = _morning_adapters[profile].call(context)
		result = value if value is Dictionary else {"status": "pending"}
	elif not context.events.is_empty():
		result = {"status": "pending"}
	if result.get("status", "pending") != "complete" or result.get("world", {}).get("preview_only", false) != job.request.preview_only:
		_morning[token].status = "pending"
		morning_ready.emit({"request_id": token, "status": "needs_rule", "message": "次日必须事件尚未处理完成，白天规划保持关闭。"})
		return
	_morning[token] = {"status": "complete", "world": result.world.duplicate(true)}
	morning_ready.emit({"request_id": token, "status": "complete", "day": context.day})

func resume_morning(token: String) -> bool:
	if not _morning.has(token) or _morning[token].status != "pending":
		return false
	_morning[token].status = "queued"
	_run_morning.call_deferred(token)
	return true
