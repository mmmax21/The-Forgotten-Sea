extends RefCounted
## 规则状态独立于界面；渔村五天行动与日初／日末事件。
const Academy := preload("res://scripts/story/trail2_academy.gd")
var academy: Dictionary = {}

const Market := preload("res://scripts/story/trail2_market.gd")
var market: Dictionary = {}

const ACTIONS := {
	"feed": {"title": "送粮", "group": "salt", "ap": 1, "food": 1, "npc": "salt", "trust": 15, "result": "送出一份粮食，盐嫂愿意与你交谈。"},
	"press_relic": {"title": "追问丈夫遗物", "group": "salt", "ap": 1, "npc": "salt", "trust": -10, "alert": 15, "informs": true, "item": "relic", "result": "盐嫂为了让你离开，交出丈夫遗物。取得已确认物证，但信任降低、警戒上升；知情且信任不足时会进入告密预警。"},
	"listen": {"title": "倾听丈夫经历", "group": "salt", "ap": 1, "requires": ["feed"], "npc": "salt", "trust": 10, "alert": 5, "result": "你得知丈夫遗物的线索，也了解到家人安置的需要。"},
	"relic": {"title": "查看遗物", "group": "salt", "ap": 1, "requires": ["listen"], "npc": "salt", "support": true, "alert": 10, "informs": true, "item": "relic", "result": "盐嫂将丈夫遗物交给你。这是一份已确认的海洋证据。"},
	"protect": {"title": "安置家人", "group": "salt", "ap": 2, "food": 1, "requires": ["listen"], "npc": "salt", "alert": -20, "last_day": 3, "result": "家人乘运粮车前往村外亲戚处。"},
	"withdraw": {"title": "说明证据去向并撤回协助请求", "group": "salt", "ap": 1, "npc": "salt", "needs_informed": true, "alert": -10, "result": "盐嫂警戒降低10；取回交给她的全部材料，取消她的保管与传播安排。本阶段不再接受协助请求，知情状态保留。"},
	"repair": {"title": "修整旧物", "group": "mute", "ap": 1, "npc": "mute", "trust": 15, "result": "你帮哑伯修整旧物，他对你的信任增加了。"},
	"identify": {"title": "辨认碎片", "group": "mute", "ap": 1, "npc": "mute", "support": true, "needs_item": "fragment", "alert": 10, "informs": true, "result": "哑伯确认刻痕碎片是一块船体构件。原有碎片成为已确认证据。"},
	"hide_old": {"title": "收好危险旧物", "group": "mute", "ap": 1, "npc": "mute", "needs_informed": true, "alert": -10, "result": "哑伯收好危险旧物，警戒降低10。"},
	"rumor": {"title": "听见闻", "group": "luo", "ap": 1, "npc": "luo", "trust": 10, "result": "螺螺说遗迹有隐蔽入口，但尚未指出准确位置。"},
	"retrieve": {"title": "取回遗落物品", "group": "luo", "ap": 1, "requires": ["rumor"], "npc": "luo", "trust": 15, "result": "你取回螺螺遗落的物品，她指出遗迹准确入口。入口线不会使她知情。"},
	"clarify": {"title": "梳理不能公开说的内容", "group": "luo", "ap": 1, "npc": "luo", "needs_informed": true, "alert": -10, "result": "螺螺警戒降低10，仍记得你的调查。"},
	"survey": {"title": "自行勘察外围", "group": "warehouse", "ap": 1, "last_day": 4, "result": "你找到了遗迹准确入口。"},
	"clear": {"title": "清理入口", "group": "warehouse", "ap": 1, "last_day": 4, "result": "杂物已清理，可以进入遗迹。"},
	"search": {"title": "搜查内部", "group": "warehouse", "ap": 1, "requires": ["clear"], "last_day": 4, "item": "fragment", "result": "你找到刻痕碎片。用途尚未确认，可请哑伯辨认。"},
}
const NAMES := {"salt": "盐嫂", "mute": "哑伯", "luo": "螺螺", "qian": "钱伯", "xiang": "阿香", "dao": "刀郎", "mo": "墨先生", "er": "二笔", "gao": "高帽子"}
const ITEMS := {
	"relic": {"name": "丈夫遗物", "source": "husband_relic", "confirmed": true},
	"fragment": {"name": "刻痕碎片", "source": "warehouse_fragment", "confirmed": false},
}
var current_location := "fishing_village"
const PLACE_NAMES := {"fishing_village": "渔村", "ruins": "遗迹", "market": "集市", "old_academy": "旧学城"}

