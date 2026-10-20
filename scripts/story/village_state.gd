extends RefCounted
## Six-day rules. UI and story text never mutate resources independently.
const RULESET := "village_6turn_v03"
const NAMES := {"salt":"盐嫂", "elder":"哑伯", "child":"螺螺"}
const TITLES := {"H":"丈夫的潮汐手记", "H_r":"潮汐手记记录", "F":"船体构件", "F_r":"船体构件记录", "fragment":"刻痕碎片"}
const DESCRIPTIONS := {
 "H":"旧册留有水位刻线，以及苦咸的水、望不到岸的蓝色水面的描述。它确认有人记录过异常水域，不能单独证明见闻全部真实。",
 "F":"弧形接缝、成列孔眼与填缝材料，对应哑伯旧图纸中的船体结构。确认用途，但尚不能单凭此物排除河船。",
 "fragment":"遗迹中找到的弯曲木件，有孔眼和深色填料。用途尚未确认，可请哑伯辨认。"
}
const ACTIONS := {
 "feed":{"title":"送粮", "group":"salt", "ap":1,"food":1},
 "listen":{"title":"倾听丈夫经历", "group":"salt", "ap":1,"requires":"feed"},
 "family":{"title":"安置家人", "group":"salt", "ap":2,"food":1,"requires":"listen","last":3},
 "heirloom":{"title":"查看丈夫遗物", "group":"salt", "ap":1,"requires":"listen"},
 "repair":{"title":"修整旧物", "group":"elder", "ap":1},
 "identify":{"title":"辨认碎片", "group":"elder", "ap":1},
 "tidy":{"title":"收好危险旧物", "group":"elder", "ap":1},
 "hear":{"title":"听螺螺的见闻", "group":"child", "ap":1},
 "retrieve":{"title":"取回遗落布包", "group":"child", "ap":1,"requires":"hear"},
 "caution":{"title":"梳理不能公开说的内容", "group":"child", "ap":1},
 "survey":{"title":"勘察遗迹外围", "group":"ruins", "ap":1,"last":4},
 "clear":{"title":"清理入口", "group":"ruins", "ap":1,"last":4},
 "search":{"title":"搜查遗迹", "group":"ruins", "ap":1,"requires":"clear","last":4},
 "waterline":{"title":"观察并核对水线", "group":"village", "ap":2,"last":4},
 "public_material":{"title":"公开匿名物证", "group":"public", "ap":2},
 "public_anonymous":{"title":"匿名讲述丈夫经历", "group":"public", "ap":1},
 "public_salt":{"title":"实名公开丈夫证词", "group":"public", "ap":1},
 "public_elder":{"title":"实名公开船匠辨认", "group":"public", "ap":1},
 "record":{"title":"自己制作记录", "group":"material", "ap":2},
 "scribe":{"title":"请抄写摊制作记录", "group":"material", "ap":1,"food":1},
 "show":{"title":"私下展示", "group":"material", "ap":1},
 "store":{"title":"安排保管", "group":"material", "ap":1},
 "take":{"title":"取回保管物品", "group":"material", "ap":0},
 "neighbor":{"title":"安排邻里传播", "group":"material", "ap":1},
 "apology":{"title":"承认越界并停止引用", "group":"material", "ap":1}
}
var run_id := "%s-%s" % [str(Time.get_unix_time_from_system()),str(Time.get_ticks_usec())]
var day := 1
var entry_turn := 1
var ap := 3
var food := 2
var belief := 0
var spent := 0
var location := "fishing_village"
var people := {"salt":{"t":40,"a":50,"known":false,"due":0,"reported":false,"exposed":false},"elder":{"t":50,"a":40,"known":false,"due":0,"reported":false,"exposed":false},"child":{"t":35,"a":20,"known":false,"due":0,"reported":false,"exposed":false}}
var flags: Dictionary = {}
var items: Dictionary = {}
var storage := {"salt":[], "elder":[]}
var spread: Dictionary = {}
var public_event: Dictionary = {}
var penalty_used := false
var pending_penalty := false
var finished := false
var snapshot: Dictionary = {}
var history: Array = []
var presentation: Dictionary = {}
var selected := ""
var sequence := 0

func source(key: String) -> String:
	return "H" if key.begins_with("H") else ("F" if key.begins_with("F") else "fragment")

