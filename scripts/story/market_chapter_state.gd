extends RefCounted
## Four local days. Findings, delivered messages and channel safety are separate.
const RULESET := "market_four_days_v1"
const NAMES := {"qian":"钱伯","xiang":"阿香","dao":"刀郎"}
const TOPICS := {"censorship":"传播调查发现","sea":"航行痕迹不只存在于渔村"}
const ACTIONS := {
 "supplement_manual":{"title":"向走访读者补充说明","group":"research","ap":1},
 "supplement_private":{"title":"向客栈读者补充说明","group":"xiang","ap":1},
 "supplement_public":{"title":"向公众补充说明","group":"research","ap":1},
 "quick_cargo":{"title":"请钱伯跳过查验，先交货单","group":"qian","ap":1},
 "repair_dao":{"title":"接手后续联络，向刀郎赔礼","group":"dao","ap":1},
 "qian_help":{"title":"帮钱伯核清货单","group":"qian","ap":1},
 "xiang_help":{"title":"取得阿香的引荐","group":"xiang","ap":1},
 "dao_help":{"title":"帮刀郎整理残页","group":"dao","ap":1},
 "cargo":{"title":"核验古物与原始货单","group":"qian","ap":1,"requires":"qian_help"},
 "seizure":{"title":"查阅货物扣押记录","group":"research","ap":1},
 "goods_verify":{"title":"核对货物与扣押理由","group":"research","ap":1},
 "text":{"title":"查看删改前的旧文本","group":"dao","ap":1,"requires":"dao_help"},
 "ban":{"title":"抄录现行查禁清单","group":"research","ap":1},
 "text_verify":{"title":"对照旧文本与查禁条目","group":"research","ap":1},
 "sea_verify":{"title":"比对渔村材料与外地古物","group":"qian","ap":1,"requires":"cargo"},
 "protect":{"title":"隐去印记与消息来源","group":"dao","ap":1,"requires":"dao_help"},
 "small":{"title":"印制匿名小批材料","group":"dao","ap":1,"requires":"dao_help","topic":true},
 "self_copy":{"title":"自行抄写少量材料","group":"research","ap":2,"topic":true},
 "contacts":{"title":"筛选可靠的接收者","group":"xiang","ap":1,"requires":"xiang_help"},
 "private":{"title":"向可靠接收者递送","group":"xiang","ap":1,"requires":"contacts","topic":true},
 "manual":{"title":"自行走访并递送","group":"research","ap":2,"topic":true},
 "rush":{"title":"公开传播：投放2 AP＋回应2 AP","group":"dao","ap":2,"requires":"dao_help","topic":true},
 "answer":{"title":"出示依据，回应读者质疑","group":"research","ap":2,"topic":true},
 "caravan":{"title":"交付末班商队","group":"qian","ap":1,"requires":"cargo","topic":true},
 "move":{"title":"转移印刷工具与存稿","group":"dao","ap":2},
 "reassure_qian":{"title":"承担货物查验，保护货主","group":"qian","ap":1,"requires":"qian_help"},
 "reassure_xiang":{"title":"隐去旅客身份与住址","group":"xiang","ap":1,"requires":"xiang_help"},
}
var day := 1
var entry_turn := 7
var ap := 3
var spent := 0
var belief := 0
var selected := ""
var location := "market"
var people := {"qian":{"t":40,"a":30,"reported":false},"xiang":{"t":40,"a":25,"reported":false},"dao":{"t":40,"a":35,"reported":false}}
var flags: Dictionary = {"handoff_rules_v2":true,"unified_belief_v3":true}
var origin: Dictionary = {}
var origin_id := ""
var packets: Dictionary = {}
var deliveries: Array = []
var pending: Array = []
var public_waiting: Array = []
var history: Array = []
var presentation: Dictionary = {}
var finished := false
var snapshot: Dictionary = {}
var exposed := false
var moved := false
var print_closed := false
var inspection_done := false
var import_penalty_used := false
var qian_due := 0
var penalty_next := false
var events: Array = []

func initialize(village: Dictionary) -> void:
	origin = village.duplicate(true)
	origin_id = JSON.stringify(origin).sha256_text()
	entry_turn = int(origin.get("market_entry_turn",7))
	import_penalty_used = origin.get("penalty_used",false)
	if origin.get("pending_penalty",false):
		ap = 2
		import_penalty_used = true
		events.append("渔村告密的后果已到达：集市首日少1 AP。")

