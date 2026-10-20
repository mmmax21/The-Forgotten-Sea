extends RefCounted
const Lines := preload("res://scripts/story/village_story.gd")
const State := preload("res://scripts/story/market_chapter_state.gd")
static func opening(s) -> Array:
	var text: Array = ["离开渔村后，你来到往返商队聚集的集市。若别处也留下了海洋的痕迹，走过远路的人也许知道更多。", "你想弄清一个问题：商品和旅客每天来往，为什么关于海洋的消息却很难听到？", "入口悬着王印通行牌。一辆货车顺利进城，另一位商人却忙着把货单上的‘远航’改成‘河运’。旁边送审的书页，也缺了几行文字。", "可以去问古物商钱伯，货物为什么要改名；也可以找地下印刷者刀郎，看看书页究竟删去了什么。选择一条查清即可，不必把所有人的事都做完。", "客栈老板阿香认识各地旅客。但在把新消息告诉他们之前，你需要能让别人核对的依据，不能只是再讲一个传闻。", "告示写着：第三天末检查书摊与商货，第四天末最后一班商队出发。你有四天调查，并尝试让核实后的发现真正传到读者手中。搜查过后再留下印记，仍会暴露新线索，影响离市后的合作。"]
	if s.supports("salt_intro"): text.append("盐嫂托邻里捎来一句问候：客栈的阿香认得这位联系人，你可以省去一次引荐的工夫。")
	if s.supports("elder_origin"): text.append("哑伯的来源说明随调查结果保存。携带渔村证据时，它可以帮助你核验钱伯的古物。")
	text.append("已经有读者的传播组织可以在终章继续行动；只印刷或只准备渠道还不够。")
	text.append_array(s.events)
	var result := Lines.lines(text)
	result[2]["illustration"] = "gate"
	return result
static func greeting(s, who: String) -> Array:
	var text: Array = {"qian":["钱伯|古物不是不准卖，是有些来历不能写。你若替我核清一批货单，我就给你看原始凭据。","钱伯|别把我的名字贴上墙。我做买卖，不替谁殉道。"],"xiang":["阿香|客人说的未必是假的，但三个人也可能是在重复同一个人的话。","阿香|先把来源核清，再决定告诉谁。你要保护的是住在这里的人。"],"dao":["刀郎|我留着删改前的残页。明明写的是远方水域，送审后却只剩下一条河。","刀郎|文字能走得比人远。可纸上的印记，也能把巡查者带回这里。"]}[who].duplicate()
	if who=="qian" and s.flags.has("cargo"):
		text = ["钱伯|货单你已经看过。别把我改报的名称当成原来的用途，也别把怀疑当成结论。"]
	elif who=="dao" and s.flags.has("text"):
		text = ["刀郎|残页上的字不会自己消失。可要说清删改的理由，还得拿条目逐段对照。"] if not s.verified("censorship") else ["刀郎|现在你有能让别人核对的依据了。接下来要想的是，谁来读，又会留下什么痕迹。"]
	elif who=="xiang" and not s.verified("censorship"):
		text.append("阿香|先找钱伯查货物，或者找刀郎查文字。查清一种限制，再把发现交给愿意听的人。")
	elif who=="xiang":
		text = ["阿香|我可以替你筛选愿意读材料的住客。先联系，再交纸页，听到他们的回应才知道消息有没有传到。", "阿香|告诉他们你查明了什么就好。查禁会让人重新考虑大海的存在；如果还有渔村实证，他们会更相信你的判断。"]
	if who=="dao" and s.print_closed: text = ["旧作坊已经关了。刀郎从巷口向你摇头：这里不能再印。随身的抄本和已送出的消息还在。"]
	if who=="qian" and s.people.qian.reported: text = ["钱伯不再接你的话。他已经交出交易线索，旧合作无法继续。"]
	if who=="xiang" and s.people.xiang.a>=60: text = ["阿香|有人开始打听住客了。先把姓名和住址从联系记录里隐去，我才能继续考虑递送。"]
	return Lines.lines(text)

