extends RefCounted
## Fifteen fixed events; UI and persistence share this single source of rules.
const DATA_PATH := "res://data/story/trial1.json"
const NPC_STATES := ["未接触", "已知情", "愿意协助", "保持沉默", "失去协助", "已告密"]
var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
var round_number := 1
var ap := 3
var faith := 0
var alert := 0
var phase := "ready"
var pending := ""
var pending_text := ""
var evidence: Dictionary = {}
var npc: Dictionary = {}
var channels: Array = []
var flags: Array = []
var turn_clues: Array = []
var history: Array = []
var generic_used := false
var ending := ""
var ending_cause := ""
var report := ""
## Frozen dialogue lines + current cursor; separate from once-only game settlement.
var presentation: Dictionary = {}

func event() -> Dictionary:
	return data.events[round_number - 1]

func region() -> int:
	return int(event().region)

func registered(scope := "all") -> Array:
	var result: Array = []
	for id in evidence:
		if not evidence[id]:
			continue
		var entry: Dictionary = data.evidence[id]
		if scope == "village" and int(entry.region) != 0:
			continue
		if scope == "external" and int(entry.region) >= 2:
			continue
		result.append(id)
	return result

func categories(scope := "all") -> Array:
	var result: Array = []
	for id in registered(scope):
		var category: String = data.evidence[id].category
		if not result.has(category):
			result.append(category)
	return result

func evidence_names(ids: Array) -> String:
	var names := PackedStringArray()
	for id in ids:
		names.append(str(data.evidence[id].name))
	return "、".join(names)

func option(id: String) -> Dictionary:
	for raw in event().options:
		if str(raw.id) != id:
			continue
		var value: Dictionary = raw.duplicate(true)
		if round_number == 5 and id == "A":
			if flags.has("public_tide"):
				value.f += 1
			if flags.has("salt_help") and not flags.has("salt_help_used"):
				value.a -= 1
		if round_number == 5 and id == "B" and flags.has("salt_hurt"):
			value.title = "向盐嫂道歉，再与老人核对遗物"
			value.cost = 2
			value.evidence = ["copper", "chart"]
			value.npc = {"盐嫂": "愿意协助"}
			value.flags = ["salt_help"]
			value.text = "你先向盐嫂道歉，承认自己只顾寻找东西，忽略了她的失去。\n\n盐嫂沉默了很久，终于拿出布包：“这次，请你先记住他是一个人。”\n\n你将铜片与半页航海图登记下来，再与几位老人私下核对他们关于远方水域的记忆。"
		return value
	return {}

func blocked_reason(id: String) -> String:
	var value := option(id)
	if value.is_empty():
		return "无此选项"
	if phase != "ready":
		return "本回合已作出选择"
	if ap < int(value.cost):
		return "行动点不足"
	if alert >= 14 and bool(value.get("high_alert", false)):
		return {7: "客栈受到监视，阿香不再替你传话", 8: "熟人网络被盯上，无法隐蔽分发", 10: "商队受到检查，领队拒绝夹带材料"}.get(round_number, "警戒过高")
	var req: String = value.get("requirement", "")
	var scope := "village" if req == "village2" else ("external" if req == "external2" else "all")
	var needed := 3 if req == "final3" else (1 if req == "any1" else 2)
	if not req.is_empty() and categories(scope).size() < needed:
		var prefix := "渔村" if scope == "village" else ("外部" if scope == "external" else "")
		return "需要 %d 类%s已登记证据，目前 %d 类" % [needed, prefix, categories(scope).size()]
	if req == "final3":
		var regions: Array = []
		for key in registered():
			if not regions.has(data.evidence[key].region):
				regions.append(data.evidence[key].region)
		if regions.size() < 2:
			return "公开传播需要来自至少两个地区的证据"
	return ""

func begin(id: String) -> bool:
	if not blocked_reason(id).is_empty():
		return false
	pending = id
	pending_text = result_text(id)
	phase = "result"
	return true