func has_village_evidence() -> bool:
	for key in origin.get("evidence",{}):
		if key in ["H","F","H_r","F_r"] and origin.evidence[key].get("holder","")=="player": return true
	return false

func supports(id: String) -> bool:
	return origin.get("support_offers",[]).has(id) and not origin.get("support_consumed",[]).has(id)

func cost(id: String) -> int:
	if id=="xiang_help" and supports("salt_intro"): return 0
	if id=="cargo" and supports("elder_origin") and has_village_evidence(): return 0
	return int(ACTIONS[id].ap)

func key_for(id: String, topic: String) -> String:
	if id.begins_with("supplement_"): return id+":"+str(evidence_tier())
	topic = "censorship"
	return id+":"+topic if ACTIONS[id].get("topic",false) else id

func verified(topic: String) -> bool:
	return flags.has("sea_verify") if topic=="sea" else flags.has("text_verify") or flags.has("goods_verify")

func cooperative(who: String) -> bool:
	return people[who].t>=60 and people[who].a<60 and not people[who].reported

func status(who: String) -> String:
	if people[who].reported: return "已出卖玩家，交易终止"
	if who=="dao" and print_closed: return "旧印刷点已关闭"
	if who=="qian" and qian_due>0: return "自保预警：第%d天末仍高危将出卖玩家" % qian_due
	if people[who].a>=60: return "暂时关闭递送渠道" if who=="xiang" else "风险过高，暂停合作"
	return "可以合作" if people[who].t>=60 else "尚未建立合作"

func blocked(id: String, topic := "censorship") -> Array:
	topic = "censorship"
	if not ACTIONS.has(id): return ["没有这个行动"]
	var a: Dictionary = ACTIONS[id]
	var reasons: Array = []
	if finished: reasons.append("集市已经结束")
	if not presentation.is_empty(): reasons.append("请先读完当前对白")
	if flags.has(key_for(id,topic)): reasons.append("已经完成")
	if id=="qian_help" and people.qian.reported: reasons.append("钱伯已出卖玩家，无法重建交易")
	if ap<cost(id): reasons.append("AP不足：需要%d" % cost(id))
	if a.has("requires") and not flags.has(a.requires): reasons.append("需先完成「%s」" % ACTIONS[a.requires].title)
	if a.get("topic",false) and (not TOPICS.has(topic) or not verified(topic)) and not (id=="answer" and public_waiting.has(topic) and flags.has("legacy_public_gain")): reasons.append("这项发现尚未验证")
	if id.begins_with("supplement_"):
		var channel := id.trim_prefix("supplement_")
		if credited(channel)==0: reasons.append("需要先向这批读者完成传播")
		elif reward(channel)<=credited(channel): reasons.append("没有新的已核实依据可补充")
	var who: String = a.group
	if NAMES.has(who) and not id.ends_with("_help") and not id.begins_with("reassure_") and id not in ["move","quick_cargo","repair_dao"]:
		if not cooperative(who): reasons.append("需要对方信任≥60、警戒<60，且没有出卖玩家")
	if who=="dao" and id in ["small","rush","protect"] and print_closed: reasons.append("印刷点已关闭")
	match id:
		"quick_cargo":
			if flags.has("cargo") or people.qian.reported: reasons.append("货单已取得或交易已终止")
		"repair_dao":
			if public_waiting.is_empty() and not flags.has("rush:censorship") and not flags.has("rush:sea"): reasons.append("需先发生公开赶印")
		"text_verify":
			if not flags.has("text") or not flags.has("ban"): reasons.append("需要旧文本与现行查禁清单")
		"goods_verify":
			if not flags.has("cargo") or not flags.has("seizure"): reasons.append("需要古物货单与对应扣押记录")
		"sea_verify":
			if not has_village_evidence(): reasons.append("需实际携带渔村手记、构件或对应记录")
		"private","manual","caravan":
			if int(packets.get(topic,{}).get("count",0))<1: reasons.append("需要一份尚未使用的对应材料")
		"rush":
			if day not in [2,3]: reasons.append("公开投放只在第2—3天的集会上开放")
		"answer":
			if not public_waiting.has(topic): reasons.append("尚无等待回应的公开质疑")
		"move":
			if not exposed or moved or print_closed or (inspection_done and not late_print_risk()): reasons.append("需要尚未处理的据点暴露，且本章尚未转移")
		"reassure_qian":
			if people.qian.reported: reasons.append("交易已经终止")
	return reasons