# Read-only guidance is derived from facts, so old saves immediately receive it.
static func stage(s) -> Dictionary:
	if s.finished:
		return {"title":"离市之后", "question":"消息留下了什么影响？", "next":"查看离市结果：已经送达的消息、尚在途中的材料和人物处境分别记录。"}
	if s.late_print_risk():
		return {"title":"处理离市前的暴露", "question":"这次印刷留下的地址怎么办？", "next":"已送达的消息保留。搜查后留下的印记会让后续印刷合作暂停；若尚未转移过，可花2 AP转移，否则带着风险离市。保护来源只影响之后的印刷。"}
	if s.success():
		return {"title":"发现已经传出", "question":"离开前，还要保护谁、留下什么？", "next":"基本目标已完成。补齐另一条调查线或核验渔村证据，可提高后续传播收益；已送达的读者需补充说明才增加差额。也可处理暴露、保留渠道或安排商队外送。"}
	if not s.verified("censorship"):
		var hint := "找钱伯询问改名的货物，或找刀郎调查被删的文字。选择一条路线即可。"
		if s.flags.has("text") and s.flags.has("ban"): hint = "两份文字依据已齐。在公共调查中对照旧文本与查禁条目，确认删除是否有针对性。"
		elif s.flags.has("cargo") and s.flags.has("seizure"): hint = "货单与扣押记录已齐。在公共调查中核对货号和扣押理由，确认哪些用途受到限制。"
		elif s.flags.has("text"): hint = "旧页只能说明内容被删。去公共调查抄录查禁清单，再核对哪些段落正好落入禁令。"
		elif s.flags.has("cargo"): hint = "改名可能只是商人的做法。去公共调查查阅扣押记录，再判断它是否与官方限制有关。"
		elif s.flags.has("ban"): hint = "禁令说明哪些内容不准传。找刀郎取得旧文本，才能核对它怎样作用于具体故事。"
		elif s.flags.has("seizure"): hint = "扣押理由已经记下。找钱伯核验原货单，确认被扣物品原本是什么用途。"
		elif s.flags.has("dao_help"): hint = "残页已经整理好。继续向刀郎查看旧文本，寻找被删掉的内容。"
		elif s.flags.has("qian_help"): hint = "钱伯愿意合作了。继续核验古物与原始货单，追查改名之前的用途。"
		return {"title":"追查信息限制", "question":"这些信息为什么难以流通？", "next":hint}
	if not s.public_waiting.is_empty():
		return {"title":"回应读者的追问", "question":"你说的限制，有什么依据？", "next":"公开的纸页已引起注意，但读者还在等待证据。到公共调查回应质疑，需要2 AP；印刷点的暴露仍需另行处理。"}
	for topic in s.packets:
		if s.packets[topic].count>0:
			return {"title":"把依据交给读者", "question":"谁会真正读到你的发现？", "next":"已有未用副本。可请阿香联系并递送，或在公共调查自行走访。商队能送往外地，但待发不能代替本章实际传播。"}
	if s.print_closed:
		return {"title":"寻找仍能使用的渠道", "question":"印刷点关闭后，消息还能怎样传出？", "next":"已送达的消息没有撤销。可在公共调查查看是否还能自行抄写，再走访或请阿香递送；若时间或材料不足，离市时会记为尚未完成传播。"}
	if not s.pending.is_empty():
		return {"title":"消息仍在路上", "question":"集市里有人读过了吗？", "next":"商队材料还未送达。要完成本章目标，还需准备另一份材料递送。公开投放只在第2—3天开放，不能把尚未抵达的商队当作当前成果。"}
	if s.day==4:
		return {"title":"完成最后的交接", "question":"离市前，谁能读到你的发现？", "next":"公开投放的集会窗口已结束。查看还能制作或使用哪些副本，再选择递送；若剩余时间不足，可接受未完成传播的离市结果。"}
	return {"title":"决定如何传播", "question":"查明的限制，要怎样让别人知道？", "next":"选择传播方式：请刀郎印制后递送，自己抄写并走访，或在第2—3天公开赶印再回应质疑。调查已完成，无需重复验证另一条路线。"}

static func overview(s) -> String:
	var current := stage(s)
	return "为什么来集市\n渔村留下了关于海洋的疑问。这里往来的人和货物更多，你想知道：相关消息为什么没有随商路一起流通？\n\n你在追查什么\n钱伯的货单和扣押记录，可以说明航行物品为何改名；刀郎的旧文本和查禁清单，可以说明故事为何被删。查明一条就能推进。\n\n为什么还要传播\n只有你知道，消息仍停在原处。把核实后的依据交给读者、听到回应，才能确认信息跨过了这道限制。印好和装袋都不是送达。\n\n目前：%s\n%s\n%s" % [current.title,current.question,current.next]

