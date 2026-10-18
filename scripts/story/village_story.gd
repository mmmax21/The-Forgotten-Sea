extends RefCounted
## Presentation only: no resource or reward mutations.
const TEXT := {
 "feed":["盐嫂先把粮食分出家人的一份，才让你坐下。","盐嫂|你想问旧事，等这锅饭煮上。"],
 "listen":["盐嫂|他留下过水位和远处水面的记录，后来因调查和传播禁忌故事被处死。","盐嫂|事情可以匿名讲。不要提他的名字，也不要提家里的人。运粮车第三天就走了。"],
 "family":["你把粮食和行李送上运粮车。家人将前往村外亲戚家。","盐嫂|他们有地方落脚，我才能想下一步。"],
 "heirloom":["盐嫂打开包布，递出丈夫的潮汐手记。旧页上有水位刻线，以及苦咸的水、望不到岸的蓝色水面的描述。","盐嫂|这是他写下的。哪一处是真的，你去核对。匿名使用可以，别点出我们的名字。"],
 "repair":["你扶稳松动的支架，重新固定旧物。哑伯用残臂示意，把旧图纸推向你。","你在他的目光示意下，将工作台上的图纸铺平。他点了点头。"],
 "identify":["哑伯以残臂示意旧图纸的位置。你把弯曲木件放在船身轮廓旁：接缝与填料的位置相合。","他点头确认，再望向门外。你答应不说出辨认者的名字。","这是一块船体构件。不过，河里也有船；它还不能独自排除所有其他解释。"],
 "tidy":["你按哑伯的示意，将危险旧物包好，放进工具箱。门外的脚步声渐远，他的肩膀松下来。"],
 "hear":["螺螺|贝壳是在河边捡到的。遗迹正门堵住了，可风还是从石墙后面出来。","螺螺|我把布包落在墙外了，你能帮我找回来吗？"],
 "retrieve":["你沿着外墙找回布包。螺螺蹲下，画出断墙与窄道的位置。","螺螺|你自己小心。我留在村里，不进去。"],
 "caution":["你们把普通见闻与涉及他人身份的内容分开。","螺螺|我记得你的调查，但不会把别人的名字挂在嘴边。"],
 "survey":["你绕过外墙，循着石缝里的风找到窄道。入口被旧梁和杂物掩住。"],
 "clear":["最后一根横木被拖开，遗迹内部露出一道旧水线。入口已打开，内部尚未搜查。"],
 "search":["碎石下压着一块弯曲木件。成列孔眼里嵌着深色填料，刻痕的用途尚不明确。","你把碎片收好。村里的老船匠也许能解释它。"],
 "waterline":["你比对河工旧水尺、带日期的涨落记录和无雨备注，又记下当日水线。","重复涨落难以只用降雨解释。它增强了海潮的解释，但还不是完整潮周期的观测。"],
 "record":["你描下原物的图样、文字与取得经过。记录便于携带，来源仍然只有一份。"],
 "scribe":["摊主照着原物抄绘，不讨论其中含义。你收好记录；复制材料并不等于已经传播。"],
 "show":["你私下展示材料，说明调查经过，然后收回。只有眼前的人得知了调查。"],
 "store":["你把选好的原物交给对方，确认藏放位置。纯保管物品可以取回；暂时不能从背包使用它们。"],
 "take":["你取回保管物品。之前的保管费用不退，人物的担忧也不会因交接自动消失。"],
 "neighbor":["盐嫂|我会把材料留给信得过的邻里。等你离村时，若情势还允许，这件事就能继续。","材料已交接，不能主动撤回。家人已经安置时，这次安排不再增加警戒。"],
 "apology":["玩家|我不该拿你的名字作保证。我不会继续引用，但已经说出去的收不回来。","对方听完了。恐惧有所缓和，公开的身份和失去的隐蔽协助并没有恢复。"]
}

static func lines(values: Array) -> Array:
	var result: Array = []
	for value in values:
		var parts := str(value).split("|",true,1)
		result.append({"speaker":parts[0] if parts.size()==2 else "", "text":parts[1] if parts.size()==2 else parts[0]})
	return result

static func opening() -> Array:
	return lines(["告示背面有人写过一个‘海’字，又被刮去了。盐嫂收起空粮袋，哑伯守着旧图纸，螺螺举着河边捡来的贝壳。","你获准停留六天。找到手记或船体构件，只是调查的起点。成功完成调查，需要验证线索，并决定如何让发现传下去。未完成也可以离村，但不算调查成功。","用手记与确认的船体构件相互印证，或用确认的船体构件核对水线，才能完成验证。随后公开说明，或让盐嫂在离村时继续向邻里传播。抄本不算新的来源，村民相信也不等于真相已经查明。","每天3 AP；地图移动、点击人物和阅读信息免费。你可以自由选择调查顺序，确认付费行动后才扣AP。"])