func consequence(id: String, topic: String) -> String:
	if id.begins_with("supplement_"):
		var channel := id.trim_prefix("supplement_")
		return "向原接收者解释新增依据，集市公众海洋认知+%d；只补差额，不重复计算原传播。" % maxi(0,reward(channel)-credited(channel))
	match id:
		"quick_cargo": return "立即取得同一份货单，钱伯信任−10、警戒+35。他可能在下一天末出卖你；这不是新的独立来源。可花时间帮他核货、承担查验补救。"
		"repair_dao": return "刀郎信任+15、警戒−10；不抹去暴露，也不重开已被查封的据点。"
		"small": return "制作一批材料，暂存印刷点；尚未传播。" + ("已隐去印记，不暴露据点。" if flags.has("protect") else "未隐去印记，会暴露当前印刷地址；离市时渠道暂停，带着追查风险进入后续地区。此前的搜查结束不代表安全。" if day==4 else "未隐去印记，会暴露印刷点；第3天末搜查。")
		"self_copy": return "制作一份随身材料。抄本不增加独立证据，也不算传播。"
		"private": return "材料交给可靠接收者，现场取得回应。阿香警戒+5；"+gain_text(topic,20)+"。获得客栈引荐信：阿香离市时仍能合作，才保留下一地区的介绍安排。"
		"manual": return "自行走访少量接收者并取得回应；"+gain_text(topic,10)+"。获得读者联络便笺：下一地区可联系这位亲历读者核实消息，不替代新证据。"
		"rush": return "公开传播总计4 AP：本次投放2 AP，之后回应2 AP；保护据点另计。它换取公开影响，不保证比走访省时。印制与投放一并完成，刀郎信任−15、警戒+20，据点暴露。须另花2 AP回应质疑，才形成有效传播；没有预留副本。若已联系客栈读者，第三天搜查将使阿香警戒+25；提前隐去住客身份可避免这项压力。"
		"answer": return "读者接受证据后形成有效传播；"+gain_text(topic,35)+"。获得公众问答记录：后续公开质证可以引用这次已发生的讨论；不自动说服官方人物。已暴露的印刷点不会因此恢复安全。"
		"caravan": return "材料进入待发商队，钱伯警戒+15。第4天末复查合作后出发，离市后的下一全局回合才送达；现在不算传播成功。当前证据对应后续地区海洋认知+%d（待抵达兑现）。到达后接收者能提前阅读，首次会面会带着具体问题；抵达旧学城时按时间结算。" % reward("caravan")
		"move": return "花2 AP保全工具和存稿，处理已暴露的当前地址。每章仅一次，不能抹去之前的传播和身份暴露。"
		"reassure_qian": return "钱伯信任+10、警戒−20，减少出卖风险；不撤回已安排的运输。"
		"reassure_xiang": return "阿香警戒−20，隐去联系信息；已发生的传播仍然保留。"
		"qian_help","xiang_help","dao_help": return "对方信任+20，建立合作。" + ("使用渔村留下的一次引荐，本次免1 AP。" if id=="xiang_help" and cost(id)==0 else "")
		"cargo": return "取得有流转编号的外地古物凭据，钱伯警戒+5。" + ("哑伯的来源说明帮助核验，本次免1 AP。" if cost(id)==0 else "")
		"text": return "取得被删去远方水域段落的旧文本；刀郎警戒+5。"
		"protect": return "隐去印记与来源，刀郎警戒−10；保护后续小批印刷，不会抹去已经发生的暴露。"
		"contacts": return "阿香警戒+5。确定接收者，不算已经送达。"
	return "取得或核验调查材料；不会自动增加认知或传播。"

func evidence_tier() -> int:
	if not verified("censorship"): return 0
	if flags.has("sea_verify"): return 3
	if flags.has("text_verify") and flags.has("goods_verify"): return 2
	return 1

func reward(channel: String) -> int:
	var value := int({"manual":[0,5,10,15],"private":[0,10,15,25],"public":[0,20,25,35],"caravan":[0,10,15,25]}[channel][evidence_tier()])
	return maxi(value,int(flags.get("legacy_public_gain",0))) if channel=="public" else value

