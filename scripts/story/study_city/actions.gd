extends RefCounted
## 旧学城动作定义与执行规则。
## 配合 StudyCityState 使用,所有动作的 AP / 前置 / 副作用都在这里。

const State := preload("res://scripts/story/study_city/state.gd")

## 三 NPC
const NPC_MO := "mo"
const NPC_ER := "er"
const NPC_GAO := "gao"

# ─── 动作字典 ─────────────────────────────────────────
## 字段:
##   title: 显示名
##   group: 哪个 tab 显示
##   ap: AP 消耗
##   kind: "npc"/"archive"/"verify"/"publish"/"rescue"
##   need_claim: 前置主张
##   need_location: 前置位置
##   need_item: 需要拥有某物
##   need_flag: 需要某标志为 true
##   set_flag: 设置标志
##   gives_doc: 取得的底稿 key
##   trust / alert: 数值变化(包含在对象里)
##   informs: 是否让某 NPC 知情
##   asks_support: 是否检查 cooperative()
##   needs_informed: 需要该 NPC 已经知情

const ACTIONS := {
	# ─── 调查(MO / ER / GAO 各自的"普通帮助")──
	"mo_help": {
		"title": "请墨先生整理目录",
		"group": NPC_MO, "kind": "npc", "npc": NPC_MO,
		"ap": 1, "trust": 15, "alert": 0,
		"asks_support": true,
		"set_flag": "mo_relationship",
		"text": "墨先生愿意跟你坐下来梳理馆藏目录,但不会公开任何事。",
	},
	"er_help": {
		"title": "请二笔核对抄本",
		"group": NPC_ER, "kind": "npc", "npc": NPC_ER,
		"ap": 1, "trust": 15, "alert": 0,
		"asks_support": true,
		"set_flag": "er_relationship",
		"text": "二笔能凭位置快速取出她熟悉的抄本。",
	},
	"gao_help": {
		"title": "请高帽子指明常典出处",
		"group": NPC_GAO, "kind": "npc", "npc": NPC_GAO,
		"ap": 1, "trust": 15, "alert": 0,
		"asks_support": true,
		"set_flag": "gao_relationship",
		"text": "高帽子会用官方目录回答你的问题,不会越线。",
	},

	# ─── 调查(具体取档)──
	"get_versions": {
		"title": "按目录取旧版本",
		"group": "archive", "kind": "archive",
		"ap": 1,
		"need_location": "versions",
		"first": 1, "last": 4,    # 第 4 天末清理,只能 1-4 天取
		"gives_doc": "versions",
		"text": "旧版本馆藏副本带着受潮的气味,但仍可读。",
	},
	"get_execution": {
		"title": "按编号取执行记录",
		"group": "archive", "kind": "archive",
		"ap": 1,
		"need_location": "execution",
		"first": 1, "last": 4,
		"gives_doc": "execution",
		"text": "执行记录标注了替换版本和销毁数量。",
	},
	"get_command": {
		"title": "申请调阅命令副本",
		"group": "archive", "kind": "archive",
		"ap": 2,
		"need_location": "command",
		"first": 1, "last": 4,
		"gives_doc": "command",
		"text": "命令由上级机构下达,官印仍在。",
	},

	# ─── 调查(请人协助)──
	"er_know_versions": {
		"title": "请二笔指出旧版本位置",
		"group": NPC_ER, "kind": "npc", "npc": NPC_ER,
		"ap": 1, "trust": 5, "alert": 0,
		"asks_support": true,
		"informs": true,
		"set_flag": "er_knows_versions",
		"text": "二笔点头,低声告诉你档案柜子号。",
	},
	"er_know_execution": {
		"title": "请二笔指出执行记录位置",
		"group": NPC_ER, "kind": "npc", "npc": NPC_ER,
		"ap": 1, "trust": 5, "alert": 0,
		"need_flag": "er_knows_versions",
		"asks_support": true,
		"informs": true,
		"set_flag": "er_knows_execution",
		"text": "二笔指向封存间低声说:'在左边第三层。'",
	},
	"mo_warn_command": {
		"title": "请墨先生提醒命令副本位置",
		"group": NPC_MO, "kind": "npc", "npc": NPC_MO,
		"ap": 1, "trust": 5, "alert": 5,
		"asks_support": true,
		"set_flag": "mo_knows_command",
		"text": "墨先生犹豫片刻,告诉你主簿案卷抽屉位置,提醒你这件事有风险。",
	},

	# ─── 验证(形成主张)──
	"verify_contradiction": {
		"title": "核对版本矛盾 → 认定删改",
		"group": "verify", "kind": "verify",
		"ap": 2,
		"need_item_required": ["versions", "execution"],  # 两者都要
		"set_flag": "verified_contradiction",
		"text": "同批修订单上,旧版完整 / 新版缺段;执行记录记明了替换量。删改已不止是可能,而是有据可查。",
	},
	"trace_command_chain": {
		"title": "追查命令链至上级机构",
		"group": "verify", "kind": "verify",
		"ap": 2,
		"need_flag": "verified_contradiction",
		"need_item_required": ["command"],
		"set_flag": "command_chain_traced",
		"set_claim": "P3",
		"text": "你沿着命令副本的官印追溯到'王城审查司'—— 这是一个从未公开过的机构。",
	},

	# ─── 抢救(末日窗口)──
	"save_versions_self": {
		"title": "自行保全旧版本",
		"group": "rescue", "kind": "rescue",
		"ap": 2, "first": 4, "last": 4,
		"need_location": "versions",
		"gives_doc": "versions_saved",
		"text": "你偷偷把它抄出馆藏。明天旧馆藏副本被清理时,你的副本还能作证。",
	},
	"save_execution_self": {
		"title": "自行保全执行记录",
		"group": "rescue", "kind": "rescue",
		"ap": 2, "first": 4, "last": 4,
		"need_location": "execution",
		"gives_doc": "execution_saved",
		"text": "你对照编号誊写了一份。馆藏清理时原件会消失。",
	},

	# ─── 发表(声明主张,留档)──
	"publish_statement": {
		"title": "学城分散发表主张声明",
		"group": "publish", "kind": "publish",
		"ap": 2,
		"need_claim": "P3",
		"set_flag": "statement_published",
		"text": "你在学城公开张贴 P3 主张声明,引用核对过的版本差异和执行记录。",
	},
}