static func purpose(id: String) -> String:
	return {
	 "qian_help":"先理清货号，钱伯才肯让你追查改名之前的货物用途。",
	 "xiang_help":"阿香要先确认来意，才会把你介绍给需要保护身份的住客。",
	 "dao_help":"把残页按版本整理，才能找到被删段落；这也是取得刀郎合作的机会。",
	 "text":"亲眼看到删改前写了什么，随后才能与查禁条目核对。",
	 "ban":"找出官方禁止传播的具体内容，判断旧文本的缺失是否与它对应。",
	 "text_verify":"把‘故事少了几句’推进为有依据的判断：删掉的是禁令针对的内容。",
	 "cargo":"确认古物的原用途与流转编号，避免把商人改写的名称当成事实。",
	 "seizure":"了解哪类物品被扣、理由是什么，之后用原货单核对。",
	 "goods_verify":"核对具体货号和用途，判断扣押是否专门针对航行相关物品。",
	 "sea_verify":"把渔村疑问与外地线索联系起来；完成比对后，它会增强调查传播的认知收益；仍需完成一条集市调查。",
	 "contacts":"找到愿意读材料的人，并安排保护身份的交接；还没有把消息送出去。",
	 "small":"把已经验证的发现做成可以交给读者的材料；下一步仍需递送。",
	 "self_copy":"没有印刷者也能准备材料，代价是时间更多、能接触的人较少。",
	 "private":"让可靠的接收者读到依据，并确认他们理解了什么。",
	 "manual":"自己花时间寻找读者、回答问题，完成少量实际传播。",
	 "rush":"借集会迅速让更多人注意你的发现，但需要回应质疑，也会留下追查线索。",
	 "answer":"回答读者为什么应该相信这份材料，让公开投放转化成有效传播。",
	 "caravan":"让发现走出集市，为后续地区留下影响；它不会立即改变眼前的读者。",
	 "protect":"纸上的印记可能把巡查者带回作坊，提前保护后续印刷的来源。",
	 "move":"巡查时间已经公布。转移保住的是未来继续印刷的能力，不能收回已经传出的消息。"
	}.get(id,"处理合作中的风险，让帮助你的人有继续行动的余地。")