func travel_preview(destination: String) -> Dictionary:
	var reason := ""
	if destination not in ["fishing_village", "ruins"] or village_finished:
		reason = "当前不能前往该地点；跨区域请使用离场报告。"
	elif destination == current_location:
		reason = "你已经在这里，不消耗AP。"
	elif destination == "ruins" and day > 4:
		reason = "遗迹已封闭，不能再进入。"
	elif ap < 1:
		reason = "AP不足：移动需要1 AP，请结束今日后再出发。"
	return {"allowed": reason.is_empty(), "text": reason if not reason.is_empty() else "从%s前往%s，消耗1 AP，抵达后剩余%d AP。" % [PLACE_NAMES[current_location], PLACE_NAMES[destination], ap - 1]}

func travel(destination: String) -> Dictionary:
	var preview := travel_preview(destination)
	if not preview.allowed:
		return {"ok": false, "text": preview.text}
	ap -= 1
	current_location = destination
	var text := "抵达%s · 移动消耗1 AP · 剩余%d AP" % [PLACE_NAMES[destination], ap]
	history.append("第%d天 · %s" % [day, text])
	return {"ok": true, "text": text}

var day := 1
var ap := 3
var food := 2
var people := {
	"salt": {"trust": 40, "alert": 50, "informed": false, "warning_day": 0, "reported": false},
	"mute": {"trust": 50, "alert": 40, "informed": false, "warning_day": 0, "reported": false},
	"luo": {"trust": 35, "alert": 20, "informed": false, "warning_day": 0, "reported": false},
}
var completed: Dictionary = {}
var inventory: Dictionary = {}
var history: Array[String] = []
var entrance_known := false
var salt_assistance_revoked := false
var patrol_applied := false
var village_finished := false
# 按来源区域只生成一次；第5天的处罚保留给第6天。
var report_penalty: Dictionary = {}
var departure_snapshot: Dictionary = {}
# inventory 是唯一材料账本，holder 决定是否在玩家背包中。
var storage := {"salt": [], "mute": []}
var spread: Dictionary = {}
var publications: Array = []
var shown_to: Dictionary = {}
var record_serial := 0
var departure_report := ""
var outcomes: Dictionary = {}
const STASHES := {"salt": "床底隐蔽夹层", "mute": "工具箱暗格"}
const MATERIAL_ACTIONS := {
	"record_self": {"title": "自己制作记录", "ap": 2, "food": 0},
	"record_scribe": {"title": "请抄写摊制作记录", "ap": 1, "food": 1},
	"show": {"title": "私下展示证据", "ap": 1, "food": 0},
	"store": {"title": "安排保管", "ap": 1, "food": 0},
	"spread": {"title": "安排传播", "ap": 1, "food": 0},
	"retrieve": {"title": "取回材料并取消相关安排", "ap": 0, "food": 0},
}


func action_definition(id: String) -> Dictionary:
	var action: Dictionary = ACTIONS.get(id, {}).duplicate(true)
	if completed.has("press_relic"):
		if id == "feed":
			action.title = "赔礼并送粮"
			action.result = "你为先前的逼问道歉，留下粮食。盐嫂仍有顾虑，但愿意听你解释。"
		elif id == "listen":
			action.title = "倾听她的顾虑"
			action.trust = 15
			action.result = "你听完盐嫂对家人受牵连的担心，承认先前的逼问。信任增加15，警戒增加5；达到信任60可解除预警，警戒仍高时保持沉默。"
	return action


func actions_for(group: String) -> Array[String]:
	var result: Array[String] = []
	for id in ACTIONS:
		if ACTIONS[id].group == group:
			result.append(id)
	return result


func status(person: Dictionary) -> String:
	if person.reported:
		return "已告密"
	if person.trust >= 60:
		return "支持" if person.alert < 60 else "沉默"
	if person.alert >= 60:
		return "告密预警" if person.informed else "退缩"
	return "旁观／不合作"