func credited(channel: String) -> int:
	var total := 0
	for delivery in deliveries:
		if delivery.channel==channel: total += int(delivery.get("gain",0))
	return total

func evidence_text() -> String:
	return ["尚未完成集市调查","单线调查已核实","两条调查线已交叉印证","集市调查＋渔村证据已比对"][evidence_tier()]

func gain_text(_topic: String, amount: int) -> String:
	var channel: String = {10:"manual",20:"private",35:"public"}[amount]
	var base: int = {"manual":5,"private":10,"public":20}[channel]
	var extra := reward(channel)-base
	return "集市调查+%d，%s额外+%d；本次集市公众海洋认知合计+%d" % [base,"渔村证据补强" if evidence_tier()==3 else "双线交叉印证",maxi(0,extra),reward(channel)]

func preview(id: String, topic := "censorship") -> Dictionary:
	var reasons := blocked(id,topic)
	var text := "消耗%d AP。\n%s" % [cost(id),consequence(id,topic)]
	if ACTIONS[id].get("topic",false): text += "\n传播内容："+TOPICS.censorship+"；"+evidence_text()
	if not reasons.is_empty(): text += "\n不能执行："+"；".join(reasons)
	return {"allowed":reasons.is_empty(),"text":text}

func execute(id: String, topic := "censorship") -> bool:
	topic = "censorship"
	if not blocked(id,topic).is_empty(): return false
	var paid := cost(id)
	ap -= paid
	spent += paid
	flags[key_for(id,topic)] = true
	if id.begins_with("supplement_"):
		arrive(topic,id.trim_prefix("supplement_"),0)
	match id:
		"quick_cargo":
			flags["cargo"] = true
			people.qian.t -= 10
			people.qian.a += 35
		"repair_dao":
			people.dao.t = mini(100,people.dao.t+15)
			people.dao.a = maxi(0,people.dao.a-10)
		"qian_help","xiang_help","dao_help":
			people[ACTIONS[id].group].t += 20
			if id=="xiang_help" and paid==0: consume_support("salt_intro")
		"cargo":
			people.qian.a += 5
			if paid==0: consume_support("elder_origin")
		"text": people.dao.a += 5
		"protect": people.dao.a = maxi(0,people.dao.a-10)
		"small","self_copy":
			var count := int(packets.get(topic,{}).get("count",0))+1
			# A single packet per topic; preserve carried stock when adding print stock.
			var stock: Array = packets.get(topic,{}).get("stock",[])
			stock.append("print" if id=="small" else "player")
			packets[topic] = {"count":count,"stock":stock}
			if id=="small":
				people.dao.a += 5
				if not flags.has("protect"):
					exposed = true
					if day==4: flags["late_print_exposure"] = true
		"contacts": people.xiang.a += 5
		"private","manual":
			use_packet(topic)
			if id=="private": people.xiang.a += 5
			arrive(topic,id,20 if id=="private" else 10)
		"rush":
			people.dao.t -= 15
			people.dao.a += 20
			exposed = true
			public_waiting.append(topic)
		"answer":
			public_waiting.erase(topic)
			arrive(topic,"public",35)
		"caravan":
			use_packet(topic)
			people.qian.a += 15
			var shipment := {"id":origin_id+":"+topic,"topic":topic,"status":"waiting","arrival_turn":entry_turn+4,"target":"next_region","reach":"cross_region"}
			shipment["gain"] = reward("caravan")
			shipment["evidence_tier"] = evidence_tier()
			shipment["outcome"] = "readers_discussing"
			pending.append(shipment)
		"move":
			moved = true
			flags.erase("late_print_exposure")
		"reassure_qian":
			people.qian.t = mini(100,people.qian.t+10)
			people.qian.a = maxi(0,people.qian.a-20)
		"reassure_xiang": people.xiang.a = maxi(0,people.xiang.a-20)
	sync_risk()
	history.append({"day":day,"action":id,"topic":topic,"title":ACTIONS[id].title,"ap":ap,"belief":belief,"receipt":"消耗%d AP；%s" % [paid,TOPICS[topic] if ACTIONS[id].get("topic",false) else "调查进度已记录"]})
	return true

