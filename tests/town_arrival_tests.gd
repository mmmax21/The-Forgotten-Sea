extends SceneTree
var checks := 0
var failures := 0
func _initialize():
	_run.call_deferred()
func check(value: bool, message: String):
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func frames():
	for i in range(6): await process_frame
func finish_event(n):
	for i in range(n.overlay.event.pages.size()-1): n.overlay.next.pressed.emit()
	n.overlay.actions.get_child(1).pressed.emit()
	await frames()
func _run():
	root.size = Vector2i(1280,720) if "--small" in OS.get_cmdline_user_args() else Vector2i(1600,900)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await frames()
	var ui = main.game_screen
	var c = ui.planning
	var n = ui.narrative
	var preview_before = ui.knowledge._preview_snapshot.duplicate(true)
	for day in range(1,4):
		await finish_event(n)
		check(not ui.knowledge.is_known("fisher") and not ui.knowledge.is_known("child"),"NPC hidden before day four")
		c.plan.submit()
		await frames()
		c._next_day()
		await frames()
	check(main.state.get_day()==4 and main.state.get_slot()==0,"day four morning calendar")
	check(n.active.id=="town_arrival" and c.plan.event_blocked,"mandatory arrival event")
	check(c.plan.submit().is_empty(),"cannot bypass arrival")
	check(ui.knowledge.current_location_id()=="ruins","reading has no relocation side effect")
	await finish_event(n)
	check(ui.knowledge.current_location_id()=="town","event commits actual town location")
	check(c.plan.remaining_ap()==3 and c.plan.entries().is_empty(),"story arrival costs no regular AP or slot")
	check(not c.plan.group_access().unlocked and c.plan.obtained_ideas().is_empty(),"meeting unlocks neither group nor cards")
	var world = ui.knowledge.get_snapshot()
	for id in ["fisher","widow","child","craftsman"]:
		check(ui.knowledge.is_known(id) and ui.knowledge.target_view(id).location_id=="town","known town NPC: "+id)
		check(ui.knowledge.action_options(id).talk.eligible,"talk available: "+id)
		check(not ui.knowledge.action_options(id).investigate.eligible,"meeting doesn't invent clue: "+id)
		check(ui.knowledge.target_view(id).issues.is_empty() and ui.knowledge.target_view(id).belief=="尚未了解","no hidden risk or belief exposure: "+id)
		ui.select_target(id)
		check(ui.knowledge.get_snapshot()==world,"viewing does not award information")
	check(not ui.knowledge.action_options("ruin_record").investigate.eligible,"remote ruins cannot be investigated from town")
	check(ui.knowledge.target_view("craftsman").communication.contains("手势"),"craftsman communication preserved")
	n._choose("town_arrival","continue")
	n.check_events()
	check(ui.knowledge.get_snapshot()==world and not n.overlay.visible,"arrival is idempotent")
	check(ui.knowledge._preview_snapshot==preview_before,"preview fixture unchanged")
	if "--capture" in OS.get_cmdline_user_args():
		await frames()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://previews/day-four-town-%d.png" % root.size.x)
	for id in ["fisher","widow","child"]:
		check(c.plan.put({"target_id":id,"behavior":"talk","scale":"personal","idea_id":""}).valid,"queue paid town conversation: "+id)
	check(ui.knowledge.get_snapshot()==world,"planning has no conversation effect")
	c.plan.submit()
	await frames()
	check(c.plan.is_resolved() and c.plan.remaining_ap()==0,"three town conversations settle together")
	check(c.settlement.history().back().sections.actions.size()==3,"three ordered conversation results")
	for id in ["fisher","widow","child"]:
		check(ui.knowledge.get_snapshot().known_targets[id].latest_fact_id=="talked","actual night updates conversation record: "+id)
	c._next_day()
	await frames()
	check(main.state.get_day()==5 and not n.overlay.visible and ui.knowledge.current_location_id()=="town","no repeated arrival next day")
	c.plan.put({"target_id":"craftsman","behavior":"talk","scale":"personal","idea_id":""})
	c.plan.submit()
	await frames()
	check(c.plan.is_resolved() and c.settlement.history().back().sections.actions[0].happened.contains("手势"),"craftsman night result uses gestures")
	main._restart()
	await frames()
	check(not ui.knowledge.is_known("fisher") and not ui.knowledge.get_snapshot().get("resolved_events",{}).has("town_arrival"),"restart clears acquaintance and event")
	main.queue_free()
	await frames()
	print("TOWN: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