func blocked_reasons(id: String) -> PackedStringArray:
	var reasons := PackedStringArray()
	if not ACTIONS.has(id):
		return PackedStringArray(["未知行动"])
	var action: Dictionary = action_definition(id)
	var required_place: String = "ruins" if action.group == "warehouse" else "fishing_village"
	if current_location != required_place:
		reasons.append("需先前往%s（移动1 AP）" % PLACE_NAMES[required_place])
	if village_finished:
		reasons.append("渔村阶段已结束")
	if completed.has(id):
		reasons.append("已完成，不能重复获得收益")
	for required in action.get("requires", []):
		if not completed.has(required):
			reasons.append("需先完成「%s」" % ACTIONS[required].title)
	if day > int(action.get("last_day", 5)):
		reasons.append("已超过行动截止日")
	if id in ["relic", "press_relic"]:
		if inventory.has("relic") or completed.has("relic") or completed.has("press_relic"):
			reasons.append("丈夫遗物已取得，两条取得路线互斥，不能重复领取或覆盖持有人")
		if people.salt.reported:
			reasons.append("盐嫂已经告密，不再交付遗物")
	if id == "survey" and entrance_known:
		reasons.append("已知道准确入口，无需重复勘察")
	if id == "clear" and not entrance_known:
		reasons.append("需先找到准确入口")
	if action.has("needs_item") and (not inventory.has(action.needs_item) or inventory[action.needs_item].get("holder", "player") != "player"):
		reasons.append("需持有「%s」" % ITEMS[action.needs_item].name)
	if action.has("npc"):
		var person: Dictionary = people[action.npc]
		if action.get("support", false) and (person.trust < 60 or person.alert >= 60 or person.reported):
			reasons.append("需要支持：信任≥60、警戒<60，且未告密")
		if action.get("needs_informed", false) and not person.informed:
			reasons.append("对方尚未知情")
	if ap < int(action.ap):
		reasons.append("AP不足：需同一天支付%d AP，当前%d" % [action.ap, ap])
	if food < int(action.get("food", 0)):
		reasons.append("粮食不足")
	return reasons


func _person_after(action: Dictionary) -> Dictionary:
	var person: Dictionary = people[action.npc].duplicate(true)
	person.trust = clampi(person.trust + int(action.get("trust", 0)), 0, 100)
	person.alert = clampi(person.alert + int(action.get("alert", 0)), 0, 100)
	person.informed = person.informed or action.get("informs", false)
	_update_warning(person)
	return person


func _at_risk(person: Dictionary) -> bool:
	return person.informed and person.trust < 60 and person.alert >= 60 and not person.reported


func _update_warning(person: Dictionary) -> void:
	if _at_risk(person):
		if person.warning_day == 0:
			person.warning_day = day + 1
	else:
		person.warning_day = 0


# 行动、固定事件均使用此规则：持续高危不刷新，解除后再次高危才重开。
func refresh_warnings() -> void:
	for person in people.values():
		_update_warning(person)


func preview(id: String) -> Dictionary:
	if not ACTIONS.has(id):
		return {"allowed": false, "text": "未知行动"}
	var action: Dictionary = action_definition(id)
	var lines := PackedStringArray(["成本：%d AP · %d份粮食" % [action.ap, action.get("food", 0)], "一次性行动"])
	if id == "press_relic":
		var projected := _person_after(action)
		var risk := "不补救将在第%d天结束时告密。" % projected.warning_day if projected.warning_day > 0 else "当前预计不会告密，但警戒上升可能阻止合作。"
		lines.insert(0, "提前取得遗物 · 信任−10 / 警戒＋15 / 盐嫂知情\n" + risk + "\n与正常查看遗物互斥。送粮后倾听她的顾虑可补救；预警期间也可选择撤回协助请求。")
	for required in action.get("requires", []):
		lines.append("前提：完成「%s」" % ACTIONS[required].title)
	if action.get("support", false):
		lines.append("前提：对方信任≥60、警戒<60，且未告密")
	if action.get("needs_informed", false):
		lines.append("前提：对方已知情")
	if action.has("needs_item"):
		lines.append("前提：持有「%s」" % ITEMS[action.needs_item].name)
	if id == "survey":
		lines.append("前提：尚不知道准确入口")
	if id == "clear":
		lines.append("前提：已找到准确入口")
	if action.has("last_day"):
		lines.append("截止：第%d天结束" % action.last_day)
	lines.append("\n" + action.result)
	if action.has("npc"):
		var before: Dictionary = people[action.npc]
		var after := _person_after(action)
		lines.append("\n信任 %d → %d\n警戒 %d → %d\n知情：%s → %s\n行动后：%s" % [before.trust, after.trust, before.alert, after.alert, "是" if before.informed else "否", "是" if after.informed else "否", status(after)])
		if after.warning_day > 0:
			lines.append("预警将在第%d天结束复查。" % after.warning_day)
	if action.has("item"):
		lines.append("材料去向：玩家持有原物。")
	if id == "identify":
		lines.append("材料仍由玩家持有，同一来源不增加份数。")
	var reasons := blocked_reasons(id)
	if not reasons.is_empty():
		lines.append("\n当前不能执行：\n" + "\n".join(reasons))
	return {"allowed": reasons.is_empty(), "text": "\n".join(lines)}