static func greeting(s, who: String) -> Array:
	var p: Dictionary = s.people[who]
	if p.reported: return lines(["对方避开你的目光。调查已经被报给巡查者，不再接受新的托付。"])
	if p.due > 0: return lines(["对方看向门外，担心调查会把危险带到自己身上。", "告密风险将在当地第%d天结束时复查。具体数值与可行行动可在右侧和行动预览中查看。" % p.due])
	if p.exposed: return lines(["名字已经被公开。即使关系可以缓和，这次调查中的隐蔽协助也无法恢复。"])
	if p.t >= 60 and p.a >= 60: return lines(["对方相信你，却不敢在当前情势下接受新托付。相信调查，不等于愿意承担危险。"])
	match who:
		"salt":
			if not s.spread.is_empty(): return lines(["盐嫂|材料我收好了。离村时情势若允许，我会继续传下去。"])
			if s.flags.has("heirloom"): return lines(["盐嫂|手记交给你了。记住，我们说好可以匿名讲。"])
			return lines(["盐嫂|家里粮食不够。那些旧事，我也怕再提起来会连累人。"])
		"elder": return lines(["哑伯守着旧图纸，以目光示意工作台上的旧物。他无法说话，你可以从他的动作和图纸判断意图。"])
		_: return lines(["螺螺|你看这枚贝壳。大家都说只是怪石头，可它明明有一圈一圈的纹。"])

static func action(s, id: String) -> Array:
	if id == "public_material":
		var values: Array = ["你遮住可识别身份的部分，把随身物证或记录展示给聚集的村民。","村民|会不会只是一件来历不明的旧物？"]
		values.append("两种独立来源相互支持：手记中的经历，和遗迹里的真实构件。" if s.public_event.sources.size()==2 else "你承认目前只有一种来源，只说明材料确实支持进一步调查。")
		values.append("村民|河里也有船，怎么能说明是海？")
		values.append("你用构件和水线记录解释异常涨落：这使海潮成为值得认真考虑的解释，但仍有问题没有解开。" if s.flags.has("waterline") and s.public_event.sources.has("F") else "你承认尚不能排除所有其他解释，不把缺少的观测说成已经完成。")
		return lines(values)
	if id == "public_anonymous": return lines(["玩家|有个人留下了这些水线和见闻。我不会说出他家住在哪里。","村民|我们听得明白，可还是想知道，这些经历究竟出自谁。","你遵守匿名约定，接受说服力的上限。盐嫂仍担心熟人会猜到。"])
	if id == "public_salt": return lines(["你指出手记作者的身份。人群里有人认出了盐嫂丈夫的经历。","村民|原来是他留下的。那时我们还以为，他只是说了些疯话。","盐嫂退到门边，没有替你接话。她的家庭身份已经暴露。"])
	if id == "public_elder": return lines(["你说出辨认者的名字，指向哑伯的工作处。人群开始认真讨论那块木件。","哑伯用身体挡住桌上的图纸。他没有授权你公开自己的身份。"])
	var result: Array = TEXT.get(id,["行动已经完成。可以继续调查，或结束当天。"]).duplicate()
	if id in ["heirloom","identify","waterline"]:
		result.append("线索已经完成交叉验证。接下来决定如何公开或向邻里传播。" if s.chapter_progress().verified else "这只是调查线索，还不能算完成调查。需要手记与船体构件相互印证，或用确认的船体构件核对水线。")
	return lines(result)

static func day_start(s) -> Array:
	var values: Array = ["第%d天。今日可用%d AP。" % [s.day,s.ap]]
	if s.day == 3: values.append("巡查者入村。已经知道调查的人更加担忧；运粮车将在今天结束时停止载客。")
	if s.day == 5: values.append("遗迹和河工旧记录已经封闭。已有碎片仍可辨认，今天是公开说明的最后机会。")
	if s.day == 6: values.append("今天结束时必须离村。把证据去向与未处理风险安排好；离村后无法远程补救。")
	if not s.public_event.is_empty() and not s.public_event.feedback_read and s.day > s.public_event.day:
		if s.public_event.version == "public_salt": values.append("巡查者拿着名字问了几户人家。盐嫂说：‘你让他们相信了。可他们现在也知道该敲谁的门了。’")
		elif s.public_event.version == "public_elder": values.append("巡查者到了哑伯门前，询问船体辨认的事。桌上的旧图纸已经收起。")
		elif s.public_event.version == "public_anonymous": values.append("邻里开始议论那位留下手记的人。盐嫂仍在意，熟人是否会猜到她的家庭。")
		else: values.append("村民再次谈起你展示的物证，也有人重复你尚未回答的疑问。")
		if s.belief >= 60: values.append("昨日水线之外，多了一圈湿亮的贝壳。村民认出了你提过的纹路。大海还没有出现，但河滩正在变化。")
		elif s.belief >= 30: values.append("有人拿出纸，认真记下了关于海的说法。它开始不只是一句传闻。")
	for who in s.people:
		if s.people[who].reported: values.append("%s已经告密。处罚只记一次，其他调查路线仍可继续。" % s.NAMES[who])
	return lines(values)
