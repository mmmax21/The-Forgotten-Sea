extends RefCounted
const Business := preload("res://scripts/story/trail2_market_business.gd")
const IDS := ["mo", "er", "gao"]
const NAMES := {"mo": "墨先生", "er": "二笔", "gao": "高帽子"}
const ACTIONS := {
	"mo_help": {"title": "整理普通目录", "npc": "mo", "ap": 1, "trust": 15, "relationship": true},
	"er_help": {"title": "交接普通抄件", "npc": "er", "ap": 1, "trust": 20, "relationship": true},
	"gao_help": {"title": "补齐申请来源", "npc": "gao", "ap": 2, "trust": 25, "relationship": true},
	"mo_pro": {"title": "审核匹配P2底稿", "npc": "mo", "ap": 1, "trust": 15, "alert": 5, "relationship": true, "requires": ["P2"], "locate": "versions", "informs": true},
	"er_pro": {"title": "核对明确版本矛盾", "npc": "er", "ap": 1, "trust": 20, "alert": 5, "relationship": true, "requires": ["verified"], "locate": "execution", "informs": true},
	"gao_pro": {"title": "提交版本矛盾与完整来源", "npc": "gao", "ap": 1, "trust": 25, "alert": 10, "relationship": true, "requires": ["verified"], "informs": true},
	"mo_protect": {"title": "分离私人身份与研究副本", "npc": "mo", "ap": 1, "alert": -10, "needs_informed": true},
	"er_protect": {"title": "隐去无关交接人员", "npc": "er", "ap": 1, "alert": -10, "needs_informed": true},
	"gao_protect": {"title": "明确申请范围与责任", "npc": "gao", "ap": 1, "alert": -10, "needs_informed": true},
	"versions_mo": {"title": "调阅旧新版本", "npc": "mo", "ap": 1, "alert": 5, "support": true, "doc": "versions", "last": 13},
	"execution_er": {"title": "调阅替换与销毁记录", "npc": "er", "ap": 1, "alert": 5, "support": true, "doc": "execution", "last": 13},
	"command_gao": {"title": "调阅修订命令", "npc": "gao", "ap": 1, "alert": 5, "support": true, "doc": "command"},
	"locate_versions": {"title": "定位旧版本目录", "group": "archive", "ap": 1, "locate": "versions", "last": 14},
	"locate_execution": {"title": "定位交接索引", "group": "archive", "ap": 1, "locate": "execution", "requires": ["versions"], "last": 14},
	"get_versions": {"title": "按位置自行取旧版本", "group": "archive", "ap": 1, "location": "versions", "doc": "versions", "last": 13},
	"get_execution": {"title": "按位置自行取执行记录", "group": "archive", "ap": 1, "location": "execution", "doc": "execution", "last": 13},
	"know_versions": {"title": "免费确认二笔知道旧版本去向", "npc": "er", "ap": 0, "support": true, "er_knows": "versions"},
	"know_execution": {"title": "免费确认二笔知道执行记录去向", "npc": "er", "ap": 0, "support": true, "er_knows": "execution", "requires": ["versions"]},
	"save_versions": {"title": "自行保全旧版本", "group": "archive", "ap": 2, "location": "versions", "doc": "versions", "first": 14, "last": 14},
	"save_execution": {"title": "自行保全执行记录", "group": "archive", "ap": 2, "location": "execution", "doc": "execution", "first": 14, "last": 14},
	"save_versions_er": {"title": "请二笔保全旧版本", "npc": "er", "ap": 2, "alert": 15, "support": true, "needs_er": "versions", "doc": "versions", "first": 14, "last": 14},
	"save_execution_er": {"title": "请二笔保全执行记录", "npc": "er", "ap": 2, "alert": 15, "support": true, "needs_er": "execution", "doc": "execution", "first": 14, "last": 14},
	"command_self": {"title": "追查命令副本", "group": "archive", "ap": 3, "requires": ["execution"], "doc": "command"},
	"verify": {"title": "核验版本矛盾", "group": "archive", "ap": 1, "requires": ["versions"], "flag": "verified"},
	"trace": {"title": "追溯同批制度删改 → P3", "group": "archive", "ap": 1, "requires": ["verified", "execution", "command"], "flag": "P3"},
	"museum_mo": {"title": "请墨先生核验馆藏海洋物证", "npc": "mo", "ap": 2, "alert": 5, "support": true, "doc": "museum"},
	"museum_self": {"title": "自行核验馆藏海洋物证", "group": "archive", "ap": 3, "doc": "museum"},
	"observations_mo": {"title": "取得旧观测记录", "npc": "mo", "ap": 1, "support": true, "doc": "observations"},
	"observations_reply": {"title": "取公开P1回应的观测簿", "group": "archive", "ap": 1, "doc": "observations", "first": 12, "reply": "P1"},
	"observe_first": {"title": "首次观测旧水槽", "group": "archive", "ap": 1, "last": 14, "flag": "observed_first"},
	"observe_second": {"title": "隔日再次观测并整理", "group": "archive", "ap": 1, "requires": ["observed_first"], "flag": "observed_second"},
	"sign": {"title": "请墨先生审核署名", "npc": "mo", "ap": 1, "alert": 5, "support": true, "requires": ["P3"], "flag": "signed"},
	"challenge": {"title": "审议现场公开质证", "group": "archive", "ap": 2, "requires": ["P3"], "first": 15, "flag": "challenge"},
	"response": {"title": "要求书面回应", "npc": "gao", "ap": 1, "alert": 5, "support": true, "requires": ["P3"], "flag": "response"},
	"file": {"title": "正式留档并取得回执", "npc": "gao", "ap": 2, "alert": 5, "support": true, "requires": ["response"], "flag": "filed"},
	"distribute_mo": {"title": "墨先生协助分散传播", "npc": "mo", "ap": 2, "alert": 5, "support": true, "distribute": true},
	"distribute_er": {"title": "二笔协助分散传播", "npc": "er", "ap": 2, "alert": 5, "support": true, "distribute": true},
	"resend_mo": {"title": "墨先生协助向集市补发", "npc": "mo", "ap": 1, "alert": 5, "support": true, "resend": true, "last": 14},
	"resend_er": {"title": "二笔协助向集市补发", "npc": "er", "ap": 1, "alert": 5, "support": true, "resend": true, "last": 14},
	"early": {"title": "取得早期封闭案卷", "group": "archive", "ap": 1, "doc": "early", "last": 14},
	"running": {"title": "调查法器运行记录", "group": "archive", "ap": 1, "requires": ["early"], "doc": "running", "first": 12},
	"negotiate": {"title": "记忆与政策交涉", "group": "archive", "ap": 1, "requires": ["early", "running"], "flag": "negotiated", "first": 12},
	"artifact": {"title": "接受疯祭司法器交接", "group": "archive", "ap": 1, "requires": ["negotiated"], "flag": "artifact", "first": 15},
}
const DOCS := {"versions": "修订批次A旧新版本及来源", "execution": "修订批次A替换销毁执行记录", "command": "修订批次A命令与编号", "museum": "旧港器具完整核验底稿", "observations": "旧观测水槽历史记录", "early": "早期冲突与疯祭司签署案卷", "running": "法器依赖共同认知的维护档案"}