# ─── 阻拦判定 ─────────────────────────────────────────

static func blocked(state, id: String) -> Array:
	# 返回不能执行的原因数组(空数组 = 可执行)
	var reasons: Array = []
	if not ACTIONS.has(id):
		return ["未知动作"]
	var action: Dictionary = ACTIONS[id]
	# 末日检查
	if state.finished:
		reasons.append("学城章节已结束")
	if not state.presentation.is_empty():
		reasons.append("请先读完当前对白")
	if state.ap < int(action.ap):
		reasons.append("AP 不足(需%d)" % action.ap)
	# 日期窗口
	if action.has("first") and state.day < int(action.first):
		reasons.append("仅第 %d 天之后开放" % int(action.first))
	if action.has("last") and state.day > int(action.last):
		reasons.append("已超过第 %d 天,不能再做" % int(action.last))
	# NPC support 检查
	if action.get("asks_support", false) and action.has("npc"):
		var npc: String = action.npc
		if not state.cooperative(npc):
			reasons.append("需要%s T≥60、A<60 且未告密" % State.NAMES[npc])
	if action.get("needs_informed", false) and action.has("npc"):
		var p: Dictionary = state.people[action.npc]
		if not p.informed:
			reasons.append("对方尚未知情")
	# 前置主张
	if action.has("need_claim"):
		if not state.has_claim(action.need_claim):
			reasons.append("需先建立 %s 主张" % action.need_claim)
	# 前置标志
	if action.has("need_flag"):
		if not state.has_flag(action.need_flag):
			var label: String = action.need_flag
			reasons.append("需先完成「%s」" % label)
	# 前置位置
	if action.has("need_location"):
		if not state.locations.get(action.need_location, false):
			reasons.append("需要先定位: %s" % action.need_location)
	# 必须携带某物(多件)
	if action.has("need_item_required"):
		for key in action.need_item_required:
			if not state.owned(key):
				reasons.append("需要已确认 %s" % key)
			# 取得即可,不必"已确认"
	return reasons


# ─── 执行 ──────────────────────────────────────────

static func execute(state, id: String) -> bool:
	var reasons: Array = blocked(state, id)
	if not reasons.is_empty():
		return false
	var action: Dictionary = ACTIONS[id]
	# 扣 AP
	state.ap -= int(action.ap)
	state.spent += int(action.ap)
	# NPC 数值变化
	if action.has("npc"):
		var npc: String = action.npc
		var p: Dictionary = state.people[npc]
		p.t = clampi(int(p.t) + int(action.get("trust", 0)), 0, 100)
		p.a = clampi(int(p.a) + int(action.get("alert", 0)), 0, 100)
		if bool(action.get("informs", false)):
			p.informed = true
	# 标志
	if action.has("set_flag"):
		state.flags[action.set_flag] = true
	# 主张
	if action.has("set_claim"):
		state.claims[action.set_claim] = true
	# 取得底稿
	if action.has("gives_doc"):
		var doc: String = action.gives_doc
		state.inventory[doc] = {
			"name": _doc_title(doc),
			"kind": "original" if doc in ["versions", "execution", "command"] else "museum",
			"source": doc,
			"confirmed": true,
			"holder": "player",
		}
	# 末日成就
	if id == "save_versions_self" or id == "save_execution_self":
		# 末日成就:玩家救下的副本也算"已确认"
		state.flags["rescued_some"] = true
	return true


static func _doc_title(doc: String) -> String:
	return {
		"versions": "修订单 A 旧版本馆藏副本",
		"execution": "修订单 A 执行记录",
		"command": "修订单 A 命令副本",
		"versions_saved": "修订单 A 旧版本(玩家保全)",
		"execution_saved": "修订单 A 执行记录(玩家保全)",
	}.get(doc, doc)


# ─── UI 辅助 ──────────────────────────────────────────

# 暴露需要的物品名集合(给 UI 弹窗显示)
static func need_item_label(item_key: String) -> String:
	if item_key == "versions": return "旧版本副本"
	if item_key == "execution": return "执行记录"
	if item_key == "command": return "命令副本"
	return item_key


# action 是否已经做过(防重复获取收益)
static func is_done(state, id: String) -> bool:
	var action: Dictionary = ACTIONS.get(id, {})
	if not action.has("set_flag"): return false
	var flag: String = action.set_flag
	return state.has_flag(flag)
