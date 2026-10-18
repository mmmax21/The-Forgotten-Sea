extends RefCounted
## 学城章节对白生成器。所有输出都是 [{speaker, text}, ...] 形式,可被 UI 渲染。
## 不修改 state,只读入。这一层纯粹做"展示"。

const State := preload("res://scripts/story/study_city/state.gd")
const Actions := preload("res://scripts/story/study_city/actions.gd")


# ─── 通用工具 ──────────────────────────────────────────

static func _lines(values) -> Array:
	var result: Array = []
	for value in values:
		var s: String = str(value)
		var parts: PackedStringArray = s.split("|", true, 1)
		var entry: Dictionary = {}
		if parts.size() >= 2:
			entry["speaker"] = parts[0]
			entry["text"] = parts[1]
		else:
			entry["speaker"] = ""
			entry["text"] = s
		result.append(entry)
	return result


# ─── 开场 ─────────────────────────────────────────────

static func opening(state) -> Array:
	var s: Array = [
		"告示板|:|欢迎来到旧学城。学术禁令已经生效数年,但馆藏副本仍然有缺口。",
		"你拿到了一个前任村民的副本,以及一枚未确认的古物铜牌。需要查证,再决定是否相信。",
		"墨先生|:|你是新来的调查者?档案馆目录我可以指给你,但最好不要跨线。",
		"二笔|:|我能帮你指出几份副本的位置,但我也只是个抄写员,担不起更多。",
		"高帽子|:|常典出处我可以告诉你。越线的事,我不会配合。",
		"学城五天,每天 3 AP。前三天建立调查;第四天可亲自抢救副本,日末销毁清理;第五天结算。",
	]
	# 根据状态微调
	if state.owned("demo_reliquary"):
		s.append("你持有的副本来自渔村前任村民之手,有过外部印记。")
	return _lines(s)


# ─── 每日开场 ─────────────────────────────────────────

static func day_start(state) -> Array:
	var s: Array = ["第%d天开始 · %d AP。" % [state.day, state.ap]]
	if state.day == 2 and not state.has_flag("mo_relationship"):
		s.append("墨先生看完告示,沉默地把目录抽屉钥匙放在你桌上。")
	if state.day == 3 and not state.has_flag("er_relationship"):
		s.append("二笔路过档案馆门口,低声叹气:'馆藏编号清楚,可惜没人敢抄。'")
	if state.day == 4:
		s.append("公告:今天日末销毁未登记副本!所有不在你身上的副本、原件会消失。")
	if state.day == 5:
		s.append("今天结束后结算。建议你最后核对自己的副本、声明、警告。")
	# 末日提前公告(第 3 天)
	if state.day == 3 and state.archive_warning_day == 0:
		s.append("高帽子贴出新公告:'明日清理未登记副本。'")
	# 第 4 天初 - 提醒一次
	if state.day == 4 and state.archive_warning_day == 0:
		s.append("馆藏清理已设,日末执行。")
	# 主线提醒
	if state.day >= 4 and not state.has_flag("verified_contradiction"):
		s.append("你还没核对版本矛盾——这一天时间已经不算富余。")
	return _lines(s)


# ─── NPC 会见前问候 ───────────────────────────────────

static func greeting(state, who: String) -> Array:
	var p: Dictionary = state.people[who]
	if p.reported:
		return _lines(["%s|:|%s已不在学城,或不愿意见你。" % [State.NAMES[who], State.NAMES[who]]])
	if p.exposed:
		return _lines(["%s|:|身份已被记下,我不能再公开协助。" % State.NAMES[who]])
	if p.warning_day > 0:
		return _lines(["%s|:|今天我有些紧张,请先核对告密预警。" % State.NAMES[who]])
	if not p.informed:
		return _lines(["%s|:|你是新来的调查者?先让我看看你的来历。" % State.NAMES[who]])
	return _lines(["%s|:|%s · %s" % [State.NAMES[who], _t_a_label(p), state.status(who)]])


# ─── 动作执行后对白 ───────────────────────────────────

static func action(state, id: String) -> Array:
	match id:
		"mo_help": return _mo_help_response(state)
		"er_help": return _er_help_response(state)
		"gao_help": return _gao_help_response(state)
		"get_versions": return _get_versions_response(state)
		"get_execution": return _get_execution_response(state)
		"get_command": return _get_command_response(state)
		"er_know_versions": return _lines(["二笔|:|你知道这件事我会记下。", "她把档案柜号写在纸条边角递过来。"])
		"er_know_execution": return _lines(["二笔|:|这次更危险。我会告诉你位置,但不要让别人看到我给的东西。"])
		"mo_warn_command": return _lines(["墨先生|:|这件事风险很大。官印副本在主簿案卷抽屉里,只有看管员能调阅。", "你若决定调阅,要有心理准备。"])
		"verify_contradiction": return _verify_response(state)
		"trace_command_chain": return _p3_response(state)
		"save_versions_self": return _save_versions_response(state)
		"save_execution_self": return _save_execution_response(state)
		"publish_statement": return _publish_response(state)
		_: return _lines(["行动结束。", "学城继续等你下一个动作。"])