func execute(id: String) -> Dictionary:
	var check := preview(id)
	if not check.allowed:
		return {"ok": false, "text": check.text}
	var action: Dictionary = action_definition(id)
	ap -= int(action.ap)
	food -= int(action.get("food", 0))
	if action.has("npc"):
		people[action.npc] = _person_after(action)
	if action.has("item"):
		var item: Dictionary = ITEMS[action.item].duplicate(true)
		item.merge({"kind": "original", "holder": "player", "location": "inventory"})
		inventory[action.item] = item
	if id in ["survey", "retrieve"]:
		entrance_known = true
	if id == "identify":
		inventory.fragment.confirmed = true
		inventory.fragment.name = "船体构件"
	if id == "withdraw":
		salt_assistance_revoked = true
		for key in inventory:
			if inventory[key].holder == "salt":
				_take_back(key)
	completed[id] = true
	history.append("第%d天 · %s · %d AP／%d粮食\n%s" % [day, action.title, action.ap, action.get("food", 0), action.result])
	return {"ok": true, "text": check.text + "\n\n剩余：%d AP · %d份粮食" % [ap, food]}


func warning_text() -> String:
	var lines := PackedStringArray()
	for id in people:
		var person: Dictionary = people[id]
		if person.warning_day > 0 and not person.reported:
			lines.append("%s：第%d天末复查%s" % [NAMES[id], person.warning_day, "（今晚到期）" if person.warning_day <= day else ""])
	return "暂无告密预警" if lines.is_empty() else "\n".join(lines)


func end_day_preview() -> Dictionary:
	if not academy.is_empty():
		return Academy.end_preview(self)
	if not market.is_empty():
		return Market.end_preview(self)
	if village_finished:
		return {"allowed": false, "text": "渔村阶段已结束，可以查看阶段记录或重新试玩。"}
	var lines := PackedStringArray(["结束第%d天，剩余%d AP作废，粮食与材料保留。" % [day, ap]])
	var will_report := false
	for id in people:
		var person: Dictionary = people[id]
		if person.warning_day > 0 and not person.reported:
			if person.warning_day <= day:
				will_report = will_report or _at_risk(person)
				lines.append("%s：今晚复查，按当前状态%s。" % [NAMES[id], "将告密；本阶段失去合作资格" if _at_risk(person) else "解除预警"])
			else:
				lines.append("%s：预警保留至第%d天结束，今晚不会提前告密。" % [NAMES[id], person.warning_day])
	if day == 2:
		lines.append("明早巡查：仅当时已知情人物警戒＋10，可能进入沉默或新增预警。")
	if day == 3:
		lines.append("今晚家人安置窗口关闭。" + ("家人已安置，成果保留。" if completed.has("protect") else "尚未安置，之后不能补做。"))
	if day == 4:
		lines.append("今晚遗迹关闭，不能再勘察、清障或搜查；已取得碎片仍可辨认。")
	var penalized: bool = (will_report and report_penalty.is_empty()) or (not report_penalty.is_empty() and not report_penalty.applied and report_penalty.due_day == day + 1)
	if day < 5:
		lines.append("第%d天开始：%d AP，粮食不会补满。" % [day + 1, 2 if penalized else 3])
	else:
		lines.append("今晚结算后结束渔村阶段，不能再执行本地行动。")
		lines.append(arrangements_text())
		lines.append("先处理到期告密，再复查协助。失效材料退还；有效传播不会把原物留在玩家背包。")
		lines.append("未决预警与处罚保留供集市承接；可在离场报告中前往集市。")
		if penalized:
			lines.append("渔村首次告密处罚：第6天少1 AP，尚未执行。")
	return {"allowed": true, "text": "\n\n".join(lines)}


