extends RefCounted
## 传播批次、渠道与已发生传播分开记账。
const NAMES := {"print": "印刷点", "local": "客栈本地递送", "cross": "商队递送"}

static func initialize(s) -> void:
	if s.market.has("business"):
		return
	var channels := {}
	for key in NAMES:
		channels[key] = {"owner": "dao" if key == "print" else "xiang", "address": key + "_old", "exposed": [], "inspected": [], "closed": false, "moved": false, "used": false, "active": false, "cancelled": false, "claims": []}
	s.market.business = {"channels": channels, "batches": {}, "serial": 0, "contacts": {}, "pending": [], "delivered": [], "public_claims": [], "inspection": [], "rushed": false, "repaired": false}

static func valid(s, key: String) -> bool:
	var c: Dictionary = s.market.business.channels[key]
	var p: Dictionary = s.people[c.owner]
	return c.active and not c.closed and not c.cancelled and not p.reported and p.trust >= 60 and p.alert < 60

static func options(s, group: String) -> Array:
	initialize(s)
	var result := []
	for claim in s.market.claims:
		if group == "research":
			result.append({"id": "copy_single:" + claim, "title": "自行抄写" + claim + " · 2 AP"})
		if group == "dao":
			for mode in ["small", "large", "rush"]:
				result.append({"id": "copy_" + mode + ":" + claim, "title": {"small": "小批复制", "large": "大批复制", "rush": "具名赶印投放"}[mode] + claim})
		if group == "xiang":
			for target in ["local", "cross"]:
				result.append({"id": "contact:" + target + ":" + claim, "title": "筛选" + NAMES[target] + "联系人 · " + claim})
	for bid in s.market.business.batches:
		var batch: Dictionary = s.market.business.batches[bid]
		if batch.scale == "used" or batch.holder == "confiscated":
			continue
		if group == "dao" and batch.scale in ["small", "large"]:
			result.append({"id": "publish:local:" + bid, "title": "小范围投放 · " + batch.claim + " " + bid})
			if batch.scale == "large":
				result.append({"id": "publish:public:" + bid, "title": "公开投放（全部） · " + batch.claim})
				result.append({"id": "publish:localreserve:" + bid, "title": "小范围投放并预留一份 · " + batch.claim})
				result.append({"id": "publish:reserve:" + bid, "title": "公开投放并预留一份 · " + batch.claim})
		if group == "xiang":
			for target in ["local", "cross"]:
				result.append({"id": "deliver:" + target + ":" + bid, "title": "交付" + NAMES[target] + " · " + batch.claim + " " + bid})
		if group == "research" and batch.holder != "player":
			result.append({"id": "retrieve:" + bid, "title": "免费取回未用副本 · " + bid})
	for key in NAMES:
		var c: Dictionary = s.market.business.channels[key]
		if c.owner == group:
			result.append({"id": "move:" + key, "title": "转移" + NAMES[key] + " · 2 AP"})
			result.append({"id": "cancel:" + key, "title": "免费取消" + NAMES[key]})
	if group == "dao":
		result.append({"id": "repair", "title": "接手后续联络 · 1 AP"})
	return result