# ─── 各动作的具体对白 ────────────────────────────────

static func _mo_help_response(state) -> Array:
	if state.has_flag("mo_relationship"):
		return _lines(["墨先生|:|我们之前已经谈过。继续你的调查。"])
	return _lines([
		"墨先生|:|目录在右手第二个柜子,编号 §§3-§§14 是公开索引。",
		"他抬起头看了你一眼:'但请你先弄清楚你手里的东西是不是真的来自被改之前的版本。'",
		"高帽子从馆藏间经过,目光扫过墨先生:'目录是公开的,调阅记录照规矩来。'",
	])


static func _er_help_response(state) -> Array:
	if state.has_flag("er_relationship"):
		return _lines(["二笔|:|我们之前已经核对过。"])
	return _lines([
		"二笔|:|我熟悉这几份常抄的卷子,但我也是一个抄写员。",
		"'请不要把我带进两份证据之间的矛盾里。'",
	])


static func _gao_help_response(state) -> Array:
	if state.has_flag("gao_relationship"):
		return _lines(["高帽子|:|常典出处我说过。继续照规矩来。"])
	return _lines([
		"高帽子|:|常典出处按公开目录调阅,规矩由档案馆定,不在学者手中。",
		"'希望你能理解——统一版本不是我的发明,是社会的需要。'",
	])


static func _get_versions_response(state) -> Array:
	if state.inventory.has("versions"):
		return _lines(["旧版本副本你之前已经拿到。"])
	var s: Array = ["你从档案柜里取出旧版本副本。墨先生远远地看了你一眼。"]
	if state.people.gao.informed:
		s.append("高帽子在门口停下:'登记了吗?'")
		s.append("你说已经登记。他没说什么就走了。")
	s.append("副本带着陈旧感,边角已经被书虫啃过。")
	return _lines(s)


static func _get_execution_response(state) -> Array:
	if state.inventory.has("execution"):
		return _lines(["执行记录你之前已经拿到。"])
	var s: Array = ["你按编号取出执行记录。"]
	s.append("记录详细到:哪些版本被替换,销毁数量是多少,日期是哪一天。")
	if state.people.mo.informed:
		s.append("墨先生叹了口气:'现在你也看到了。'")
	return _lines(s)


static func _get_command_response(state) -> Array:
	if state.inventory.has("command"):
		return _lines(["命令副本你之前已经拿到。"])
	var s: Array = ["主簿案卷抽屉被允许调阅——但要登记。"]
	s.append("命令带有官印:'据审查司令,对该批次进行限级修缮,旧版不得流通。'")
	s.append("签发日期约是一年半前。")
	if state.archive_warning_day > 0:
		s.append("高帽子从外走过:'你今天调阅多。要不要想想末日?。'")
	return _lines(s)


static func _verify_response(state) -> Array:
	return _lines([
		"你在一张桌子上摊开旧版本与执行记录。",
		"段落标题一致,但旧版本完整,新版里那一段缺了。",
		"执行记录详细到:替换数量、销毁数量、原件下落。",
		"墨先生走过来,沉默注视:",
		"墨先生|:|这就是'制度删改'。不是偶然遗漏,是有人下过令。",
		"二笔远远看着,低下头。",
	])


static func _p3_response(state) -> Array:
	var s: Array = [
		"你顺着命令副本的签发追溯——",
		"官印指向一个从未公开过的机构:'王城审查司'。",
		"高帽子正好经过。他说:",
		"高帽子|:|有些命令的存在本身就是不该让人看见的。",
	]
	if state.archive_warning_day > 0:
		s.append("你手里已经有了这套指控链。但末日清理会销毁馆藏副本,你手上只有保全的版本。")
	else:
		s.append("你手里已经有了这套指控链——但原件清理会来。")
	return _lines(s)


static func _save_versions_response(state) -> Array:
	var s: Array = [
		"你偷偷抄出了旧版本副本。",
		"二笔在你身后走过——她没有停,但她看见了。",
	]
	if state.people.gao.alert >= 50:
		s.append("你担心高帽子也注意到了——但愿没有。")
	return _lines(s)


static func _save_execution_response(state) -> Array:
	var s: Array = [
		"你对照编号誊写了一份执行记录。",
		"明天日末原件会被清理;你手上有副本。",
	]
	if not state.has_flag("rescued_some"):
		s.append("这是一份成功保住的副本——并非所有的副本都会留存。")
	return _lines(s)


static func _publish_response(state) -> Array:
	var s: Array = [
		"你在学城公开张贴 P3 主张声明。",
		"声明里引用核对过的版本差异、执行记录、命令签名。",
	]
	if state.has_flag("rescued_some"):
		s.append("声明还引用了你今日保全的副本——原件没了,副本还在。")
	else:
		s.append("原件馆藏明天会被清理,这份张贴的副本是你手头仅存的证据。")
	s.append("高帽子经过时没有停下——他或许没注意,或许他在等机会。")
	return _lines(s)


# ─── 私有工具 ─────────────────────────────────────────

static func _t_a_label(p: Dictionary) -> String:
	return "T%d / A%d" % [p.t, p.a]
