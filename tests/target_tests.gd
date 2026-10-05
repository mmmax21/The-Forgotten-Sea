extends RefCounted

const Knowledge = preload("res://scripts/target_knowledge.gd")
const MainScene = preload("res://scenes/main.tscn")


func test_model(suite: SceneTree) -> void:
	var model := Knowledge.new()
	var formal := model.get_snapshot()
	suite.check(model.visible_targets().is_empty(), "正式记录未接入时不伪造相识与地点")
	model.set_preview(true)
	var fixture := model.get_snapshot()
	suite.check(model.visible_targets("person").size() == 4, "预览四名关键人物")
	suite.check(model.visible_targets("place").size() == 3, "预览三个已知地点")
	var fisher := model.target_view("fisher")
	suite.check(fisher.name == "老渔夫" and fisher.cooperation.contains("尚未同意公开作证"), "信任不等于公开合作")
	suite.check(not JSON.stringify(fisher).contains("孙子"), "未发现的孙子顾虑不进入投影")
	suite.check(model.target_view("widow").cooperation.contains("生计未稳"), "盐嫂合作范围反映已知处境")
	suite.check(not model.target_view("widow").cooperation.contains("已经加入"), "仇恨不等于已加入")
	suite.check(model.target_view("child").issues[0].contains("旁人的注意"), "螺螺显示已观察到的暴露风险")
	suite.check(model.target_view("craftsman").cooperation.contains("手势"), "哑伯以手势表达合作")
	suite.check(model.action_options("fisher").talk.eligible, "同地已认识人物可选交流")
	suite.check(not model.action_options("child").talk.eligible, "异地人物不能直接交谈")
	suite.check(not model.action_options("town").investigate.eligible, "普通建筑地点不能凭点击调查")
	suite.check(model.action_options("shell").investigate.eligible, "同地明确物件线索可选调查")
	suite.check(not model.action_options("mark").investigate.eligible, "异地异常也受距离限制")
	suite.check(model.action_options("ruins").move.eligible, "已知可达地点可选移动意图")
	suite.check(not model.action_options("boundary").move.eligible, "不可到达地点禁止移动意图")
	suite.check(model.action_options("boundary").move.reason.contains("第三法则"), "不可达说明来自已知原因")
	suite.check(not model.action_options("town").move.eligible, "当前所在地无需移动")
	suite.check(not model.set_live_data(fixture.targets, fixture), "预览快照不能直接作为正式数据")
	for index in range(10):
		for entry in model.visible_targets():
			model.target_view(entry.id)
			model.action_options(entry.id)
	suite.check(model.get_snapshot() == fixture, "重复读取不揭示事实或移动位置")
	var detached := model.target_view("fisher")
	detached.cooperation = "篡改返回值"
	suite.check(model.target_view("fisher").cooperation != detached.cooperation, "详情返回深拷贝")
	model.set_preview(false)
	suite.check(model.get_snapshot() == formal, "关闭预览恢复原正式记录")

	# 隔离的测试快照，验证正式接入边界，不写回任何正式文件。
	var live_fixture := fixture.duplicate(true)
	live_fixture.preview_only = false
	live_fixture.known_targets.erase("widow")
	live_fixture.known_targets.erase("boundary")
	model.set_live_data(fixture.targets, live_fixture)
	suite.check(model.visible_targets("person").size() == 3, "正式模式只显示已经认识的人物")
	suite.check(model.target_view("widow").is_empty(), "直接请求未认识人物也不返回资料")
	suite.check(model.target_view("boundary").is_empty(), "未发现地点不公开")
	suite.check(not model.action_options("boundary").move.eligible, "隐藏目标不能通过行为接口绕过")
	live_fixture.known_targets.fisher.fact_ids.append("f_grandson")
	model.set_live_data(fixture.targets, live_fixture)
	suite.check(model.target_view("fisher").issues[0].contains("孙子不是螺螺"), "发现后明确区分孙子与螺螺")
	live_fixture.known_targets.fisher.fact_ids.erase("f_song")
	live_fixture.known_targets.fisher.latest_fact_id = "f_song"
	model.set_live_data(fixture.targets, live_fixture)
	suite.check(not model.target_view("fisher").has_lead, "移除已发现线索后不再能调查")
	suite.check(model.target_view("fisher").latest_status == "暂无新的已知状态", "最新状态也不能泄露未发现事实")
	live_fixture.known_targets.craftsman.erase("known_location")
	model.set_live_data(fixture.targets, live_fixture)
	suite.check(model.target_view("craftsman").location_label == "当前位置未知", "缺失位置如实显示未知")
	suite.check(not model.action_options("craftsman").talk.eligible, "未知位置不能直接交流")
	live_fixture.current_location_id = "ruins"
	model.set_live_data(fixture.targets, live_fixture)
	suite.check(model.action_options("child").talk.eligible, "外部位置更新后异地人物可转为同地")
	suite.check(not model.action_options("fisher").talk.eligible, "位置更新后原同地人物变为异地")
	suite.check(model.action_options("mark").investigate.eligible, "同地异常有明确观察时可调查")
	print("PASS: 知识过滤、四人物语义、正式/预览隔离、距离与调查适用性")


