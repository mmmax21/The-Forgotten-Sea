extends Control

const GameState = preload("res://scripts/game_state.gd")
var state := GameState.new()

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


func _ready() -> void:
	state.changed.connect(_refresh)
	skip_button.pressed.connect(_request_skip)
	next_button.pressed.connect(_advance)
	restart_button.pressed.connect(_restart)
	skip_dialog.confirmed.connect(_confirm_skip)
	# 取消、关闭、Esc 都由原生弹窗隐藏；任何隐藏路径都会恢复按钮。
	skip_dialog.visibility_changed.connect(_refresh_buttons)
	_refresh()
	next_button.grab_focus()


func _refresh() -> void:
	var finished: bool = state.is_finished()
	game_screen.visible = not finished
	settlement_screen.visible = finished
	day_label.text = "第 %d 天 / 共 %d 天" % [state.get_day(), GameState.TOTAL_DAYS]
	time_label.text = "当前时间：%s" % state.get_slot_name()
	progress_label.text = "时间进度 %d / %d" % [state.get_progress(), GameState.TOTAL_SLOTS]
	progress_bar.value = state.get_progress()
	last_day_hint.visible = state.get_day() == GameState.TOTAL_DAYS
	_refresh_buttons()
	if finished:
		restart_button.grab_focus()


func _refresh_buttons() -> void:
	var locked: bool = skip_dialog.visible or state.is_finished()
	skip_button.disabled = locked or not state.can_skip_day()
	next_button.disabled = locked
	skip_button.tooltip_text = "已是最后一天" if state.get_day() == GameState.TOTAL_DAYS else "跳过当天剩余时间"
	if not locked:
		next_button.grab_focus()


func _advance() -> void:
	if skip_dialog.visible or state.is_finished():
		return
	state.advance()


func _request_skip() -> void:
	if skip_dialog.visible or not state.can_skip_day():
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
	state.restart()