static func has(s, key: String) -> bool:
	if key == "P2":
		return s.market.claims.has("P2") and s.inventory.has("market_text") and s.inventory.market_text.holder == "player"
	if key == "versions" and has(s, "P2"):
		return true
	if key == "verified" and has(s, "P2"):
		return true
	if DOCS.has(key):
		return s.inventory.has("academy_" + key) and s.inventory["academy_" + key].holder == "player"
	return s.academy.flags.has(key)

static func supported(s, npc: String) -> bool:
	var p: Dictionary = s.people[npc]
	return p.trust >= 60 and p.alert < 60 and not p.reported

static func sea_basis(s) -> bool:
	if s.market.claims.has("P1"):
		return true
	var physical: bool = has(s, "museum")
	for item in s.inventory.values():
		if item.holder == "player" and item.confirmed and item.source in ["husband_relic", "warehouse_fragment"]:
			physical = true
	return physical and has(s, "versions") and has(s, "verified")

static func enter(s) -> Dictionary:
	if s.market.is_empty() or not s.market.finished or not s.academy.is_empty():
		return {"ok": false, "text": "需先结束集市，不能重复进入学城。"}
	s.academy = {"done": {}, "flags": {}, "locations": {}, "er_knows": {}, "relationships": {}, "distribution": {}, "resend_day": 0, "observed_day": 0, "ended": false, "finished": false, "artifact_choice": "", "ending": "", "report": "", "feedback": false, "destroyed": false, "contributions": {"mo": [], "er": [], "gao": []}}
	for npc in IDS:
		s.people[npc] = {"trust": {"mo": 45, "er": 40, "gao": 35}[npc], "alert": {"mo": 45, "er": 35, "gao": 30}[npc], "informed": false, "warning_day": 0, "reported": false}
	for sent in s.market.business.delivered:
		if sent.claim in ["P1", "P2"]:
			s.academy.locations.versions = true
	s.day = 11
	s.ap = 2 # 抵达当天的3 AP中扣除1 AP路程。
	s.current_location = "old_academy"
	_apply_penalty(s)
	var text := "第11天 · 旧学城（移动消耗1 AP）\n第13天末普通旧版本和执行记录调阅关闭；第14天可定向保全，日末销毁指定馆藏；第15天定本审议。\n当前公开目录指向《海港篇》修订批次A，可自行定位或寻求合作。\n第12天可能收到公开回应与有效渠道反馈。\n今日%d AP。" % s.ap
	s.history.append(text)
	return {"ok": true, "text": text}

