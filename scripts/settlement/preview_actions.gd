extends RefCounted
## 沿用阶段3的隔离生命周期测试，不提供正式成功公式或剧情反应。
static func execute(context: Dictionary, config: Dictionary) -> Dictionary:
	var world: Dictionary = context.world.duplicate(true)
	var records: Array = []
	var consumed: Array = []
	for index in range(context.request.entries.size()):
		var entry: Dictionary = context.request.entries[index]
		var happened := "尚未执行正式%s判定；仅完成开发预览中的计划交接与用卡生命周期测试。" % entry.behavior_name
		var reason := "项目尚未接入该行为的效果规则，不能据此认定人物合作、获得线索或信念改变。"
		if entry.behavior == "move":
			if config.get("movement_outcome", "success") == "failure":
				return {"status": "pending", "message": "预览移动失败：后续依赖行动的 AP 处理待确认。计划保持锁定；本批暂存结果未写入世界，不退款、不开放重排。"}
			world.current_location_id = entry.target_id
			happened = "开发预览中已到达%s。" % entry.target_name
			reason = "沿用独立预览配置的移动结果；这不是正式移动成功判定。"
		if not entry.idea_id.is_empty():
			consumed.append(entry.idea_id)
		records.append({"category": "actions", "action_index": index, "visibility": "known", "title": "%s · %s" % [entry.target_name, entry.behavior_name], "happened": known(happened), "reason": known(reason), "direction": known("下一天可依据已经知道的目标与实际位置继续安排；本次没有揭示新条件。")})
	return {"status": "complete", "world": world, "records": records, "consumed_ideas": consumed}

static func known(text: String) -> Dictionary:
	return {"text": text, "visibility": "known"}