func consume_support(id: String) -> void:
	if not origin.has("support_consumed"): origin.support_consumed = []
	origin.support_consumed.append(id)

func use_packet(topic: String) -> void:
	packets[topic].stock.pop_front()
	packets[topic].count -= 1

func arrive(_topic: String, channel: String, _gain: int) -> void:
	var delta := maxi(0,reward(channel)-credited(channel))
	belief = mini(100,belief+delta)
	for delivery in deliveries:
		if delivery.channel==channel:
			delivery["gain"] = int(delivery.get("gain",0))+delta
			delivery["evidence_tier"] = evidence_tier()
			return
	deliveries.append({"topic":"censorship","channel":channel,"day":day,"reach":reach_for(channel),"gain":delta,"evidence_tier":evidence_tier(),"outcome":"readers_discussing"})

static func reach_for(channel: String) -> String:
	return {"manual":"small","private":"targeted","public":"public"}.get(channel,"small")

func late_print_risk() -> bool:
	return flags.has("late_print_exposure") and not print_closed

func handoff_rewards() -> Dictionary:
	var result := {}
	for delivery in deliveries:
		match delivery.get("channel", ""):
			"manual": result["reader_contact"] = {"title":"读者联络便笺","status":"ready","use":"下一地区可联系亲历读者核实传播经过，不替代新证据","consumed":false}
			"private": result["inn_introduction"] = {"title":"客栈引荐信","status":"ready" if cooperative("xiang") else "suspended","use":"下一地区可接受客栈联系人的介绍；离市时阿香仍需具备合作条件","consumed":false}
			"public": result["public_record"] = {"title":"公众问答记录","status":"ready","use":"后续公开质证可引用已经发生的公众讨论，不自动说服官方人物","consumed":false}
	for shipment in pending:
		result["advance_reading:"+shipment.topic] = {"title":"商队预先送阅 · "+TOPICS[shipment.topic],"status":"in_transit" if shipment.status=="dispatched" else "failed" if shipment.status=="returned" else "waiting","arrival_turn":shipment.arrival_turn,"use":"实际到达后，接收者首次会面可讨论已读材料","consumed":false}
	return result

func handoff_text() -> String:
	var text: Array = []
	var rewards := handoff_rewards()
	for reward in rewards.values():
		text.append(reward.title+"："+{"ready":"已保留，待后续地区使用","suspended":"合作暂停，暂不能引荐","in_transit":"在途，尚未收到","waiting":"待发，尚未收到","failed":"未发出，材料已归还"}[reward.status]+"\n"+reward.use)
	if text.is_empty(): text.append("尚无读者联络、客栈引荐、公众记录或商队送阅安排。")
	if late_print_risk(): text.append("刀郎：搜查后暴露的地址仍有追查风险，后续印刷合作暂停。已送达的消息保留。")
	return "\n".join(text)

func achievements() -> Dictionary:
	var discussion := false
	var public_discussion := false
	for delivery in deliveries:
		if delivery.topic=="censorship":
			discussion = true
			if delivery.get("reach",reach_for(delivery.get("channel","")))=="public": public_discussion = true
	var channels: Array = []
	if flags.has("contacts") and cooperative("xiang"): channels.append("inn")
	if not print_closed and not late_print_risk() and cooperative("dao"):
		for topic in TOPICS:
			if flags.has("small:"+topic) or flags.has("rush:"+topic):
				channels.append("print")
				break
	return {"restriction_verified":verified("censorship"),"readers_discussing":discussion,"public_discussion":public_discussion,"independent_channels":channels}

func achievements_text() -> String:
	var result := achievements()
	var channels: Array = []
	for id in result.independent_channels: channels.append("客栈递送" if id=="inn" else "印刷点")
	return "揭露查禁事实：%s\n读者开始讨论禁令：%s\n形成公开讨论：%s\n仍可使用的独立渠道：%s" % ["已核实" if result.restriction_verified else "尚未核实","已发生" if result.readers_discussing else "尚未发生","已发生" if result.public_discussion else "尚未发生","、".join(channels) if not channels.is_empty() else "尚未建立或已经关闭"]

func sync_risk() -> void:
	if not people.qian.reported and people.qian.a>=60 and people.qian.t<60:
		if qian_due==0: qian_due = day+1
	else: qian_due = 0