func end_day(expected_day: int = -1) -> Dictionary:
	if not academy.is_empty():
		return Academy.end_day(self, expected_day)
	if not market.is_empty():
		return Market.end_day(self, expected_day)
	if village_finished or (expected_day != -1 and expected_day != day):
		return {"ok": false, "text": "日期已变化或渔村阶段已结束，本次未重复结算。"}
	var ended_day := day
	var lines := PackedStringArray(["昨夜 · 第%d天结束\n剩余%d AP作废。" % [day, ap]])
	refresh_warnings()
	# 先复查预警，再关闭窗口，最后进入次日或离场。
	for id in people:
		var person: Dictionary = people[id]
		if person.warning_day > 0 and person.warning_day <= day and _at_risk(person):
			person.reported = true
			person.warning_day = 0
			lines.append("%s告密成立，本阶段失去合作资格；不没收玩家材料，不让其他人物自动知情。" % NAMES[id])
			if report_penalty.is_empty():
				report_penalty = {"source": "village", "due_day": day + 1, "applied": false}
				lines.append("渔村首次告密：第%d天少1 AP（本区域仅一次）。" % (day + 1))
	if day == 3:
		lines.append("家人安置窗口关闭；已完成的安置保留。")
	if day == 4:
		lines.append("遗迹关闭；背包中已有的碎片仍可辨认。")
	ap = 0
	if day == 5:
		village_finished = true
		_settle_arrangements()
		departure_snapshot = {
			"day": day, "food": food, "people": people.duplicate(true),
			"inventory": inventory.duplicate(true), "completed": completed.duplicate(true),
			"report_penalty": report_penalty.duplicate(true),
			"salt_assistance_revoked": salt_assistance_revoked,
			"storage": storage.duplicate(true), "spread": spread.duplicate(true),
			"publications": publications.duplicate(true), "shown_to": shown_to.duplicate(true),
			"entrance_known": entrance_known, "patrol_applied": patrol_applied,
			"report": departure_report, "outcomes": outcomes.duplicate(true),
		}
		lines.append("渔村阶段结束。材料与未决期限已保留，下一步可前往集市。")
		lines.append(warning_text())
		lines.append(departure_report)
	else:
		day += 1
		ap = 3
		if not report_penalty.is_empty() and not report_penalty.applied and report_penalty.due_day == day:
			ap -= 1
			report_penalty.applied = true
			lines.append("已执行渔村首次告密处罚，今日只有2 AP。")
		lines.append("今日 · 第%d天开始" % day)
		if day == 2:
			lines.append("第2天提醒：第3天开始时巡查入村，已知情人物警戒＋10。")
		if day == 3 and not patrol_applied:
			patrol_applied = true
			var affected := PackedStringArray()
			for id in people:
				var person: Dictionary = people[id]
				if person.informed:
					var before: int = person.alert
					person.alert = clampi(before + 10, 0, 100)
					affected.append("%s %d→%d" % [NAMES[id], before, person.alert])
			lines.append("巡查入村：" + ("无人知情，没有人物增加警戒。" if affected.is_empty() else "、".join(affected)))
		refresh_warnings()
		lines.append("第%d天开始 · %d AP · %d粮食\n%s" % [day, ap, food, warning_text()])
	var report := "\n\n".join(lines)
	history.append("第%d天日末结算\n%s" % [ended_day, report])
	return {"ok": true, "text": report}


func _can_assist(npc: String) -> bool:
	if not storage.has(npc):
		return false
	var person: Dictionary = people[npc]
	return person.informed and person.trust >= 60 and person.alert < 60 and not person.reported and not (npc == "salt" and salt_assistance_revoked)


