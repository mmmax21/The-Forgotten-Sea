extends RefCounted
const Lines := preload("res://scripts/story/village_story.gd")
static func opening(s) -> Array:
 var text: Array=["穿过高墙下的门道，你来到羽之森。这里的人背后都有羽翼，却像早已忘记天空一样生活。", "艾尔站在旧训练台边张开翅膀，洛恩把他劝了下来。", "洛恩|我们这一支早就不能飞了。别让家里人替一次没有准备的尝试担心。", "艾尔|可每次梦见那片蓝色，我都觉得自己知道怎么飞。", "不远处，伊卡恩想起自己从高墙跌落又短暂飞起的经历。他迟疑了一下，仍称那是一场梦。", "第五天将举行安翼礼，长者会重申地面生活与身份秩序。你可以在那之前调查、组织尝试，并决定是否公开展示。", "五天，每天3 AP。先核实普通羽人的飞行历史，再找自愿参与者、准备低台并联系见证者。首次尝试2 AP，另一天复核2 AP；最晚第四天开始。", "飞行现象和海洋认知分别记录：飞起来不直接证明有海，向居民解释已核实的海洋依据才增加认知。"]
 text.append("普通羽人的跨日复核是海回归所需的现实验证。是否公开传播另行决定；没有读者的地区不能在终章凭空补传。")
 text.append_array(s.events)
 return Lines.lines(text)
static func stage(s) -> Dictionary:
 if s.finished: return {"title":"羽之森离林交接","next":"查看飞行观察、海洋传播与人物处境。可以继续进入王城，调查法器与禁令的起源。"}
 if s.success(): return {"title":"普通羽人已重新腾空","next":"基本目标已完成。可进入高塔、追查禁令签署，或第五天在安翼礼公开展示。公开会增加参与者压力，海洋收益取决于实际依据。"}
 if s.day==5 and not s.has("first_trial"): return {"title":"已错过跨日复核窗口","next":"今天无法补做两天的观察。仍可调查、说明海洋依据，最后带着部分成果离林。"}
 if not s.has("roster"): return {"title":"谁曾经飞过？","next":"在公共调查查阅普通羽人空运名册，再调查旧训练场。学城帮助可以在确认行动时主动使用。"}
 if not s.has("platform"): return {"title":"文字需要实物印证","next":"调查旧训练场，核对起落设施是否只供少数贵族使用。"}
 if not s.has("verify_history"): return {"title":"核实普通羽人的飞行历史","next":"名册与训练场记录已齐。到公共调查核对身份、任务和设施，不把贵族的个人经历当作普通人的证明。"}
 if not s.participant_ready(): return {"title":"寻找自愿参与者","next":"与艾尔约定尝试边界，或回应洛恩的家庭顾虑。选择一位普通参与者；若已有预警，先处理他的压力。"}
 if not s.has("witnesses") or not s.has("prepare"): return {"title":"为共同尝试做准备","next":"在公共调查联系愿意见证的居民，并准备低台。两项都完成后才能进行首次尝试。"}
 if not s.has("first_trial"): return {"title":"第一次有见证的尝试","next":"准备已经齐全。花2 AP记录第一次短暂腾空，之后另一天还需2 AP复核。"}
 if s.attempts[0].day==s.day: return {"title":"记录已经出现的现象","next":"今天不能再次计作复核。可以调查禁令或高塔，明天再用2 AP进行第二次观察。"}
 return {"title":"让现象经得起复核","next":"在公共调查隔日复核。可以由原参与者再次尝试，也可以先取得另一位普通人的自愿合作；这一步完成后才算基本通关。"}
static func greeting(s,who: String) -> Array:
 if s.people[who].closed: return Lines.lines([s.NAMES[who]+"暂时不再参加新的行动。此前的观察和已传播成果仍然保留。"])
 return Lines.lines({"el":["艾尔|我想知道那不是梦。我也不想让别人为了证明我的愿望去冒险。", "艾尔|如果你找到了依据，就一起准备好，再请愿意听的人来看。"],"lo":["洛恩|我不是讨厌天空。我只是知道，一次冲动之后，还得有人照顾家里。", "洛恩|先让我看看普通人确实飞过的证据。把准备和见证做好，我才愿意尝试。"],"ika":["伊卡恩|小时候我从墙上跌下来，却记得自己在空中停住了。他们说那是梦，也说只有我们的血统才可能做到。", "伊卡恩|我能带你进入高塔。但你若要证明普通人也能飞，不能只拿我的经历作证。"]}[who])
