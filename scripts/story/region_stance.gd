extends RefCounted
## 地区支持度与全局警戒值。增减量在 data/region_stance.json，说明在 docs/data_formats.md。
## 支持度 = 当前地区居民个体支持度的平均值，四舍五入到整数。没有居民时为 0。
## 警戒值不按地区分开，不低于表里的 alert_min。暂不设上限。
## apply 不检查、也不扣除行动点。调用方确认并且 preview.ok 之后再调用。

const TABLE_PATH := "res://data/region_stance.json"

static var _table := {}
static var _table_loaded := false


static func table() -> Dictionary:
	if _table_loaded:
		return _table
	_table_loaded = true
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
	_table = parsed if parsed is Dictionary else _fallback()
	return _table


static func normalize(saved = null) -> Dictionary:
	var source: Dictionary = saved if saved is Dictionary else {}
	var stored = source.get("supports", {})
	if not stored is Dictionary:
		stored = {}
	var supports := {}
	var regions = table().get("regions", {})
	if regions is Dictionary:
		for region_id in regions:
			for npc in _roster(str(region_id)):
				var id := str(npc.get("id", ""))
				if id == "":
					continue
				var value := int(stored[id]) if stored.has(id) else int(npc.get("support", 0))
				supports[id] = maxi(_support_min(), value)
	var alert := int(source["alert"]) if source.has("alert") else int(table().get("alert", 0))
	return {"alert": maxi(_alert_min(), alert), "supports": supports}


static func region_of(location: String) -> String:
	var mapping = table().get("location_region", {})
	if mapping is Dictionary and mapping.has(location):
		return str(mapping[location])
	var regions = table().get("regions", {})
	if regions is Dictionary and regions.has(location):
		return location
	return location


static func region_name(region_id: String) -> String:
	var regions = table().get("regions", {})
	if regions is Dictionary and regions.get(region_id) is Dictionary:
		var name := str(regions[region_id].get("name", ""))
		if name != "":
			return name
	return region_id


static func regional_support(stance: Dictionary, region_id: String) -> int:
	var roster := _roster(region_id)
	if roster.is_empty():
		return 0
	var supports: Dictionary = stance.get("supports", {}) if stance.get("supports") is Dictionary else {}
	var total := 0
	var count := 0
	for npc in roster:
		var id := str(npc.get("id", ""))
		if id == "":
			continue
		total += int(supports.get(id, npc.get("support", 0)))
		count += 1
	if count == 0:
		return 0
	return int(round(float(total) / float(count)))


static func alert_of(stance: Dictionary) -> int:
	return maxi(_alert_min(), int(stance.get("alert", 0)))


## 不修改 stance。ok 为假时，确认弹窗只说明原因，调用方不要 apply。
static func preview(stance: Dictionary, action: String, region_id: String, ap: int) -> Dictionary:
	var spec := _action(action)
	var known := not spec.is_empty()
	var before_support := regional_support(stance, region_id)
	var before_alert := alert_of(stance)
	var after_support := before_support
	var after_alert := before_alert
	if known:
		var draft := stance.duplicate(true)
		apply(draft, action, region_id)
		after_support = regional_support(draft, region_id)
		after_alert = alert_of(draft)
	var cost := _ap_cost()
	var changed := known and (after_support != before_support or after_alert != before_alert)
	var affordable := known and ap >= cost and changed
	return {
		"action": action,
		"region_id": region_id,
		"region_name": region_name(region_id),
		"known": known,
		"changed": changed,
		"ok": affordable,
		"has_residents": not _roster(region_id).is_empty(),
		"ap_cost": cost,
		"ap_before": ap,
		"ap_after": ap - cost if affordable else ap,
		"support_before": before_support,
		"support_after": after_support,
		"alert_before": before_alert,
		"alert_after": after_alert,
	}


## 按设计表改 stance。不检查行动点。
static func apply(stance: Dictionary, action: String, region_id: String) -> void:
	var spec := _action(action)
	if spec.is_empty():
		return
	var supports: Dictionary = stance.get("supports", {}) if stance.get("supports") is Dictionary else {}
	var support_delta := int(spec.get("support", 0))
	for npc in _roster(region_id):
		var id := str(npc.get("id", ""))
		if id == "":
			continue
		var current := int(supports.get(id, npc.get("support", 0)))
		supports[id] = maxi(_support_min(), current + support_delta)
	stance["supports"] = supports
	stance["alert"] = maxi(_alert_min(), int(stance.get("alert", 0)) + int(spec.get("alert", 0)))


