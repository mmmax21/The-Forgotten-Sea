extends Control

const GameState = preload("res://scripts/game_state.gd")
var state := GameState.new()
var live_state = state
var preview_state := GameState.new()

@onready var game_screen: MarginContainer = %GameScreen
@onready var settlement_screen: CenterContainer = %SettlementScreen
@onready var day_label: Label = %DayLabel
@onready var time_label: Label = %TimeLabel
@onready var progress_label: Label = %ProgressLabel
@onready var progress_bar: ProgressBar = %TimeProgress
@onready var skip_button: Button = %SkipButton
@onready var next_button: Button = %NextButton
@onready var last_day_hint: Label = %LastDayHint
@onready var restart_button: Button = %RestartButton
@onready var skip_dialog: ConfirmationDialog = %SkipDialog
@onready var debug_panel: AcceptDialog = %DebugPanel
@onready var phase_label: Label = %PhaseLabel


func _ready() -> void:
	state = preview_state if game_screen.knowledge.preview_enabled else live_state
	game_screen.profile_changed.connect(_switch_profile)
	%PlanningController.night_started.connect(func(): state.begin_night())
	%PlanningController.next_day_requested.connect(_finish_planned_day)
	state.changed.connect(_refresh)
	skip_button.pressed.connect(_request_skip)
	next_button.pressed.connect(_advance)
	restart_button.pressed.connect(_restart)
	skip_dialog.confirmed.connect(_confirm_skip)
	# 取消、关闭、Esc 都由原生弹窗隐藏；任何隐藏路径都会恢复按钮。
	skip_dialog.visibility_changed.connect(_refresh_buttons)
	debug_panel.window_input.connect(_on_debug_input)
	_refresh()
	%NotesButton.grab_focus()


func _refresh() -> void:
	%PlanningController.sync_day(state.get_day())
	var finished: bool = state.is_finished()
	game_screen.visible = not finished
	settlement_screen.visible = finished
	day_label.text = "第 %d 天 / 共 %d 天" % [state.get_day(), GameState.TOTAL_DAYS]
	time_label.text = "当前时间：%s" % state.get_slot_name()
	# 仅映射旧时间节点的显示，不修改上午/下午/晚上的状态规则。
	phase_label.text = "阶段：夜间结算" if state.get_slot() == 2 else "阶段：白天规划"
	phase_label.tooltip_text = "整份计划在夜间统一交接，期间不能修改。"
	progress_label.text = "时间进度 %d / %d" % [state.get_progress(), GameState.TOTAL_SLOTS]
	progress_bar.value = state.get_progress()
	last_day_hint.visible = state.get_day() == GameState.TOTAL_DAYS
	_refresh_buttons()
	if finished:
		debug_panel.hide()
		restart_button.grab_focus()


func _refresh_buttons() -> void:
	var locked: bool = skip_dialog.visible or state.is_finished() or not %PlanningController.can_debug_advance()
	skip_button.disabled = locked or not state.can_skip_day()
	next_button.disabled = locked
	skip_button.tooltip_text = "已是最后一天" if state.get_day() == GameState.TOTAL_DAYS else "跳过当天剩余时间"
	if not locked and debug_panel.visible:
		next_button.grab_focus()


func _advance() -> void:
	if not debug_panel.visible or skip_dialog.visible or state.is_finished() or not %PlanningController.can_debug_advance():
		return
	state.advance()


func _request_skip() -> void:
	if not debug_panel.visible or skip_dialog.visible or not state.can_skip_day() or not %PlanningController.can_debug_advance():
		return
	skip_dialog.dialog_text = "确定跳过当天剩余时间，进入第 %d 天上午吗？" % (state.get_day() + 1)
	skip_dialog.popup_centered(Vector2i(820, 240))
	_refresh_buttons()
	skip_dialog.get_cancel_button().grab_focus()


func _confirm_skip() -> void:
	# dialog_hide_on_ok=false，保持确认时仍可检查弹窗是否打开。
	if not skip_dialog.visible:
		return
	skip_dialog.hide()
	state.skip_day()


func _restart() -> void:
	skip_dialog.hide()
	debug_panel.hide()
	%PlanningController.restart_plan()
	if game_screen.knowledge.preview_enabled:
		game_screen.knowledge.reset_preview()
	game_screen.refresh_known_targets()
	state.restart()
	%NotesButton.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_toggle_debug()
		get_viewport().set_input_as_handled()


func _on_debug_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_toggle_debug()


func _toggle_debug() -> void:
	if state.is_finished() or skip_dialog.visible or %InfoDialog.visible or %SubmitConfirm.visible or %NightDialog.visible:
		return
	if debug_panel.visible:
		debug_panel.hide()
	else:
		debug_panel.popup_centered(Vector2i(620, 300))
		_refresh_buttons()


func _switch_profile(preview: bool) -> void:
	state.changed.disconnect(_refresh)
	state = preview_state if preview else live_state
	state.changed.connect(_refresh)
	_refresh()


func _finish_planned_day() -> void:
	if %PlanningController.plan.is_resolved() and not state.is_finished():
		state.finish_day()
