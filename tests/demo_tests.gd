extends SceneTree
const Summary = preload("res://scripts/demo_summary.gd")
var checks := 0
var failures := 0
func _initialize():
	_run.call_deferred()
func check(ok: bool, text: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func frames():
	for i in range(6): await process_frame
func click(control: Control):
	var point = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	control.get_viewport().push_input(motion, true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		control.get_viewport().push_input(event, true)
	await frames()
func capture(name: String):
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://previews/town-update-%s-%d.png" % [name,root.size.x])
func queue_investigation(main: Control, target: String):
	for button in main.get_node("%MarkerNodes").get_children():
		if button.get_meta("target_id", "") == target:
			await click(button)
	main.get_node("%DetailsScroll").ensure_control_visible(main.get_node("%InvestigateAction"))
	await frames()
	await click(main.get_node("%InvestigateAction"))
	main.get_node("%DetailsScroll").ensure_control_visible(main.get_node("%QueueAction"))
	await frames()
	await click(main.get_node("%QueueAction"))
func _run():
	root.size = Vector2i(1280,720) if "--small" in OS.get_cmdline_user_args() else Vector2i(1600,900)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await frames()
	var ui = main.game_screen
	var c = ui.planning
	var n = ui.narrative
	var summary = main.settlement_screen
	var review = main.get_node("%NightReview")
	var baseline = ui.knowledge.get_snapshot()
	for day in range(1,11):
		check(main.state.get_day()==day,"calendar day %d" % day)
		if day <= 4:
			check(n.overlay.visible and c.plan.event_blocked,"event priority day %d" % day)
			for attempt in range(6):
				if n.overlay.page >= n.overlay.event.pages.size()-1: break
				await click(n.overlay.next)
			if n.overlay.page < n.overlay.event.pages.size()-1:
				check(false,"mouse paging did not advance; check window focus")
				quit(1)
				return
			await click(n.overlay.actions.get_child(1))
			check(not c.plan.event_blocked,"event unlock day %d" % day)
		if day == 1:
			await click(main.get_node("%PeopleList").get_child(0))
			check(ui.selected_id=="teacher","mouse target selection")
			main.get_node("%DetailsScroll").ensure_control_visible(main.get_node("%TalkAction"))
			await frames()
			await click(main.get_node("%TalkAction"))
			main.get_node("%DetailsScroll").ensure_control_visible(main.get_node("%QueueAction"))
			await frames()
			await click(main.get_node("%QueueAction"))
			check(c.plan.entries().size()==1,"mouse composer queues ordinary action")
		if day == 2:
			await queue_investigation(main,"ruin_record")
		if day == 3:
			await queue_investigation(main,"unknown_object")
		if day == 10:
			ui.select_target("craftsman")
			ui._select_behavior("talk")
			c._queue()
			check(c.plan.entries().size()==1,"real town conversation on final day")
		await click(main.get_node("%EndDayButton"))
		check(main.get_node("%SubmitConfirm").visible,"unused AP confirmation day %d" % day)
		main.get_node("%SubmitConfirm").get_ok_button().pressed.emit()
		await frames()
		check(c.plan.is_resolved() and review.visible and not main.state.is_finished(),"night shown before transition day %d" % day)
		if not c.plan.is_resolved():
			quit(1)
			return
		var token = c.plan.request_id()
		for i in range(10): c._end_day()
		check(c.settlement.history().size()==day,"duplicate end click deduplicated day %d" % day)
		if day == 10:
			check(c.settlement.receipt(token).steps.size()==8,"all eight final-night stages recorded")
			check(ui.knowledge.get_snapshot().journal_entries["town_talk:craftsman"].text.contains("第 10 天"),"final-night conversation committed before summary")
			check(not summary.visible,"summary cannot precede final review")
			await capture("final-night")
		await click(review.next_day)
		for i in range(10): c._next_day()
		await frames()
	check(main.state.is_finished() and main.state.get_day()==10,"finished with no eleventh day")
	check(summary.visible and summary.snapshot.night_complete,"real completed summary displayed")
	check(str(summary.snapshot.sections[0]).contains("玛瑞斯"),"summary reads discovered Maris record")
	check(str(summary.snapshot.sections[1]).contains("老渔夫") and str(summary.snapshot.sections[1]).contains("哑伯"),"day four known NPCs included in summary")
	check(str(summary.snapshot.sections[2]).contains("尚无"),"no invented water change")
	check(not str(summary.snapshot.sections[4]).contains("物件 · 待查"),"last-night investigation removed pending journal item")
	check(str(summary.snapshot.sections[4]).contains("用途尚未辨明"),"unanswered discovered question preserved after investigation")
	var world = ui.knowledge.get_snapshot()
	for i in range(5):
		await click(summary.tabs[i])
		check(ui.knowledge.get_snapshot()==world,"summary tabs read only")
	await click(summary.tabs[0])
	await capture("summary")
	var bounds = Rect2(Vector2.ZERO,Vector2(root.size))
	for node in [summary.frame,summary.scroll,summary.footer,summary.records,main.restart_button,summary.menu_button]:
		check(bounds.encloses(node.get_global_rect()),"summary layout: " + str(node.name))
	await click(summary.records)
	check(n.journal.visible,"summary opens current run records")
	n.journal.category = 3
	n.journal.render()
	var old = n.journal.entries.filter(func(item): return item.id.begins_with("night:"))[0]
	for i in range(8): n.journal._read(old)
	check(ui.knowledge.get_snapshot()==world and c.settlement.history().size()==10,"old records do not recalculate")
	n.journal.hide()
	await click(summary.menu_button)
	check(main.menu_active and main.main_menu.visible and not summary.visible,"return main menu")
	await click(main.main_menu.get_child(0).get_child(2))
	check(summary.visible and ui.knowledge.get_snapshot()==world,"return summary preserves finished run")
	var old_token = c.plan.request_id()
	await click(main.restart_button)
	check(main.state.get_day()==1 and not main.state.is_finished() and n.overlay.visible,"restart from summary")
	check(c.plan.entries().is_empty() and c.plan.remaining_ap()==3 and c.plan.obtained_ideas().is_empty(),"restart clears actions and cards")
	check(ui.knowledge.get_snapshot()==baseline,"restart clears NPC temporary state, discoveries and events")
	check(c.settlement.history().is_empty() and c.settlement.receipt(old_token).is_empty(),"restart drops old receipts and jobs")
	check(n.journal.entries.is_empty() and n.journal.seen.is_empty(),"restart clears journal and read state")
	# Isolated preview projection and stress data. Never commit these to formal state.
	var k = preload("res://scripts/target_knowledge.gd").new()
	k.set_preview(true)
	var preview_world = k.get_snapshot()
	preview_world.known_targets.erase("craftsman")
	preview_world.regional_feedback["town"].scene.state = "shallow"
	k.apply_settled_snapshot(preview_world)
	var projection = Summary.build(k,[])
	check(projection.preview_only and not projection.night_complete,"preview summary explicitly labeled")
	check(str(projection.sections[1]).contains("盐嫂") and not str(projection.sections[1]).contains("哑伯"),"known NPCs only")
	check(str(projection.sections[1]).contains("合作") and str(projection.sections[1]).contains("安全"),"cooperation and safety distinct")
	k._preview_definitions.fisher.facts.append({"id":"test_safety","field":"safety","text":"测试用已知安全记录"})
	check(not str(Summary.build(k,[]).sections[1]).contains("测试用已知安全记录"),"hidden safety fact withheld")
	preview_world.known_targets.fisher.fact_ids.append("test_safety")
	k.apply_settled_snapshot(preview_world)
	check(str(Summary.build(k,[]).sections[1]).contains("测试用已知安全记录"),"discovered safety fact is shown independently")
	check(str(projection.sections[2]).contains("浅水"),"known actual scene state appears")
	preview_world.regional_feedback.town.scene.state = "dry"
	k.apply_settled_snapshot(preview_world)
	check(not str(Summary.build(k,[]).sections[2]).contains("浅水"),"regressed current state not forced into watery ending")
	n.overlay.hide()
	ui.hide()
	summary.show()
	projection.sections[0].items = ["【独立布局测试，不代表剧情】\n" + "很长的中文记录与未完成调查说明。".repeat(120)]
	summary.present(projection)
	await frames()
	check(bounds.encloses(summary.footer.get_global_rect()),"long summary preserves fixed actions")
	check(summary.scroll.get_v_scroll_bar().max_value > summary.scroll.size.y,"long summary scrolls locally")
	await capture("long-record-test")
	main.queue_free()
	await frames()
	# Separate development fixture for long names and daily card cleanup.
	root.set_meta("skip_intro",true)
	var fixture = load("res://scenes/main.tscn").instantiate()
	root.add_child(fixture)
	await frames()
	var fixture_ui = fixture.game_screen
	fixture_ui.set_development_preview(true)
	await frames()
	var pc = fixture_ui.planning
	var original_preview = fixture_ui.knowledge.get_snapshot()
	var original_name = fixture_ui.knowledge._preview_definitions.fisher.name
	fixture_ui.knowledge._preview_definitions.fisher.name = "【独立长名称测试】" + "非常长的人物姓名与已知称呼".repeat(8)
	fixture_ui.refresh_known_targets()
	pc.plan.put({"target_id":"fisher","behavior":"talk","scale":"personal","idea_id":"sea"})
	await frames()
	for name in ["BottomPanel","EndDayButton","ActionSlot1","ActionSlot2","ActionSlot3","RightPanel"]:
		check(bounds.encloses(fixture.get_node("%"+name).get_global_rect()),"long name bounds " + name)
	check(fixture.get_node("%ActionSlot1").summary_label.get_parent().get_v_scroll_bar().max_value > 64,"long action description scrolls locally")
	await capture("long-plan-test")
	fixture_ui.knowledge._preview_definitions.fisher.name = original_name
	pc.plan.submit()
	await frames()
	check(pc.plan.idea_status("sea").state=="used","fixture uses card before restart")
	var mutation = fixture_ui.knowledge.get_snapshot()
	mutation.known_targets.erase("child")
	mutation.resolved_events = {"temporary":true}
	fixture_ui.knowledge.apply_settled_snapshot(mutation)
	fixture._restart()
	await frames()
	check(pc.plan.idea_status("sea").state=="available" and pc.plan.entries().is_empty(),"restart releases used and reserved cards")
	check(fixture_ui.knowledge.get_snapshot()==original_preview,"restart resets temporary NPC and event data in preview")
	var pending = preload("res://scripts/night_settlement.gd").new()
	pending.submit({"request_id":"old_run","day":1,"preview_only":false,"entries":[]}, {}, {"preview_only":false})
	pending.clear_history()
	await frames()
	check(pending.receipt("old_run").is_empty(),"deferred old run cannot revive after restart")
	fixture.queue_free()
	await frames()
	print("DEMO: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
