extends SceneTree
## 无插件依赖的状态及真实场景集成测试；失败返回非零退出码。

const State = preload("res://scripts/game_state.gd")
const MainScene = preload("res://scenes/main.tscn")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)


func _run() -> void:
	root.size = Vector2i(1280, 720) if "--small" in OS.get_cmdline_user_args() else Vector2i(1920, 1080)
	print("TEST WINDOW: ", root.size)
	_test_state()
	await _test_navigation()
	await _test_scene()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _test_state() -> void:
	var state := State.new()
	for position in range(30):
		check(state.get_progress() == position + 1, "正常推进：进度")
		check(state.get_day() == floori(float(position) / 3) + 1, "正常推进：天数与跨天")
		check(state.get_slot() == position % 3, "正常推进：节点")
		check(not state.is_finished(), "进入第 10 天晚上不提前结算")
		state.advance()
	check(state.is_finished(), "第 10 天晚上再次推进结算")
	state.advance()
	state.skip_day()
	check(state.get_day() == 10 and state.get_progress() == 30, "结算后不出现第 11 天")
	state.restart()
	check(state.get_progress() == 1 and not state.is_finished(), "重置状态")
	# 从每一天的每一个时间节点验证跳天，包括第 10 天拒绝跳天。
	for position in range(30):
		state.restart()
		for step in range(position):
			state.advance()
		var day: int = state.get_day()
		state.skip_day()
		if day < 10:
			check(state.get_day() == day + 1 and state.get_slot() == 0, "任意节点跳至次日上午")
		else:
			check(state.get_progress() == position + 1, "第 10 天拒绝跳天")
	print("PASS: 状态正常推进、跨天、所有节点跳天、结算边界、重置")