func success() -> bool:
	return verified("censorship") and not deliveries.is_empty()

func end_preview() -> String:
	var text := "剩余%d AP将作废。\n调查：%s；已形成有效传播：%d次。" % [ap,"已查明针对性限制" if verified("censorship") else "尚未验证",deliveries.size()]
	if day<=3: text += "\n第3天末搜查："+("旧址已暴露，转移后安全。" if moved else "印刷点已暴露，需要转移工具或接受关闭。" if exposed else "目前没有暴露印刷地址。")
	if day<=3 and exposed and flags.has("contacts") and not flags.has("reassure_xiang"): text += "\n搜查会波及客栈读者：阿香警戒+25，隐去旅客身份可避免。"
	if qian_due>0: text += "\n钱伯将在第%d天末复查自保风险。" % qian_due
	if late_print_risk(): text += "\n印刷地址在搜查后暴露：离市时暂停后续印刷合作，保留追查风险；没有新增临时搜查。"
	if day==4: text += "\n今天结束后离市。商队只在合作有效时出发，离市后的下一回合才送达，不能代替本章实际传播。"
	if not public_waiting.is_empty(): text += "\n公开投放仍有质疑未回应；需要2 AP回应，才能形成有效传播。"
	if day==4: text += "\n\n交接事项\n"+handoff_text()
	return text

func end_day() -> bool:
	if finished or not presentation.is_empty(): return false
	events = []
	if day==3:
		inspection_done = true
		if exposed and flags.has("contacts") and not flags.has("reassure_xiang"):
			people.xiang.a = mini(100,people.xiang.a+25)
			events.append("巡查扩及讨论材料的客栈读者。阿香警戒+25；若达到60，她会暂时关闭递送渠道。")
		if exposed and not moved:
			print_closed = true
			for topic in packets:
				packets[topic].stock = packets[topic].stock.filter(func(holder): return holder!="print")
				packets[topic].count = packets[topic].stock.size()
			events.append("巡查者查封旧印刷点，没收仍存放在那里的副本。已送达的消息不受影响。刀郎避入小巷，无法再印刷。")
		else: events.append("巡查者搜过书摊。"+("旧址扑空，转移的工具和存稿安全。" if moved else "匿名材料没有留下地址，印刷点未被查到。"))
	if qian_due>0 and qian_due<=day:
		people.qian.reported = true
		qian_due = 0
		penalty_next = true
		events.append("钱伯交出交易线索以自保；下一回合少1 AP，未发运输终止。")
	# Village warnings are immutable after departure and use absolute global turns.
	if not import_penalty_used:
		for due in origin.get("warnings",{}).values():
			if int(due)<=entry_turn+day-1:
				import_penalty_used = true
				penalty_next = true
				events.append("渔村未决告密已传来；下一回合少1 AP，同一渔村来源不重复处罚。")
				break
	if day==4:
		for shipment in pending:
			shipment.status = "dispatched" if cooperative("qian") else "returned"
			if shipment.status=="returned":
				var topic: String = shipment.topic
				var stock: Array = packets.get(topic,{}).get("stock",[])
				stock.append("player")
				packets[topic] = {"stock":stock,"count":stock.size()}
		finished = true
		snapshot = {"success":success(),"investigation_verified":verified("censorship"),"belief_local":belief,"deliveries":deliveries.duplicate(true),"shipments":pending.duplicate(true),"print_available":not print_closed and not late_print_risk() and cooperative("dao"),"contacts_available":flags.has("contacts") and cooperative("xiang"),"origin":origin.duplicate(true),"people":people.duplicate(true),"pending_penalty":penalty_next,"public_unanswered":public_waiting.duplicate(),"next_turn":entry_turn+4,"findings":flags.duplicate(true),"packets":packets.duplicate(true),"origin_penalty_used":import_penalty_used,"warnings":{"qian":entry_turn+qian_due-1} if qian_due>0 else {}}
		snapshot["belief_local"] = belief
		snapshot["achievements"] = achievements()
		snapshot["handoff_rewards"] = handoff_rewards()
		snapshot["channel_risks"] = {"print":{"status":"suspended","reason":"late_exposure","address":"new" if moved else "old"}} if late_print_risk() else {}
	else:
		day += 1
		ap = 2 if penalty_next else 3
		penalty_next = false
	return true

