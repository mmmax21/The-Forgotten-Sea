extends RefCounted
const Lines := preload("res://scripts/story/village_story.gd")
static func opening(s) -> Array:
 var text: Array=["羽之森的人背后没有完整的翅膀。艾尔让你看肩胛附近两处突出的骨头，问你：‘它们以前是不是别的样子？’", "艾尔|我总梦见一片蓝色，梦里我能离开地面。可醒来以后，什么都做不到。", "洛恩|飞行只是长辈讲的传说。不过他们说过，很久以前，人们会登高看远方。", "伊卡恩回避飞行记录的话题。他小时候曾从高墙坠落，濒死时似乎短暂离地，长辈却说那是幻觉。他如今也不能自由飞行。", "普通人与贵族原本具有同样的飞行能力。你还要查明这段过去；眼下能看到的身份差别，是贵族有机会接近高塔，普通人不被允许。", "第五天将举行安翼礼，孩子们会背诵‘普通羽人应当安守地面’，洛恩的孩子也在其中。第四天晚间开始戒严，高塔将关闭。", "五天，每天3 AP。先调查废弃观测台，再找另一条旧生活线索。取得、核实并保全高塔中的两项证据，就能完成基本目标；传播和飞行迹象另作结算。"]
 text.append_array(s.events)
 return Lines.lines(text)
static func stage(s) -> Dictionary:
 if s.finished: return {"title":"羽之森留下了什么？","next":"查看证据、传播与人物处境，再前往王城。"}
 if s.day==5 and not s.has("wall_record"): return {"title":"高塔已经封锁","next":"无法再补取关键证据。可以处理已有线索或二笔的接应，第五天结束后带着部分调查离开。"}
 if not s.has("platform"): return {"title":"为什么长辈曾经登高？","next":"去公共调查查看废弃观测台和旧石牌。也可先听三位人物的经历与顾虑。"}
 if not s.has("old_routes") and not s.has("old_customs"): return {"title":"观测台曾给谁使用？","next":"自行查旧通行记录，或先争取洛恩支持，请他回忆高墙修建前的生活。"}
 if not s.has("lead_compare"): return {"title":"把塔外线索放在一起","next":"在公共调查免费整理观测台和旧生活的疑点，再选择怎样进入高塔。"}
 if not s.has("tower_open"): return {"title":"赶在封锁前进入高塔","next":"用已有调查争取伊卡恩带路，或在公共调查定位废弃入口、自行进入。第四天末关闭，进入后还要留1 AP取证。"}
 if not s.has("wall_record"): return {"title":"进入了，还要拿到证据","next":"在公共调查花1 AP调查封存区，同时取得翅骨测绘与高墙修建记录。必须第四天结束前完成。"}
 if not s.has("verify_history"): return {"title":"骨头和文书说明了什么？","next":"到公共调查核对如今的骨痕、古老翼骨与修建记录。取到材料不等于已经查明。"}
 if not s.has("preserve"): return {"title":"先让证据留得下来","next":"花1 AP保全证据和副本即可基本通关。想第五天公开，还需第四天前选好支持者、联系居民。"}
 return {"title":"查明之后，怎样让别人知道？","next":"可保存后离开，或花1 AP小范围说明。公开需第四天前组织居民，第五天花2 AP；额外补强齐备才出现飞行迹象。海洋认知要先核对海岸条目或携带实证。"}
static func greeting(s,who: String) -> Array:
 if s.people[who].closed: return Lines.lines([s.NAMES[who]+"因压力暂停新协助，已交出的材料保留。"])
 if who=="el": return Lines.lines(["艾尔|梦里的我能飞，醒来却只有这两处骨头。我想知道自己是不是一直在幻想。", "艾尔|如果你找到证据，我愿意认真听。但公开之前，得想想家里人会被问什么。"])
 if who=="lo": return Lines.lines(["洛恩|我以前只叫孩子安分些。可长辈为什么又说，过去的人总要登高看远方？", "洛恩|先把证据查清楚。我不想为了传说，让家人被巡视的人盯上。"])
 return Lines.lines(["伊卡恩|小时候从墙上掉下来，我以为自己在空中停了一下。长辈说，快死的时候什么幻觉都可能有。", "伊卡恩|我也不能随时飞起来。身份能让我接近高塔，却不能替我解释那件事。"])
