extends RefCounted
## 集市调查、传播与按日检查。
const Business := preload("res://scripts/story/trail2_market_business.gd")
const IDS := ["qian", "xiang", "dao"]
const NAMES := {"qian": "钱伯", "xiang": "阿香", "dao": "刀郎"}
const ACTIONS := {
	"qian_help": {"title": "核对货物记录", "npc": "qian", "ap": 2, "trust": 20, "relationship": true},
	"xiang_help": {"title": "送达普通旅客口信", "npc": "xiang", "ap": 1, "trust": 15, "relationship": true},
	"dao_help": {"title": "整理旧纸、校对普通样张", "npc": "dao", "ap": 2, "trust": 25, "relationship": true},
	"qian_pro": {"title": "以匹配物证记录专业说服", "npc": "qian", "ap": 1, "trust": 20, "alert": 10, "relationship": true, "professional": true, "informs": true},
	"xiang_pro": {"title": "核对村消息与独立证言", "npc": "xiang", "ap": 1, "trust": 15, "alert": 5, "relationship": true, "professional": true, "informs": true, "last_day": 8, "material": "testimony"},
	"dao_pro": {"title": "以已有P1底稿专业说服", "npc": "dao", "ap": 1, "trust": 25, "alert": 5, "relationship": true, "professional": true, "informs": true},
	"qian_protect": {"title": "隐去无关身份线索", "npc": "qian", "ap": 1, "alert": -10, "needs_informed": true},
	"xiang_protect": {"title": "约定安全联系时间地点", "npc": "xiang", "ap": 1, "alert": -10, "needs_informed": true},
	"dao_protect": {"title": "整理接单身份信息", "npc": "dao", "ap": 1, "alert": -10, "needs_informed": true},
	"qian_material": {"title": "取得古物来源记录", "npc": "qian", "ap": 1, "alert": 5, "support": true, "informs": true, "material": "antique"},
	"xiang_material": {"title": "核验独立旅客证言", "npc": "xiang", "ap": 1, "alert": 5, "support": true, "informs": true, "last_day": 8, "material": "testimony"},
	"dao_material": {"title": "取得旧文本对照底稿", "npc": "dao", "ap": 1, "alert": 5, "support": true, "informs": true, "material": "text"},
	"p1_antique": {"title": "渔村物证＋古物记录 → P1", "ap": 1, "recipe": ["village", "antique"], "claim": "P1", "direction": "antique"},
	"p1_traveler": {"title": "渔村物证＋旅客证言 → P1", "ap": 1, "recipe": ["village", "testimony"], "claim": "P1"},
	"p1_local": {"title": "古物记录＋独立旅客证言 → P1", "ap": 1, "recipe": ["antique", "testimony"], "claim": "P1", "direction": "antique"},
	"p2_text": {"title": "文本底稿＋对应禁令 → P2", "ap": 1, "recipe": ["text", "decree"], "claim": "P2", "direction": "document"},
}
# MVP以明确批次和特征配置匹配，绝不把任意两份材料拼成结论。
const MATERIALS := {
	"antique": {"name": "旧港古物来源底稿", "source": "academy_antique_batch_a", "feature": "old_port", "batch": "port_a"},
	"testimony": {"name": "异地旅客亲历证言", "source": "traveler_east_port", "feature": "old_port", "batch": "port_a"},
	"text": {"name": "海港篇旧新版本对照底稿", "source": "revision_batch_a", "feature": "censorship", "batch": "revision_a"},
}
const DECREE := "公开禁令：禁止抄录与流通《海港篇》旧版指定段落。实施日期与修订批次A对应。禁令本身不能证明海洋存在。"

static func enter(s) -> Dictionary:
	if not s.village_finished or not s.market.is_empty():
		return {"ok": false, "text": "需先结束渔村，且不能重复进入集市。"}
	s.market = {"finished": false, "done": {}, "relationships": {}, "claims": {}, "recipes": {}, "directions": {}, "messengers": {}, "penalty": {}, "heard_village": not s.publications.is_empty(), "report": ""}
	for id in IDS:
		s.people[id] = {"trust": {"qian": 40, "xiang": 45, "dao": 35}[id], "alert": {"qian": 45, "xiang": 40, "dao": 50}[id], "informed": false, "warning_day": 0, "reported": false}
	Business.initialize(s)
	s.day = 6
	s.ap = 2 # 抵达当天的3 AP中扣除1 AP路程。
	s.current_location = "market"
	_apply_penalties(s)
	var text: String = "第6天 · 抵达集市（移动消耗1 AP）。粮食与材料按实际持有人继承；村中托管物不会进入背包。\n第8天末旅客离开；第9天检查、第10天商队出发。第7—8天可公开投放；检查名单将提前公布。\n" + s.warning_text()
	if s.market.heard_village:
		text += "\n阿香听过渔村消息，但没有自动增加信任或获得独立证据。"
	text += "\n今日%d AP · %d粮食" % [s.ap, s.food]
	s.history.append(text)
	return {"ok": true, "text": text}