static func config(s, id: String) -> Dictionary:
	var p := id.split(":")
	var verb := p[0]
	var action := {"ap": 0, "alert": 0, "trust": 0, "npc": "", "channel": "", "support": false, "text": ""}
	match verb:
		"copy_single", "copy_small", "copy_large", "copy_rush":
			if p.size() != 2 or p[1] not in ["P1", "P2"]:
				return {}
			action.claim = p[1]
			action.ap = 2 if verb in ["copy_single", "copy_large", "copy_rush"] else 1
			if verb != "copy_single":
				action.npc = "dao"
				action.channel = "print"
				action.support = true
				action.alert = {"copy_small": 5, "copy_large": 10, "copy_rush": 20}[verb]
				action.trust = -20 if verb == "copy_rush" else 0
			action.text = "制作传播副本，底稿不消耗。" if verb != "copy_rush" else "同日完成复制和公开投放；T−20/A＋20，印刷点暴露；不留下预留副本，登记第12天回应。"
		"contact":
			if p.size() != 3 or p[1] not in ["local", "cross"]:
				return {}
			action.merge({"ap": 1, "alert": 5, "npc": "xiang", "support": true, "channel": p[1], "claim": p[2], "text": "筛选本项联系人；不发放材料，也不算已传播。"}, true)
		"deliver", "publish":
			if p.size() != 3 or not s.market.business.batches.has(p[2]):
				return {}
			action.batch = p[2]
			action.claim = s.market.business.batches[p[2]].claim
			action.merge({"ap": 1, "alert": 5 if verb == "deliver" or p[1] in ["local", "localreserve"] else 10, "npc": "xiang" if verb == "deliver" else "dao", "support": true, "channel": p[1] if verb == "deliver" else "print"}, true)
			action.text = "小范围投放立即完成，后续沉默不撤销既成传播。"
			if verb == "publish" and p[1] not in ["local", "localreserve"]:
				action.text = "仅第7—8天公开投放；印刷点暴露，登记第12天回应。" + ("明确预留一份副本。" if p[1] == "reserve" else "本批全部投放，不预留。")
			if verb == "deliver":
				action.text = "本地递送立即完成。" if p[1] == "local" else "副本交给阿香，等待第10天末复查T/A、联系人、材料和渠道后出发；现在不算送达。"
		"move", "cancel":
			if p.size() != 2 or not NAMES.has(p[1]):
				return {}
			action.channel = p[1]
			action.npc = s.market.business.channels[p[1]].owner if verb == "move" else ""
			action.ap = 2 if verb == "move" else 0
			action.alert = -20 if verb == "move" else 0
			action.text = "转移此业务的现存材料，旧址仍会被查；每条业务只允许一次。沉默不妨碍保护性转移。" if verb == "move" else "只取消这项业务，归还可取回材料；不退款、不回滚警戒、不抹掉既成传播。"
		"retrieve":
			if p.size() != 2 or not s.market.business.batches.has(p[1]):
				return {}
			action.batch = p[1]
			action.text = "免费取回此副本，取消它的待发安排；保留联系人，不抹掉既成传播。"
		"repair":
			action.merge({"ap": 1, "trust": 20, "npc": "dao", "text": "补回具名赶印损失的20信任，不消除暴露，不恢复已关闭据点。"}, true)
		_: return {}
	return action

static func preview(s, id: String) -> Dictionary:
	initialize(s)
	var a := config(s, id)
	if a.is_empty():
		return {"allowed": false, "text": "无效业务"}
	var p := id.split(":")
	var verb := p[0]
	var reasons := PackedStringArray()
	var lines := PackedStringArray(["成本：%d AP，不消耗粮食。" % a.ap, a.text])
	if s.day < 6 or s.day > 10 or s.market.finished:
		reasons.append("不在集市行动阶段")
	if s.ap < a.ap:
		reasons.append("当日AP不足")
	if a.has("claim") and not s.market.claims.has(a.claim):
		reasons.append("缺少已核验主张和底稿")
	if not a.npc.is_empty():
		var person: Dictionary = s.people[a.npc]
		if person.reported:
			reasons.append("人物已告密，退出合作")
		if a.support and (person.trust < 60 or person.alert >= 60):
			reasons.append("需信任≥60、警戒<60")
		var after: Dictionary = s._person_after({"npc": a.npc, "trust": a.trust, "alert": a.alert, "informs": a.support})
		lines.append("T %d→%d · A %d→%d · %s" % [person.trust, after.trust, person.alert, after.alert, s.status(after)])
		if after.warning_day > 0:
			lines.append("预警截止第%d天末。" % after.warning_day)
		if verb == "deliver" and p[1] == "cross" and after.alert >= 60:
			lines.append("注意：交付后沉默，若不恢复支持，第10天商队不会发送。")
	if not a.channel.is_empty():
		var c: Dictionary = s.market.business.channels[a.channel]
		if c.closed and verb != "cancel":
			reasons.append("据点已关闭，不可重开")
		if verb == "move" and (c.moved or not c.exposed.has(c.address)):
			reasons.append("须当前据点已暴露，且本业务尚未转移")
	if a.has("batch"):
		var b: Dictionary = s.market.business.batches[a.batch]
		if b.scale == "used" or b.holder in ["confiscated", "sent"]:
			reasons.append("材料已使用、送出或没收")
		if verb == "retrieve" and b.holder == "player":
			reasons.append("副本已在玩家手中")
		if verb in ["deliver", "publish"] and b.get("pending", false):
			reasons.append("已交付待发，需先取回才可改用")
		if verb == "publish" and (b.scale == "single" or (p[1] != "local" and b.scale != "large")):
			reasons.append("公开需大批，小范围需小批或大批")
	if verb == "contact" and s.market.business.contacts.has(p[1] + ":" + p[2]):
		reasons.append("已有有效联系人，不重复收费")
	if verb == "deliver" and not s.market.business.contacts.has(p[1] + ":" + a.claim):
		reasons.append("缺少对应主张与地区的联系人")
	if verb == "copy_rush" or (verb == "publish" and p[1] not in ["local", "localreserve"]):
		if s.day not in [7, 8]:
			reasons.append("公开投放仅第7—8天")
	if verb == "copy_rush" and s.market.business.rushed:
		reasons.append("具名赶印仅一次")
	if verb == "repair" and (not s.market.business.rushed or s.market.business.repaired):
		reasons.append("需发生具名赶印，且尚未补回信任")
	if not reasons.is_empty():
		lines.append("不能执行：\n" + "\n".join(reasons))
	return {"allowed": reasons.is_empty(), "text": "\n\n".join(lines)}