static func options(s, group: String) -> Array:
	var result := []
	for id in ACTIONS:
		if ACTIONS[id].get("npc", ACTIONS[id].get("group", "archive")) == group:
			result.append({"id": id, "title": ACTIONS[id].title})
	if s.day == 11:
		for npc in ["qian", "xiang", "dao"]:
			if s.people[npc].warning_day == 11:
				result.append({"id": "messenger_" + npc, "title": "向%s传话补救" % s.NAMES[npc]})
	return result

static func preview(s, id: String) -> Dictionary:
	var a: Dictionary = ACTIONS.get(id, {})
	if id.begins_with("messenger_"):
		a = {"title": "向集市传话", "npc": id.trim_prefix("messenger_"), "ap": 1, "alert": -20}
	if a.is_empty():
		return {"allowed": false, "text": "未知行动"}
	var reasons := PackedStringArray()
	var lines := PackedStringArray(["%s · %d AP（同一天支付）" % [a.title, a.ap]])
	if s.academy.is_empty() or s.day < 11 or s.day > 15 or s.academy.ended:
		return {"allowed": false, "text": "不在旧学城自由行动阶段"}
	if s.ap < a.ap:
		reasons.append("AP不足")
	if s.day < a.get("first", 11) or s.day > a.get("last", 15):
		reasons.append("不在开放日期内")
	if s.academy.done.has(id):
		reasons.append("已完成，不能重复奖励")
	for requirement in a.get("requires", []):
		if not has(s, requirement):
			reasons.append("缺少：" + str(DOCS.get(requirement, requirement)))
	if a.has("doc") and has(s, a.doc):
		reasons.append("已持有同类可用底稿，不重复收费取件")
	if a.has("flag") and has(s, a.flag):
		reasons.append("调查或成果已完成")
	if a.has("location") and not s.academy.locations.has(a.location):
		reasons.append("需先取得精确位置或目录编号")
	if a.has("locate") and s.academy.locations.has(a.locate) and not a.has("relationship"):
		reasons.append("已知位置，无需再次付费")
	if a.has("needs_er") and not s.academy.er_knows.has(a.needs_er):
		reasons.append("需先免费确认二笔知道目标去向")
	if a.has("reply") and not s.market.business.public_claims.has(a.reply):
		reasons.append("没有对应公开投放的回应入口")
	if a.has("npc"):
		var npc: String = a.npc
		if not s.people.has(npc):
			return {"allowed": false, "text": "人物不存在"}
		var person: Dictionary = s.people[npc]
		if person.reported:
			reasons.append("人物已告密，不能恢复合作")
		if a.get("support", false) and not supported(s, npc):
			reasons.append("需要T≥60、A<60")
		if a.get("needs_informed", false) and not person.informed:
			reasons.append("对方尚未知情")
		if a.get("relationship", false) and s.academy.relationships.has(npc):
			reasons.append("普通帮助与专业入口奖励只能领取一次")
		var effect: Dictionary = a.duplicate()
		effect.informs = a.get("informs", false) or a.get("support", false)
		var after: Dictionary = s._person_after(effect)
		lines.append("T %d→%d · A %d→%d · %s" % [person.trust, after.trust, person.alert, after.alert, s.status(after)])
		if after.warning_day > 0:
			lines.append("预警到第%d天末；第16天预警只进入后日谈，不提前结算。" % after.warning_day)
	if a.get("distribute", false):
		if not s.academy.distribution.is_empty():
			reasons.append("本阶段只完成一次有效分散发布")
		if not sea_basis(s) and not has(s, "P3") and not has(s, "P2"):
			reasons.append("需至少一个已核验主张及可用底稿")
		lines.append("2 AP包含制作和交接，立即完成；同时包含当前已证实的全部内容，不按主张重复收费。内容：%s%s%s" % ["海洋依据 " if sea_basis(s) else "", "P3 " if has(s, "P3") else "", "P2" if has(s, "P2") else ""])
	if a.get("resend", false):
		if not s.academy.distribution.get("ocean", false) or not sea_basis(s):
			reasons.append("需先完成海洋分散传播，且海洋依据齐全")
		if s.academy.resend_day > 0:
			reasons.append("已经补发过")
		lines.append("最晚第14天发送；次日抵达集市才计入异地传播，既成发送不因后续沉默撤销。")
	if id == "early" and not supported(s, "mo") and not (s.day >= 12 and s.market.business.public_claims.has("P2")):
		reasons.append("需墨先生支持，或第12天公开P2回应入口")
	if id == "negotiate" and not has(s, "P2") and not has(s, "P3"):
		reasons.append("缺少P2或P3调查底稿")
	if id == "observe_second" and s.academy.observed_day >= s.day:
		reasons.append("两次观测必须跨日")
	if id.begins_with("observe"):
		lines.append("P4还需历史观测资料、跨日两次观测，以及至少一地实际海洋传播；否则只保留异常记录。")
	if id == "artifact":
		lines.append("持有法器不自动成为新的王；终局还要主动接管且有有效渠道。当前有效渠道：" + ("有" if active_channel(s) else "无"))
	if id.begins_with("messenger_"):
		var npc: String = a.npc
		if npc not in ["qian", "xiang", "dao"] or s.day != 11 or s.people[npc].warning_day != 11:
			reasons.append("仅第11天尚有集市预警时可传话，每人一次")
		lines.append("取消此人尚未完成的合作；不撤销已经送出或传播的内容。")
	if a.has("doc"):
		lines.append("取得：%s，玩家持有底稿；明确同批来源，不自动完成跨材料核验。" % DOCS[a.doc])
	if not reasons.is_empty():
		lines.append("不能执行：\n" + "\n".join(reasons))
	return {"allowed": reasons.is_empty(), "text": "\n\n".join(lines)}

