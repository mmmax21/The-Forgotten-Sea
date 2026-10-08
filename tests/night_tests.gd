extends SceneTree
## 所有测试效果均只在本文件注册，不写入正式/开发游戏配置。
const Service = preload("res://scripts/night_settlement.gd")
const Knowledge = preload("res://scripts/target_knowledge.gd")
var checks := 0
var failures := 0
var calls: Array = []
var morning_calls := 0

func _initialize():
	root.set_meta("skip_intro", true)
	_run.call_deferred()

func check(ok: bool, description: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func known(text: String, requires: Array = []) -> Dictionary:
	return {"text": text, "visibility": "known", "requires": requires}

func record(category: String, title: String) -> Dictionary:
	return {"category": category, "visibility": "known", "title": title, "happened": known("测试规则实际触发的事件：" + title), "reason": known("本次输入满足独立测试条件。"), "direction": known("可在已知目标中继续查看资料。"), "hidden_score": 9876}

func fixture() -> Dictionary:
	var k=Knowledge.new()
	k.set_preview(true)
	var world=k.get_snapshot()
	world.preview_only=false
	world.erase("preview_settlement")
	world.test_counts={}
	return world

func adapt(context: Dictionary, stage: String) -> Dictionary:
	calls.append(stage)
	var world: Dictionary=context.world
	world.test_counts[stage]=world.test_counts.get(stage,0)+1
	var records: Array=[]
	if stage=="actions":
		for index in range(context.request.entries.size()):
			var item=record("actions", "行动结果 %d" % (index+1))
			item.action_index=index
			# 可公开结果与未知原因分别过滤。
			item.reason=known("未发现的孙子秘密",[{"target_id":"fisher","fact_id":"f_grandson"}])
			records.push_front(item)
	elif stage=="direct":
		world.test_npc_reactions=world.get("test_npc_reactions",0)+1
		records.append(record("people","测试人物的自主反应"))
	elif stage=="spread":
		records.append(record("people","测试群体的后续反应"))
	elif stage=="ideas":
		world.test_idea_updates=world.get("test_idea_updates",0)+1
		records.append(record("world","测试思想变化"))
	elif stage=="offscreen":
		var secret=record("world","绝不可显示的后台秘密")
		secret.visibility="hidden"
		records.append(secret)
	elif stage=="kingdom":
		world.known_alert="已知测试警戒"
		records.append(record("kingdom","测试中已获知的调查征兆"))
	var result={"status":"complete","world":world,"records":records}
	if stage=="tomorrow":
		result.next_events=[{"id":"test_required","private_reason":"后台事件秘密"}]
	return result

func morning(context: Dictionary) -> Dictionary:
	morning_calls+=1
	check(context.events.size()==1,"mandatory event delivered to adapter")
	var world: Dictionary=context.world
	world.test_morning_done=true
	return {"status":"complete","world":world}

func install(service, preview:=false):
	for stage in Service.STEPS:
		service.set_adapter(stage[0], adapt.bind(stage[0]),preview)

func payload(id: String, entries: Array=[]) -> Dictionary:
	return {"request_id":id,"day":1,"preview_only":false,"entries":entries,"initial_location":"town","budget":3}

func _run():
	root.size=Vector2i(1280,720) if "--small" in OS.get_cmdline_user_args() else Vector2i(1600,900) if "--medium" in OS.get_cmdline_user_args() else Vector2i(1920,1080)
	var s=Service.new()
	install(s)
	var initial=fixture()
	var notices: Array=[]
	s.batch_ready.connect(func(receipt): notices.append(receipt))
	check(s.submit(payload("empty"),{},initial),"empty plan accepted")
	for repeat in range(10):
		check(not s.submit(payload("empty"),{},initial),"rapid duplicate submit ignored")
	check(calls.is_empty() and initial.test_counts.is_empty(),"submission doesn't mutate input or evaluate synchronously")
	await process_frame
	check(calls==Service.STEPS.map(func(step): return step[0]),"exact eight-stage order even with no player actions")
	check(notices.size()==1 and notices[0].status=="complete","one full receipt")
	check(s.receipt("empty").sections.people.size()==2,"autonomous actions independent of empty player plan")
	var public_text=JSON.stringify(s.receipt("empty"))
	check(not public_text.contains("后台秘密") and not public_text.contains("hidden_score") and not public_text.contains("9876"),"hidden fields omitted from receipt")
	check(s.receipt("empty").sections.actions.is_empty(),"empty actions section")
	var stored=s.receipt("empty")
	stored.sections.people.clear()
	check(s.receipt("empty").sections.people.size()==2,"receipt deep copy")
	var world=s.committed_world("empty")
	for repeat in range(20):
		s.history()
		s.receipt("empty")
	check(s.committed_world("empty")==world and calls.size()==8,"read history does not recalculate")
	check(s.begin_next_day("empty") and not s.begin_next_day("empty"),"morning starts at most once per request")
	await process_frame
	check(s.committed_world("empty",true).is_empty(),"mandatory events block morning when adapter missing")
	s.set_morning_adapter(morning)
	check(s.resume_morning("empty"),"explicit adapter resume")
	await process_frame
	check(s.committed_world("empty",true).test_morning_done and morning_calls==1,"mandatory event before day access")
	check(not s.begin_next_day("empty") and not s.resume_morning("empty"),"completed morning cannot repeat")
	check(s.history(true).is_empty(),"formal and preview histories isolated")
	# 挂起与恢复不会重跑前面已经处理过的步骤；未完成批次没有世界快照。
	calls.clear()
	var pending=Service.new()
	install(pending)
	pending.set_adapter("spread",func(_ctx): return {"status":"pending","message":"测试规则等待"})
	pending.submit(payload("pending"),{},fixture())
	await process_frame
	check(calls==["actions","direct"] and pending.committed_world("pending").is_empty(),"pending batch not partially committed")
	check(pending.history().is_empty(),"pending results not inserted into history")
	pending.set_adapter("spread",adapt.bind("spread"))
	pending.resume("pending")
	await process_frame
	check(calls==Service.STEPS.map(func(step):return step[0]),"resume skips completed steps")
	# 默认正式适配器不能把一条行动冒充成功。
	var unsupported=Service.new()
	var unresolved: Array=[]
	unsupported.batch_ready.connect(func(r):unresolved.append(r))
	unsupported.submit(payload("undefined",[{"target_name":"盐嫂","behavior_name":"交谈","idea_id":""}]),{},fixture())
	await process_frame
	check(unresolved[0].status=="needs_rule" and unsupported.history().is_empty(),"undefined formal action stays pending")
	var empty_default=Service.new()
	empty_default.submit(payload("no_rules"),{},fixture())
	await process_frame
	check(empty_default.receipt("no_rules").steps.size()==8 and empty_default.receipt("no_rules").steps[1].status=="unimplemented","missing systems explicit, no fabricated actions")
	await test_ui()
	print("NIGHT: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)

func test_ui():
	calls.clear()
	morning_calls=0
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var ui=main.get_node("%GameScreen")
	var c=main.get_node("%PlanningController")
	var review=main.get_node("%NightReview")
	var world=fixture()
	ui.set_known_world(world.targets,world)
	install(c.settlement)
	for id in ["widow","fisher","craftsman"]:
		check(c.plan.put({"target_id":id,"behavior":"talk","scale":"personal","idea_id":""}).valid,"test plan accepted")
	var initial=ui.knowledge.get_snapshot()
	for repeat in range(12):
		main.get_node("%EndDayButton").pressed.emit()
	check(c.plan.is_locked() and ui.knowledge.get_snapshot()==initial,"rapid click locks without early effects")
	await process_frame
	check(calls.size()==8 and c.plan.is_resolved(),"one evaluation for rapid end clicks")
	check(main.state.get_day()==1 and main.state.get_slot()==2,"review stays on current night")
	check(review.report.sections.actions[0].action_index==0 and review.report.sections.actions[2].action_index==2,"action results follow plan, not adapter emission order")
	check(not JSON.stringify(review.report).contains("孙子秘密"),"undiscovered cause not in UI report")
	check(main.get_node("%AlertLabel").text.contains("已知测试警戒"),"committed known alert updates main UI")
	for frame in range(5):
		await process_frame
	var saved=ui.knowledge.get_snapshot()
	click(review.tabs[1])
	check(review.category==1,"real pointer changes section")
	click(review.following)
	check(review.page==1 and main.state.get_day()==1,"real pointer advances result only")
	for category in range(4):
		review.select_category(category)
		for repeat in range(6):
			review.change_page(1)
			review.change_page(-1)
	check(ui.knowledge.get_snapshot()==saved and main.state.get_day()==1 and calls.size()==8,"tabs and paging never mutate state")
	review.select_category(1)
	check(review.report.sections.people.size()==2 and review.report.sections.actions.size()==3,"autonomous reactions separate from player actions")
	for frame in range(3):
		await process_frame
	var bounds=Rect2(Vector2.ZERO,Vector2(root.size))
	for node in [review,review.next_day,review.tabs[3],main.get_node("%BottomPanel"),main.get_node("%DayLabel"),main.get_node("%PhaseLabel")]:
		check(bounds.encloses(node.get_global_rect()),"review bounds at requested resolution")
	check(main.get_node("%CenterPanel").get_global_rect().encloses(review.get_global_rect()),"review covers central region")
	if DisplayServer.get_name()!="headless" and "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://previews/stage5-night-review-%d.png"%root.size.x)
	for repeat in range(5):
		review.close_review()
		c._end_day()
		ui._show_notes()
	check(ui.narrative.journal.visible,"notes book opens read-only history")
	ui.narrative.journal.show_day(1)
	check(main.state.get_day()==1 and calls.size()==8 and ui.knowledge.get_snapshot()==saved,"history reopen cannot recalculate or advance")
	review.close_review()
	c._end_day()
	for repeat in range(10):
		c._next_day()
	check(main.state.get_day()==1 and c.plan.is_locked(),"morning work begins while planning still locked")
	await process_frame
	check(main.state.get_day()==1 and c.plan.is_locked() and review.report.message.contains("必须事件"),"missing mandatory event adapter blocks daytime")
	c.settlement.set_morning_adapter(morning)
	c.settlement.resume_morning(c.plan.request_id())
	await process_frame
	check(main.state.get_day()==2 and ui.knowledge.get_snapshot().test_morning_done and not c.plan.is_locked(),"apply mandatory events then open new day")
	check(morning_calls==1 and c.plan.remaining_ap()==3,"one morning, new AP budget")
	ui._show_notes()
	var day_one := ""
	for page in ui.narrative.journal.pages:
		if int(page.day) == 1:
			day_one = str(page.entries)
	check(day_one.contains("夜间回顾") and day_one.contains("1") and main.state.get_day()==2,"history date distinct from current date")
	review.close_review()
	main._restart()
	check(c.settlement.history().is_empty(),"restart clears current run history")
	check(ui.knowledge.get_snapshot()==initial,"restart restores run initial world")
	ui.set_development_preview(true)
	c.plan.put({"target_id":"ruins","behavior":"move","scale":"personal","idea_id":""})
	c.plan.put({"target_id":"child","behavior":"talk","scale":"personal","idea_id":"sea"})
	c._end_day()
	await process_frame
	check(c.plan.is_resolved() and review.report.preview_only,"existing preview adapter still resolves as preview")
	check(review.report.steps.size()==8 and review.report.steps[1].status=="unimplemented","preview missing systems clearly marked")
	check(review.report.sections.people.is_empty() and review.report.sections.world.is_empty() and review.report.sections.kingdom.is_empty(),"preview doesn't invent autonomous or world stories")
	check(ui.knowledge.current_location_id()=="ruins" and c.plan.local_belief("sea")=="渐强","preview move applied only at whole batch completion")
	for frame in range(4):
		await process_frame
	if DisplayServer.get_name()!="headless" and "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://previews/stage5-night-preview-%d.png"%root.size.x)
	main.queue_free()
	await process_frame

func click(control: Control):
	var motion=InputEventMouseMotion.new()
	motion.position=control.get_global_rect().get_center()
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event=InputEventMouseButton.new()
		event.position=motion.position
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		root.push_input(event,true)