static func action(s,id: String) -> Array:
 var text: Array=[]
 match id:
  "platform": text=["残缺石牌写着：‘登高以辨风向，望远以识归途。’观测台与高墙的接缝并不一致，台子比墙更早。", "这里曾经用来观察远方、辨认方向。墙建起来以前，人们的生活可能并不局限在里面。还需要另一条来源核对。"]
  "roster": text=["公共旧记录提到普通居民曾沿高处往返，并使用观测设施。旧路在如今的墙边中断。它与石牌的用途相符，却还不能单独证明飞行。"]
  "el_help": text=["艾尔讲起反复出现的蓝色梦境，并让你记下肩胛骨附近的骨痕。他愿意帮助调查，也希望公开前先说清风险。"]
  "lo_help": text=["洛恩|我不想让孩子重复一段没人查过的传说，也不想把真正的过去当作胡话。", "你答应先查证，不把家属当作组织者。他愿意继续讲旧习俗。"]
  "lo_memory": text=["洛恩回忆，长辈说高墙建起前，人们会登高辨认归途，普通家庭也会这样做。后来登高和眺望墙外被禁止，故事才逐渐变成传说。"]
  "lead_compare": text=["观测台早于高墙，另一条记录也提到普通人登高往返。官方说法留下了无法解释的空白。", "高塔可能保存更完整的旧档案。可以把调查交给伊卡恩，请他带路；也可以自己寻找废弃入口。"]
  "ika_help": text=["你把观测台和旧生活线索交给伊卡恩。他看了很久，才说：‘也许长辈的解释并不是全部。’", "伊卡恩|我能用通行资格带你进去，但不能保证没人追问。先约好查哪些材料。"]
  "tower_locate": text=["你沿旧图找到废弃通道，记下入口。巡视者注意到有人在附近停留；进入还需要另外安排时间。"]
  "tower_enter": text=["你从废弃入口步行进入高塔，避过正门的身份检查。巡视因此更警觉。封存区还没有调查，不能空手离开。"]
  "tower_permit": text=["伊卡恩以自己的通行资格带你步行进入高塔。他承担带路的追问风险，身份没有让他获得飞行能力。"]
  "tower_search": text=["封存区里，一具古老骨架的肩胛向两侧延伸出明显翼骨。你对照如今羽人的骨痕，仔细测绘并记录出处。", "另一份文书记载：后来修建的高墙用于阻止羽族飞往外界，相关历史也被删除。签署者是疯祭司。", "两项关键证据已经保存为随身记录，还需要核对它们能说明什么。"]
  "verify_history": text=["古老翼骨与如今的骨痕能够对应；修建记录说明限制外出和删除历史并非自然发生。普通人与贵族过去都能飞，身份差别在于接触高塔的机会。", "你确认了身体变化与人为限制的证据，但尚不知道它们怎样共同造成今天的状态。疯祭司的签署把调查指向王城。"]
  "preserve": text=["你保存测绘、原文对应位置与可核查的副本。即使不公开，本章的调查也已留下完整成果。", "接下来可以小范围说明，或提前组织支持者，在第五天公开。拿到飞行证据不会自动增加海洋认知。"]
  "corroborate": text=["你再次用观测台的年代与旧生活线索核对高塔文书，排除只凭一份档案下结论的疑虑。不同来源能够互相支持。"]
  "witnesses": text=["你和具名支持者联系居民，约好第五天听取证据，说明材料出处与可以确认的范围。大家尚未听完公开说明，不会提前计作传播。"]
  "sea_basis": text=["修建档案的附页提到海岸、外部水域与通往墙外的路线。你核对日期、出处与上下文，确认它不只是关于飞行的传说。", "查阅这些条目增加了官方注意。还需讲给居民，才会提高海洋认知。"]
  "cross_region": text=["你将实际携带的外地实证与修建记录中的海岸条目核对，留下对应关系。飞行历史与海洋证据现在可以分别向居民解释。"]
  "sea_share": text=["几位居民收下副本，听你解释翅骨和修建记录。他们开始怀疑‘羽人从来不能飞’的旧说法。", "这次说明只在小范围发生，安翼礼仍会照常举行。"]
  "public_demo":
   text=["孩子们准备在安翼礼背诵旧训诫，洛恩的孩子也在其中。你请现场先听翅骨与修建记录所揭示的过去。", "%s自愿站出来支持调查。有人要求停止，也有人留下听完。" % s.NAMES[s.participant]]
   if s.has("flight_sign"): text.append("在充分准备的说明和讨论后，一名羽人忽然感到身体变轻，双脚短暂离地，肩胛骨痕微微发热。没有完整翅膀扇动，也没有人恢复自由飞行。居民分别记下这次异常，原因仍要继续追查。")
   else: text.append("没有人当场离地。证据仍使一些家庭停下背诵，重新思考旧说法；有效传播并不以出现奇迹为条件。")
   text.append(family_text(s.make_snapshot()))
  "sea_supplement": text=["你找到原来的读者，补充后来核实的海洋依据。只记录新增理解，旧传播不会重复计奖。"]
  "discreet": text=["你调整公开材料的范围与联络安排，避开巡视者正在追查的聚集点。官方注意降低，已经发生的事仍然保留。"]
  "protect_el","protect_lo","protect_ika": text=["你安排见证记录、陪同回应和后续联系。艾尔的家人不必替他解释组织经过，涉及洛恩孩子的询问要由家长陪同，伊卡恩也可以有人陪他面对长辈。", "此人的压力减轻，公开身份没有被抹去。"]
  "select_el","select_lo","select_ika": text=["你与%s确认由他担任具名支持者。" % s.NAMES[s.participant]]
  "er_prepare": text=["你托人送出交接凭据，说明师姐没有参与额外开箱；仍需安排接应，可以另一天完成。"]
  "er_receive": text=["二笔已被接到安全处，师姐的责任得到澄清，联系恢复。她失去抄写工作的损失仍在。"]
 if id in ["sea_share","public_demo","sea_supplement"]: text.append("本次传播的海洋认知依据："+("已核对海岸或外地实证，按已解释的材料计入。" if s.evidence_tier()>0 else "尚未核对海洋材料，本次只改变飞行历史的认识。")+"当前海洋认知%d。" % s.belief)
 text.append(stage(s).next)
 return Lines.lines(text)