func material_preview(kind: String, npc: String, ids: Array) -> Dictionary:
	if not MATERIAL_ACTIONS.has(kind):
		return {"allowed": false, "text": "未知材料行动"}
	var rule: Dictionary = MATERIAL_ACTIONS[kind]
	var reasons := PackedStringArray()
	var lines := PackedStringArray(["成本：%d AP · %d粮食" % [rule.ap, rule.food]])
	if kind != "record_self" and current_location != "fishing_village":
		reasons.append("需先返回渔村（移动1 AP）")
	if village_finished:
		reasons.append("渔村阶段已结束")
	if ap < rule.ap:
		reasons.append("当日AP不足，不能跨天支付")
	if food < rule.food:
		reasons.append("粮食不足")
	var unique: Dictionary = {}
	for id in ids:
		unique[id] = true
	if ids.is_empty() or unique.size() != ids.size() or (kind != "store" and ids.size() != 1):
		reasons.append("请选择有效材料；保管可一次选择最多两件原物，其余行动选择一件")
	for id in ids:
		if not inventory.has(id):
			reasons.append("材料不存在")
			continue
		var item: Dictionary = inventory[id]
		lines.append("材料：%s · %s · %s持有" % [item.name, "原物" if item.get("kind", "original") == "original" else "记录", NAMES.get(item.holder, "玩家")])
		var local_shared: bool = item.holder == npc and ((kind == "spread" and storage.get(npc, []).has(id)) or (kind == "store" and spread.get("item", "") == id and npc == "salt"))
		if kind == "retrieve":
			if item.holder == "player":
				reasons.append("材料已在玩家手中")
		elif item.holder != "player" and not local_shared:
			reasons.append("玩家当前不持有此材料；不能使用远处托管物")
		if kind in ["record_self", "record_scribe", "show", "spread"] and not item.confirmed:
			reasons.append("需要已确认的海洋证据或记录")
		if kind == "store" and item.get("kind", "original") != "original":
			reasons.append("保管只接受原物，记录可交盐嫂用于传播")
		if kind == "store" and storage.get(npc, []).has(id):
			reasons.append("这件原物已经安排保管")
	if kind in ["show", "store", "spread"] and not people.has(npc):
		reasons.append("请选择人物")
	if kind in ["store", "spread"]:
		lines.append("前提：对方已知情、T≥60、A<60，且未告密或失去协助资格。第5天离场复查。")
		if not _can_assist(npc):
			reasons.append("对方当前不具备协助资格")
	if kind == "store":
		if not storage.has(npc) or storage.get(npc, []).size() + ids.size() > 2:
			reasons.append("仅盐嫂、哑伯可保管，每人最多两件原物")
		lines.append("本次选中原物一并交接，只收1 AP。存放：%s。玩家失去即时使用权，可免费取回。" % STASHES.get(npc, "无保管地点"))
	if kind == "spread":
		if npc != "salt":
			reasons.append("只有盐嫂可以传播")
		if not spread.is_empty():
			reasons.append("已有传播安排，请先取回原材料再重新安排")
		lines.append("材料交给盐嫂，A＋10；现在只登记待执行安排，第5天复查有效才形成海洋传播。不会自动新建保管安排。")
	if kind == "show":
		if shown_to.has(npc):
			reasons.append("此人本阶段已经获得过展示收益，更换材料不能重复")
		lines.append("每人一次：T＋10、A＋15，并知情；展示后材料仍由玩家持有。")
	if kind in ["show", "spread"] and people.has(npc):
		var after := _person_after({"npc": npc, "trust": 10 if kind == "show" else 0, "alert": 15 if kind == "show" else 10, "informs": true})
		lines.append("信任 %d→%d · 警戒 %d→%d\n行动后：%s" % [people[npc].trust, after.trust, people[npc].alert, after.alert, status(after)])
		if after.warning_day > 0:
			lines.append("告密预警：第%d天末复查。" % after.warning_day)
		if kind == "spread" and after.alert >= 60:
			lines.append("行动后传播立即暂停；离场前需恢复支持，否则材料退还且不算传播。")
	if kind in ["record_self", "record_scribe"]:
		lines.append("生成一份由玩家持有的记录；原材料不消耗、持有人不变。记录与原材料同源，不增加独立来源；不增加任何人的警戒或知情。")
	if kind == "retrieve":
		lines.append("免费取回所选材料，同时取消这件材料的保管与传播安排。不退历史AP，不降低警戒，不抹除知情；重新安排需重新付费。")
	if not reasons.is_empty():
		lines.append("当前不能执行：\n" + "\n".join(reasons))
	return {"allowed": reasons.is_empty(), "text": "\n\n".join(lines)}


func execute_material(kind: String, npc: String, ids: Array) -> Dictionary:
	var check := material_preview(kind, npc, ids)
	if not check.allowed:
		return {"ok": false, "text": check.text}
	var rule: Dictionary = MATERIAL_ACTIONS[kind]
	ap -= int(rule.ap)
	food -= int(rule.food)
	match kind:
		"record_self", "record_scribe":
			var source: Dictionary = inventory[ids[0]]
			record_serial += 1
			inventory["record_%d" % record_serial] = {"name": source.name.trim_suffix("记录") + "记录", "source": source.source, "confirmed": true, "kind": "record", "holder": "player", "location": "inventory"}
		"show":
			people[npc] = _person_after({"npc": npc, "trust": 10, "alert": 15, "informs": true})
			shown_to[npc] = true
		"store":
			for id in ids:
				storage[npc].append(id)
				inventory[id].holder = npc
				inventory[id].location = STASHES[npc]
		"spread":
			spread = {"item": ids[0], "status": "pending", "npc": "salt"}
			inventory[ids[0]].holder = "salt"
			inventory[ids[0]].location = STASHES.salt
			people.salt = _person_after({"npc": "salt", "alert": 10, "informs": true})
		"retrieve":
			_take_back(ids[0])
	history.append("第%d天 · %s\n%s" % [day, rule.title, check.text])
	return {"ok": true, "text": check.text + "\n\n已执行。剩余%d AP · %d粮食" % [ap, food]}