func sources() -> Array:
	var result: Array = []
	for key in items:
		if items[key].holder == "player" and key != "fragment" and not result.has(source(key)):
			result.append(source(key))
	return result

func owned(key: String) -> bool:
	return items.has(key) and items[key].holder == "player"

func cooperative(who: String) -> bool:
	var p: Dictionary = people[who]
	return p.known and p.t >= 60 and p.a < 60 and not p.exposed and not p.reported

func risk(who: String) -> bool:
	var p: Dictionary = people[who]
	return p.known and p.t < 60 and p.a >= 60 and not p.reported

func status(who: String) -> String:
	var p: Dictionary = people[who]
	if p.reported: return "已告密"
	if p.due > 0: return "告密预警 · 当地第%d天末" % p.due
	if p.exposed: return "身份已曝光 · 隐蔽协助失效"
	if p.t >= 60: return "相信你，但暂时不敢合作" if p.a >= 60 else "愿意合作" if p.known else "信任你，尚未知情"
	return "害怕受牵连" if p.a >= 60 else "尚未建立足够信任"

func change(who: String, t: int, a: int, known := false) -> void:
	people[who].t = clampi(int(people[who].t) + t, 0, 100)
	people[who].a = clampi(int(people[who].a) + a, 0, 100)
	people[who].known = people[who].known or known

func sync() -> void:
	for who in people:
		if risk(who):
			if people[who].due == 0: people[who].due = day + 1
		else: people[who].due = 0
		if people[who].exposed or people[who].reported:
			for key in storage.get(who, []).duplicate():
				items[key].holder = "player"
			storage[who] = []
			if who == "salt" and not spread.is_empty():
				items[spread.item].holder = "player"
				spread = {}

func action_key(id: String, args: Dictionary) -> String:
	if id in ["show", "apology"]: return id + ":" + str(args.get("who", ""))
	if id in ["record", "scribe"]: return "recorded:" + source(str(args.get("item", "")))
	return id

func blocked(id: String, args: Dictionary = {}) -> Array:
	var reasons: Array = []
	if not ACTIONS.has(id): return ["没有这个行动"]
	var a: Dictionary = ACTIONS[id]
	var key := str(args.get("item", ""))
	var who := str(args.get("who", ""))
	if finished: reasons.append("渔村章节已经结束")
	if not presentation.is_empty(): reasons.append("请先读完当前对白")
	if id not in ["store", "take"] and flags.has(action_key(id, args)): reasons.append("已完成，不能重复获得收益")
	if a.has("requires") and not flags.has(a.requires): reasons.append("需先完成「%s」" % ACTIONS[a.requires].title)
	if day > int(a.get("last", 6)): reasons.append("已超过第%d天末的期限" % a.last)
	var required := "ruins" if a.group == "ruins" else "fishing_village"
	if location != required: reasons.append("需先通过地图免费前往" + ("遗迹" if required == "ruins" else "渔村"))
	if ap < a.ap: reasons.append("AP不足：需%d，剩余%d" % [a.ap, ap])
	if food < int(a.get("food", 0)): reasons.append("粮食不足")
	match id:
		"heirloom":
			if people.salt.t < 60 or people.salt.a >= 60 or people.salt.reported: reasons.append("需要盐嫂信任≥60、警戒<60且未告密")
		"identify":
			if not owned("fragment"): reasons.append("需要随身携带未确认碎片")
			if people.elder.t < 60 or people.elder.a >= 60 or people.elder.reported: reasons.append("需要哑伯信任≥60、警戒<60且未告密")
		"tidy", "caution":
			if not people["elder" if id == "tidy" else "child"].known: reasons.append("对方尚不知道你的调查")
		"survey":
			if flags.has("entrance"): reasons.append("已知道准确入口")
		"clear":
			if not flags.has("entrance"): reasons.append("需要准确入口")
		"waterline":
			if day < 2: reasons.append("第2天起可核对水线")
			if not sources().has("F"): reasons.append("需持有已确认船体构件或其记录")
		"record", "scribe":
			if key not in ["H", "F"] or not owned(key): reasons.append("需选择随身的已确认原物")
		"show":
			if not people.has(who) or not owned(key) or key == "fragment": reasons.append("需选择人物及随身的确认证据或记录")
		"store":
			var chosen: Array = args.get("items", [])
			if not storage.has(who): reasons.append("只有盐嫂、哑伯可以保管")
			elif not cooperative(who): reasons.append("需要知情、信任≥60、警戒<60且有协助资格")
			if chosen.is_empty(): reasons.append("至少选择一件原物")
			var unique: Array = []
			for item in chosen:
				if item not in ["H", "F"] or not owned(item) or unique.has(item): reasons.append("只能交接不同的随身原物")
				unique.append(item)
			if storage.has(who) and storage[who].size() + chosen.size() > 2: reasons.append("每人最多保管两件原物")
		"take":
			if not items.has(key) or items[key].holder == "player": reasons.append("该物品不在保管中")
			elif not storage.get(items[key].holder, []).has(key): reasons.append("传播材料不能主动取回")
			if not spread.is_empty() and spread.item == key: reasons.append("此原物还承担传播用途，不能取回")
		"neighbor":
			if not cooperative("salt"): reasons.append("盐嫂暂不具备协助条件")
			if not spread.is_empty(): reasons.append("已经安排传播，不能撤回或更换材料")
			if not owned(key) and not storage.salt.has(key): reasons.append("需选择随身材料或盐嫂保管的原物")
			if key not in ["H", "F", "H_r", "F_r"]: reasons.append("需要已确认来源的原物或记录")
		"apology":
			if not people.has(who) or not people.get(who, {}).get("exposed", false): reasons.append("只有被实名曝光的人可进行此项交涉")
	if id.begins_with("public_"):
		if day not in [4,5]: reasons.append("公开说明只在第4—5天开放")
		if not public_event.is_empty(): reasons.append("公开说明已经执行，不能改换版本")
		if sources().is_empty(): reasons.append("需持有至少一种已确认来源")
		if id in ["public_salt", "public_anonymous"] and (not sources().has("H") or not flags.has("listen")): reasons.append("需要丈夫手记或记录，并已倾听经历")
		if id == "public_elder" and not sources().has("F"): reasons.append("需要船体构件或记录")
	return reasons