func report() -> String:
	var text := "集市调查成功：查明信息限制，并完成一次实际传播。" if success() else "集市目标未完成，仍然可以离开。"
	text += "\n\n集市公众海洋认知：%d\n实际传播：%d次\n\n%s\n这些成果不直接触发全游戏结局。" % [belief,deliveries.size(),achievements_text()]
	for message in deliveries:
		var reach: String = {"small":"少量走访读者","targeted":"可靠接收者","public":"集会公众"}.get(message.get("reach","small"),"读者")
		text += "\n已送达："+TOPICS[message.topic]+" → "+reach
		if message.has("gain"): text += "（海洋认知+%d）" % message.gain
	for shipment in pending: text += "\n商队："+TOPICS[shipment.topic]+("，已出发，预计全局第%d回合送达；尚未兑现" % shipment.arrival_turn if shipment.status=="dispatched" else "，未能发出，材料已归还")
	text += "\n\n交接成果\n"+handoff_text()
	text += "\n\n印刷点："+("搜查后暴露，后续合作暂停" if late_print_risk() else "关闭" if print_closed else "已转移" if moved else "保留")
	for who in NAMES: text += "\n"+NAMES[who]+"："+status(who)
	if not public_waiting.is_empty(): text += "\n公开质疑未回应，不能计作有效传播。"
	if penalty_next: text += "\n下一地区首回合少1 AP。"
	if qian_due>0: text += "\n钱伯自保预警尚未到期：全局第%d回合末复查；离市后无法在本章补救。" % (entry_turn+qian_due-1)
	return text+"\n\n可继续前往旧学城；商队按实际到达时间结算。完成旧学城后可前往羽之森，羽之森结束后可进入王城。"

func to_data() -> Dictionary:
	var result := {}
	for key in ["day","entry_turn","ap","spent","belief","selected","location","people","flags","origin","origin_id","packets","deliveries","pending","public_waiting","history","presentation","finished","snapshot","exposed","moved","print_closed","inspection_done","import_penalty_used","qian_due","penalty_next","events"]: result[key] = get(key)
	return result.duplicate(true)

func valid_data(data: Dictionary) -> bool:
	for key in to_data():
		if not data.has(key): return false
	for key in ["day","entry_turn","ap","spent","belief","qian_due"]:
		if not data[key] is int: return false
	if data.day<1 or data.day>4 or data.ap<0 or data.ap>3 or data.spent<0: return false
	for key in ["people","flags","origin","packets","snapshot","presentation"]:
		if not data[key] is Dictionary: return false
	for key in ["deliveries","pending","public_waiting","history","events"]:
		if not data[key] is Array: return false
	for key in ["finished","exposed","moved","print_closed","inspection_done","import_penalty_used","penalty_next"]:
		if not data[key] is bool: return false
	if data.entry_turn<1 or data.belief<0 or data.belief>100: return false
	if not data.origin_id is String or data.location!="market": return false
	for topic in data.packets:
		if not TOPICS.has(topic) or not data.packets[topic] is Dictionary: return false
		var packet: Dictionary = data.packets[topic]
		if not packet.get("stock") is Array or not packet.get("count") is int: return false
		if packet.count!=packet.stock.size(): return false
		for holder in packet.stock:
			if holder not in ["print","player"]: return false
	for shipment in data.pending:
		if not shipment is Dictionary or not TOPICS.has(shipment.get("topic","")): return false
		if shipment.get("status","") not in ["waiting","dispatched","returned"] or not shipment.get("arrival_turn") is int: return false
	for delivery in data.deliveries:
		if not delivery is Dictionary or not TOPICS.has(delivery.get("topic",""))  : return false
		if (delivery.topic=="sea" or data.flags.get("unified_belief_v3",false)) and not delivery.get("gain") is int: return false
		if delivery.has("gain") and (not delivery.gain is int or delivery.gain<0): return false
		if delivery.get("reach","") not in ["small","targeted","public"]: return false
	for topic in data.public_waiting:
		if not TOPICS.has(topic): return false
	if not data.selected is String or (not data.selected.is_empty() and not NAMES.has(data.selected)): return false
	for who in NAMES:
		if not data.people.get(who) is Dictionary: return false
		for key in ["t","a"]:
			if not data.people[who].get(key) is int or data.people[who][key]<0 or data.people[who][key]>100: return false
		if not data.people[who].get("reported") is bool: return false
	if not data.presentation.is_empty():
		if not data.presentation.get("lines") is Array or not data.presentation.get("index") is int: return false
		if data.presentation.index<0 or data.presentation.index>=data.presentation.lines.size(): return false
		for line in data.presentation.lines:
			if not line is Dictionary or not line.get("text") is String or not line.get("speaker") is String: return false
	return true

