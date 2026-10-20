extends SceneTree
const State := preload("res://scripts/story/trail2_state.gd")
const Story := preload("res://scripts/story/trail2_village_story.gd")
var failures := 0
func check(ok: bool, label: String):
	if not ok:
		failures += 1
		push_error(label)
func _initialize(): call_deferred("run")
func settle():
	for i in 4: await process_frame
func act(scene, id: String):
	var group: String = State.ACTIONS[id].group
	if group == "warehouse":
		scene._show_ruins()
	else:
		scene._select_person(scene.PERSON_IDS.find(group), "", "", null)
	scene._preview_action(id)
	scene.modal._select("execute:" + id)
	check(scene.state.completed.has(id), "实际场景行动：" + id)
	await settle()
	check(scene.get_node("%DialogueBox/Text").get_content_height() <= scene.get_node("%DialogueBox/Text").size.y, "行动结果无需滚动：" + id)
	check(scene.context_label.position.y + scene.context_label.size.y <= scene.action_scroll.position.y, "人物信息不覆盖行动：" + id)
func next(scene):
	scene._ask_end_day()
	scene.modal._select("end_day:%d" % scene.state.day)
	scene.modal._select("close")
	await settle()
func run():
	var scene = load("res://scenes/trail2.tscn").instantiate()
	scene.persistence_enabled = false
	root.size = Vector2i(1280, 720)
	root.add_child(scene)
	await settle()
	var dialogue = scene.get_node("%DialogueBox/Text")
	check(scene.get_node("%DialogueBox").dialogue_text == Story.OPENING, "开场交代调查目的与五天期限")
	check(dialogue.get_content_height() <= dialogue.size.y, "开场无需滚动")
	scene._select_person(0, "", "", null)
	scene._preview_action("feed")
	scene.modal._select("execute:feed")
	check(not scene.get_node("%DialogueBox").dialogue_text.contains("成本："), "执行后不复读规则预览")
	check(scene.feedback.text.contains("粮食 2 → 1"), "数值变化独立显示")
	scene._select_person(0, "", "", null)
	check(scene.get_node("%DialogueBox").dialogue_text.contains("粮食收到了"), "送粮后重选不再缺粮开场")
	scene._preview_action("listen")
	scene.modal._select("execute:listen")
	await settle()
	var first: Button = scene.action_list.get_child(0)
	check(first.get_meta("action_id", "") == "protect", "安置优先于遗物并在首屏")
	check(first.position.y + first.size.y <= scene.action_scroll.size.y, "截止行动完整可见")
	check(scene.action_list.get_children().any(func(b): return b.text.begins_with("已完成 2 项")), "完成行动折叠")
	check(scene.scroll_hint.text.contains("下方还有"), "滚动区有明确后续提示")
	scene.state.end_day()
	scene._refresh()
	scene._preview_action("protect")
	scene.modal._select("execute:protect")
	scene._select_person(0, "", "", null)
	check(scene.get_node("%DialogueBox").dialogue_text.contains("已经安顿好"), "安置后人物记住进展")
	# 对白只读，不因重复查看发奖励；检查每个状态与全部行动文本的显示边界。
	var before: String = JSON.stringify(scene.state.to_save_data())
	for npc in ["salt", "mute", "luo"]: Story.greeting(scene.state, npc)
	check(before == JSON.stringify(scene.state.to_save_data()), "对白读取不改变规则状态")
	var texts: Array = [Story.OPENING]
	texts.append_array(Story.ACTION_TEXT.values())
	for day in [2,3,4,5]:
		scene.state.day = day
		texts.append(Story.morning(scene.state))
	for npc in ["salt", "mute", "luo"]:
		texts.append(Story.greeting(scene.state, npc))
	for dimensions in [Vector2i(1280,720), Vector2i(1920,1080)]:
		root.size = dimensions
		await settle()
		for t in texts:
			scene.get_node("%DialogueBox").show_text(t)
			await settle()
			check(dialogue.get_content_height() <= dialogue.size.y, "对白应无需滚动：" + str(t).left(20))
		check(scene.action_scroll.position.y + scene.action_scroll.size.y <= scene.scroll_hint.position.y, "行动区不压滚动提示")
		check(scene.warehouse.position.y + scene.warehouse.size.y <= scene.get_node("%DialogueBox").position.y, "移动按钮不遮挡对白")
	# 告密、沉默、撤回不再使用乐观合作对白。
	var s = State.new()
	s.people.salt.trust = 65
	s.people.salt.alert = 65
	check(Story.greeting(s, "salt").contains("不能再接"), "沉默动态反馈")
	s.people.salt.reported = true
	check(Story.greeting(s, "salt").contains("巡查者"), "告密动态反馈")
	s = State.new()
	s.salt_assistance_revoked = true
	check(Story.greeting(s, "salt").contains("不再替你"), "撤回不再承诺协助")
	s.day = 5
	check(Story.ruins(s).contains("封条"), "关闭遗迹不再提示可勘察")
	s = State.new()
	var day_result: Dictionary = s.end_day()
	check(day_result.text.find("今日 · 第2天开始") < day_result.text.find("第2天提醒"), "先明确日期再提醒巡查")
	for i in 4: s.end_day()
	check(not Story.farewell(s).contains("家人已经安顿好"), "未安置不会出现成功告别")
	scene.state = s
	scene._refresh()
	scene._ask_end_day()
	check(scene.modal.visible, "离村交接仍可反复查看")
	scene.modal._select("close")
	scene.state = State.new()
	scene.selected_group = ""
	scene._refresh()
	# 走完含两次移动的15 AP路线，确认最后一屏确实由选择生成。
	for id in ["feed", "listen", "repair"]: await act(scene, id)
	await next(scene)
	await act(scene, "protect")
	scene._select_map_location("ruins")
	scene.modal._select("travel:ruins:-1")
	await next(scene)
	for id in ["survey", "clear", "search"]: await act(scene, id)
	await next(scene)
	scene._select_map_location("fishing_village")
	scene.modal._select("travel:fishing_village:-1")
	for id in ["identify", "relic"]: await act(scene, id)
	await next(scene)
	scene._begin_material("record_self", "")
	scene.modal._select("pick_material:relic")
	scene.modal._select("confirm_material")
	scene._begin_material("spread", "salt")
	scene.modal._select("pick_material:record_1")
	scene.modal._select("confirm_material")
	scene._ask_end_day()
	scene.modal._select("end_day:5")
	check(scene.state.village_finished and scene.state.ap == 0, "故事演出不改变15AP路线")
	check(scene.modal.body.get_child(1).text.contains("家人已经安顿好") and scene.modal.body.get_child(1).text.contains("托上商路"), "离村告别反映安置和实际传播")
	scene.modal._select("village_report")
	check(scene.modal.visible and scene.modal.body.get_child(0).text == "渔村离场报告", "告别后进入交接清单")
	scene.modal._select("enter_market")
	check(scene.state.day == 6 and scene.state.ap == 2, "下一章仍扣1AP路费且可继续")
	scene.queue_free()
	await process_frame
	print("Experience checks: ", "PASS" if failures == 0 else "FAIL %d" % failures)
	quit(1 if failures else 0)
