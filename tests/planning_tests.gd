extends SceneTree
const K = preload("res://scripts/target_knowledge.gd")
const P = preload("res://scripts/daily_plan.gd")
const S = preload("res://scripts/night_settlement.gd")
var checks := 0
var failures := 0
func _initialize():
	_run.call_deferred()
func check(ok: bool, text: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func entry(id: String, action := "talk", card := "") -> Dictionary:
	return {"target_id": id, "target_name": id, "behavior": action, "behavior_name": P.ACTION_NAMES[action], "scale": "personal", "scale_name": "个人", "idea_id": card, "idea_name": card if card != "" else "无卡"}
func _run():
	root.size = Vector2i(1280,720) if "--small" in OS.get_cmdline_user_args() else Vector2i(1920,1080)
	var k = K.new()
	k.set_preview(true)
	var original = k.get_snapshot()
	var p = P.new(k,"preview")
	check(p.put(entry("widow","talk","sea")).valid,"add card action")
	check(not p.put(entry("fisher","talk","sea")).valid,"duplicate card denied")
	check(p.remaining_ap()==2,"duplicate doesn't spend")
	check(p.put(entry("fisher")).valid and p.put(entry("widow")).valid,"3 AP")
	check(not p.put(entry("fisher")).valid and not p.is_locked(),"full budget no auto submission")
	check(p.remove(0) and p.idea_status("sea").state=="available" and p.remaining_ap()==1,"remove releases card and AP")
	check(p.put(entry("widow","talk","sea"),0).valid,"replace")
	check(p.put(entry("fisher"),0).valid and p.idea_status("sea").state=="available","replace releases card")
	p.start_day(1,true)
	check(not p.put(entry("child")).valid,"remote talk denied")
	check(not p.put(entry("ruins","move","sea")).valid,"undefined move card denied")
	check(p.put(entry("ruins","move")).valid,"2 AP movement")
	check(p.put(entry("child","talk","sea")).valid,"dependent remote talk")
	check(p.validate().items[1].slot==2 and p.validate().items[1].dependency!="","two contiguous slots")
	check(k.get_snapshot()==original and p.local_belief("sea")=="微弱","planning no world effects")
	check(p.reorder(1,-1) and not p.validate().valid and p.submit().is_empty(),"reordering detects invalid dependency")
	check(p.reorder(0,1) and p.validate().valid,"repair order")
	check(p.remove(0) and not p.validate().valid,"deleting move invalidates dependent action")
	p.start_day(1,true)
	k.apply_resolved_location("ruins")
	check(p.put(entry("town","move")).valid and p.remaining_ap()==0,"3 AP move")
	check(p.entries().size()==1 and p.remove(0) and p.remaining_ap()==3,"3 AP move atomic delete")
	k.apply_resolved_location("town")
	var group = entry("widow")
	group.scale="group"
	check(not p.put(group).valid,"group locked by organization")
	check(not p.put(entry("widow","talk","unacquired")).valid,"unobtained idea denied")
	p.put(entry("widow","talk","sea"))
	var payload = p.submit()
	check(p.is_locked() and not p.remove(0) and not p.reorder(0,1) and not p.put(entry("widow")).valid and p.submit().is_empty(),"atomic lock and duplicate guard")
	check(not p.start_day(2),"cannot bypass pending batch")
	var s = S.new()
	check(s.submit(payload) and not s.submit(payload),"batch deduplication")
	check(not s.complete_batch(payload.request_id,{"preview_only":false}),"preview isolation")
	check(not s.complete_batch(payload.request_id,{"preview_only":true,"consumed_ideas":["boundary_idea"]}),"invalid receipt rejected")
	check(p.mark_resolved(payload.request_id,["sea"]) and p.idea_status("sea").state=="used","used distinct from planned")
	check(p.start_day(2) and p.idea_status("sea").state=="available","new day resets usage")
	p.put(entry("ruins","move"))
	var failed = p.submit()
	var failure_service = S.new()
	var receipts = []
	failure_service.batch_ready.connect(func(r): receipts.append(r))
	failure_service.submit(failed,{"enabled":true,"movement_outcome":"failure"})
	await process_frame
	check(receipts.size()==1 and receipts[0].status=="needs_rule" and p.is_locked() and p.remaining_ap()==1,"failure AP policy pending, no refund")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var ui=main.get_node("%GameScreen")
	var c=main.get_node("%PlanningController")
	check(c.plan.obtained_ideas().is_empty(),"formal acquired cards only")
	ui.set_development_preview(true)
	ui.select_target("ruins")
	ui._select_behavior("move")
	c._queue()
	ui.select_target("child")
	check(not main.get_node("%TalkAction").disabled,"UI supports planned distance")
	ui._select_behavior("talk")
	c.selected_idea="sea"
	c._queue()
	check(c.plan.remaining_ap()==0 and main.get_node("%ActionSlot2").owner_index==0,"UI continuous slots")
	await process_frame
	await process_frame
	for name in ["TopBar","LawBar","LeftPanel","CenterPanel","RightPanel","BottomPanel","EndDayButton","ActionSlot1","ActionSlot2","ActionSlot3"]:
		var rect:Rect2=main.get_node("%"+name).get_global_rect()
		check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(rect),"layout bounds "+name)
	if DisplayServer.get_name()!="headless" and "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://previews/stage4-planning-plan-%d.png"%root.size.x)
	c._end_day()
	check(c.plan.is_locked() and main.state.get_slot()==2 and not c.plan.is_resolved(),"submit enters night before deferred batch")
	c._end_day()
	await process_frame
	check(c.plan.is_resolved() and ui.knowledge.current_location_id()=="ruins" and c.plan.idea_status("sea").state=="used","batch changes position and usage only after full resolution")
	check(not c.plan.remove(0),"resolved plan remains locked")
	c._next_day()
	await process_frame
	check(main.state.get_day()==2 and c.plan.remaining_ap()==3 and c.plan.idea_status("sea").state=="available","next day reset")
	ui.set_development_preview(false)
	check(main.state.get_day()==1 and ui.knowledge.visible_targets().is_empty(),"preview date and knowledge isolated")
	ui.set_development_preview(true)
	for day in range(2,11):
		c._end_day()
		check(main.get_node("%SubmitConfirm").visible and not c.plan.is_locked(),"unused AP confirmation")
		main.get_node("%SubmitConfirm").hide()
		check(not c.plan.is_locked(),"cancel unused AP preserves editable plan")
		c._end_day()
		c._confirm_submit()
		await process_frame
		check(c.plan.is_resolved() and not main.state.is_finished(),"night doesn't finish early")
		c._next_day()
		await process_frame
	check(main.state.is_finished() and main.state.get_day()==10,"final settlement without day11")
	main._restart()
	check(main.state.get_day()==1 and c.plan.remaining_ap()==3 and not c.plan.is_locked(),"restart clears plan")
	check(ui.knowledge.current_location_id()=="town","restart restores preview position")
	for frame in range(4):
		await process_frame
	var person=main.get_node("%PeopleList").get_child(1)
	person.get_parent().get_parent().get_parent().ensure_control_visible(person)
	await process_frame
	await process_frame
	click(person)
	check(ui.selected_id=="widow","real pointer selects widow")
	for frame in range(3):
		await process_frame
	main.get_node("%DetailsScroll").ensure_control_visible(main.get_node("%TalkAction"))
	await process_frame
	await process_frame
	click(main.get_node("%TalkAction"))
	check(ui.selected_behavior=="talk","real pointer configures talk")
	c._choose_idea(1)
	check(main.get_node("%ActionDescription").text.contains("丈夫留下的记录"),"known conditional description")
	for frame in range(3):
		await process_frame
	main.get_node("%DetailsScroll").ensure_control_visible(main.get_node("%QueueAction"))
	await process_frame
	await process_frame
	if DisplayServer.get_name()!="headless" and "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://previews/stage4-planning-composer-%d.png"%root.size.x)
	click(main.get_node("%QueueAction"))
	check(c.plan.entries().size()==1 and c.plan.remaining_ap()==2,"real pointer queues without executing")
	c._queue()
	check(c.plan.entries().size()==1,"repeat stale queue ignored")
	click(main.get_node("%ActionSlot1").edit_button)
	check(c.editing_index==0,"slot edit opens replacement")
	c._choose_idea(0)
	c._queue()
	check(c.plan.idea_status("sea").state=="available" and c.plan.remaining_ap()==2,"UI replacement releases card without double spending")
	click(main.get_node("%ActionSlot1").remove_button)
	check(c.plan.remaining_ap()==3 and c.plan.entries().is_empty(),"pointer delete releases AP")
	main.queue_free()
	await process_frame
	print("PLANNING: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)

func click(control: Control):
	var position=control.get_global_rect().get_center()
	var motion=InputEventMouseMotion.new()
	motion.position=position
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event=InputEventMouseButton.new()
		event.position=position
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		root.push_input(event,true)