func result_text(id: String) -> String:
	var value := option(id)
	var text: String = value.text
	if round_number == 5 and id == "A":
		text = "你将%s摆在一起。\n\n你：“这些记录来自不同的人，却都指向同一个地方——海。”\n\n集会第一次认真讨论起这个词。" % evidence_names(registered("village"))
		if flags.has("children"):
			text += "\n\n孩子们主动说起那枚贝壳，人群中的疑问有了回应。"
		if channels.has("潮歌传播"):
			text += "\n\n孩子们敲着船板唱起潮歌，老人轻轻跟上节拍。"
		if flags.has("public_tide"):
			text += "\n\n村民拿来水位记录。潮汐为你的解释提供了共同见证。"
		if flags.has("salt_help") and not flags.has("salt_help_used"):
			text += "\n\n盐嫂替你保管原件，只把副本带到集会，减少了暴露的痕迹。"
	if round_number == 6 and id == "A" and evidence.get("copper", false):
		text += "\n\n你将它与盐嫂铜片的拓记对照：两者的波浪纹几乎相同。"
	if round_number == 13 and id == "A":
		text += "\n\n辩论结束后，高帽子将你的名字与展示的材料报告给了审查官。"
	if round_number == 15 and id in ["A", "B"]:
		text += "\n\n本次使用的证据：" + evidence_names(registered()) + "。"
	return text

func settle() -> bool:
	if phase != "result" or pending.is_empty():
		return false
	var value := option(pending)
	ap -= int(value.cost)
	faith += int(value.f)
	var old_alert := alert
	alert = maxi(0, alert + int(value.a))
	for id in value.evidence:
		evidence[id] = true
	for id in value.clues:
		if not evidence.get(id, false):
			evidence[id] = false
			if not turn_clues.has(id):
				turn_clues.append(id)
	for name in value.npc:
		if npc.get(name, "未接触") != "已告密":
			npc[name] = value.npc[name]
	for channel in value.channels:
		if not channels.has(channel):
			channels.append(channel)
	for flag in value.flags:
		if not flags.has(flag):
			flags.append(flag)
	if round_number == 5 and pending == "A" and flags.has("salt_help") and not flags.has("salt_help_used"):
		flags.append("salt_help_used")
	report = "信仰 F %+d　警戒 A %+d　消耗 %d AP" % [int(value.f), alert - old_alert, int(value.cost)]
	if not value.evidence.is_empty():
		report += "\n已登记：" + evidence_names(value.evidence)
	if not turn_clues.is_empty():
		report += "\n待整理：" + evidence_names(turn_clues)
	for name in value.npc:
		report += "\n%s：%s" % [name, npc[name]]
	if not value.channels.is_empty():
		report += "\n建立渠道：" + "、".join(value.channels)
	history.append({"round": round_number, "title": event().title, "choice": pending, "action": value.title, "report": report})
	pending = ""
	phase = "aftermath"
	if alert >= 18:
		ending = "forgotten"
		ending_cause = "alert"
		phase = "ending"
	return true

func can_generic(kind: String) -> bool:
	return phase == "aftermath" and not generic_used and ap >= 1 and (kind == "careful" or (kind == "notes" and not turn_clues.is_empty()))

func generic(kind: String) -> bool:
	if not can_generic(kind):
		return false
	ap -= 1
	generic_used = true
	var text := ""
	if kind == "careful":
		var old := alert
		alert = maxi(0, alert - 1)
		text = "谨慎收尾：A %+d。" % (alert - old)
	else:
		for id in turn_clues:
			evidence[id] = true
		text = "整理调查笔记：已登记" + evidence_names(turn_clues) + "。"
		turn_clues.clear()
	report += "\n" + text
	history[-1].report = report
	return true

func next_round() -> bool:
	if phase != "aftermath":
		return false
	if round_number == 15:
		ending = "forgotten" if alert >= 18 else ("sea" if faith >= 20 else ("liberation" if faith >= 12 and alert <= 10 else "forgotten"))
		ending_cause = "alert" if alert >= 18 else "final"
		phase = "ending"
		return true
	round_number += 1
	ap = 3
	phase = "ready"
	generic_used = false
	turn_clues.clear()
	pending_text = ""
	report = ""
	presentation = {}
	return true

func opening() -> String:
	var text := ""
	if round_number in [1, 6, 11]:
		text = str(data.regions[region()].intro) + "\n\n"
	if round_number == 6 and flags.has("village_public"):
		text += "还没到摊位，你就听见有人谈起渔村的贝壳与潮歌。那里的记录已经传到了集市。\n\n"
	if round_number == 11 and flags.has("caravan"):
		text += "墨先生桌上放着商队送来的副本：“你来之前，我们已经读过这些材料。”\n\n"
	if round_number == 9:
		if channels.has("客栈传播"):
			text += "巡查队先包围了客栈，向阿香追问旅客的谈话。\n\n"
		if channels.has("大规模印刷"):
			text += "带着传单的巡查队直奔印刷坊，逐一检查印版。\n\n"
	if round_number == 14 and npc.get("高帽子") == "已告密":
		text += "高帽子的报告加快了搜查。审查官正按名单调走档案。\n\n"
	return text + str(event().intro)