static func execute(s, id: String) -> Dictionary:
	var check := preview(s, id)
	if not check.allowed:
		return {"ok": false, "text": check.text}
	var a: Dictionary = ACTIONS.get(id, {}).duplicate(true)
	if id.begins_with("messenger_"):
		a = {"npc": id.trim_prefix("messenger_"), "ap": 1, "alert": -20}
	s.ap -= int(a.ap)
	if a.has("npc"):
		a.informs = a.get("informs", false) or a.get("support", false)
		s.people[a.npc] = s._person_after(a)
		if s.academy.contributions.has(a.npc):
			s.academy.contributions[a.npc].append(a.title)
	if a.get("relationship", false):
		s.academy.relationships[a.npc] = id
	if a.has("doc"):
		s.inventory["academy_" + a.doc] = {"name": DOCS[a.doc], "kind": "draft", "source": "academy_" + ("revision_a" if a.doc in ["versions", "execution", "command"] else a.doc), "batch": "revision_a" if a.doc in ["versions", "execution", "command"] else a.doc, "holder": "player", "location": "inventory", "confirmed": true}
	if id == "early" and not (s.day >= 12 and s.market.business.public_claims.has("P2")):
		s.people.mo.informed = true
	if a.has("flag"):
		s.academy.flags[a.flag] = true
	if a.has("locate"):
		s.academy.locations[a.locate] = true
	if a.has("er_knows"):
		s.academy.er_knows[a.er_knows] = true
	if id == "observe_first":
		s.academy.observed_day = s.day
	if a.get("distribute", false):
		s.academy.distribution = {"ocean": sea_basis(s), "P3": has(s, "P3"), "P2": has(s, "P2"), "actor": a.npc, "day": s.day}
		for content in ["ocean", "P3", "P2"]:
			if s.academy.distribution[content]:
				s.publications.append({"region": "academy", "content": content, "actor": a.npc, "day": s.day})
	if a.get("resend", false):
		s.academy.resend_day = s.day
	if id.begins_with("messenger_"):
		for key in s.market.business.channels:
			var c: Dictionary = s.market.business.channels[key]
			if c.owner == a.npc:
				c.cancelled = true
				c.active = false
	s.academy.done[id] = true
	_refresh_p4(s)
	s.history.append("第%d天 · 学城\n%s" % [s.day, check.text])
	return {"ok": true, "text": check.text + "\n\n已完成，剩余%d AP。" % s.ap}