static func action(s,id: String) -> Array:
 var text: Array=[]
 match id:
  "roster": text=["旧名册列着搬运者、信使和沿海运输的任务。他们并不全是贵族，姓名旁还留着普通家庭的交接记号。"]
  "platform": text=["训练场排列着大量普通尺寸的起落位，磨损方向与名册中的运输用途吻合。这里曾经容纳的远不止少数贵族。"]
  "verify_history": text=["你核对职业、家族身份和训练设施：普通羽人过去确实参与过飞行。", "历史已经核实，但他们今天能否重新飞起，仍需要有准备、有见证的尝试。"]
  "el_help": text=["艾尔愿意尝试，也同意先核实依据、做好准备，再邀请普通居民见证。"]
  "lo_help": text=["你认真听完洛恩对家人的顾虑。他愿意继续核对历史，并在条件明确后参加尝试；谨慎不是必须被消除的障碍。"]
  "ika_help": text=["伊卡恩把童年的细节与家族记录放在一起，不再简单地称它为梦。你们保留这份个人反例，也承认它不能代表所有人。"]
  "select_el","select_lo": text=["你与%s约定下一次参与，过去的观察仍按原参与者记录。" % s.NAMES[s.participant]]
  "witnesses": text=["几位普通居民读过名册，听你说明训练场的用途。他们没有许诺奇迹，只答应支持参与者并如实记录看到的现象。"]
  "prepare": text=["你们选择旧训练场的低台，约定尝试方式和停止时机。准备完成，不需要从高塔跃下证明任何事。"]
  "first_trial": text=["%s在见证者面前张开羽翼。起初只是迟疑地摆动，随后双脚短暂离地。" % s.NAMES[s.participant],"旁观者没有急着宣布所有人都能飞了。你记下时间、参与者与现象，约定另一天复核。"]
  "replicate": text=["换了一个日期，%s在相同准备和见证下再次短暂腾空。" % s.NAMES[s.participant],"普通羽人的飞行现象已经过跨日复核。居民开始重新思考：那些被当作身体事实的限制，是否一直如此？"]
  "ban": text=["较早的规定写着‘不许擅自飞行’，后来的讲义却写‘普通羽人不能飞行’。两种说法之间，隔着几代人的生活。"]
  "trace_ban": text=["你核对日期与旧任务记录：禁令和教育变化先于普通飞行逐渐消失。时间线与生活经验相符，但还不足以解释全部现实规则。"]
  "public_demo": text=["安翼礼上，%s自愿站到居民面前，展示已经复核过的短暂腾空。" % s.NAMES[s.participant],"你随后说明名册中的沿海航线，并出示已经核实的其他依据。居民讨论大海，不是仅仅因为有人飞起来，而是因为旧记录终于能被公开核对。","参与者被更多人认出，公开压力也随之增加。已发生的展示不会被抹去。"]
  "protect_el","protect_lo": text=["你处理参与者与家属受到的追问，明确哪些信息与公开事件无关。压力减轻，但你没有要求读者忘记已经发生的事。"]
  "tower_locate": text=["你沿旧图辨认墙体和台阶，找到被藤蔓遮住的废弃入口。后续可以步行进入，不必依赖贵族许可。"]
  "tower_enter": text=["你从废弃入口沿台阶进入高塔。这里是观察世界的地点，不是要求参与者冒险跃下的试场。"]
  "tower_permit": text=["伊卡恩带你穿过高塔门道。他愿意承担带人进入的责任，但提醒你把看到的事实与猜测分开。"]
  "tower_observe": text=["从高处可以辨认远方一片宽广水面的方向与边界，你同现场见证者分别记录，再与旧航线核对。你仍未探索水面之外。", "塔内的禁令原件留着疯祭司的签署。它把羽之森的规定与王城中的制定者联系起来，却没有说明全部原因。"]
  "signature_application": text=["你登记需要查询的禁令编号与来源。申请只提供程序入口，不等于解除禁令。"]
  "query_signature": text=["查询记录确认疯祭司参与了禁令签署。你保存对应编号，准备在王城继续追问。"]
  "cross_region": text=["你用实际携带的独立实证核验本地航线，区分物证来源与同一文字的重复抄本。后续海洋说明更有依据。"]
  "sea_share": text=["小范围居民读到航线与现有的核验记录，并提出问题。你说明能确认的部分，他们对大海的相信开始增加。"]
  "sea_supplement": text=["你向已经听过说明的居民补充新证据，只记录尚未获得的认知增量。"]
 if id in ["public_demo","sea_share","sea_supplement"]: text.append("羽之森公众海洋认知现为%d。" % s.belief)
 text.append(stage(s).next)
 return Lines.lines(text)
static func day_start(s) -> Array:
 var text: Array=s.events.duplicate()
 text.append("羽之森第%d天，可用%d AP。" % [s.day,s.ap])
 if s.day==4: text.append("今天是首次尝试的最后机会。若想第五天公开展示，今天必须已经完成跨日复核。")
 if s.day==5: text.append("今天举行安翼礼。复核和公开展示各需2 AP，不能在今天同时完成；日末离林。")
 text.append(stage(s).next)
 return Lines.lines(text)