static func _batch(s, claim: String, scale: String, holder: String, channel: String = "") -> String:
	var biz: Dictionary = s.market.business
	biz.serial += 1
	var id := "副本%d" % biz.serial
	biz.batches[id] = {"claim": claim, "scale": scale, "holder": holder, "channel": channel, "address": biz.channels[channel].address if not channel.is_empty() else "inventory", "pending": false}
	return id

static func _published(s, claim: String, actor: String, public: bool = false) -> void:
	var key := "%s:%s:%s" % [claim, actor, public]
	for event in s.publications:
		if event.get("key") == key:
			return
	s.publications.append({"key": key, "region": "market", "content": "ocean" if claim == "P1" else "P2", "claim": claim, "actor": actor, "public": public, "day": s.day})
	if public and claim not in s.market.business.public_claims:
		s.market.business.public_claims.append(claim)

static func execute(s, id: String) -> Dictionary:
	var check := preview(s, id)
	if not check.allowed:
		return {"ok": false, "text": check.text}
	var a := config(s, id)
	var p := id.split(":")
	var verb := p[0]
	var biz: Dictionary = s.market.business
	s.ap -= int(a.ap)
	if not a.npc.is_empty():
		s.people[a.npc] = s._person_after({"npc": a.npc, "trust": a.trust, "alert": a.alert, "informs": a.support})
	if not a.channel.is_empty() and verb != "cancel":
		biz.channels[a.channel].used = true
	match verb:
		"copy_single": _batch(s, a.claim, "single", "player")
		"copy_small", "copy_large": _batch(s, a.claim, "small" if verb == "copy_small" else "large", "dao", "print")
		"copy_rush":
			biz.rushed = true
			_activate(s, "print", a.claim)
			_expose(s, "print")
			_published(s, a.claim, "dao", true)
		"contact": biz.contacts[p[1] + ":" + p[2]] = true
		"publish":
			var batch: Dictionary = biz.batches[a.batch]
			batch.scale = "used"
			if p[1] in ["reserve", "localreserve"]:
				_batch(s, a.claim, "single", "player")
			_activate(s, "print", a.claim)
			_published(s, a.claim, "dao", p[1] not in ["local", "localreserve"])
			if p[1] not in ["local", "localreserve"]:
				_expose(s, "print")
		"deliver":
			var batch: Dictionary = biz.batches[a.batch]
			batch.scale = "small" if batch.scale == "large" else "used"
			var bid := _batch(s, a.claim, "single", "xiang", p[1])
			biz.channels[p[1]].cancelled = false
			if p[1] == "local":
				biz.batches[bid].scale = "used"
				_activate(s, "local", a.claim)
				_published(s, a.claim, "xiang")
			else:
				biz.batches[bid].pending = true
				biz.pending.append(bid)
		"move":
			var c: Dictionary = biz.channels[a.channel]
			var old: String = c.address
			c.address = a.channel + "_new"
			c.moved = true
			for b in biz.batches.values():
				if b.channel == a.channel and b.address == old and b.holder not in ["player", "sent", "confiscated"]:
					b.address = c.address
		"retrieve": _retrieve(s, a.batch)
		"cancel":
			var c: Dictionary = biz.channels[a.channel]
			c.cancelled = true
			c.active = false
			for bid in biz.batches:
				var b: Dictionary = biz.batches[bid]
				if b.channel == a.channel and b.scale != "used" and b.holder not in ["confiscated", "sent", "player"]:
					_retrieve(s, bid)
		"repair": biz.repaired = true
	s.history.append("第%d天 · 传播业务\n%s" % [s.day, check.text])
	return {"ok": true, "text": check.text + "\n\n已执行，剩余%d AP。" % s.ap}

static func _activate(s, key: String, claim: String) -> void:
	var c: Dictionary = s.market.business.channels[key]
	c.active = true
	c.cancelled = false
	if claim not in c.claims:
		c.claims.append(claim)

static func _expose(s, key: String) -> void:
	var c: Dictionary = s.market.business.channels[key]
	if c.address not in c.exposed:
		c.exposed.append(c.address)