func _take_back(id: String) -> void:
	for items in storage.values():
		items.erase(id)
	if spread.get("item", "") == id:
		spread.clear()
	inventory[id].holder = "player"
	inventory[id].location = "inventory"


func arrangements_text() -> String:
	var lines := PackedStringArray()
	for npc in storage:
		for id in storage[npc]:
			lines.append("%s保管「%s」：%s" % [NAMES[npc], inventory[id].name, "当前有效，离场复查" if _can_assist(npc) else "当前失效，离场将退还"])
	if not spread.is_empty():
		lines.append("盐嫂传播「%s」：%s" % [inventory[spread.item].name, "已完成" if spread.status == "completed" else ("离场暂停，未传播" if spread.status == "failed" else ("待离场执行" if _can_assist("salt") else "暂停，离场前需恢复支持"))])
	return "暂无保管或传播安排" if lines.is_empty() else "\n".join(lines)


func _settle_arrangements() -> void:
	var notes := PackedStringArray()
	# 传播和保管分别判定，同一原物只保留一个持有人。
	var spread_valid: bool = not spread.is_empty() and _can_assist("salt") and inventory.has(spread.item) and inventory[spread.item].holder == "salt" and inventory[spread.item].confirmed
	if not spread.is_empty():
		spread.status = "completed" if spread_valid else "failed"
		if spread_valid:
			publications.append({"region": "village", "content": "ocean", "source": inventory[spread.item].source, "material": spread.item, "day": 5, "actor": "salt"})
		else:
			notes.append("盐嫂传播未通过复查，未形成传播；本次安排不会在后台自动恢复。")
	for npc in storage:
		if not _can_assist(npc):
			for id in storage[npc]:
				notes.append("%s的保管失效：%s退还玩家。" % [NAMES[npc], inventory[id].name])
			storage[npc].clear()
	for id in inventory:
		var item: Dictionary = inventory[id]
		if item.holder == "player":
			continue
		var kept: bool = storage.get(item.holder, []).has(id) or (spread_valid and spread.item == id)
		if not kept:
			item.holder = "player"
			item.location = "inventory"
	var carried := PackedStringArray()
	var left := PackedStringArray()
	var sources: Dictionary = {}
	for id in inventory:
		var item: Dictionary = inventory[id]
		if item.holder == "player":
			carried.append(item.name)
			if item.confirmed:
				sources[item.source] = true
		else:
			left.append("%s：%s（%s）" % [NAMES[item.holder], item.name, item.location])
	var advanced: bool = spread_valid or not storage.salt.is_empty() or not storage.mute.is_empty()
	outcomes = {"basic": not sources.is_empty(), "advanced": advanced, "carried_sources": sources.keys(), "family_protected": completed.has("protect"), "ocean_spread": spread_valid}
	departure_report = "基本目标：%s（随身%d个独立确认来源）\n进阶目标：%s\n家人安置：%s\n\n带走：%s\n留下：%s\n\n%s\n\n%s" % ["完成" if not sources.is_empty() else "未完成", sources.size(), "完成" if advanced else "未完成", "已完成" if completed.has("protect") else "未完成", "、".join(carried) if not carried.is_empty() else "无", "；".join(left) if not left.is_empty() else "无", arrangements_text(), "\n".join(notes)]
	departure_report += "\n\n" + warning_text()
	if not report_penalty.is_empty() and not report_penalty.applied:
		departure_report += "\n第%d天少1 AP，尚未执行。" % report_penalty.due_day
	departure_report += "\n\n集市入口：" + ("可使用随身已确认证据或记录进行后续核验；不自动取得P1。" if not sources.is_empty() else "没有随身确认材料，仍可在集市从本地来源调查。")
	if spread_valid:
		departure_report += "\n盐嫂的有效传播可形成阿香听过消息的入口，但不自动加信任，也不是独立来源。"


const SAVE_FIELDS := ["current_location", "academy", "market", "day", "ap", "food", "people", "completed", "inventory", "history", "entrance_known", "salt_assistance_revoked", "patrol_applied", "village_finished", "report_penalty", "departure_snapshot", "storage", "spread", "publications", "shown_to", "record_serial", "departure_report", "outcomes"]

