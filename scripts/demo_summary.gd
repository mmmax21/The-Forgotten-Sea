extends RefCounted
## Read-only projection of this run's discovered facts and public receipts.
const NPCS := ["fisher", "widow", "child", "craftsman"]
const TITLES := ["玛瑞斯的痕迹", "人物的合作与安全", "已知的现实变化", "仍然存在的阻碍", "未完成的调查方向"]

static func build(knowledge: RefCounted, history: Array) -> Dictionary:
	var world: Dictionary = knowledge.get_snapshot()
	var sections: Array = []
	for title in TITLES:
		sections.append({"title":title,"items":[]})
	for entry in world.get("journal_entries", {}).values():
		if int(entry.get("category", -1)) == 0:
			sections[0].items.append(entry.title + "\n" + entry.text)
		if str(entry.get("title", "")).contains("待查"):
			sections[4].items.append(entry.title + "\n" + entry.text)
		if not str(entry.get("open_question", "")).is_empty():
			sections[4].items.append(entry.title + "\n" + entry.open_question)
	for id in NPCS:
		if not knowledge.is_known(id): continue
		var view: Dictionary = knowledge.target_view(id)
		var safety: String = view.get("safety", "尚无已知安全状态")
		sections[1].items.append("%s\n合作：%s\n安全：%s\n已知风险：%s" % [view.name,view.cooperation,safety,"；".join(view.issues) if not view.issues.is_empty() else "暂无已发现的风险记录；不代表已经安全。"])
	for view in knowledge.visible_targets():
		if view.has_lead:
			sections[4].items.append(view.name + "\n" + "；".join(view.clues))
		if view.kind == "place" and view.id != knowledge.current_location_id() and view.place_status == "已知 · 不可到达":
			sections[3].items.append(view.name + "\n" + knowledge.known_route_reason(view.id))
	var feedback = preload("res://scripts/world_feedback.gd").new()
	for region in world.get("regional_feedback", {}):
		if not knowledge.is_known(region): continue
		var local := world.duplicate(true)
		local.current_location_id = region
		var scene: Dictionary = feedback.scene(local)
		if scene.state not in ["unknown", "dry"]:
			sections[2].items.append(knowledge.target_view(region).name + " · 当前观察\n" + scene.label)
		for index in range(3):
			var law: Dictionary = feedback.law(local,index)
			if law.state in ["questioned", "wavering", "ineffective"]:
				sections[2].items.append(knowledge.target_view(region).name + "\n" + law.description)
			elif law.state == "stable":
				sections[3].items.append(knowledge.target_view(region).name + "\n" + law.description)
	for receipt in history:
		for record in receipt.get("sections", {}).get("world", []):
			sections[2].items.append("第 %d 天 · 已知记录\n%s\n%s" % [receipt.day,record.title,record.happened])
	var group: Dictionary = world.get("group_access", {})
	if not group.get("unlocked", false) and not str(group.get("known_reason", "")).is_empty():
		sections[3].items.append("群体行动尚未开放\n" + group.known_reason)
	var empty := ["尚未保留与玛瑞斯有关的已发现记录。", "尚未认识这四名人物，不显示他们的结局或隐藏状态。", "本局尚无可公开的现实变化记录。", "尚无已知阻碍记录；这不表示所有限制都已解除。", "暂无已经开放而尚未完成的调查记录；未知答案不会被自动补全。"]
	for i in range(sections.size()):
		var unique: Array = []
		for item in sections[i].items:
			if item not in unique: unique.append(item)
		sections[i].items = unique if not unique.is_empty() else [empty[i]]
	var completed := history.any(func(receipt): return receipt.get("day", 0) == 10 and receipt.get("status", "") == "complete")
	return {"preview_only":world.get("preview_only", false),"night_complete":completed,"sections":sections}