func preview(id: String, args: Dictionary = {}) -> Dictionary:
	var reasons := blocked(id,args)
	if not ACTIONS.has(id): return {"allowed":false,"text":"没有这个行动"}
	var a: Dictionary = ACTIONS[id]
	var lines: Array = ["消耗 %d AP · %d份粮食" % [a.ap, a.get("food",0)]]
	if not reasons.is_empty():
		lines.append("尚不能执行：\n" + "\n".join(reasons))
		return {"allowed":false,"text":"\n\n".join(lines)}
	var copy = get_script().new()
	copy.restore(to_data())
	copy.apply(id,args)
	lines.append("执行后剩余 %d AP" % copy.ap)
	if copy.belief != belief: lines.append("渔村认知 %d → %d" % [belief,copy.belief])
	for who in people:
		var before: Dictionary = people[who]
		var after: Dictionary = copy.people[who]
		if before.t != after.t or before.a != after.a or before.known != after.known:
			lines.append("%s：信任 %d→%d；警戒 %d→%d；%s" % [NAMES[who],before.t,after.t,before.a,after.a,copy.status(who)])
		if after.exposed and not before.exposed:
			lines.append("身份将永久曝光，失去本区隐蔽协助及后续%s。道歉不能收回已经公开的姓名。" % ("介绍消息" if who == "salt" else "来源核验帮助"))
		if after.due > 0:
			lines.append("%s：当地第%d天末仍高危将告密。" % [NAMES[who],after.due])
			if day == 6:
				lines.append("离村后无法远程补救。" + ("本区已无剩余行动可补救。" if copy.ap == 0 else "今天还可用%d AP处理。" % copy.ap))
	if id == "neighbor": lines.append("材料交给盐嫂，不能主动取回或换件；离场有效才增加10认知并产生一次后续介绍帮助。")
	if id in ["record","scribe"]: lines.append("生成同来源记录，不增加独立证据来源。")
	if id == "store": lines.append("物品交给对方，失去即时使用权；纯保管物品可以免费取回。")
	if id.begins_with("public_"): lines.append("本区只能公开一次。材料不消耗，现场回应不另扣AP；后果在次日呈现。")
	return {"allowed":true,"text":"\n\n".join(lines)}