static func confirm_copy(plan: Dictionary) -> Dictionary:
	var spec := _action(str(plan.get("action", "")))
	var title := str(spec.get("title", "请确认"))
	if not plan.get("known", false):
		return {"title": "请确认", "text": "这项行动还没有写进数值表。"}
	if int(plan.get("ap_before", 0)) < int(plan.get("ap_cost", 0)):
		return {
			"title": title,
			"text": "行动点不足，无法%s。\n需要 %d AP，当前剩余 %d。\n支持度、警戒值和行动点都不会改变。" % [title, int(plan.get("ap_cost", 0)), int(plan.get("ap_before", 0))],
		}
	if not plan.get("changed", false):
		var idle := "这次不会改变支持度或警戒值，也不消耗行动点。"
		if str(plan.get("action", "")) == "hide":
			idle = str(spec.get("floor_summary", idle))
		idle += "\n支持度 %d → %d\n警戒值 %d → %d" % [int(plan.get("support_before", 0)), int(plan.get("support_after", 0)), int(plan.get("alert_before", 0)), int(plan.get("alert_after", 0))]
		return {"title": title, "text": idle}
	var lead := str(spec.get("lead", "")).replace("{region}", str(plan.get("region_name", "")))
	var summary := str(spec.get("summary", ""))
	if str(plan.get("action", "")) == "gather" and not plan.get("has_residents", false):
		summary = str(spec.get("empty_summary", summary))
	var lines: PackedStringArray = PackedStringArray()
	if lead != "":
		lines.append(lead)
	if summary != "":
		lines.append(summary)
	lines.append("支持度 %d → %d" % [int(plan.get("support_before", 0)), int(plan.get("support_after", 0))])
	lines.append("警戒值 %d → %d" % [int(plan.get("alert_before", 0)), int(plan.get("alert_after", 0))])
	lines.append("行动点 %d → %d" % [int(plan.get("ap_before", 0)), int(plan.get("ap_after", 0))])
	lines.append("确认后才会结算。取消则保持原样。")
	return {"title": title, "text": "\n".join(lines)}


static func _roster(region_id: String) -> Array:
	var regions = table().get("regions", {})
	if not regions is Dictionary or not regions.get(region_id) is Dictionary:
		return []
	var npcs = regions[region_id].get("npcs", [])
	return npcs if npcs is Array else []


static func _action(id: String) -> Dictionary:
	var actions = table().get("actions", {})
	if not actions is Dictionary or not actions.get(id) is Dictionary:
		return {}
	var raw: Dictionary = (actions[id] as Dictionary).duplicate()
	raw["support"] = int(raw.get("support", 0))
	raw["alert"] = int(raw.get("alert", 0))
	raw["title"] = str(raw.get("title", id))
	return raw


static func _ap_cost() -> int:
	return maxi(0, int(table().get("ap_cost", 1)))


static func _alert_min() -> int:
	return int(table().get("alert_min", 0))


static func _support_min() -> int:
	return int(table().get("support_min", 0))


static func _fallback() -> Dictionary:
	return {
		"alert": 0,
		"alert_min": 0,
		"support_min": 0,
		"ap_cost": 1,
		"actions": {
			"gather": {
				"title": "集会",
				"lead": "在{region}召集集会。",
				"summary": "居民会更接受海的想法，王国也更容易注意到这里。",
				"empty_summary": "这里还没有居民，支持度不变。警戒值仍会上升。",
				"support": 1,
				"alert": 1,
			},
			"hide": {
				"title": "隐藏",
				"lead": "暂时隐藏行踪。",
				"summary": "王国对你的注意会下降。本地区支持度不变。",
				"floor_summary": "警戒值已经到下限，不会再下降。这次不消耗行动点。",
				"support": 0,
				"alert": -1,
			},
		},
		"regions": {
			"fishing_village": {
				"name": "渔村",
				"npcs": [
					{"id": "fisher", "name": "老渔夫", "support": 0},
					{"id": "salt", "name": "盐嫂", "support": 0},
					{"id": "luoluo", "name": "螺螺", "support": 0},
					{"id": "yabo", "name": "哑伯", "support": 0},
				],
			},
			"ruins": {"name": "遗迹", "npcs": []},
		},
		"location_region": {"home": "fishing_village", "ruins": "ruins"},
	}
