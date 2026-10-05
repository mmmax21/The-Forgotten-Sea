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
	_test_state()
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
	main.next_button.pressed.emit()
	check(main.time_label.text == "当前时间：下午", "按钮推进至下午")
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
	var error := root.get_texture().get_image().save_png("res://previews/%s.png" % file_name)
	check(error == OK, "保存实际渲染预览")