func execute(id: String, args: Dictionary = {}) -> bool:
	if not blocked(id,args).is_empty(): return false
	apply(id,args)
	return true

func apply(id: String, args: Dictionary) -> void:
	var old_people := people.duplicate(true)
	var old_belief := belief
	var a: Dictionary = ACTIONS[id]
	ap -= int(a.ap)
	food -= int(a.get("food",0))
	spent += int(a.ap)
	flags[action_key(id,args)] = true
	var key := str(args.get("item",""))
	var who := str(args.get("who",""))
	match id:
		"feed": change("salt",15,0)
		"listen": change("salt",10,5)
		"family": change("salt",0,-20)
		"heirloom":
			items.H = {"holder":"player"}
			change("salt",0,10,true)
		"repair": change("elder",15,0)
		"identify":
			items.erase("fragment")
			items.F = {"holder":"player"}
			change("elder",0,10,true)
		"tidy": change("elder",0,-10)
		"hear": change("child",10,0)
		"retrieve":
			change("child",15,0)
			flags.entrance = true
		"survey": flags.entrance = true
		"search": items.fragment = {"holder":"player"}
		"caution": change("child",0,-10)
		"record", "scribe": items[key+"_r"] = {"holder":"player"}
		"show": change(who,10,15,true)
		"store":
			for item in args.items:
				storage[who].append(item)
				items[item].holder = who
		"take":
			storage[items[key].holder].erase(key)
			items[key].holder = "player"
		"neighbor":
			items[key].holder = "salt"
			spread = {"item":key}
			change("salt",0,0 if flags.has("family") else 10)
		"apology": change(who,5,-10)
		"public_material":
			belief += 40 if sources().size() == 2 else 20
			if sources().has("F") and flags.has("waterline"): belief += 20
		"public_anonymous":
			belief += 40
			change("salt",0,10,true)
		"public_salt", "public_elder":
			var target := "salt" if id == "public_salt" else "elder"
			belief += 60
			change(target,-20,20,true)
			people[target].exposed = true
	if id.begins_with("public_"):
		public_event = {"version":id,"sources":sources(),"day":day,"feedback_read":false}
	belief = clampi(belief,0,100)
	sync()
	sequence += 1
	var receipt: Array = ["消耗%d AP、%d粮食" % [a.ap,a.get("food",0)]]
	if belief != old_belief: receipt.append("认知%d→%d" % [old_belief,belief])
	for target in people:
		if people[target].t != old_people[target].t or people[target].a != old_people[target].a:
			receipt.append("%s T%d→%d / A%d→%d" % [NAMES[target],old_people[target].t,people[target].t,old_people[target].a,people[target].a])
	history.append({"sequence":sequence,"day":day,"action":id,"title":a.title,"args":args.duplicate(true),"ap":ap,"belief":belief,"receipt":"；".join(receipt)})

func travel(destination: String) -> bool:
	if finished or not presentation.is_empty() or destination not in ["fishing_village","ruins"]: return false
	if destination == "ruins" and day > 4 and location != "ruins": return false
	location = destination
	selected = ""
	return true

func end_preview() -> String:
	var lines: Array = ["剩余%d AP将作废。" % ap]
	if day == 6: lines.append(outcome_text() + "\n" + progress_text())
	if day == 3 and not flags.has("family"): lines.append("今天结束后，不能再安置盐嫂家人。")
	if day == 4: lines.append("今天结束后，遗迹调查和水线核对关闭。")
	if day == 5 and public_event.is_empty(): lines.append("今天结束后，不再有公开说明机会。")
	for who in people:
		if people[who].due > 0:
			lines.append("%s：当地第%d天末复查告密风险。" % [NAMES[who],people[who].due])
			if day == 6: lines.append("离村后没有远程补救，请在离村前处理或接受后果。")
	if day == 6: lines.append("离村前可返回材料页免费取回纯保管物。传播材料不可撤回。离村后本章不能再行动。")
	return "\n\n".join(lines)

