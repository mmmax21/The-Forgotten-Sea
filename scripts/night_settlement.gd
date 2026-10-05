extends RefCounted
## 统一批次入口：仅发布整批回执；正式规则未接入时保持待处理。
signal batch_requested(payload: Dictionary)
signal batch_ready(receipt: Dictionary)
var _requests: Dictionary = {}
var _receipts: Dictionary = {}


func submit(payload: Dictionary, preview_config: Dictionary = {}) -> bool:
	var token: String = payload.get("request_id", "")
	if token.is_empty() or _requests.has(token):
		return false
	_requests[token] = payload.duplicate(true)
	batch_requested.emit(payload.duplicate(true))
	if payload.get("preview_only", false) and preview_config.get("enabled", false):
		_run_preview.call_deferred(token, preview_config.duplicate(true))
	return true


func receipt(token: String) -> Dictionary:
	return _receipts.get(token, {}).duplicate(true)


func complete_batch(token: String, result: Dictionary) -> bool:
	if not _requests.has(token) or _receipts.has(token):
		return false
	var request: Dictionary = _requests[token]
	if result.get("preview_only", false) != request.preview_only:
		return false
	# 失败依赖的 AP 规则未定义时，不能用成功回执掩盖或允许退款/重排。
	if result.get("movement_failed", false) and result.get("dependency_ap_policy", "pending") == "pending":
		var pending := {"request_id": token, "status": "needs_rule", "preview_only": request.preview_only, "message": "移动失败：后续依赖行动的 AP 处理尚待确认。计划保持锁定，不退款、不开放重排。"}
		batch_ready.emit(pending)
		return false
	var expected_cards: Array = []
	for entry in request.entries:
		if not entry.idea_id.is_empty():
			expected_cards.append(entry.idea_id)
	for idea_id in result.get("consumed_ideas", []):
		if idea_id not in expected_cards:
			return false
	var completed := result.duplicate(true)
	completed.request_id = token
	completed.status = "complete"
	_receipts[token] = completed
	batch_ready.emit(completed.duplicate(true))
	return true


func _run_preview(token: String, config: Dictionary) -> void:
	var payload: Dictionary = _requests[token]
	var position: String = payload.initial_location
	var consumed: Array[String] = []
	var lines: Array[String] = ["开发预览结算：仅测试整批交接、移动及用卡生命周期，不模拟剧情、信念变化或新发现。"]
	for entry in payload.entries:
		if entry.behavior == "move":
			if config.get("movement_outcome", "success") == "failure":
				complete_batch(token, {"preview_only": true, "movement_failed": true, "dependency_ap_policy": "pending"})
				return
			position = entry.target_id
		if not entry.idea_id.is_empty():
			consumed.append(entry.idea_id)
		lines.append("预览处理：%s · %s AP" % [entry.target_name, entry.ap_cost])
	if payload.entries.is_empty():
		lines.append("没有主动行动；已向统一入口提交空计划，世界事件尚未接入。")
	complete_batch(token, {"preview_only": true, "consumed_ideas": consumed, "final_location": position, "message": "\n".join(lines)})