func restore(data: Dictionary) -> bool:
	data = data.duplicate(true)
	# Discard retired scores; migrate from actual actions and delivery records only.
	data.erase("openness")
	if data.get("deliveries") is Array:
		for delivery in data.deliveries:
			if delivery is Dictionary:
				if not delivery.has("reach"): delivery["reach"] = reach_for(delivery.get("channel",""))
				if delivery.get("topic")=="censorship":
					if not data.get("flags",{}).get("unified_belief_v3",false): delivery.erase("gain")
					delivery["outcome"] = "readers_discussing"
	if data.get("pending") is Array:
		for shipment in data.pending:
			if shipment is Dictionary:
				shipment["reach"] = "cross_region"
				if shipment.get("topic")=="censorship":
					if not data.get("flags",{}).get("unified_belief_v3",false): shipment.erase("gain")
					shipment["outcome"] = "readers_discussing"
	if not valid_data(data): return false
	for key in to_data(): set(key,data[key])
	if not flags.has("handoff_rules_v2"):
		var protected := false
		var late := false
		for entry in history:
			if entry.get("action","")=="protect": protected = true
			if entry.get("action","")=="small" and entry.get("day",0)==4 and not protected: late = true
			if entry.get("action","")=="move": late = false
		if late: flags["late_print_exposure"] = true
		flags["handoff_rules_v2"] = true
	if not flags.has("unified_belief_v3"): migrate_unified()
	snapshot.erase("openness_local")
	if finished:
		snapshot["belief_local"] = belief
		snapshot["achievements"] = achievements()
		snapshot["handoff_rewards"] = handoff_rewards()
		snapshot["channel_risks"] = {"print":{"status":"suspended","reason":"late_exposure","address":"new" if moved else "old"}} if late_print_risk() else {}
		snapshot["deliveries"] = deliveries.duplicate(true)
		snapshot["shipments"] = pending.duplicate(true)
		snapshot["print_available"] = not print_closed and not late_print_risk() and cooperative("dao")
	# Keep the saved line index and settlement, updating only retired-score wording.
	if not presentation.is_empty():
		var retired := RegEx.new()
		retired.compile("对查禁制度的质疑[：:]?[0-9]+")
		for line in presentation.lines:
			line.text = retired.sub(line.text,"调查与传播成果已记录",true).replace("两种影响分别保留。","读者回应与渠道状态分别保留。")
	return true


func migrate_unified() -> void:
	# Preserve earned legacy belief; merge audience records so old topic buttons cannot farm rewards.
	for id in ACTIONS:
		if flags.has(id+":sea"): flags[id+":censorship"] = true
	if packets.has("sea"):
		var stock: Array = packets.get("censorship",{}).get("stock",[])
		stock.append_array(packets.sea.stock)
		packets["censorship"] = {"stock":stock,"count":stock.size()}
		packets.erase("sea")
	if public_waiting.has("sea"):
		flags["legacy_public_gain"] = 35
		public_waiting.erase("sea")
		if not public_waiting.has("censorship"): public_waiting.append("censorship")
	var merged: Array = []
	for channel in ["manual","private","public"]:
		var entries: Array = deliveries.filter(func(d): return d.channel==channel)
		if entries.is_empty(): continue
		var earned := 0
		for entry in entries: earned += int(entry.get("gain",0))
		var d: Dictionary = entries[0].duplicate(true)
		d.merge({"topic":"censorship","gain":maxi(earned,reward(channel)),"evidence_tier":evidence_tier(),"outcome":"readers_discussing"},true)
		merged.append(d)
	deliveries = merged
	var total := 0
	for d in deliveries: total += int(d.gain)
	belief = mini(100,maxi(belief,total))
	for shipment in pending:
		shipment["gain"] = maxi(int(shipment.get("gain",0)),reward("caravan"))
		shipment["outcome"] = "readers_discussing"
	flags["unified_belief_v3"] = true
