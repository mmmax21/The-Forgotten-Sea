extends RefCounted
## 只映射既有离散状态，不计算信念阈值、法则效力或通行资格。
const IDS = ["sea", "items", "travel"]
const FULL = ["大海从不存在。", "未经允许禁止使用特定物品。", "未经允许禁止跨越区域。"]
const SHORT = ["大海从不存在", "特定物品受限", "未经允许禁止跨区"]
var styles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/feedback_styles.json"))

func law(snapshot: Dictionary, index: int) -> Dictionary:
	var region: String = snapshot.get("current_location_id", "")
	var raw: Dictionary = snapshot.get("regional_feedback", {}).get(region, {}).get("laws", {}).get(IDS[index], {})
	var state: String = raw.get("state", "unknown") if raw.get("known", false) else "unknown"
	if not styles.laws.has(state):
		state = "unknown"
	var text: String = FULL[index] + "\n当前地区：" + styles.laws[state].label
	text += "\n已知影响：" + "；".join(raw.get("known_effects", [])) if state != "unknown" and not raw.get("known_effects", []).is_empty() else "\n尚无已知影响记录。"
	return {"state": state, "label": styles.laws[state].label, "pattern": styles.laws[state].pattern, "title": SHORT[index], "description": text}

func idea(snapshot: Dictionary, id: String) -> Dictionary:
	var belief: String = snapshot.get("idea_beliefs", {}).get(snapshot.get("current_location_id", ""), {}).get(id, "未知")
	return {"label": belief, "pattern": styles.belief_patterns.get(belief, "unknown")}

func scene(snapshot: Dictionary) -> Dictionary:
	var raw: Dictionary = snapshot.get("regional_feedback", {}).get(snapshot.get("current_location_id", ""), {}).get("scene", {})
	if not raw.get("known", false) or raw.get("kind", "") != "canal" or not styles.scenes.has(raw.get("state", "")):
		return {"state": "unknown", "label": "地区场景 · 状态未接入", "layers": [], "target_id": ""}
	var result: Dictionary = styles.scenes[raw.state].duplicate(true)
	result.state = raw.state
	result.label = "石渠 · " + result.label
	result.target_id = raw.get("target_id", "")
	return result

func changes(before: Dictionary, after: Dictionary) -> Array:
	var result: Array = []
	var region: String = after.get("current_location_id", "")
	# 比较同一实际地区的两个快照；仅移动/重开视图不制造世界变化。
	var previous := before.duplicate(true)
	previous.current_location_id = region
	var old_scene := scene(previous)
	var new_scene := scene(after)
	if old_scene.state != new_scene.state and new_scene.state != "unknown" and after.get("known_targets", {}).has(new_scene.target_id):
		result.append({"text": new_scene.notice, "target_id": new_scene.target_id})
	for index in range(3):
		var old := law(previous, index)
		var current := law(after, index)
		var raw: Dictionary = after.get("regional_feedback", {}).get(region, {}).get("laws", {}).get(IDS[index], {})
		var target: String = raw.get("target_id", "")
		if index == 2 and previous.get("known_routes", {}).get(target, {}) != after.get("known_routes", {}).get(target, {}) and after.get("known_targets", {}).has(target):
			result.append({"text": "区域边界的通行条件发生变化。", "target_id": target})
		elif old.state != current.state and current.state != "unknown" and after.get("known_targets", {}).has(target):
			result.append({"text": "第%s法则在当地%s。" % [["一", "二", "三"][index], current.label], "target_id": target})
	var idea_targets: Dictionary = after.get("regional_feedback", {}).get(region, {}).get("idea_targets", {})
	for id in idea_targets:
		var target: String = idea_targets[id]
		if id in after.get("acquired_ideas", []) and idea(previous,id).label != idea(after,id).label and after.get("known_targets", {}).has(target):
			result.append({"text": "当地思想信念发生变化：" + idea(after,id).label + "。", "target_id": target})
	return result