static func action(s, id: String, topic: String) -> Array:
	var text: Array = []
	match id:
		"quick_cargo": text = ["钱伯|你连这批货单都没替我核清，就要拿原始凭据去追问？", "他把凭据推过来，反复确认你有没有把货站的名字告诉别人。", "钱伯|我先给你。真有人来问，我得先保住这摊生意。"]
		"repair_dao": text = ["你接手印刷后的联系与解释，向刀郎承认赶印给他带来的风险。", "刀郎|后面的事一起担。印记已经出去，旧址还是得处理。"]
		"qian_help": text = ["你把混在河运用品中的货号重新列好，钱伯收起了戒备的目光。","钱伯|现在谈来历。先说好，原始货单别交给巡查者。"]
		"xiang_help": text = ["阿香核实介绍人的身份，带你走到客栈后院。","阿香|有人愿意听，但名字不能写在传单上。"]
		"dao_help": text = ["你帮刀郎按纸张与页码整理残页，同一段故事露出了两个版本。","刀郎|你看这里，水面的颜色还在，名字被刮掉了。"]
		"cargo": text = ["钱伯取出一件弧形旧船饰和原始货单。外地货站的编号仍在，航行用品却被改报成了河岸装饰。","这提供了跨地区流转线索；尚需扣押记录来判断改报是否与查禁有关。"]
		"seizure": text = ["扣押登记写着货站编号和处置理由：普通河运用品放行，涉及远航用途的部件则被单独扣留。你记下编号，准备与原始货单核对。"]
		"goods_verify": text = ["原货单的用途、货号与扣押登记吻合。扣押并非所有旧货一律处理，而是针对远航用途。","你确认：与海洋相关的物品流通受到有针对性的限制。谁制定了这些规则，仍需往下追查。"]
		"text": text = ["旧页记着望不到岸的蓝色水域，以及驶离河口的船。刀郎保留了原页，也指出送审版本的删除位置。"]
		"ban": text = ["告示不只限制未经许可的印刷，还单列了远方水域、离境航行及相关地图的传播条款。你抄下日期与条目。"]
		"text_verify": text = ["你逐段核对旧页与查禁条目。被删掉的内容恰好对应海洋与远航，其他段落却完整保留。","你确认这类信息受到针对性限制；尚不能仅凭这份材料推断所有历史都被改写。把发现告诉居民，会让他们更相信大海可能存在。"]
		"sea_verify": text = ["你将携带的渔村材料与有外地来源的古物记录并列核验。类似的航行痕迹并非只出现在渔村。"]
		"protect": text = ["刀郎换掉能辨认作坊的印记，你把人名与住址从后续小批材料中移除。已经公开出去的版本无法收回。"]
		"small": text = ["刀郎印好一小批材料，暂存在作坊。墨迹未干，纸还没有到读者手里。"]
		"self_copy": text = ["你自己抄录依据，避开可识别身份的细节。少量副本留在身上；它们仍然来自同一组证据。"]
		"contacts": text = ["阿香核实接收者不会只是转述同一个消息，分别约好交接地点。联系已建立，材料还未送到。"]
		"private": text = ["阿香陪你把材料交给可靠的住客。有人拿着条目追问，你当面指出对应依据。",("客人|渔村与外地都留下了航行痕迹，大海的传闻更可信了。" if s.evidence_tier()==3 else "客人|原来这些内容被有意限制了。关于大海的传闻，也许值得重新考虑。"),"接收者已经回应，这次传播正式生效。阿香写下客栈引荐信；离市时她仍愿意合作，后续介绍才能保留。"]
		"manual": text = ["你花时间逐户走访，说明来源并回答问题。愿意接下纸页的人不多，但你听到了真实的回应。","少量读者已经接收并理解材料，这次传播正式生效。一位即将远行的读者留下联络便笺，之后可以核实这次传播的经过。"]
		"rush": text = ["新印的纸页迅速出现在集会上，也留下了作坊的印刷特征。","刀郎|消息是快了。现在他们顺着印记就能找到这里。","读者|你写得这么肯定，凭据在哪里？","投放已发生，但质疑尚未回应。离市前需要另花2 AP出示依据，才能形成有效传播。"]
		"answer": text = ["你把可核验的依据放到读者面前，解释文字里每一处判断的来源，不夸大尚未查明的部分。","围观者开始拿着材料相互讨论。公开传播已生效；你留下公众问答记录，供后续质证引用。印刷点的风险仍然存在。"]
		"caravan": text = ["钱伯把副本装进末班商队的待发袋。货袋仍在集市。","钱伯|离开前我还得看风声。发出去也要走一天，别把装袋当作已经送到。"]
		"move": text = ["你们把工具和存稿移到另一个临时作坊。旧址的痕迹还在，巡查者仍会去那里。"]
		"reassure_qian": text = ["你接过需要解释的查验环节，把货主身份从后续文件中隐去。钱伯重新权衡风险，暂时收起了退意。"]
		"reassure_xiang": text = ["你和阿香重新整理接收记录，移去旅客姓名与住址。她愿意继续评估递送安排。"]
	if id.begins_with("supplement_"): text = ["你找到原来的接收者，说明新增的核实依据。他们对大海的判断进一步改变；本次只计算新增认知。"]
	if id in ["private","manual","answer"]: text.append("本次依据："+s.evidence_text()+"。集市公众海洋认知现为%d。" % s.belief)
	if id=="small" and s.late_print_risk(): text.append("新印记留下了可追查的地址。今晚不会突然再搜查，但后续印刷合作将暂停；已送达的消息不撤销。")
	if id in ["qian_help","dao_help","cargo","quick_cargo","text","ban","seizure","goods_verify","text_verify","small","self_copy","contacts","private","manual","answer","caravan"]:
		text.append(stage(s).next)
	if id in ["goods_verify","text_verify"]:
		text.insert(2,"你已经查明一种限制。下一步不用再向自己证明一遍，而是让别人有机会读到依据，并自己判断。")
	if State.ACTIONS[id].get("topic",false): text.append("本次内容："+State.TOPICS.censorship+"。")
	var result := Lines.lines(text)
	match id:
		"goods_verify": result[0]["illustration"] = "cargo"
		"text_verify": result[0]["illustration"] = "pages"
		"private", "manual", "answer": result[1]["illustration"] = "readers"
	return result
static func day_start(s) -> Array:
	var text: Array = s.events.duplicate()
	text.append("集市第%d天，可用%d AP。" % [s.day,s.ap])
	if s.day==3: text.append("今晚检查书摊与商货。留下印记的据点需要现在处理；这是集会公开投放的最后一天。")
	text.append(stage(s).question+" "+stage(s).next)
	if s.day==4: text.append("今晚末班商队出发，你也必须离开。先确认读者联络、客栈引荐与公众记录，再检查商队是否能发出。今天未隐去印记的印刷仍会暴露地址，离市时暂停后续印刷合作。")
	return Lines.lines(text)
