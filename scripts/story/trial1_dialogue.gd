extends RefCounted
## The first five rounds use approved scripts. Later rounds only split existing prose.
const SCRIPT_PATH := "res://data/story/trial1_dialogue.json"
var script_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCRIPT_PATH))

func lines_for(state, section: String) -> Array:
	var key := section
	if state.round_number == 5 and section == "B" and state.flags.has("salt_hurt"):
		key = "B_apology"
	var chapter: Dictionary = script_data.rounds.get(str(state.round_number), {})
	if chapter.has(key):
		var lines: Array = []
		for line in chapter[key]:
			if matches(state, str(line.get("when", ""))):
				lines.append({"speaker": line.speaker, "text": line.text})
		return lines
	if section == "opening":
		return split_prose(state.opening())
	if section in ["A", "B", "C"]:
		return split_prose(state.result_text(section))
	if section == "ending":
		return split_prose(state.ending_text())
	if section == "closing":
		var text: String = state.event().closing
		if state.round_number == 10:
			text += "\n\n古物、传闻与禁书相互呼应。为什么海洋的信息只能以残片流通？下一站，旧学城。"
		return split_prose(text)
	return []

func matches(state, expression: String) -> bool:
	if expression.is_empty():
		return true
	for alternative in expression.split("|"):
		var accepted := true
		for term in alternative.split("&"):
			var atom := term.strip_edges()
			var negate := atom.begins_with("!")
			if negate:
				atom = atom.substr(1)
			var pair := atom.split(":", true, 1)
			if pair.size() != 2:
				return false
			var value := false
			match pair[0]:
				"evidence": value = bool(state.evidence.get(pair[1], false))
				"flag": value = state.flags.has(pair[1])
				"channel": value = state.channels.has(pair[1])
				"choice":
					var choice: String = state.pending
					if choice.is_empty() and not state.history.is_empty() and int(state.history[-1].round) == state.round_number:
						choice = str(state.history[-1].choice)
					value = choice == pair[1]
				_: return false
			accepted = accepted and (not value if negate else value)
		if accepted:
			return true
	return false

func split_prose(text: String) -> Array:
	var lines: Array = []
	var speakers := ["你", "玩家", "螺螺", "哑伯", "盐嫂", "村民", "老人", "钱伯", "阿香", "刀郎", "巡查队员", "商队领队", "墨先生", "二笔", "高帽子"]
	for paragraph in text.split("\n", false):
		var body := paragraph.strip_edges()
		if body.is_empty():
			continue
		var speaker := ""
		var separator := body.find("：")
		if separator > 0 and speakers.has(body.left(separator)):
			speaker = body.left(separator)
			body = body.substr(separator + 1)
			if speaker == "你":
				speaker = "玩家"
		lines.append({"speaker": speaker, "text": body})
	return lines