static func _refresh_p4(s) -> void:
	if not has(s, "observed_first") or not has(s, "observed_second") or not has(s, "observations"):
		return
	for publication in s.publications:
		if publication.content == "ocean":
			s.academy.flags.P4 = true

static func active_channel(s) -> bool:
	for key in ["print", "local"]:
		if Business.valid(s, key):
			return true
	return not s.academy.distribution.is_empty() and supported(s, s.academy.distribution.actor)

static func _apply_penalty(s) -> void:
	var penalty: Dictionary = s.market.penalty
	if not penalty.is_empty() and not penalty.applied and penalty.due_day == s.day:
		s.ap -= 1
		penalty.applied = true

static func end_preview(s) -> Dictionary:
	var text := "结束第%d天，剩余%d AP作废。\n%s" % [s.day, s.ap, s.warning_text()]
	if s.day == 13:
		text += "\n今晚关闭普通调阅，明日须保全（2 AP），当天才定位共3 AP。\n" + archive_status(s)
	if s.day == 14:
		text += "\n今晚销毁指定旧版本与执行记录。未取得底稿且无其他私人入口的材料不能补领。"
	if s.day == 15:
		text += "\n完成到期风险复查后结算终局；不增加第16天行动，不免费补做调查。"
	return {"allowed": not s.academy.ended, "text": text}

static func end_day(s, expected: int) -> Dictionary:
	if s.academy.ended or (expected != -1 and expected != s.day):
		return {"ok": false, "text": "不能重复结算"}
	var lines := PackedStringArray(["第%d天结束。" % s.day])
	s.refresh_warnings()
	for npc in s.people:
		var person: Dictionary = s.people[npc]
		if person.warning_day > 0 and person.warning_day <= s.day and s._at_risk(person):
			person.reported = true
			person.warning_day = 0
			lines.append(s.NAMES[npc] + "到期告密，既成调查、署名与传播保留。")
			if npc in ["qian", "xiang", "dao"]:
				Business.report_actor(s, npc)
				if s.market.penalty.is_empty():
					s.market.penalty = {"source": "market", "due_day": s.day + 1, "applied": false}
	if s.day == 14:
		s.academy.destroyed = true
		lines.append("馆藏旧版本与执行记录清点销毁。已取得底稿、私人抄本、命令、观测与维护资料保留。")
	if s.day == 15:
		s.ap = 0
		s.academy.ended = true
		_refresh_p4(s)
		if has(s, "artifact"):
			lines.append("你已取得法器，请选择最终处置。接管仅在仍有有效渠道时开放。")
		else:
			finish(s, "none")
			lines.append(s.academy.report)
	else:
		s.day += 1
		s.ap = 3
		_apply_penalty(s)
		if s.day == 12:
			for key in ["print", "local"]:
				if Business.valid(s, key):
					s.academy.locations.execution = true
					s.academy.feedback = true
			lines.append("第12天回应到达：公开P1提供观测簿入口，公开P2提供早期案卷入口；有效当地渠道提供执行记录编号。线索需付费实际取件。")
		if s.academy.resend_day > 0 and s.day == s.academy.resend_day + 1:
			s.publications.append({"region": "market", "content": "ocean", "actor": "academy_resend", "day": s.day})
			lines.append("补发材料在集市送达传阅。")
		lines.append("第%d天开始 · %d AP" % [s.day, s.ap])
	var text := "\n\n".join(lines)
	s.history.append(text)
	return {"ok": true, "text": text}