func _test_scene() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	await capture("01-main")
	check(main.day_label.text == "第 1 天 / 共 10 天", "初始天数")
	check(main.time_label.text == "当前时间：上午", "初始时间")
	check(main.progress_label.text == "时间进度 1 / 30", "初始进度文字")
	check(main.progress_bar.value == 1, "初始进度条")
	main._toggle_debug()
	await process_frame
	check(main.debug_panel.visible, "DEBUG 可打开")
	main.next_button.pressed.emit()
	check(main.time_label.text == "当前时间：下午", "按钮推进至下午")
	check(main.phase_label.text == "阶段：白天规划", "下午映射白天规划")
	main.skip_button.pressed.emit()
	await process_frame
	check(main.skip_dialog.visible and main.skip_dialog.exclusive, "模态确认弹窗")
	check(main.skip_dialog.title == "跳过当天", "弹窗标题")
	check(main.skip_dialog.dialog_text == "确定跳过当天剩余时间，进入第 2 天上午吗？", "弹窗动态正文")
	await capture("02-confirmation")
	check(main.next_button.disabled and main.skip_button.disabled, "弹窗禁用主按钮")
	main.next_button.pressed.emit()
	main.skip_button.pressed.emit()
	check(main.state.get_progress() == 2, "弹窗期间处理函数也阻止操作")
	main.skip_dialog.get_cancel_button().pressed.emit()
	await process_frame
	check(not main.skip_dialog.visible and main.state.get_progress() == 2, "取消保持当前节点")
	check(not main.next_button.disabled and not main.skip_button.disabled, "取消恢复按钮")
	main.skip_button.pressed.emit()
	await process_frame
	# 原生窗口关闭通知，验证标题栏关闭路径。
	main.skip_dialog.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await process_frame
	check(not main.skip_dialog.visible and main.state.get_progress() == 2, "关闭弹窗保持状态")
	main.skip_button.pressed.emit()
	await process_frame
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	# 从宿主视口派发，经过嵌入窗口的原生输入路径。
	root.push_input(escape, true)
	await process_frame
	check(not main.skip_dialog.visible and main.state.get_progress() == 2, "Esc 取消保持状态")
	check(not main.next_button.disabled, "Esc 后解除锁定")
	main.skip_button.pressed.emit()
	await process_frame
	main.skip_dialog.get_ok_button().pressed.emit()
	await process_frame
	check(not main.skip_dialog.visible, "确认后关闭弹窗")
	check(main.state.get_day() == 2 and main.state.get_slot() == 0, "确认跳至第 2 天上午")
	check(main.progress_label.text == "时间进度 4 / 30" and main.progress_bar.value == 4, "跳天同步进度")
	main.next_button.pressed.emit()
	main.next_button.pressed.emit()
	main.next_button.pressed.emit()
	check(main.day_label.text == "第 3 天 / 共 10 天" and main.state.get_slot() == 0, "晚上跨日至上午")
	# 用弹窗连续跳至第 10 天，验证下一天文案及禁用状态。
	while main.state.get_day() < 10:
		main.skip_button.pressed.emit()
		check(main.skip_dialog.dialog_text.contains("第 %d 天上午" % (main.state.get_day() + 1)), "下一天文案随状态变化")
		main.skip_dialog.get_ok_button().pressed.emit()
	check(main.skip_button.disabled, "第 10 天禁用后一天")
	check(main.last_day_hint.visible and main.last_day_hint.text == "已是最后一天", "最后一天可见提示")
	check(main.skip_button.tooltip_text == "已是最后一天", "最后一天悬停提示")
	main.skip_button.pressed.emit()
	check(not main.skip_dialog.visible and main.state.get_day() == 10, "第 10 天无法打开跳天弹窗")
	main.next_button.pressed.emit()
	main.next_button.pressed.emit()
	check(main.progress_label.text == "时间进度 30 / 30" and main.progress_bar.value == 30, "第 10 天晚上进度 30/30")
	check(main.phase_label.text == "阶段：夜间结算", "晚上映射夜间结算")
	check(main.game_screen.visible and not main.settlement_screen.visible, "最后晚上仍显示主界面")
	check(not main.next_button.disabled, "最后晚上仍可推进")
	await capture("03-last-evening")
	main.next_button.pressed.emit()
	check(main.settlement_screen.visible and not main.game_screen.visible, "最后晚上再次推进才显示结算")
	check(main.state.get_day() == 10, "界面不产生第 11 天")
	await capture("04-settlement")
	main.restart_button.pressed.emit()
	check(main.game_screen.visible and not main.settlement_screen.visible, "重新开始返回游戏界面")
	check(main.day_label.text == "第 1 天 / 共 10 天" and main.time_label.text == "当前时间：上午", "重新开始还原天数和时间")
	check(main.progress_bar.value == 1 and main.progress_label.text == "时间进度 1 / 30", "重新开始还原进度")
	check(not main.skip_button.disabled and not main.next_button.disabled and not main.last_day_hint.visible, "重新开始还原按钮和提示")
	main.queue_free()
	await process_frame
	print("PASS: 场景按钮、原生取消/关闭/Esc、模态锁定、显示同步及重新开始")