static func village_materials(s, records_only: bool = false, allow_fragment: bool = false) -> Array:
	var found := []
	for id in s.inventory:
		var item: Dictionary = s.inventory[id]
		if item.holder == "player" and item.source in ["husband_relic", "warehouse_fragment"] and (item.confirmed or (allow_fragment and id == "fragment")) and (not records_only or item.kind == "record"):
			found.append(id)
	return found

static func material_present(s, id: String) -> bool:
	return s.inventory.has("market_" + id) and s.inventory["market_" + id].holder == "player"

static func preview(s, id: String) -> Dictionary:
	var reasons := PackedStringArray()
	var lines := PackedStringArray()
	var action: Dictionary = ACTIONS.get(id, {})
	if id.begins_with("messenger_"):
		action = {"title": "向渔村传话", "npc": id.trim_prefix("messenger_"), "ap": 1, "alert": -20}
	if action.is_empty():
		return {"allowed": false, "text": "未知行动"}
	if s.market.is_empty() or s.day < 6 or s.day > 10 or s.market.finished:
		return {"allowed": false, "text": "当前不在集市自由行动阶段"}
	lines.append("%s · %d AP · 不消耗粮食" % [action.title, action.ap])
	if s.ap < action.ap:
		reasons.append("当日AP不足")
	if s.market.done.has(id):
		reasons.append("已完成，不能重复领取")
	if s.day > action.get("last_day", 10):
		reasons.append("旅客已离开，证言窗口关闭")
	if action.has("npc"):
		var npc: String = action.npc
		if not s.people.has(npc):
			return {"allowed": false, "text": "人物不存在"}
		var person: Dictionary = s.people[npc]
		if person.reported:
			reasons.append("人物已告密，不能恢复本阶段合作")
		if action.get("support", false) and (person.trust < 60 or person.alert >= 60 or person.reported):
			reasons.append("需T≥60、A<60且未告密")
		if action.get("needs_informed", false) and not person.informed:
			reasons.append("对方尚未知情")
		if action.get("relationship", false) and s.market.relationships.has(npc):
			reasons.append("普通帮助与专业说服的关系奖励只能二选一")
		if id == "qian_pro" and village_materials(s, true).is_empty():
			reasons.append("需随身持有特征匹配的已确认物证记录")
		if id == "xiang_pro" and (not s.market.heard_village or village_materials(s).is_empty()):
			reasons.append("需阿香听过村消息且玩家持有独立物证或记录")
		if id == "dao_pro" and not s.market.claims.has("P1"):
			reasons.append("需先通过其他调查形成有底稿的P1")
		if id.begins_with("messenger_"):
			if npc not in ["salt", "mute", "luo"] or s.day != 6 or person.warning_day != 6 or person.reported:
				reasons.append("仅第6天尚有渔村预警时可传话，每人一次")
			lines.append("取消该人物参与和合作，保留知情与既成传播；远处材料不会自动回到背包。")
		var after: Dictionary = s._person_after(action)
		lines.append("信任%d→%d · 警戒%d→%d\n行动后：%s" % [person.trust, after.trust, person.alert, after.alert, s.status(after)])
		if after.warning_day > 0:
			lines.append("预警到第%d天末复查" % after.warning_day)
	if action.has("material"):
		if material_present(s, action.material):
			reasons.append("该材料已取得，不能再次领取")
		lines.append("取得调查底稿：%s，玩家持有；不是传播副本。" % MATERIALS[action.material].name)
	if action.has("recipe"):
		for part in action.recipe:
			if part == "village":
				if village_materials(s, false, id == "p1_antique").is_empty():
					reasons.append("缺少随身渔村匹配物证或记录")
			elif part != "decree" and not material_present(s, part):
				reasons.append("缺少" + MATERIALS[part].name)
		lines.append("固定配方：%s。来源独立、特征／批次匹配。原件与同源记录不能算两个来源。" % action.title)
		lines.append("P1：海洋痕迹并非只在渔村。" if action.claim == "P1" else "P2：海洋信息受到针对性流通限制，不等于已证明系统性改写全部历史。")
		if id == "p1_antique":
			lines.append("本原型遗迹刻痕与旧港古物特征匹配；如使用未辨认碎片，此1 AP包含辨认，不另收费。")
		lines.append("解锁旧学城方向：" + {"antique": "古物流转来源", "document": "文献来源"}.get(action.get("direction", ""), "本配方不额外解锁"))
	if not reasons.is_empty():
		lines.append("不能执行：\n" + "\n".join(reasons))
	return {"allowed": reasons.is_empty(), "text": "\n\n".join(lines)}