func end_day() -> bool:
	if finished or not presentation.is_empty(): return false
	sync()
	for who in people:
		if people[who].due > 0 and people[who].due <= day:
			people[who].reported = true
			people[who].due = 0
			if not penalty_used:
				penalty_used = true
				pending_penalty = true
	sync()
	if day == 6:
		depart()
	else:
		day += 1
		ap = 2 if pending_penalty else 3
		pending_penalty = false
		if day == 3:
			for who in people:
				if people[who].known: change(who,0,10)
		sync()
	return true

# Investigation is an acquired finding, independent of who now holds the original.
# Copies never add a source; belief alone never verifies an investigation.
func chapter_progress() -> Dictionary:
	var found := flags.has("heirloom") or flags.has("identify")
	var verified := flags.has("identify") and (flags.has("heirloom") or flags.has("waterline"))
	var propagated := not public_event.is_empty() or (not spread.is_empty() and cooperative("salt"))
	var outcome := "no_lead"
	if found: outcome = "unverified"
	if verified: outcome = "verified_only"
	if verified and propagated: outcome = "success"
	return {"lead_found":found,"verified":verified,"propagated":propagated,"success":verified and propagated,"outcome":outcome}

func progress_text() -> String:
	var progress := chapter_progress()
	return "找到线索：%s\n完成验证：%s\n留下传播影响：%s\n\n验证需：手记＋确认船体构件，或确认船体构件＋水线核对。\n传播需：完成公开说明，或离村时盐嫂的邻里传播仍有效。抄本不增加来源，认知高也不能代替验证。" % ["已完成" if progress.lead_found else "尚未完成", "已完成" if progress.verified else "尚未完成", "已公开" if not public_event.is_empty() else "当前有效，离村复查" if progress.propagated else "尚未建立有效传播"]

func outcome_text() -> String:
	match chapter_progress().outcome:
		"success": return "调查成功离村：已完成交叉验证，并留下传播影响。"
		"verified_only": return "调查已验证，但未完成传播：尚未成功完成渔村目标。"
		"unverified": return "带着未验证线索离村：尚未成功完成渔村调查。" + ("村民已经听到你的说法，但真相仍未查明。" if not public_event.is_empty() else "")
	return "未找到确认证据便离村：渔村调查未完成。"

func depart() -> void:
	var valid := not spread.is_empty() and cooperative("salt")
	for who in storage:
		if not cooperative(who):
			for key in storage[who]:
				if not (valid and key == spread.item): items[key].holder = "player"
			storage[who] = []
	if valid: belief = mini(100,belief+10)
	elif not spread.is_empty():
		if not storage.salt.has(spread.item): items[spread.item].holder = "player"
		spread = {}
	var offers: Array = []
	if valid: offers.append("salt_intro")
	if flags.has("identify") and cooperative("elder"): offers.append("elder_origin")
	var warnings: Dictionary = {}
	for who in people:
		if people[who].due > 0: warnings[who] = entry_turn + int(people[who].due) - 1
	snapshot = {"ruleset":RULESET,"evidence":items.duplicate(true),"npc":people.duplicate(true),"public_event":public_event.duplicate(true),"belief_local":belief,"reality_tier":2 if belief >= 60 else 1 if belief >= 30 else 0,"storage":storage.duplicate(true),"neighbor_valid":valid,"spread":spread.duplicate(true),"support_offers":offers,"support_consumed":[],"warnings":warnings,"pending_penalty":pending_penalty,"penalty_used":penalty_used,"family_safe":flags.has("family"),"waterline_record":flags.has("waterline"),"ruins_closed":true}
	snapshot["chapter_progress"] = chapter_progress()
	snapshot["run_id"] = run_id
	finished = true