static func _retrieve(s, bid: String) -> void:
	var b: Dictionary = s.market.business.batches[bid]
	s.market.business.pending.erase(bid)
	b.pending = false
	b.holder = "player"
	b.channel = ""
	b.address = "inventory"

static func report_actor(s, npc: String) -> void:
	for key in s.market.business.channels:
		var c: Dictionary = s.market.business.channels[key]
		if c.owner == npc and c.used:
			_expose(s, key)
			c.active = false

static func start_day(s) -> String:
	initialize(s)
	var biz: Dictionary = s.market.business
	biz.inspection = []
	if s.day not in [9, 10]:
		return ""
	var affected := {}
	var names := PackedStringArray()
	for key in biz.channels:
		var c: Dictionary = biz.channels[key]
		for address in c.exposed:
			if address not in c.inspected:
				biz.inspection.append({"channel": key, "address": address})
				names.append(NAMES[key] + ("新址" if address.ends_with("_new") else "旧址"))
				affected[c.owner] = true
	if s.day == 9:
		for npc in affected:
			s.people[npc].alert = mini(100, s.people[npc].alert + 10)
	s.refresh_warnings()
	return "今日检查名单：" + ("无；不增加人物警戒。" if names.is_empty() else "、".join(names) + ("；相关人物各A＋10一次。" if s.day == 9 else "；不另加警戒。"))

static func inspect(s) -> String:
	var notes := PackedStringArray()
	var biz: Dictionary = s.market.business
	for entry in biz.inspection:
		var c: Dictionary = biz.channels[entry.channel]
		c.inspected.append(entry.address)
		if c.address == entry.address:
			c.closed = true
			c.active = false
			for bid in biz.batches:
				var b: Dictionary = biz.batches[bid]
				if b.address == entry.address and b.holder not in ["player", "sent"] and b.scale != "used":
					b.holder = "confiscated"
					b.pending = false
					biz.pending.erase(bid)
			notes.append(NAMES[entry.channel] + "旧址关闭，留存材料没收。")
		else:
			notes.append(NAMES[entry.channel] + "旧址被查，新址按实际状态保留。")
	return "\n".join(notes)

static func depart(s) -> String:
	var biz: Dictionary = s.market.business
	var notes := PackedStringArray()
	for bid in biz.pending.duplicate():
		var b: Dictionary = biz.batches[bid]
		var c: Dictionary = biz.channels.cross
		var person: Dictionary = s.people.xiang
		if not c.closed and not c.cancelled and not person.reported and person.trust >= 60 and person.alert < 60 and b.holder == "xiang" and biz.contacts.has("cross:" + b.claim):
			b.holder = "sent"
			b.pending = false
			if not biz.delivered.any(func(entry): return entry.claim == b.claim):
				biz.delivered.append({"claim": b.claim, "recipient": "学城文献保管员", "day": 11})
			notes.append(b.claim + "商队已出发，学城收件入口建立。")
		else:
			if b.holder != "confiscated":
				_retrieve(s, bid)
			notes.append(b.claim + "商队发送失败，可取回副本已退还。")
	biz.pending.clear()
	return "\n".join(notes)

static func summary(s) -> String:
	initialize(s)
	var lines := PackedStringArray()
	for key in NAMES:
		var c: Dictionary = s.market.business.channels[key]
		lines.append("%s：%s%s" % [NAMES[key], "关闭" if c.closed else ("有效" if valid(s, key) else "未建立／暂停／取消"), "（新址）" if c.moved else ""])
	for bid in s.market.business.batches:
		var b: Dictionary = s.market.business.batches[bid]
		lines.append("%s · %s · %s · %s%s" % [bid, b.claim, {"single": "单份", "small": "小批", "large": "大批", "used": "已使用"}[b.scale], {"player": "玩家持有", "dao": "刀郎持有", "xiang": "阿香持有", "sent": "已送出", "confiscated": "已没收"}.get(b.holder, b.holder), " · 待第10天发送" if b.pending else ""])
	for sent in s.market.business.delivered:
		lines.append("已送往%s：%s" % [sent.recipient, sent.claim])
	if not s.market.business.public_claims.is_empty():
		lines.append("已公开投放，将获学城回应：" + "、".join(s.market.business.public_claims))
	return "\n".join(lines)


static func inspection_text(s) -> String:
	initialize(s)
	var targets := PackedStringArray()
	for entry in s.market.business.inspection:
		targets.append(NAMES[entry.channel] + ("新址" if entry.address.ends_with("_new") else "旧址"))
	return "今晚检查：" + ("无已公布对象" if targets.is_empty() else "、".join(targets))