static func execute(s, id: String) -> Dictionary:
	var check := preview(s, id)
	if not check.allowed:
		return {"ok": false, "text": check.text}
	var action: Dictionary = ACTIONS.get(id, {})
	if id.begins_with("messenger_"):
		action = {"npc": id.trim_prefix("messenger_"), "ap": 1, "alert": -20}
	s.ap -= int(action.ap)
	if action.has("npc"):
		s.people[action.npc] = s._person_after(action)
	if action.get("relationship", false):
		s.market.relationships[action.npc] = id
	if action.has("material"):
		var item: Dictionary = MATERIALS[action.material].duplicate(true)
		item.merge({"kind": "draft", "holder": "player", "location": "inventory", "confirmed": true})
		s.inventory["market_" + action.material] = item
	if action.has("recipe"):
		s.market.recipes[id] = action.recipe.duplicate()
		s.market.claims[action.claim] = true
		if action.has("direction"):
			s.market.directions[action.direction] = true
		if id == "p1_antique" and s.inventory.has("fragment") and s.inventory.fragment.holder == "player":
			s.inventory.fragment.confirmed = true
			s.inventory.fragment.name = "船体构件"
	if id.begins_with("messenger_"):
		s.market.messengers[action.npc] = true
		if s.storage.has(action.npc):
			s.storage[action.npc].clear()
		if action.npc == "salt" and not s.spread.is_empty():
			s.spread["ongoing_cancelled"] = true
	s.market.done[id] = true
	s.history.append("第%d天 · 集市调查\n%s" % [s.day, check.text])
	return {"ok": true, "text": check.text + "\n\n已执行，剩余%d AP" % s.ap}

static func _apply_penalties(s) -> void:
	for penalty in [s.report_penalty, s.market.penalty]:
		if not penalty.is_empty() and not penalty.applied and penalty.due_day == s.day:
			s.ap -= 1
			penalty.applied = true

static func end_preview(s) -> Dictionary:
	if s.market.finished:
		return {"allowed": false, "text": s.market.report}
	var text: String = "结束第%d天，剩余%d AP作废。\n%s" % [s.day, s.ap, s.warning_text()]
	if s.day == 8:
		text += "\n今晚旅客离开，此后不能取得证言；已取得的材料保留。"
	if s.day == 10:
		text += "\n今日先处理预警，再检查已公布据点，最后复查商队发送条件。"
	text += "\n" + Business.inspection_text(s) + "\n" + Business.summary(s)
	return {"allowed": true, "text": text}

static func end_day(s, expected_day: int) -> Dictionary:
	if s.market.finished or (expected_day != -1 and expected_day != s.day):
		return {"ok": false, "text": "不能重复结束当天"}
	Business.initialize(s)
	var lines := PackedStringArray(["第%d天结束。" % s.day])
	s.refresh_warnings()
	for npc in s.people:
		var person: Dictionary = s.people[npc]
		if person.warning_day > 0 and person.warning_day <= s.day and s._at_risk(person):
			person.reported = true
			person.warning_day = 0
			var village: bool = npc not in IDS
			var penalty: Dictionary = s.report_penalty if village else s.market.penalty
			if penalty.is_empty():
				penalty.merge({"source": "village" if village else "market", "due_day": s.day + 1, "applied": false})
			lines.append("%s到期告密；只影响实际知情内容。" % s.NAMES[npc])
			Business.report_actor(s, npc)
	lines.append(Business.inspect(s))
	if s.day == 10:
		lines.append(Business.depart(s))
		s.market.finished = true
		s.ap = 0
		s.market.report = "集市调查阶段完成\n主张：%s\n学城方向：%s\n%s\n传播与渠道：\n%s" % ["、".join(s.market.claims.keys()), "、".join(s.market.directions.keys().map(func(key): return {"antique": "古物流转来源", "document": "文献来源"}.get(key, key))), s.warning_text(), Business.summary(s)]
		lines.append(s.market.report)
	else:
		s.day += 1
		s.ap = 3
		_apply_penalties(s)
		lines.append("第%d天开始，%d AP；粮食不补满。" % [s.day, s.ap])
		lines.append(Business.start_day(s))
		if s.day == 9:
			lines.append("旅客窗口已关闭；已取得的材料与既成传播保留。")
	var text: String = "\n\n".join(lines)
	s.history.append(text)
	return {"ok": true, "text": text}
