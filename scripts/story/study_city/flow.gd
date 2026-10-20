extends RefCounted
## 学城章节主流程:开始新局、跨日结算、末日事件触发。

const State := preload("res://scripts/story/study_city/state.gd")
const Actions := preload("res://scripts/story/study_city/actions.gd")
const Story := preload("res://scripts/story/study_city/story.gd")


# ─── 进入 ──────────────────────────────────────────────

# 从无前史开始一局。返回 PackedStringArray 作开场白。
static func enter(state) -> Array:
	state.reset()
	# 锁定第一段开场对白
	state.presentation = {
		"lines": Story.opening(state),
		"index": 0,
		"kind": "opening",
	}
	return Story.opening(state)


# ─── 末日事件 ─────────────────────────────────────────

# 每天跨日时调用一次。返回追加的"发生了什么"。
static func on_end_day(state) -> Array:
	var lines: Array = []
	# 第 3 天末:发布"明天末馆藏清理"公告
	if state.day == 3:
		state.archive_warning_day = 4
		state.flags["archive_warning_set"] = true
		lines.append("公告:明日日末销毁未登记副本(含旧版本与执行记录)。")
	# 第 4 天末:执行清理
	if state.day == 4:
		_archive_destruction(state)
	# 第 5 天末:进入结算(viewer 跳出结算面板)
	if state.day == 5:
		_settle(state)
	return lines


static func _archive_destruction(state) -> void:
	state.archive_destroyed = true
	var lost: Array = []
	var kept: Array = []
	# 检查玩家是否救出了副本
	for key in ["versions", "execution"]:
		var saved_key: String = key + "_saved"
		if state.inventory.has(saved_key):
			kept.append(key)
		else:
			lost.append(key)
	state.flags["versions_lost"] = "versions" in lost
	state.flags["execution_lost"] = "execution" in lost
	state.flags["archive_settled"] = true


# 进入结算:基于已完成的标志决定结局档位
static func settle(state) -> Dictionary:
	state.finished = true
	var has_p3: bool = state.has_claim("P3")
	var kept: bool = (not state.flags.get("versions_lost", false)) or (not state.flags.get("execution_lost", false))
	var published: bool = state.has_flag("statement_published")
	var report: Dictionary = {
		"ending": "",
		"summary": "",
		"npc_notes": {},
	}
	if has_p3 and published:
		if kept:
			report.ending = "制度突破"
			report.summary = "你的 P3 主张已被公开留下副本。即使原件清理,副本仍有留存机会。"
		else:
			report.ending = "线索断裂"
			report.summary = "P3 已声明,但没有副本留存。学城官方可把这件事变成'未发生'。"
	elif has_p3:
		report.ending = "院内承认"
		report.summary = "P3 已成立,但你没公开。馆藏清理后原件消失,主张只能靠档案副本。"
	elif kept:
		report.ending = "碎片在手"
		report.summary = "你保存了副本,但未建立完整主张。归档这些材料等待下个机会。"
	else:
		report.ending = "学城白行"
		report.summary = "你离开学城时,既没有建立 P3 也没有保住副本。"
	# NPC 后日谈
	for npc in State.NPC_IDS:
		report.npc_notes[npc] = state.status(npc)
	return report


# ─── 跨日推进 ─────────────────────────────────────────

# 调用时机:玩家点"结束当天"。
# 行为:先触发末日事件 → 检查并应用每 NPC 的预警 → 推进 day / 初始化 ap → 设置下一日对白
static func advance_day(state) -> Dictionary:
	var before_busy: bool = state.busy()
	var result: Dictionary = {
		"day": state.day,
		"changes": [],
		"next_opening": [],
	}
	if before_busy:
		result.changes.append("请先结束当前对白再跨日")
		return result
	# 末日事件
	var end_lines: Array = on_end_day(state)
	for line in end_lines:
		result.changes.append(line)
	# 推进
	if state.day >= State.TOTAL_DAYS:
		state.finished = true
		return result
	state.day += 1
	state.ap = 3
	state.selected = ""
	# 新一天开场白
	state.presentation = {
		"lines": Story.day_start(state),
		"index": 0,
		"kind": "day",
	}
	result.next_opening = Story.day_start(state)
	result.day = state.day
	return result


# ─── 执行一个动作(包装 Actions.execute)──────────────

static func perform(state, id: String) -> bool:
	if state.busy():
		return false
	var ok: bool = Actions.execute(state, id)
	if ok and ACTIONS_HAS_DIALOGUE(id):
		# 取得动作的对白输出
		state.presentation = {
			"lines": Story.action(state, id),
			"index": 0,
			"kind": "action",
		}
	return ok


# 哪些动作应该弹出对白(其他纯数值类暂不展示)
static func ACTIONS_HAS_DIALOGUE(id: String) -> bool:
	return true