static func archive_status(s) -> String:
	var lines := PackedStringArray()
	for key in ["versions", "execution"]:
		lines.append(DOCS[key] + "：" + ("已有底稿，无须抢救" if has(s, key) else ("精确定位，可自行保全" if s.academy.locations.has(key) else ("二笔能定位，可协助" if s.academy.er_knows.has(key) else "需先定位"))))
	return "\n".join(lines)

static func finish(s, choice: String) -> Dictionary:
	if not s.academy.ended or s.academy.finished:
		return {"ok": false, "text": "终局尚未开放或已完成"}
	if choice not in ["none", "take", "keep", "return"] or (has(s, "artifact") and choice == "none") or (not has(s, "artifact") and choice != "none"):
		return {"ok": false, "text": "无效法器选择"}
	if choice == "take" and not active_channel(s):
		return {"ok": false, "text": "没有可调用的有效渠道，无法接管"}
	var other_ocean := false
	for event in s.publications:
		if event.content == "ocean" and event.region in ["village", "market"]:
			other_ocean = true
	var sea: bool = sea_basis(s) and s.academy.distribution.get("ocean", false) and other_ocean and has(s, "P4")
	var liberation: bool = has(s, "P3") and s.academy.distribution.get("P3", false) and ((has(s, "challenge") and has(s, "signed")) or (has(s, "response") and has(s, "filed")))
	s.academy.artifact_choice = choice
	s.academy.flags.sea_returned = sea
	s.academy.flags.liberation = liberation
	s.academy.ending = "king" if choice == "take" else ("sea" if sea else ("liberation" if liberation else "forgetting"))
	var lines := PackedStringArray([{"king": "新的王", "sea": "海回归", "liberation": "王国获得解放", "forgetting": "遗忘重临"}[s.academy.ending]])
	if sea:
		lines.append("海洋依据、跨地区传播与重复观测相互印证，海重新进入共同现实；这不自动等于制度自由。")
	if liberation:
		lines.append("可核对且已流出的证据使定本审议无法再把现行版本作为唯一合法历史。多个参与机构拒绝继续销毁异议材料，停止相关禁阅禁抄执行，变化沿网络扩展。")
	if not sea and not liberation:
		lines.append("尚未形成现实或制度突破。" + ("已保住的材料与知识仍存在，并非所有人都失去记忆。" if not s.inventory.is_empty() else "调查材料不足，但人物与行动留下的经历仍在。"))
	lines.append({"none": "你未取得法器。", "take": "你主动接管法器，并借仍有效的渠道逐步取代原控制者；不是瞬间控制全国，既成现实变化保留。", "keep": "你保留法器，拒绝操控他人认知。工具仍存在，未来尚未决定。", "return": "你将法器交还疯祭司，拒绝成为掌控者。此举不撤销已发生的海回归或制度变化。"}[choice])
	lines.append("人物后日谈")
	for npc in s.people:
		var person: Dictionary = s.people[npc]
		var contribution: String = "、".join(s.academy.contributions.get(npc, []))
		if npc == "salt":
			contribution = "家人已安置。" if s.completed.has("protect") else "家人未安置。"
			contribution += "曾完成海洋传播。" if not s.publications.filter(func(e): return e.get("region") == "village").is_empty() else "未完成村内传播。"
		elif npc == "mute":
			contribution = "曾辨认船体构件。" if s.completed.has("identify") else "未参与辨认。"
		elif npc == "luo":
			contribution = "曾指出仓库入口。" if s.completed.has("retrieve") else "未提供入口。"
		elif npc in ["qian", "xiang", "dao"]:
			contribution = "参与集市调查。" if s.market.relationships.has(npc) else "未建立调查合作。"
			if npc == "dao" and not s.market.business.public_claims.is_empty():
				contribution += "既成公开投放及回应保留。"
			if npc == "xiang" and not s.market.business.delivered.is_empty():
				contribution += "商队材料已送出。"
		lines.append("%s · T%d/A%d · %s\n%s%s" % [s.NAMES[npc], person.trust, person.alert, s.status(person), contribution, "预警将于第%d天末到期，进入后日谈；仅涉及本人实际知情，不追溯撤销成果。" % person.warning_day if person.warning_day > 0 else ""])
	s.academy.report = "\n\n".join(lines)
	s.academy.finished = true
	s.history.append(s.academy.report)
	return {"ok": true, "text": s.academy.report}