func to_save_data() -> Dictionary:
	var data: Dictionary = {}
	for key in SAVE_FIELDS:
		var value = get(key)
		data[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return data


# 校验后一次性恢复；读档不运行事件或重新发奖励。
func restore_save_data(data: Dictionary) -> bool:
	data = data.duplicate(true)
	if not data.get("academy") is Dictionary or not data.get("market") is Dictionary:
		return false
	if not data.has("current_location"):
		data.current_location = "old_academy" if not data.get("academy", {}).is_empty() else ("market" if not data.get("market", {}).is_empty() else "fishing_village")
	var valid_places: Array = ["old_academy"] if not data.get("academy", {}).is_empty() else (["market"] if not data.get("market", {}).is_empty() else ["fishing_village", "ruins"])
	if data.current_location not in valid_places:
		return false
	for key in SAVE_FIELDS:
		if not data.has(key):
			return false
		var expected = get(key)
		var value = data[key]
		if expected is int:
			if not (value is int or value is float) or float(value) != floor(float(value)):
				return false
		elif typeof(expected) != typeof(value):
			return false
	if data.day < 1 or data.day > 15 or data.ap < 0 or data.ap > 3 or data.food < 0 or data.record_serial < 0:
		return false
	for npc in (NAMES.keys() if not data.academy.is_empty() else (["salt", "mute", "luo"] if data.market.is_empty() else ["salt", "mute", "luo", "qian", "xiang", "dao"])):
		if not data.people.get(npc) is Dictionary:
			return false
		var person: Dictionary = data.people[npc]
		for field in ["trust", "alert", "warning_day"]:
			var value = person.get(field)
			if not (value is int or value is float) or float(value) != floor(float(value)) or value < 0 or value > (16 if field == "warning_day" else 100):
				return false
		for field in ["informed", "reported"]:
			if not person.get(field) is bool:
				return false
	for id in data.inventory:
		var item = data.inventory[id]
		if not item is Dictionary:
			return false
		for field in ["name", "source", "kind", "holder", "location"]:
			if not item.get(field) is String:
				return false
		if not item.get("confirmed") is bool or item.kind not in ["original", "record", "draft"] or item.holder not in ["player", "salt", "mute"]:
			return false
	for npc in STASHES:
		if not data.storage.get(npc) is Array or data.storage[npc].size() > 2:
			return false
		var seen := {}
		for id in data.storage[npc]:
			if not data.inventory.has(id) or data.inventory[id].holder != npc or data.inventory[id].kind != "original" or seen.has(id):
				return false
			seen[id] = true
	if not data.spread.is_empty():
		if not data.inventory.has(data.spread.get("item", "")) or data.spread.get("npc") != "salt" or data.spread.get("status") not in ["pending", "completed", "failed"]:
			return false
		if data.spread.status != "failed" and data.inventory[data.spread.item].holder != "salt":
			return false
	if not data.report_penalty.is_empty():
		if data.report_penalty.get("source") != "village" or not data.report_penalty.get("applied") is bool:
			return false
		var due = data.report_penalty.get("due_day")
		if not (due is int or due is float) or due < 2 or due > 7 or float(due) != floor(float(due)):
			return false
	if data.village_finished and (data.day < 5 or (data.day == 5 and data.ap != 0) or data.departure_snapshot.is_empty()):
		return false
	if not data.market.is_empty():
		if data.day < 6 or not data.village_finished:
			return false
		for key in ["done", "relationships", "claims", "recipes", "directions", "messengers", "penalty"]:
			if not data.market.get(key) is Dictionary:
				return false
		if not data.market.get("finished") is bool or not data.market.get("heard_village") is bool or not data.market.get("report") is String:
			return false
	elif data.day > 5:
		return false
	if not data.academy.is_empty():
		if data.day < 11 or data.market.is_empty() or not data.market.finished:
			return false
		for key in ["done", "flags", "locations", "er_knows", "relationships", "distribution", "contributions"]:
			if not data.academy.get(key) is Dictionary:
				return false
		for key in ["ended", "finished", "feedback", "destroyed"]:
			if not data.academy.get(key) is bool:
				return false
		for key in ["artifact_choice", "ending", "report"]:
			if not data.academy.get(key) is String:
				return false
	elif data.day > 10:
		return false
	for line in data.history:
		if not line is String:
			return false
	for key in SAVE_FIELDS:
		if key == "history":
			history.assign(data.history)
		elif get(key) is int:
			set(key, int(data[key]))
		else:
			var value = data[key]
			set(key, value.duplicate(true) if value is Dictionary or value is Array else value)
	return true