func report() -> String:
	var carried: Array = []
	var left: Array = []
	for key in items:
		(carried if owned(key) else left).append(TITLES[key] + ("" if owned(key) else " → " + NAMES[items[key].holder]))
	var lines: Array = [outcome_text(), progress_text(), "后续调查需要本地交叉核验与可核查材料；已有读者才能收到终章的补充说明。", "带走：" + ("暂无" if carried.is_empty() else "、".join(carried)), "当前随身独立来源：%d（材料交接不会抹去已完成的验证）" % sources().size(), "渔村认知 %d/100 · %s" % [belief,"出现局部现实变化" if belief >= 60 else "留下认知火种" if belief >= 30 else "仍是零散传闻"], "家人：" + ("已安置" if flags.has("family") else "未安置"), "留存：" + ("暂无" if left.is_empty() else "、".join(left))]
	for who in people: lines.append(NAMES[who] + "：" + status(who))
	lines.append("邻里传播：" + ("有效" if snapshot.get("neighbor_valid",false) else "未建立有效安排"))
	if snapshot.get("support_offers",[]).has("salt_intro"): lines.append("后续帮助：盐嫂介绍消息，可在一次联系人引荐中免1 AP。")
	if snapshot.get("support_offers",[]).has("elder_origin"): lines.append("后续帮助：哑伯来源说明，可在一次来源核验中免1 AP，不替代原物。")
	if pending_penalty: lines.append("下一地区首回合少1 AP（渔村来源仅处罚一次）。")
	if not snapshot.get("warnings",{}).is_empty(): lines.append("未结预警随快照交给下一地区；离村后没有远程补救。")
	lines.append("渔村章节结束。可继续前往集市，此处不触发全游戏结局。")
	return "\n\n".join(lines)

func to_data() -> Dictionary:
	var result: Dictionary = {}
	for key in ["run_id","day","entry_turn","ap","food","belief","spent","location","people","flags","items","storage","spread","public_event","penalty_used","pending_penalty","finished","snapshot","history","presentation","selected","sequence"]:
		result[key] = get(key)
	return result.duplicate(true)

func restore(data: Dictionary) -> bool:
	data = data.duplicate(true)
	if not data.has("run_id"): data["run_id"] = "legacy-"+JSON.stringify(data).sha256_text()
	if not valid_data(data): return false
	for key in to_data(): set(key,data[key])
	# Older saves have all action facts; derive the new outcome without resetting play.
	if finished:
		snapshot["chapter_progress"] = chapter_progress()
		snapshot["run_id"] = run_id
	return true

func valid_data(d: Dictionary) -> bool:
	if d.has("run_id") and not d.run_id is String: return false
	for key in to_data():
		if not d.has(key): return false
	for key in ["day","entry_turn","ap","food","belief","spent","sequence"]:
		if not (d[key] is int or d[key] is float) or float(d[key]) != floor(float(d[key])): return false
	if d.day < 1 or d.day > 6 or d.ap < 0 or d.ap > 3 or d.food < 0 or d.food > 2 or d.belief < 0 or d.belief > 100 or d.entry_turn < 1: return false
	for key in ["people","flags","items","storage","spread","public_event","snapshot","presentation"]:
		if not d[key] is Dictionary: return false
	if not d.history is Array or d.location not in ["fishing_village","ruins"] or not d.selected is String: return false
	for key in ["penalty_used","pending_penalty","finished"]:
		if not d[key] is bool: return false
	for who in NAMES:
		if not d.people.has(who) or not d.people[who] is Dictionary: return false
		var p: Dictionary = d.people[who]
		for field in ["t","a","due"]:
			if not p.has(field) or not (p[field] is int or p[field] is float): return false
		if p.t < 0 or p.t > 100 or p.a < 0 or p.a > 100 or p.due < 0 or p.due > 7: return false
		for field in ["known","reported","exposed"]:
			if not p.get(field) is bool: return false
	for key in d.items:
		if not TITLES.has(key) or not d.items[key] is Dictionary or d.items[key].get("holder","") not in ["player","salt","elder"]: return false
	for who in ["salt","elder"]:
		if not d.storage.get(who) is Array or d.storage[who].size() > 2: return false
		var seen: Array = []
		for key in d.storage[who]:
			if key not in ["H","F"] or not d.items.has(key) or d.items[key].holder != who or seen.has(key): return false
			seen.append(key)
	if not d.spread.is_empty():
		if not d.items.has(d.spread.get("item","")) or d.items[d.spread.item].holder != "salt": return false
	if not d.presentation.is_empty():
		if not d.presentation.get("lines") is Array or d.presentation.lines.is_empty(): return false
		if not (d.presentation.get("index") is int or d.presentation.get("index") is float): return false
		if d.presentation.index < 0 or d.presentation.index >= d.presentation.lines.size(): return false
		for line in d.presentation.lines:
			if not line is Dictionary or not line.get("text") is String or not line.get("speaker") is String: return false
	return true