func capture(file_name: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://previews")
	var suffix := "1280" if "--small" in OS.get_cmdline_user_args() else "1920"
	var error := root.get_texture().get_image().save_png("res://previews/stage1-%s-%s.png" % [file_name, suffix])
	check(error == OK, "保存实际渲染预览")


func _click_control(control: Control) -> void:
	_click_at(control.get_global_rect().get_center())


func _click_at(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)


func _test_navigation() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	for frame in range(4):
		await process_frame
	check(not main.debug_panel.visible, "正式界面默认隐藏 DEBUG")
	check(not main.progress_label.is_visible_in_tree(), "正式界面隐藏 30 节点进度")
	var ui = main.game_screen
	var before: int = main.state.get_progress()
	var people: VBoxContainer = main.get_node("%PeopleList")
	_click_control(people.get_child(0))
	await process_frame
	check(ui.selected_id == "fisher", "鼠标点击人物选择目标")
	check(main.get_node("%TargetTitle").text == "潮叔", "人物详情同步")
	check(main.get_node("%RelationshipStatus").visible, "独立展示信任、思想信念和合作意愿")
	await capture("person")
	var footer_rect: Rect2 = main.get_node("%BottomPanel").get_global_rect()
	main.get_node("%DetailsScroll").scroll_vertical = 1000
	await process_frame
	check(main.get_node("%BottomPanel").get_global_rect() == footer_rect, "滚动人物详情不移动底部操作区")
	main.get_node("%DetailsScroll").scroll_vertical = 0
	_click_control(main.get_node("%PlaceNodes").get_child(1))
	await process_frame
	check(ui.selected_id == "channel", "鼠标点击地点选择目标")
	check(not main.get_node("%RelationshipStatus").visible, "地点不显示人物关系")
	_click_control(main.get_node("%MarkerNodes").get_child(0))
	await process_frame
	check(ui.selected_id == "trace", "鼠标点击线索标记")
	_click_at(main.get_node("%ScenePlaceholder").get_global_rect().position + Vector2(8, 8))
	await process_frame
	check(ui.selected_id == "trace" and main.state.get_progress() == before, "空白区域不改变目标或时间")
	for name in ["TalkAction", "InvestigateAction", "ConcealAction", "MoveAction", "PersonalScale", "GroupScale", "QueueAction", "EndDayButton"]:
		var control: Button = main.get_node("%" + name)
		check(control.disabled, "未接入功能明确禁用：" + name)
	check(main.get_node("%APLabel").text == "剩余 AP  — / 3", "未伪造 AP 状态")
	_click_control(main.get_node("%EndDayButton"))
	check(main.state.get_progress() == before, "禁用结束行动不推进时间")
	for name in ["NotesButton", "MenuButton", "Law1", "Law2", "Law3"]:
		_click_control(main.get_node("%" + name))
		await process_frame
		var dialog: AcceptDialog = main.get_node("%InfoDialog")
		check(dialog.visible and not dialog.dialog_text.is_empty(), "基础导航有反馈：" + name)
		if name.begins_with("Law"):
			check(dialog.dialog_text == main.get_node("%" + name).tooltip_text, "点击显示完整法则")
		dialog.get_ok_button().pressed.emit()
		await process_frame
	check(main.state.get_progress() == before, "全部基础导航不改变日期")
	# 实际尺寸与布局边界，覆盖主要区域与底部按钮。
	var bounds := Rect2(Vector2.ZERO, Vector2(root.size))
	for name in ["TopBar", "LawBar", "LeftPanel", "CenterPanel", "RightPanel", "BottomPanel", "EndDayButton", "NotesButton", "MenuButton", "DayLabel", "PhaseLabel", "ActionSlot1", "ActionSlot2", "ActionSlot3"]:
		var control: Control = main.get_node("%" + name)
		if not bounds.encloses(control.get_global_rect()):
			print("OUTSIDE ", name, " ", control.get_global_rect(), " bounds ", bounds)
		check(bounds.encloses(control.get_global_rect()), "窗口内可见：" + name)
	check(main.get_node("%LeftPanel").get_global_rect().end.x < main.get_node("%CenterPanel").global_position.x, "左中栏有间距")
	check(main.get_node("%CenterPanel").get_global_rect().end.x < main.get_node("%RightPanel").global_position.x, "中右栏有间距")
	check(main.get_node("%Body").get_global_rect().end.y < main.get_node("%BottomPanel").global_position.y, "底部独立于主体")
	var original_size := root.size
	for window_size in [Vector2i(1920, 1080), Vector2i(1280, 720), original_size]:
		root.size = window_size
		for frame in range(5):
			await process_frame
		var resized_bounds := Rect2(Vector2.ZERO, Vector2(window_size))
		for name in ["TopBar", "LawBar", "LeftPanel", "CenterPanel", "RightPanel", "BottomPanel"]:
			check(resized_bounds.encloses(main.get_node("%" + name).get_global_rect()), "动态缩放保持区域可见：" + name)
		check(ui.selected_id == "trace" and main.state.get_progress() == before, "动态缩放保留选择及日期")
	await capture("navigation")
	ui.reset_navigation()
	var f3 := InputEventKey.new()
	f3.keycode = KEY_F3
	f3.pressed = true
	root.push_input(f3, true)
	await process_frame
	check(main.debug_panel.visible, "F3 打开隐藏 DEBUG")
	for frame in range(3):
		await process_frame
	check(main.debug_panel.size.x <= root.size.x and main.debug_panel.size.y <= root.size.y - 40, "DEBUG 尺寸不超出窗口")
	await capture("debug")
	root.push_input(f3, true)
	await process_frame
	check(not main.debug_panel.visible, "F3 关闭 DEBUG")
	check(main.state.get_progress() == before, "开关 DEBUG 不改变日期")
	main.queue_free()
	await process_frame
	print("PASS: 工作台鼠标导航、占位禁用、五区布局、F3 与状态隔离")
