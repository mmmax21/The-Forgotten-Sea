extends SceneTree
var checks := 0
var failures := 0
func _initialize():
	_run.call_deferred()
func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func frames():
	for i in range(8): await process_frame
func draft(target: String, action: String) -> Dictionary:
	return {"target_id":target,"behavior":action,"scale":"personal","idea_id":""}
func finish_event(n):
	while n.overlay.page < n.overlay.event.pages.size() - 1:
		n.overlay.next.pressed.emit()
	n.overlay.actions.get_child(1).pressed.emit()
	await frames()
func _run():
	root.size = Vector2i(1280,720) if "--small" in OS.get_cmdline_user_args() else Vector2i(1600,900) if "--medium" in OS.get_cmdline_user_args() else Vector2i(1920,1080)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await frames()
	var ui = main.get_node("%GameScreen")
	var c = ui.planning
	var n = ui.narrative
	check(n.overlay.visible and c.plan.event_blocked,"mandatory day one overlay")
	check(c.plan.submit().is_empty() and c.plan.entries().is_empty(),"event prevents model submit")
	check(main.get_node("%EndDayButton").disabled,"mandatory event disables end day")
	var before = ui.knowledge.get_snapshot()
	n.overlay.next.pressed.emit()
	n.overlay.previous.pressed.emit()
	check(ui.knowledge.get_snapshot()==before and c.plan.remaining_ap()==3,"pages do not mutate world or AP")
	await finish_event(n)
	check(not c.plan.event_blocked and ui.knowledge.is_known("teacher"),"event introduces teacher then unlocks planning")
	check(c.plan.obtained_ideas().is_empty(),"intro does not invent acquired cards")
	before = ui.knowledge.get_snapshot()
	n._choose("intro","continue")
	check(ui.knowledge.get_snapshot()==before,"duplicate event choice ignored")
	check(c.plan.put(draft("teacher","talk")).valid,"day one teacher action usable")
	check(ui.knowledge.get_snapshot()==before,"planning has no results")
	c.plan.submit()
	await frames()
	check(c.plan.is_resolved(),"intro talk settles through unified service")
	c._next_day()
	await frames()
	check(main.state.get_day()==2 and n.overlay.visible and c.plan.event_blocked,"day two mandatory before planning")
	await finish_event(n)
	check(ui.knowledge.target_view("ruin_record").has_lead,"day two opens actual lead")
	check(not str(n.journal.entries).contains("辨认出"),"no uninvestigated answer in notes")
	check(c.plan.put(draft("ruin_record","investigate")).valid,"ruin investigation available")
	check(c.plan.put(draft("unknown_object","investigate")).valid,"object investigation available")
	c.plan.submit()
	await frames()
	check(c.plan.is_resolved(),"both discoveries settle once")
	check(ui.knowledge.get_snapshot().journal_entries.record.text.contains("玛瑞斯"),"actual investigation discovers Maris")
	check(not ui.knowledge.target_view("ruin_record").has_lead,"completed investigation not indefinitely farmable")
	before = ui.knowledge.get_snapshot()
	for i in range(3):
		ui._show_notes()
		n.journal.help.pressed.emit()
		n.journal.hide()
	check(ui.knowledge.get_snapshot()==before and main.state.get_day()==2,"notes and help read only")
	check(n.journal.unread(),"new records marked")
	for entry in n.journal.entries: n.journal._read(entry)
	check(not n.journal.unread(),"read records cleared")
	n.refresh_journal()
	check(not n.journal.unread(),"refresh does not restore read badges")
	c._next_day()
	await frames()
	check(main.state.get_day()==3 and n.overlay.visible,"day three story shown")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://previews/stage6-event.png")
	await finish_event(n)
	check(not ui.knowledge.action_options("teacher").talk.eligible,"deceased teacher cannot talk")
	check(c.plan.obtained_ideas().is_empty() and not c.plan.group_access().unlocked,"day three no unconfigured card or group unlock")
	c.plan.submit()
	await frames()
	check(c.plan.is_resolved(),"empty day still settles")
	c._next_day()
	await frames()
	check(main.state.get_day()==4 and c.plan.event_blocked and n.overlay.visible,"day four arrival before planning")
	await finish_event(n)
	check(ui.knowledge.current_location_id()=="town" and not c.plan.event_blocked,"town arrival opens planning")
	before = ui.knowledge.get_snapshot()
	before.known_targets.child = {"fact_ids":[]}
	before.event_signals = {"child_threat_reported":true}
	ui.knowledge.apply_settled_snapshot(before,"test:known-report")
	await frames()
	check(n.overlay.visible and n.active.id=="child_threat","known condition event triggered")
	var ap = c.plan.remaining_ap()
	await finish_event(n)
	check(c.plan.remaining_ap()==ap and not ui.knowledge.get_snapshot().get("child_protected",false),"crisis is not free protection")
	check(n.events.due(4,ui.knowledge.get_snapshot()).is_empty(),"resolved crisis does not recur")
	var reward_event = {"id":"test_reward","choices":[{"id":"take"}],"effects":{"acquired_ideas":["sea"]}}
	var rewarded = n.events.resolve(reward_event,"take",ui.knowledge.get_snapshot())
	check(rewarded.acquired_ideas == ["sea"] and n.events.resolve(reward_event,"take",rewarded).is_empty(),"configured effect applies once; test reward never committed")
	var hidden_report = ui.knowledge.get_snapshot()
	hidden_report.resolved_events.erase("child_threat")
	hidden_report.known_targets.erase("child")
	check(n.events.due(4,hidden_report).is_empty(),"unknown NPC crisis not exposed")
	for day in range(4,11):
		c.plan.submit()
		await frames()
		c._next_day()
		await frames()
	check(main.state.is_finished() and main.state.get_day()==10,"story integration retains ten-day final boundary")
	main._restart()
	await frames()
	check(main.state.get_day()==1 and n.overlay.visible and ui.knowledge.get_snapshot().get("resolved_events",{}).is_empty(),"restart resets actual run ledger")
	await finish_event(n)
	n.open_journal()
	await frames()
	check(n.journal.get_child(0).get_global_rect().end.x <= root.size.x,"drawer stays inside width")
	check(n.journal.get_child(0).get_global_rect().end.y <= root.size.y,"drawer stays inside height")
	if "--capture" in OS.get_cmdline_user_args():
		n.journal.category = 2
		n.journal.render()
		n.journal._read(n.journal.entries[0])
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://previews/stage6-journal.png")
	# Empty first days must not require a card, AP expenditure, or tutorial action.
	n.journal.hide()
	c.plan.submit()
	await frames()
	c._next_day()
	await frames()
	await finish_event(n)
	c.plan.submit()
	await frames()
	c._next_day()
	await frames()
	check(main.state.get_day()==3 and n.overlay.visible,"empty first days reach established teacher event")
	await finish_event(n)
	check(not ui.knowledge.get_snapshot().journal_entries.record.text.contains("辨认出"),"skipped investigation never grants its answer")
	main.queue_free()
	await frames()
	print("Narrative tests: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
