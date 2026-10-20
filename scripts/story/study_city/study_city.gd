extends Control
## 学城章节最小 UI。不复用 trial1 任何 UI 组件,自己实现。
## 节点树:
##   Control (root, script)
##     ├ DialogueBox (Label, 显示对话流)
##     ├ StatusPanel (右侧,显示 NPC 状态与末日倒计时)
##     ├ ActionsPanel (VBox, 行动按钮列表)

const State := preload("res://scripts/story/study_city/state.gd")
const Actions := preload("res://scripts/story/study_city/actions.gd")
const Flow := preload("res://scripts/story/study_city/flow.gd")
const Story := preload("res://scripts/story/study_city/story.gd")
const Save := preload("res://scripts/story/study_city/save.gd")

const PAPER := Color("ece2cd")
const GOLD := Color("d5bb83")
const MUTED := Color("b5c4c0")
const ALERT := Color("efb786")
const OK := Color("b6cba0")

var state: State
var save_path := "user://study_city_v1.json"

var dialogue_label: Label
var status_label: Label
var actions_box: VBoxContainer
var nav_box: VBoxContainer
var history: Array = []
var current_dialogue_index: int = 0
var current_dialogue: Array = []


func _ready() -> void:
	state = State.new()
	# 试着读取已有存档
	var loaded := Save.load_from(save_path)
	if loaded.ok:
		state.restore(loaded.state.to_data())
	else:
		Flow.enter(state)
	_build_ui()
	_refresh()


# ─── 主题 ──────────────────────────────────────────────

func _build_ui() -> void:
	# 主根容器已经存在;我们直接 build 子节点
	var bg := ColorRect.new()
	bg.color = Color("0a141a")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var font := SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC", "Microsoft YaHei", "Noto Sans CJK SC"])

	# 标题
	var title := Label.new()
	title.text = "旧 学 城  ·  调查与抉择"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", GOLD)
	title.position = Vector2(40, 30)
	title.size = Vector2(960, 60)
	add_child(title)

	# 状态条
	status_label = Label.new()
	status_label.text = ""
	status_label.add_theme_font_override("font", font)
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", MUTED)
	status_label.position = Vector2(40, 95)
	status_label.size = Vector2(960, 30)
	add_child(status_label)

	# 对话框
	dialogue_label = Label.new()
	dialogue_label.text = ""
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.add_theme_font_override("font", font)
	dialogue_label.add_theme_font_size_override("font_size", 22)
	dialogue_label.add_theme_color_override("font_color", PAPER)
	dialogue_label.position = Vector2(40, 150)
	dialogue_label.size = Vector2(960, 460)
	dialogue_label.add_theme_constant_override("line_spacing", 8)
	add_child(dialogue_label)

	# 行动按钮区
	var actions_label := Label.new()
	actions_label.text = "动作列表"
	actions_label.add_theme_font_override("font", font)
	actions_label.add_theme_font_size_override("font_size", 22)
	actions_label.add_theme_color_override("font_color", GOLD)
	actions_label.position = Vector2(40, 640)
	actions_label.size = Vector2(960, 30)
	add_child(actions_label)

	actions_box = VBoxContainer.new()
	actions_box.position = Vector2(40, 680)
	actions_box.size = Vector2(960, 240)
	actions_box.add_theme_constant_override("separation", 6)
	add_child(actions_box)

	# 底部导航
	nav_box = VBoxContainer.new()
	nav_box.position = Vector2(40, 940)
	nav_box.size = Vector2(960, 100)
	nav_box.add_theme_constant_override("separation", 6)
	add_child(nav_box)


func _make_button(parent: Control, label: String, id: String, callback: Callable, disabled := false) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.disabled = disabled
	btn.custom_minimum_size.y = 36
	btn.clip_text = false
	btn.set_meta("action_id", id)
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn


# ─── 渲染状态 ──────────────────────────────────────────

func _refresh() -> void:
	# 状态条
	status_label.text = _status_text()
	# 对话
	if state.busy() and not state.presentation.is_empty():
		current_dialogue = state.presentation.lines
		current_dialogue_index = state.presentation.index
		dialogue_label.text = _format_dialogue()
	else:
		current_dialogue = []
		dialogue_label.text = "当前无对白。请选择下方动作。"
	# 动作按钮
	_clear(actions_box)
	_build_actions()
	# 导航按钮
	_clear(nav_box)
	_nav_buttons()


func _status_text() -> String:
	return "第 %d / %d 天 · %d AP · 末日警告:%s" % [
		state.day,
		State.TOTAL_DAYS,
		state.ap,
		"第 %d 天末" % state.archive_warning_day if state.archive_warning_day > 0 else "无",
	]