static func day_start(s) -> Array:
 var text: Array=s.events.duplicate()
 text.append("羽之森第%d天，可用%d AP。" % [s.day,s.ap])
 if s.day==4: text.append("今晚高塔封锁。已经进入也必须今天取得翅骨与修建记录；还要提前组织居民，才可明天公开。")
 if s.day==5: text.append("高塔已封锁。安翼礼前仍可整理手中证据、保全、小范围说明，或按此前安排公开。")
 text.append(stage(s).next)
 return Lines.lines(text)
static func family_text(forest: Dictionary, contacts: Dictionary={}) -> String:
 var who: String=forest.get("findings",{}).get("public_participant","")
 if who not in ["el","lo","ika"]: return ""
 var name: String={"el":"艾尔","lo":"洛恩","ika":"伊卡恩"}[who]
 if who=="ika":
  var state: String=contacts.get(who,{}).get("status","")
  if state=="suspended" or forest.get("people",{}).get(who,{}).get("closed",false): return "伊卡恩因公开质疑受到长辈追问，暂时不能提供新协助；证据与公开发言仍然保留。"
  if state=="protected" or forest.get("findings",{}).get("protect_ika",false): return "伊卡恩有人陪同回应长辈，公开质疑的责任由他自己承担，已有证据保留。"
  return "伊卡恩公开质疑后受到长辈关注。未处理的预警会延续到王城；他的身份不保证他免于追问。"
 var risk: String=contacts.get(who,{}).get("status","")
 var closed: bool=forest.get("people",{}).get(who,{}).get("closed",false) or risk=="suspended"
 var pending: bool=forest.get("warnings",{}).has(who) and risk!="protected" and not closed
 var protected: bool=forest.get("findings",{}).get("protect_"+who,false) or risk=="protected"
 if closed:
  return name+"的公开身份引来了持续追问。"+("家人被要求解释是谁组织了尝试，暂时不再替他传递消息。" if who=="el" else "家属也受到核查，他暂时停止新的公开活动，留在孩子身边。")+"已发生的调查和传播保留；这段压力不会因世界改变而被抹去。"
 if pending:
  return name+"还有未处理的公开预警。"+("家人被追问是谁组织尝试。" if who=="el" else "他担心孩子被单独问话。")+"期限到来前仍可保护；后续若无人处理，会限制新的协助，已有记录不会消失。"
 if protected:
  return name+"与家属已有陪同和后续联系。"+("艾尔可以带着见证记录回应，不必让家人替自己解释。" if who=="el" else "洛恩可以在家长陪同下处理涉及孩子的询问，孩子不必独自回答。")+"公开身份仍然存在，保护没有让别人忘记那次公开发言。"
 return name+"被更多人认出。"+("家人开始收到关于组织者的询问。" if who=="el" else "他开始担心询问会落到孩子身上。")+"当前尚未到暂停协助的程度，也仍可安排保护。"

static func departure(s) -> Array:
 var text: Array=s.events.duplicate()
 text.append(s.result_text())
 if s.has("public_demo"): text.append("安翼礼结束后，几个家庭还在讨论翅骨与高墙。训诫未立刻消失，但已经有人提出不同的解释。")
 elif s.has("sea_share"): text.append("安翼礼按原样结束。你留下的小范围读者仍保管着证据，等待以后继续核对。")
 elif s.success(): text.append("你没有公开证据，安翼礼照常举行。副本已经保全，王城调查还有依据可用。")
 else: text.append("安翼礼结束，你带着部分发现离开；这次没有查清完整经过。")
 var family:=family_text(s.make_snapshot())
 if not family.is_empty(): text.append(family)
 if s.has("signature"): text.append("疯祭司的签名指向王城。你决定去查清他为什么参与修墙与删除历史，以及飞行能力如何消失。")
 else: text.append("你尚未取得签署者的记录。下一步去王城查禁令总档案，不能把猜测当成已经查明的事实。")
 return Lines.lines(text)