func warning_text() -> String:
	if alert >= 18:
		return "记忆正在消退。"
	if alert >= 14:
		return "阿香记不起昨天讲过的故事。传播者开始退缩，部分隐蔽渠道关闭。A 达到 18 时，遗忘重临。"
	if alert >= 10:
		return "巡查与监视出现在街角。有人谈到大海时，忽然停顿。"
	if alert >= 6:
		return "官方开始关注你的调查。街上的目光多了起来。"
	return "调查尚未引起明显关注。"

func ending_text() -> String:
	var text: String = data.endings[ending].text
	if ending == "forgotten":
		text = ("一句话说到一半，所有人突然安静下来。那片蓝色从记忆中迅速褪去。" if ending_cause == "alert" else "你的记录没有形成足以延续的共同认知。日子过去，关于大海的记忆逐渐消散。") + "\n\n" + text
	return text

func snapshot() -> Dictionary:
	return {"version": 2, "round": round_number, "ap": ap, "faith": faith, "alert": alert, "phase": phase, "pending": pending, "pending_text": pending_text, "evidence": evidence, "npc": npc, "channels": channels, "flags": flags, "turn_clues": turn_clues, "history": history, "generic_used": generic_used, "ending": ending, "ending_cause": ending_cause, "report": report, "presentation": presentation}

func save_to(path: String) -> Error:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(snapshot()))
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path)

func load_from(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or int(value.get("version", 0)) not in [1, 2]:
		return false
	for key in ["evidence", "npc"]:
		if not value.get(key) is Dictionary:
			return false
	for key in ["channels", "flags", "turn_clues", "history"]:
		if not value.get(key) is Array:
			return false
	var saved_round := int(value.get("round", 0))
	var saved_phase := str(value.get("phase", ""))
	if saved_round < 1 or saved_round > 15 or saved_phase not in ["ready", "result", "aftermath", "ending"]:
		return false
	if saved_phase == "result" and str(value.get("pending", "")) not in ["A", "B", "C"]:
		return false
	if saved_phase == "ending" and not data.endings.has(value.get("ending", "")):
		return false
	for id in value.evidence:
		if not data.evidence.has(id) or not value.evidence[id] is bool:
			return false
	for id in value.turn_clues:
		if not data.evidence.has(id):
			return false
	for name in value.npc:
		if value.npc[name] not in NPC_STATES:
			return false
	var saved_presentation = value.get("presentation", {})
	if not saved_presentation is Dictionary:
		return false
	if not saved_presentation.is_empty():
		var stage := str(saved_presentation.get("stage", ""))
		var expected := {"idle": "ready", "opening": "ready", "choices": "ready", "result": "result", "closing": "aftermath", "aftermath": "aftermath", "ending": "ending", "finished": "ending"}
		if not expected.has(stage) or expected[stage] != saved_phase:
			return false
		if stage in ["opening", "result", "closing", "ending"]:
			var saved_lines = saved_presentation.get("lines")
			if not saved_lines is Array or saved_lines.is_empty():
				return false
			for line in saved_lines:
				if not line is Dictionary or not line.get("speaker") is String or not line.get("text") is String:
					return false
			var cursor := int(saved_presentation.get("index", -1))
			if cursor < 0 or cursor >= saved_lines.size():
				return false
	round_number = saved_round
	ap = clampi(int(value.get("ap", 3)), 0, 3)
	faith = int(value.get("faith", 0))
	alert = maxi(0, int(value.get("alert", 0)))
	phase = saved_phase
	pending = str(value.get("pending", ""))
	pending_text = str(value.get("pending_text", ""))
	evidence = value.evidence
	npc = value.npc
	channels = value.channels
	flags = value.flags
	turn_clues = value.turn_clues
	history = value.history
	generic_used = bool(value.get("generic_used", false))
	ending = str(value.get("ending", ""))
	ending_cause = str(value.get("ending_cause", ""))
	report = str(value.get("report", ""))
	presentation = saved_presentation
	if alert >= 18:
		ending = "forgotten"
		ending_cause = "alert"
		phase = "ending"
		if presentation.get("stage", "") not in ["ending", "finished"]:
			presentation = {}
	return true