func _format_dialogue() -> String:
	# 仅渲染到当前播放进度的那一句
	var line: Dictionary = current_dialogue[current_dialogue_index]
	var speaker: String = line.get("speaker", "")
	var text: String = line.get("text", "")
	var prefix: String = "[%s] " % speaker if not speaker.is_empty() else ""
	return "%s%s\n\n(回车继续 · 进度: %d / %d)" % [
		prefix, text,
		current_dialogue_index + 1,
		current_dialogue.size(),
	]


# ─── 动作区 ──────────────────────────────────────────

func _build_actions() -> void:
	var groups: Dictionary = {
		"墨先生": [], "二笔": [], "高帽子": [],
		"档案": [], "验证": [], "发表": [], "抢救": [],
	}
	for id in Actions.ACTIONS:
		var action: Dictionary = Actions.ACTIONS[id]
		match action.get("group", ""):
			State.NPC_MO: groups["墨先生"].append(id)
			State.NPC_ER: groups["二笔"].append(id)
			State.NPC_GAO: groups["高帽子"].append(id)
			"archive": groups["档案"].append(id)
			"verify": groups["验证"].append(id)
			"publish": groups["发表"].append(id)
			"rescue": groups["抢救"].append(id)
	for group_name in groups.keys():
		var ids: Array = groups[group_name]
		if ids.is_empty(): continue
		var header := Label.new()
		header.text = "── " + group_name + " ──"
		header.add_theme_color_override("font_color", GOLD)
		actions_box.add_child(header)
		for id in ids:
			_add_action_button(id)


func _add_action_button(id: String) -> void:
	var reasons: Array = Actions.blocked(state, id)
	var action: Dictionary = Actions.ACTIONS[id]
	var disabled: bool = not reasons.is_empty()
	var label: String = action.title
	if not reasons.is_empty():
		label += "  [置灰: " + reasons[0] + "]"
	_make_button(actions_box, label, id, _on_action_pressed, disabled)


# ─── 导航按钮 ──────────────────────────────────────────

func _nav_buttons() -> void:
	_make_button(nav_box, "继续对白 ▶  (回车)", "advance_dialogue", _on_advance_dialogue, state.busy() == false or state.presentation.is_empty())
	if state.busy() and not state.presentation.is_empty():
		return
	_make_button(nav_box, "结束当天", "end_day", _on_end_day, state.finished)
	_make_button(nav_box, "保存进度", "save", _on_save)


# ─── 输入 ──────────────────────────────────────────

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not event.is_echo():
		if state.busy() and not state.presentation.is_empty():
			_advance_dialogue()
			get_viewport().set_input_as_handled()


# ─── 事件 ──────────────────────────────────────────

func _on_action_pressed(id: String = "") -> void:
	if id.is_empty(): return
	if not Actions.blocked(state, id).is_empty():
		return
	if Flow.perform(state, id):
		_refresh()


func _on_advance_dialogue() -> void:
	_advance_dialogue()


func _advance_dialogue() -> void:
	if not state.busy() or state.presentation.is_empty():
		return
	current_dialogue_index = state.presentation.index
	current_dialogue_index += 1
	if current_dialogue_index >= state.presentation.lines.size():
		# 对白结束
		state.presentation = {}
		current_dialogue = []
		current_dialogue_index = 0
		_refresh()
		return
	state.presentation.index = current_dialogue_index
	_refresh()


func _on_end_day() -> void:
	var result: Dictionary = Flow.advance_day(state)
	if result.has("changes") and not result.changes.is_empty():
		# 把跨日事件作为开场白第一行
		state.presentation = {
			"lines": result.changes + result.next_opening,
			"index": 0,
			"kind": "day",
		}
	else:
		state.presentation = {
			"lines": result.next_opening,
			"index": 0,
			"kind": "day",
		}
	if state.finished:
		_show_settle_dialogue()
	_refresh()


func _show_settle_dialogue() -> void:
	var report: Dictionary = Flow.settle(state)
	# 结算弹窗通过加入对白显示
	state.presentation = {
		"lines": [
			"学城章节结束 · %s" % report.ending,
			"%s" % report.summary,
		] + _npc_notes_list(report.npc_notes),
		"index": 0,
		"kind": "settle",
	}


func _npc_notes_list(notes: Dictionary) -> Array:
	var result: Array = []
	for npc in State.NPC_IDS:
		var line: String = "%s · %s" % [State.NAMES[npc], notes.get(npc, "")]
		result.append(line)
	return result


func _on_save() -> void:
	Save.save_to(save_path, state)


# ─── 工具 ──────────────────────────────────────────

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
