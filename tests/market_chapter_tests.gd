extends SceneTree
const S := preload("res://scripts/story/market_chapter_state.gd")
const Narrative := preload("res://scripts/story/market_chapter_story.gd")
const Save := preload("res://scripts/story/market_chapter_save.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func act(s, id: String, topic := "censorship") -> void:
	var before: Dictionary = s.to_data()
	var preview: Dictionary = s.preview(id,topic)
	check(s.to_data()==before,"Preview has no effects: "+id)
	check(preview.allowed,"Allowed "+id+" "+preview.text)
	check(s.execute(id,topic),"Execute "+id)
func route(days: Array, seed: Dictionary = {}):
	var s = S.new()
	s.initialize(seed)
	for actions in days:
		for entry in actions:
			if entry is String: act(s,entry)
			else: act(s,entry[0],entry[1])
		check(s.end_day(),"End day")
	return s
func reject(s,id: String,topic := "censorship") -> void:
	var before: Dictionary = s.to_data()
	check(not s.execute(id,topic),"Reject "+id)
	check(before==s.to_data(),"Rejected action unchanged")
func run() -> void:
	var safe = route([["dao_help","text","ban"],["text_verify","protect","small"],["xiang_help","contacts","private"],[]])
	check(safe.success() and safe.spent==9 and safe.achievements().readers_discussing and safe.belief==10,"9 AP safe route raises belief from verified censorship")
	check(not safe.print_closed and safe.snapshot.contacts_available,"Safe channels retained")
	var manual = route([["qian_help","cargo","seizure"],["goods_verify","self_copy"],["manual"],[]])
	check(manual.success() and manual.spent==8 and manual.deliveries[0].reach=="small","8 AP independent goods route, no printer or inn required")
	var rush = route([["dao_help","text","ban"],["text_verify","rush"],[],["answer"]])
	check(rush.success() and rush.spent==8 and rush.print_closed and rush.achievements().public_discussion,"8 AP rush reaches wider audience but loses print shop")
	var preserved = route([["dao_help","text","ban"],["text_verify","rush"],["move","repair_dao"],["answer"]])
	check(preserved.success() and preserved.spent==11 and not preserved.print_closed and preserved.snapshot.print_available,"11 AP protects risky print route")
	var unpaid_response = route([["dao_help","text","ban"],["text_verify","rush"],[],[]])
	check(not unpaid_response.success() and not unpaid_response.achievements().readers_discussing,"Unanswered public claim is not accepted propagation")
	var queued = route([["qian_help","cargo","seizure"],["goods_verify","self_copy"],["caravan"],[]])
	check(not queued.success() and queued.pending[0].status=="dispatched" and queued.pending[0].arrival_turn==11,"Shipping is not arrival or chapter success")
	var stolen = route([["dao_help","text","ban"],["text_verify","small"],[],[]])
	check(stolen.print_closed and stolen.packets.censorship.count==0,"Exposed print stock confiscated")
	var stock = route([["dao_help","text","ban"],["text_verify","small"],["move"],["manual"]])
	check(stock.success() and not stock.print_closed,"Moving preserves stock for later delivery")
	var betrayal = route([["quick_cargo","seizure","goods_verify"],[],[],[]])
	check(betrayal.people.qian.reported and betrayal.events.is_empty(),"Risky cargo can cause Qian betrayal")
	var rescue = route([["quick_cargo","qian_help","reassure_qian"],["seizure","goods_verify"],[],[]])
	check(not rescue.people.qian.reported and rescue.people.qian.t==60,"Qian prewarning has a paid remedy")
	var inherited = S.new()
	inherited.initialize({"support_offers":["salt_intro","elder_origin"],"evidence":{"F":{"holder":"player"}},"market_entry_turn":20})
	act(inherited,"xiang_help")
	act(inherited,"qian_help")
	act(inherited,"cargo")
	check(inherited.ap==2 and inherited.origin.support_consumed.size()==2,"Inherited offers waive exactly two appropriate AP")
	reject(inherited,"cargo")
	act(inherited,"sea_verify")
	check(inherited.verified("sea") and not inherited.verified("censorship"),"Sea claim separate from censorship proof")
	var dual = route([["qian_help","cargo","seizure","goods_verify"],["sea_verify","dao_help","protect"],["small","xiang_help","contacts","private"],[]],{"support_offers":["salt_intro","elder_origin"],"evidence":{"F":{"holder":"player"}}})
	check(dual.success() and dual.spent==9 and dual.belief==25 and dual.achievements().readers_discussing,"Inherited evidence strengthens unified propagation")
	var left_behind = S.new()
	left_behind.initialize({"support_offers":["elder_origin"],"evidence":{"F":{"holder":"elder"}}})
	check(left_behind.cost("cargo")==1 and not left_behind.has_village_evidence(),"Stored originals not teleported to market")
	var penalty = S.new()
	penalty.initialize({"pending_penalty":true,"warnings":{"salt":7}})
	check(penalty.ap==2,"Immediate village penalty carried")
	penalty.end_day()
	check(penalty.ap==3,"Same origin penalty not repeated")
	var late = S.new()
	late.initialize({"warnings":{"salt":7}})
	late.end_day()
	check(late.day==2 and late.ap==2,"Absolute unresolved warning triggers next turn penalty")
	var already_paid = S.new()
	already_paid.initialize({"penalty_used":true,"warnings":{"salt":7}})
	already_paid.end_day()
	check(already_paid.ap==3,"Consumed village origin penalty never repeats")
	var inn = S.new()
	inn.initialize({})
	inn.day=3; inn.exposed=true; inn.flags.contacts=true
	inn.people.xiang.t=60; inn.people.xiang.a=35
	inn.end_day()
	check(not inn.cooperative("xiang") and not inn.people.xiang.reported,"Inn closes at patrol pressure without betrayal")
	act(inn,"xiang_help")
	act(inn,"reassure_xiang")
	check(inn.cooperative("xiang"),"Identity protection restores inn channel")
	var returned = route([["qian_help","cargo","seizure"],["goods_verify","self_copy"],["caravan"]])
	returned.people.qian.a=60
	returned.end_day()
	check(returned.pending[0].status=="returned" and returned.packets.censorship.count==1,"Failed departure check returns shipping material")
	var late_qian = route([[],[],[],["quick_cargo"]])
	check(late_qian.snapshot.warnings.qian==11 and not late_qian.people.qian.reported,"Late market warning exported without early betrayal")
	var invalid_packet: Dictionary = safe.to_data()
	invalid_packet.packets={"censorship":{"count":2,"stock":[]}}
	check(not S.new().restore(invalid_packet),"Inconsistent stock save rejected")
	var direct = S.new()
	direct.initialize({})
	reject(direct,"small")
	reject(direct,"rush")
	check(direct.restore({})==false,"Malformed data rejected")
	var path := "/tmp/market-state-%d.json" % OS.get_process_id()
	check(Save.save_to(path,safe)==OK,"Save complete chapter")
	var loaded := Save.load_from(path)
	check(loaded.ok and loaded.state.to_data()==safe.to_data(),"Exact save round trip")
	check(Save.save_to(path,manual)==OK,"Backup previous save")
	var f := FileAccess.open(path,FileAccess.WRITE)
	f.store_string("broken"); f.close()
	loaded = Save.load_from(path)
	check(loaded.ok and loaded.get("backup",false) and loaded.state.spent==9,"Corrupt main recovers backup")
	var story_state = S.new()
	story_state.initialize({})
	var story_before: Dictionary = story_state.to_data()
	check(Narrative.overview(story_state).contains("为什么来集市"),"Existing saves can review story motivation")
	Narrative.opening(story_state)
	Narrative.greeting(story_state,"xiang")
	check(story_state.to_data()==story_before,"Narrative and guidance never spend or reveal findings")
	story_state.flags.seizure=true
	check(Narrative.stage(story_state).next.contains("原货单"),"Record-first route points to missing evidence")
	story_state.flags.cargo=true
	check(Narrative.stage(story_state).next.contains("核对货号"),"Collected records still require verification")
	story_state.flags.goods_verify=true
	check(Narrative.stage(story_state).next.contains("传播方式"),"Verified route moves to dissemination rather than second investigation")
	story_state.public_waiting=["censorship"]
	check(Narrative.stage(story_state).next.contains("2 AP"),"Unanswered public claims retain clear next step")
	story_state.public_waiting=[]
	story_state.pending=[{"topic":"censorship","status":"waiting"}]
	check(Narrative.stage(story_state).next.contains("还未送达"),"Shipment does not trigger success narrative")
	story_state.print_closed=true
	check(Narrative.stage(story_state).next.contains("自行抄写"),"Closed printer guidance points to independent option")
	story_state.print_closed=false
	story_state.deliveries=[{"topic":"censorship","channel":"private","reach":"targeted","outcome":"readers_discussing"}]
	check(Narrative.stage(story_state).next.contains("基本目标已完成"),"Delivered verified finding leads to optional aftermath")
	check(not safe.to_data().has("openness") and not safe.snapshot.has("openness_local"),"Retired score absent from live state and snapshot")
	check(safe.deliveries[0].gain==10 and queued.pending[0].gain==10,"Unified deliveries and future shipments carry explicit belief rewards")
	check(not queued.achievements().readers_discussing,"Pending caravan is not an achieved discussion")
	check(rush.achievements().readers_discussing and rush.achievements().public_discussion and not rush.achievements().independent_channels.has("print"),"Closure removes channel but preserves real discussion")
	var old_data: Dictionary = safe.to_data()
	old_data.flags.erase("unified_belief_v3")
	old_data["belief"]=0
	old_data["openness"]=20
	old_data.snapshot.erase("achievements")
	old_data.snapshot["openness_local"]=20
	old_data.deliveries[0].erase("reach")
	old_data.deliveries[0].erase("outcome")
	old_data.deliveries[0]["gain"]=20
	old_data.snapshot.deliveries=old_data.deliveries.duplicate(true)
	old_data.presentation={"lines":[{"speaker":"","text":"实际传播1次；集市海洋认知0，对查禁制度的质疑20。两种影响分别保留。"}],"index":0,"kind":"departure","portrait":""}
	var legacy_path := path+".legacy"
	var payload := JSON.stringify(old_data)
	var legacy_file := FileAccess.open(legacy_path,FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify({"game":S.RULESET,"version":1,"payload":payload,"checksum":payload.sha256_text()})); legacy_file.close()
	var migrated := Save.load_from(legacy_path)
	check(migrated.ok and migrated.state.ap==safe.ap and migrated.state.belief==safe.belief and migrated.state.spent==safe.spent,"Legacy file migration preserves AP, belief and settlements")
	check(migrated.state.snapshot.achievements.readers_discussing and not migrated.state.snapshot.has("openness_local"),"Legacy achievements reconstructed from actual deliveries")
	check(migrated.state.presentation.index==0 and not migrated.state.presentation.lines[0].text.contains("质疑20"),"Saved dialogue wording updates without replaying action")
	check(Save.save_to(legacy_path,migrated.state)==OK and Save.load_from(legacy_path).state.to_data()==migrated.state.to_data(),"Migrated save roundtrip remains stable")
	var scalar_only: Dictionary = S.new().to_data()
	scalar_only["openness"]=100
	var no_facts = S.new()
	check(no_facts.restore(scalar_only) and not no_facts.achievements().readers_discussing and no_facts.belief==0,"Legacy scalar alone creates neither sea belief nor fictional achievements")
	check(safe.handoff_rewards().inn_introduction.status=="ready","Private route retains conditional introduction")
	check(manual.handoff_rewards().has("reader_contact") and not manual.handoff_rewards().has("public_record"),"Manual reward is distinct")
	check(rush.handoff_rewards().has("public_record") and not unpaid_response.handoff_rewards().has("public_record"),"Public reward requires actual answers")
	check(queued.handoff_rewards()["advance_reading:censorship"].status=="in_transit","Caravan reward awaits arrival")
	check(rush.consequence("rush","censorship").contains("总计4 AP"),"Full public cost announced")
	var late_print = route([["dao_help","text","ban"],["text_verify"],[],["small","manual"]])
	check(late_print.success() and late_print.late_print_risk() and not late_print.snapshot.print_available,"Late printing preserves delivery but suspends future channel")
	check(late_print.snapshot.channel_risks.print.reason=="late_exposure" and not late_print.print_closed,"Late risk exported without invented inspection")
	var late_move = route([["dao_help","text","ban"],["text_verify"],[],["small","move"]])
	check(not late_move.late_print_risk() and late_move.snapshot.print_available,"Unused move can resolve late address exposure")
	var late_safe = route([["dao_help","text","ban"],["text_verify","protect"],[],["small","manual"]])
	check(not late_safe.late_print_risk() and late_safe.snapshot.print_available,"Prior anonymity protects day four printing")
	var exposed_then_protected = route([["dao_help","text","ban"],["text_verify"],[],["small","protect"]])
	check(exposed_then_protected.late_print_risk(),"Protecting future print does not erase an exposed address")
	var new_address = route([["dao_help","text","ban"],["text_verify","rush"],["move","repair_dao"],["small","manual"]])
	check(new_address.late_print_risk() and not new_address.snapshot.print_available and new_address.snapshot.channel_risks.print.address=="new","Printing after earlier transfer can expose the new address")
	var suspended = S.new()
	check(suspended.restore(safe.to_data()),"Restore delivered inn route")
	suspended.people.xiang.a=60
	check(suspended.handoff_rewards().inn_introduction.status=="suspended" and suspended.success(),"Lost cooperation suspends introduction without withdrawing past delivery")
	var legacy_late: Dictionary = late_print.to_data()
	legacy_late.flags.erase("handoff_rules_v2")
	legacy_late.flags.erase("late_print_exposure")
	var recovered = S.new()
	check(recovered.restore(legacy_late) and recovered.late_print_risk() and recovered.spent==late_print.spent,"Legacy action history reconstructs late risk without charging AP")
	var upgraded = route([["qian_help","cargo","seizure"],["goods_verify","self_copy"],["manual","sea_verify"]],{"evidence":{"F":{"holder":"player"}}})
	check(upgraded.belief==5 and upgraded.evidence_tier()==3,"Later verification does not automatically inform prior audience")
	act(upgraded,"supplement_manual")
	check(upgraded.belief==15 and upgraded.deliveries.size()==1 and upgraded.ap==2,"Supplement charges one AP and only pays ten point difference")
	reject(upgraded,"supplement_manual")
	reject(upgraded,"manual","sea")
	var roundtrip = S.new()
	check(roundtrip.restore(upgraded.to_data()) and roundtrip.to_data()==upgraded.to_data(),"Supplement state reload cannot repay difference")
	var both = route([["dao_help","text","ban"],["text_verify","qian_help","cargo"],["seizure","goods_verify","protect"],["small","manual"]])
	check(both.success() and both.belief==10,"Real dual-investigation route gives ten for walking")
	for tier in [1,2,3]:
		var sample = S.new()
		sample.initialize({"evidence":{"F":{"holder":"player"}}})
		sample.flags.goods_verify=true
		if tier>=2: sample.flags.text_verify=true
		if tier==3: sample.flags.sea_verify=true
		for channel in ["manual","private","public"]:
			var amount: int = {"manual":[5,10,15],"private":[10,15,25],"public":[20,25,35]}[channel][tier-1]
			check(sample.reward(channel)==amount,"Reward table "+channel+str(tier))
			sample.arrive("censorship",channel,0)
			var earned: int = sample.belief
			sample.arrive("sea",channel,0)
			check(sample.belief==earned,"Repeated delivery alias cannot duplicate reward")
	var legacy_topics: Dictionary = safe.to_data()
	legacy_topics.flags.erase("unified_belief_v3")
	legacy_topics.flags["private:sea"]=true
	legacy_topics.flags.sea_verify=true
	legacy_topics.deliveries.append({"topic":"sea","channel":"private","day":4,"reach":"targeted","gain":20})
	legacy_topics.belief=20
	var legacy_joined = S.new()
	check(legacy_joined.restore(legacy_topics) and legacy_joined.belief==25 and legacy_joined.deliveries.size()==1,"Legacy topics merge by audience and receive unified entitlement")
	var joined_again = S.new()
	check(joined_again.restore(legacy_joined.to_data()) and joined_again.belief==25,"Migration runs once")
	var cargo_only = S.new()
	cargo_only.initialize({"evidence":{"F":{"holder":"player"}}})
	cargo_only.flags.sea_verify=true
	check(cargo_only.evidence_tier()==0 and not cargo_only.preview("self_copy").allowed,"Village evidence alone does not bypass market investigation")
	var old_waiting: Dictionary = S.new().to_data()
	old_waiting.flags.erase("unified_belief_v3")
	old_waiting.flags["rush:sea"]=true
	old_waiting.public_waiting=["sea"]
	old_waiting.packets={"sea":{"count":1,"stock":["player"]}}
	var waiting = S.new()
	check(waiting.restore(old_waiting) and waiting.packets.censorship.count==1,"Legacy carried sea packet merges without loss")
	act(waiting,"answer")
	check(waiting.belief==35 and not waiting.success(),"Legacy pending public promise pays once without inventing restriction investigation")
	reject(waiting,"answer","sea")
	await ui_checks()
	print("MARKET: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

var scene
func frames(count := 5) -> void:
	for i in count: await process_frame
func button(parent: Node,id: String):
	for child in parent.get_children():
		if child is Button and child.get_meta("action_id","")==id: return child
	return null
func click(node: Control) -> void:
	check(node!=null,"Clickable control exists")
	if node==null: return
	await frames()
	await create_timer(0.12).timeout
	var point := node.get_global_transform_with_canvas()*(node.size*0.5)
	var motion := InputEventMouseMotion.new(); motion.position=point; root.push_input(motion)
	await frames(2)
	await create_timer(0.08).timeout
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down
		root.push_input(event)
		await process_frame
# Full-route checks activate the actual buttons without depending on OS pointer focus.
# The initial UI smoke checks above still exercise viewport mouse input.
func activate(node: Button) -> void:
	check(node!=null,"Scenario button exists")
	if node==null: return
	await frames()
	check(not node.disabled,"Scenario button enabled")
	if not node.disabled: node.pressed.emit()
	await frames()

func finish_dialogue() -> void:
	var limit := 0
	while scene.busy() and limit<40:
		var event := InputEventKey.new(); event.keycode=KEY_ENTER; event.pressed=true
		root.push_input(event)
		await frames(2)
		limit += 1
	check(not scene.busy(),"Enter completes dialogue")
func capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshot") or DisplayServer.get_name()=="headless": return
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/market-%s-%d.png" % [label,root.size.x])
func ui_checks() -> void:
	root.size = Vector2i(1920,1080) if OS.get_cmdline_user_args().has("--large") else Vector2i(1280,720)
	# Entry is exercised from the real finished village scene.
	var village = load("res://scenes/trial1.tscn").instantiate()
	village.save_path = "/tmp/market-ui-%d.json" % OS.get_process_id()
	root.add_child(village)
	village.state.presentation = {}
	while not village.state.finished: village.state.end_day()
	village._refresh()
	check(button(village.actions,"market")!=null,"Departure has a direct market entry")
	village._map_place("market")
	await click(button(village.overlay_actions,"enter_market"))
	await frames()
	for child in root.get_children():
		if child.get_script()==load("res://scripts/ui/market_chapter.gd"): scene=child
	check(scene!=null,"Village handoff loads market scene")
	if scene==null: return
	check(scene.state.entry_turn==7 and scene.state.origin.has("evidence"),"Actual village snapshot inherited")
	await finish_dialogue()
	check(scene.state.ap==3,"Intro free")
	var cards = scene.get_node("Design/CharacterRail/Cards").get_children()
	check(cards.size()==3,"Market NPC cards retained")
	await click(cards[2]); await finish_dialogue()
	check(scene.state.selected=="dao","Card selects printer")
	await capture("npc")
	scene._toolbar("journal")
	check(scene.overlay.visible,"Story recap accessible from investigation toolbar")
	await capture("story")
	scene.overlay.hide()
	await click(button(scene.actions,"dao_help:censorship"))
	check(scene.overlay.visible and scene.state.ap==3,"Preview does not spend")
	await capture("preview")
	await click(button(scene.overlay_actions,"execute"))
	check(scene.state.ap==2 and scene.busy(),"Confirmed action settled before dialogue")
	var saved_path: String = scene.save_path
	var seed: Dictionary = scene.village_snapshot
	scene.queue_free(); await frames()
	scene = load("res://scenes/market_chapter.tscn").instantiate()
	scene.save_path=saved_path; scene.village_snapshot=seed; root.add_child(scene)
	await frames()
	check(scene.state.ap==2 and scene.busy(),"Paid dialogue reload preserves AP and position")
	await finish_dialogue()
	await click(scene.get_node("Design/MiniMap/Compass"))
	check(scene.map_modal.visible,"Original minimap opens")
	await capture("map")
	scene.map_modal.hide()
	scene._map_place("market")
	await click(button(scene.overlay_actions,"enter_market"))
	check(scene.state.selected.is_empty() and scene.state.ap==2,"Map returns to free investigation")
	# Execute a full scenario through the confirmation UI and normal day transitions.
	scene.state=S.new(); scene.state.initialize({}); scene._refresh()
	var days := [["dao_help","text","ban"],["text_verify","protect","small"],["xiang_help","contacts","private"],[]]
	for actions in days:
		for id in actions:
			scene._market_preview(id,"censorship")
			if id in ["goods_verify","text_verify"]:
				await capture("comparison")
				var before_compare: Dictionary = scene.state.to_data()
				await activate(button(scene.overlay_actions,"compare_retry"))
				check(scene.state.to_data()==before_compare,"Wrong comparison is free and does not reveal verified finding")
				await activate(button(scene.overlay_actions,"compare_correct"))
				check(scene.state.to_data()==before_compare,"Correct comparison still awaits paid confirmation")
			await activate(button(scene.overlay_actions,"execute"))
			check(scene.state.flags.has(scene.state.key_for(id,"censorship")),"UI action confirmed: "+id)
			await finish_dialogue()
		await activate(scene.end_button)
		check(scene.overlay.visible,"End day confirmation")
		await activate(button(scene.overlay_actions,"confirm_day"))
		await finish_dialogue()
	check(scene.state.finished and scene.state.success(),"Full four day UI route succeeds")
	await activate(button(scene.actions,"report"))
	check(scene.overlay.visible,"Report opens")
	await capture("report")
	check(scene.overlay_actions.get_global_rect().end.y<=root.size.y,"Report controls within viewport")
	scene.overlay.hide()
	scene.state=S.new(); scene.state.initialize({})
	scene.state.flags.goods_verify=true
	scene.state.flags.sea_verify=true
	scene.state.flags.contacts=true
	scene.state.people.xiang.t=60
	scene.state.packets={"censorship":{"count":1,"stock":["player"]}}
	scene.state.selected="xiang"
	scene._refresh()
	check(button(scene.actions,"private:sea")==null and button(scene.actions,"private:censorship")!=null,"Only one unified propagation choice is visible")
	scene._market_preview("private","censorship")
	await capture("unified-reward")
	await activate(button(scene.overlay_actions,"execute"))
	await finish_dialogue()
	check(scene.state.belief==25,"Unified UI delivery pays enhanced reward")
	scene.queue_free(); await frames()
