extends RefCounted

static func run(context: Dictionary) -> Dictionary:
	var world: Dictionary = context.world.duplicate(true)
	var records: Array = []
	var introductions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/town_introductions.json"))
	for i in range(context.request.entries.size()):
		var entry: Dictionary = context.request.entries[i]
		var text := ""
		if entry.target_id == "teacher" and entry.behavior == "talk" and not world.get("resolved_events", {}).has("teacher_loss"):
			text = "你与老师交流了眼前的遗迹调查。尚未因此获得新的线索或思想卡。"
		elif introductions.has(entry.target_id) and entry.behavior == "talk" and entry.get("scale", "personal") == "personal" and entry.get("idea_id", "").is_empty():
			var known: Dictionary = world.get("known_targets", {}).get(entry.target_id, {})
			if world.get("current_location_id", "") != "town" or known.get("known_location", {}).get("place_id", "") != "town":
				return {"status":"pending", "message":"交谈对象不在当前所在地，不能执行现场交流。"}
			text = introductions[entry.target_id].text
			if "talked" not in known.fact_ids:
				known.fact_ids.append("talked")
			known.latest_fact_id = "talked"
			if not world.has("journal_entries"): world.journal_entries = {}
			world.journal_entries["town_talk:" + entry.target_id] = {"category":2,"title":entry.target_name + " · 最近的交流","text":"第 %d 天：%s" % [context.request.day,text]}
		elif entry.target_id in ["ruin_record", "unknown_object"] and entry.behavior == "investigate":
			var target: Dictionary = world.known_targets[entry.target_id]
			if "found" not in target.fact_ids: target.fact_ids.append("found")
			target.latest_fact_id = "found"
			target.investigation_open = false
			if entry.target_id == "ruin_record":
				text = "你在残缺文字中辨认出玛瑞斯的名字。文字仍不完整，其余含义有待进一步线索。"
				world.journal_entries.record = {"category":0,"title":"玛瑞斯 · 残文中的名字","text":text,"open_question":"残文其余含义尚未辨明，仍需进一步线索。"}
			else:
				text = "你检查并记录了不明物件。它的用途仍未辨明，尚不能据此使用它。"
				world.journal_entries.object = {"category":1,"title":"不明物件 · 已记录","text":text,"open_question":"物件用途尚未辨明，目前没有开放继续调查的条件。"}
		else:
			return {"status":"pending","message":"此行动的正式判定尚未接入。保留锁定计划，等待规则适配器；没有用教学文本替代结果。"}
		records.append({"category":"actions","action_index":i,"visibility":"known","title":entry.target_name + " · " + entry.behavior_name,"happened":{"visibility":"known","text":text},"reason":{"visibility":"known","text":"依据本次安排完成现场交流或观察。"},"direction":{"visibility":"known","text":"可在手记复查已知记录；新的调查仍须安排计划。"}})
	return {"status":"complete","world":world,"records":records,"consumed_ideas":[]}
