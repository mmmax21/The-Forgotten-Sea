extends SceneTree
var checks:=0
var failures:=0
func _initialize():
	root.set_meta("skip_intro", true)
	run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:
		failures+=1
		push_error(label)
func run():
	root.size=Vector2i(1280,720) if "--small" in OS.get_cmdline_user_args() else Vector2i(1600,900) if "--medium" in OS.get_cmdline_user_args() else Vector2i(1920,1080)
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var ui=main.get_node("%GameScreen")
	var c=main.get_node("%PlanningController")
	var f=main.get_node("%FeedbackController")
	var canvas=main.get_node("%SceneCanvas")
	check(canvas.state=="unknown" and main.get_node("%Law1").pattern=="unknown","formal missing data remains unknown")
	check(not f.apply_preview(0),"formal mode rejects preview injection")
	var formal=ui.knowledge.get_snapshot()
	ui.set_development_preview(true)
	await frames()
	check(canvas.state=="dry" and not canvas.layers.water.visible,"initial canal dry, no premature sea")
	check(main.get_node("%Law1").text.contains("稳固") and main.get_node("%Law2").text.contains("稳固") and main.get_node("%Law3").text.contains("稳固"),"three individual baseline laws")
	check(not canvas.marker.visible and not ui.knowledge.action_options("canal").investigate.eligible,"background not automatically investigable")
	check(main.get_node("%IdeasRow").get_child(0).pattern=="fragment","weak acquired idea has incomplete illustration")
	await capture("normal")
	var before_day=main.state.get_progress()
	check(f.apply_preview(1) and not f.apply_preview(2),"test snapshot submission deduplicates in-flight input")
	await frames()
	check(canvas.state=="signs" and canvas.layers.signs.visible and not canvas.layers.water.visible,"signs layer independently visible")
	check(main.get_node("%Law1").pattern=="hairline" and main.get_node("%Law2").pattern=="whole" and main.get_node("%Law3").pattern=="whole","sea idea does not change other laws")
	check(not canvas.marker.visible and not ui.knowledge.action_options("canal").investigate.eligible,"visual anomaly alone does not open investigation")
	var notifications=f.notification_count
	for repeat in range(5):
		ui.refresh_known_targets()
		c._on_plan_changed()
	check(f.notification_count==notifications,"reopening same state doesn't repeat change hint")
	check(f.notifications.size()>0,"actual change creates notice")
	canvas.notices.get_child(0).pressed.emit()
	check(ui.selected_id=="canal" and c.plan.remaining_ap()==3 and main.state.get_progress()==before_day,"notice selects only, no free investigation or time")
	f.apply_preview(2)
	await frames()
	check(canvas.state=="shallow" and canvas.layers.water.visible and not canvas.layers.tide.visible,"partial progress shows shallow water")
	check(canvas.marker.visible and ui.knowledge.action_options("canal").investigate.eligible,"officially opened clue creates usable marker")
	check(not ui.knowledge.action_options("boundary").move.eligible,"cracked third law isn't permission")
	check(main.get_node("%IdeasRow").get_child(0).pattern=="emerging","local belief creates emerging motifs")
	var same_count=f.notification_count
	var unchanged=ui.knowledge.get_snapshot()
	ui.knowledge.apply_settled_snapshot(unchanged,"feedback-test:2")
	check(f.notification_count==same_count,"repeat receipt does not replay hints")
	var notice_size=f.notifications.size()
	ui.knowledge.apply_settled_snapshot(unchanged,"morning:unchanged-test")
	check(f.notifications.size()==notice_size and f.notification_count==same_count,"unchanged morning preserves night notice without replay")
	await capture("partial")
	f.apply_preview(3)
	await frames()
	check(canvas.layers.tide.visible and canvas.state=="tidal","tide marks layer supported without day threshold")
	check(main.get_node("%Law2").pattern=="whole" and main.get_node("%Law3").pattern=="broken","independent law states at consensus")
	check(ui.knowledge.action_options("boundary").move.eligible,"movement follows explicitly permitted test route")
	check(main.get_node("%IdeasRow").get_child(0).pattern=="complete","strong consensus complete card")
	await capture("consensus")
	var raw=ui.knowledge.get_snapshot()
	raw.known_routes.boundary.reachable=false
	ui.knowledge.apply_settled_snapshot(raw,"test-underlying-restriction")
	ui.refresh_known_targets()
	check(main.get_node("%Law3").pattern=="broken" and not ui.knowledge.action_options("boundary").move.eligible,"broken law never bypasses authoritative route check")
	f.apply_preview(4)
	await frames()
	check(canvas.state=="dry" and not canvas.layers.water.visible and not canvas.layers.tide.visible,"suppression reverts layers")
	check(not canvas.marker.visible and not ui.knowledge.action_options("canal").investigate.eligible,"suppression closes active investigation")
	check(ui.knowledge.target_view("canal").clues.size()==1,"old knowledge retained after active clue closes")
	check(main.get_node("%IdeasRow").get_child(0).pattern=="fragment" and not ui.knowledge.action_options("boundary").move.eligible,"belief and passage revert independently")
	await capture("suppressed")
	var belief_pattern=main.get_node("%IdeasRow").get_child(0).pattern
	var evidence=ui.knowledge.get_snapshot()
	evidence.known_targets.fisher.fact_ids.append("f_grandson")
	ui.knowledge.apply_settled_snapshot(evidence,"new-evidence-only")
	ui.refresh_known_targets()
	c._on_plan_changed()
	check(main.get_node("%IdeasRow").get_child(0).pattern==belief_pattern,"new evidence doesn't upgrade card")
	c.plan.put({"target_id":"widow","behavior":"talk","scale":"personal","idea_id":"sea"})
	check(main.get_node("%IdeasRow").get_child(0).pattern==belief_pattern and main.get_node("%IdeasRow").get_child(0).text.contains("已安排"),"reservation state doesn't dim or upgrade belief illustration")
	check(not f.apply_preview(0),"test injection disallowed with planned actions")
	c.plan.remove(0)
	c.plan.put({"target_id":"ruins","behavior":"move","scale":"personal","idea_id":""})
	check(ui.knowledge.current_location_id()=="town" and main.get_node("%IdeasRow").get_child(0).pattern==belief_pattern,"planned movement doesn't change local visuals")
	c._end_day()
	c._confirm_submit()
	await frames()
	check(ui.knowledge.current_location_id()=="ruins" and main.get_node("%IdeasRow").get_child(0).pattern=="emerging","actual arrival reads new regional belief")
	check(main.get_node("%Law1").pattern=="hairline" and canvas.state=="unknown","arrival reads different local law and scene")
	c._next_day()
	await frames()
	ui.set_development_preview(false)
	check(ui.knowledge.get_snapshot()==formal and main.state.get_progress()==1,"all visual test states isolated from formal date and knowledge")
	var route_test=preload("res://scripts/target_knowledge.gd").new()
	route_test.set_preview(true)
	var route_world=route_test.get_snapshot()
	route_world.current_location_id="ruins"
	route_world.known_routes.boundary={"reachable":true,"from_ids":["town"],"reason":"测试许可"}
	route_test.apply_settled_snapshot(route_world)
	check(not route_test.action_options("boundary").move.eligible and route_test.place_status("boundary").contains("不可到达"),"map reachability and behavior both respect actual origin")
	main.queue_free()
	await process_frame
	print("FEEDBACK: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
func frames():
	for frame in range(20):
		await process_frame
func capture(name:String):
	var main=root.get_child(root.get_child_count()-1)
	var bounds=Rect2(Vector2.ZERO,Vector2(root.size))
	for id in ["LawBar","ScenePlaceholder","BottomPanel","EndDayButton","IdeasRow"]:
		check(bounds.encloses(main.get_node("%"+id).get_global_rect()),"feedback bounds "+id)
	check(main.get_node("%CenterPanel").get_global_rect().encloses(main.get_node("%MarkerNodes").get_global_rect()),"markers stay inside central panel")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://previews/stage5-%s-%d.png"%[name,root.size.x])