func test_ui(suite: SceneTree) -> void:
	var main = MainScene.instantiate()
	suite.root.add_child(main)
	for frame in range(4):
		await suite.process_frame
	var ui = main.game_screen
	suite.check(not ui.knowledge.preview_enabled, "默认启动使用正式资料")
	suite.check(ui.knowledge.visible_targets().is_empty(), "默认界面不自动认识四名 NPC")
	await suite.capture("formal")
	main._toggle_debug()
	await suite.process_frame
	main.get_node("%PreviewToggle").button_pressed = true
	suite.check(ui.knowledge.preview_enabled, "DEBUG 开关启用独立预览")
	main.debug_panel.hide()
	for frame in range(4):
		await suite.process_frame
	var before: Dictionary = ui.knowledge.get_snapshot()
	var before_progress: int = main.state.get_progress()
	ui.select_target("fisher")
	suite.check(main.get_node("%TargetTitle").text == "老渔夫", "详情姓名同步")
	suite.check(main.get_node("%TargetPortrait").visible, "人物占位立绘可见")
	suite.check(not _visible_text(main).contains("孙子"), "未发现条件不出现在渲染文本和提示中")
	suite.check(not main.get_node("%TalkAction").disabled, "同地交流按钮可选择")
	main.get_node("%TalkAction").pressed.emit()
	suite.check(ui.selected_behavior == "talk", "点击合法行为只配置意图")
	ui.select_target("child")
	suite.check(ui.selected_behavior.is_empty(), "切换目标清除旧行为")
	suite.check(main.get_node("%TalkAction").disabled, "异地 NPC 的交流按钮禁用")
	main.get_node("%TalkAction").pressed.emit()
	suite.check(ui.selected_behavior.is_empty(), "伪造过期按钮事件也不能绕过距离限制")
	suite.check(main.get_node("%KnownIssues").text.contains("旁人的注意"), "儿童详情展示已发现的风险")
	await suite.capture("remote-npc")
	ui.select_target("craftsman")
	main.get_node("%TalkAction").pressed.emit()
	suite.check(main.get_node("%ActionHint").text.contains("手势"), "哑伯交流反馈不会使用普通长篇口述")
	# 详情内滚动后仍能真实点击可用行为；底部保持固定。
	var footer_rect: Rect2 = main.get_node("%BottomPanel").get_global_rect()
	main.get_node("%DetailsScroll").ensure_control_visible(main.get_node("%TalkAction"))
	for frame in range(3):
		await suite.process_frame
	suite._click_control(main.get_node("%TalkAction"))
	suite.check(ui.selected_behavior == "talk", "局部滚动后可用行为接收真实鼠标点击")
	suite.check(main.get_node("%BottomPanel").get_global_rect() == footer_rect, "详情滚动时底部行动槽不移动")
	await suite.capture("gesture-action")
	ui.select_target("town")
	suite.check(main.get_node("%InvestigateAction").disabled, "普通地点没有调查按钮权限")
	ui.select_target("shell")
	suite.check(not main.get_node("%InvestigateAction").disabled, "物件线索支持调查选择")
	main.get_node("%InvestigateAction").pressed.emit()
	suite.check(ui.selected_behavior == "investigate", "可选调查有明确选择反馈")
	ui.select_target("boundary")
	suite.check(main.get_node("%MoveAction").disabled and main.get_node("%Reachability").text.contains("第三法则"), "边界禁用与已知原因同步")
	await suite.capture("boundary")
	ui.select_target("unknown_id")
	suite.check(ui.selected_id == "boundary", "不能直接选择未发现 ID")
	suite.check(ui.knowledge.get_snapshot() == before, "全部详情和行为选择不获得情报或移动")
	suite.check(main.state.get_progress() == before_progress, "查看和配置意图不改变原日期")
	suite.check(main.get_node("%APLabel").text == "剩余 AP  — / 3" and main.get_node("%QueueAction").disabled, "不提前实现扣点与排程")
	# 列表滚动后四个人物均可选，条目不是只对第一个人物有效。
	var list: VBoxContainer = main.get_node("%PeopleList")
	var people_scroll: ScrollContainer = list.get_parent().get_parent()
	for button in list.get_children():
		people_scroll.ensure_control_visible(button)
		for frame in range(3):
			await suite.process_frame
		suite._click_control(button)
		suite.check(ui.selected_id == button.get_meta("target_id"), "滚动后点击每个人物条目")
	ui.set_development_preview(false)
	suite.check(ui.selected_id.is_empty() and ui.selected_behavior.is_empty(), "回正式流程清除预览选择与意图")
	suite.check(ui.knowledge.visible_targets().is_empty(), "退出预览没有污染相识和发现记录")
	suite.check(not _visible_text(main).contains("老渔夫"), "正式空记录不残留预览姓名")
	main.queue_free()
	await suite.process_frame
	print("PASS: 人物/地点/物件/异常统一详情，行为联动与知识零写入")


func _visible_text(node: Node) -> String:
	var result := ""
	if node is Control and node.is_visible_in_tree():
		result += node.tooltip_text + "\n"
		if node is Label or node is Button:
			result += node.text + "\n"
	for child in node.get_children():
		result += _visible_text(child)
	return result
