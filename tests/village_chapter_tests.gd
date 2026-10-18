extends SceneTree
const State := preload("res://scripts/story/village_state.gd")
const Save := preload("res://scripts/story/village_save.gd")
var checks := 0
var failures := 0
var scene
var file_path := "/tmp/village-test-%d.json" % OS.get_process_id()

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func act(s, id: String, args: Dictionary = {}) -> void:
	var dest := "ruins" if State.ACTIONS[id].group == "ruins" else "fishing_village"
	check(s.travel(dest),"Free travel for "+id)
	var before: Dictionary = s.to_data()
	var quote: Dictionary = s.preview(id,args)
	check(s.to_data() == before,"Preview is read only: "+id)
	check(quote.allowed,"Preview allows "+id+": "+quote.text)
	check(s.execute(id,args),"Execute "+id)

func route(days: Array):
	var s = State.new()
	for actions in days:
		for entry in actions:
			if entry is String: act(s,entry)
			else: act(s,entry[0],entry[1])
		check(s.end_day(),"End day")
	return s

func reject(s,id: String,args: Dictionary = {}) -> void:
	var before: Dictionary = s.to_data()
	check(not s.execute(id,args),"Reject "+id)
	check(before == s.to_data(),"Rejected action has no side effects")

func run() -> void:
	var base: Array = [["feed","listen","repair"],["family","survey"],["clear","search","identify"]]
	var safe = route(base+[["heirloom","waterline"],["public_material"],[["record",{"item":"H"}],["neighbor",{"item":"H_r"}]]])
	check(safe.finished and safe.spent==17 and safe.belief==70,"17 AP full protected route")
	check(safe.people.salt.a==45 and safe.snapshot.neighbor_valid and safe.owned("H") and safe.owned("F"),"Correct protected holders and alert")
	check(safe.snapshot.support_offers==["salt_intro","elder_origin"],"Two later assistance offers")
	check(safe.snapshot.chapter_progress.success,"Full route succeeds after verification and propagation")
	var short_route = route([["feed","listen","heirloom"],[],[],[],[],[]])
	check(short_route.finished and short_route.spent==3 and not short_route.snapshot.chapter_progress.success,"Three-AP heirloom route no longer succeeds")
	check(short_route.snapshot.chapter_progress.outcome=="unverified","Single diary is an unverified lead")
	var copied = route([["feed","listen","heirloom"],[["record",{"item":"H"}]],[],["public_salt"],[],[]])
	check(copied.belief==60 and not copied.snapshot.chapter_progress.verified and not copied.snapshot.chapter_progress.success,"Copy and 60 belief cannot replace verification")
	var water_success = route([["survey","clear","search"],["repair","identify"],["waterline"],["public_material"],[],[]])
	check(water_success.snapshot.chapter_progress.success,"Ship plus waterline and public statement succeeds without diary")
	var verified_only = route(base+[["heirloom"],[],[]])
	check(verified_only.snapshot.chapter_progress.outcome=="verified_only","Two sources without propagation do not succeed")
	var private_success = route(base+[["heirloom"],[["neighbor",{"item":"H"}]],[]])
	check(private_success.snapshot.chapter_progress.success and private_success.belief==10,"Valid private spread succeeds without public statement or belief threshold")
	check(not private_success.owned("H"),"Handing over original does not erase verification")
	check(State.new().run_id!=State.new().run_id,"New village runs have independent market identities")
	var legacy: Dictionary = private_success.to_data()
	legacy.erase("run_id")
	legacy.snapshot.erase("run_id")
	var legacy_state = State.new()
	check(legacy_state.restore(legacy) and legacy_state.snapshot.run_id==legacy_state.run_id,"Pre-market saves migrate without resetting progress")
	var old_save: Dictionary = private_success.to_data()
	old_save.snapshot.erase("chapter_progress")
	var resumed = State.new()
	check(resumed.restore(old_save) and resumed.snapshot.chapter_progress.success,"Old completed saves derive new outcome")
	var child = route([["feed","listen","hear"],["family","retrieve"],["clear","search","repair"],["identify","waterline"],["heirloom","public_material"],[["record",{"item":"H"}],["neighbor",{"item":"H_r"}]]])
	check(child.spent==18 and child.belief==70 and child.people.child.t==60,"Child alternative route")
	var modest = route([["feed","listen"],["family"],[],["heirloom",["record",{"item":"H"}]],["public_anonymous",["neighbor",{"item":"H_r"}]],[]])
	check(modest.spent==9 and modest.belief==50 and modest.people.salt.a==55 and modest.snapshot.neighbor_valid,"Anonymous protected spread is viable")
	var minimal = route([["survey","clear","search"],["repair","identify"],[],[],[],[]])
	check(minimal.spent==5 and minimal.owned("F") and minimal.finished,"5 AP single lead departure")
	var named = route(base+[["heirloom",["record",{"item":"H"}]],["public_salt"],[]])
	check(named.spent==13 and named.belief==60 and named.people.salt.reported and named.pending_penalty,"Naming and no remedy produces next-region penalty")
	var fixed = route(base+[["heirloom",["record",{"item":"H"}]],["public_salt"],[["apology",{"who":"salt"}]]])
	check(fixed.spent==14 and not fixed.people.salt.reported and fixed.people.salt.exposed,"Apology eases warning without erasing exposure")
	check(fixed.snapshot.support_offers==["elder_origin"],"No salt offer after apology")
	var elder = route([["survey","clear","search"],["repair","identify","tidy"],[],["public_elder"],[],[]])
	check(elder.people.elder.reported and elder.ap==2 and not elder.pending_penalty,"Report penalty consumed exactly on day6")
	var empty = route([[],[],[],[],[],[]])
	check(empty.finished and empty.sources().is_empty(),"Empty route can depart")
	var early = route([["feed","listen","heirloom"],["family"],[],["public_anonymous"],[],[]])
	check(early.people.salt.a==65 and not early.people.salt.reported,"High trust/high alert is not betrayal")
	var late = route([["survey","clear","search"],["repair","identify","tidy"],[],[],[]])
	late.entry_turn = 20
	act(late,"hear"); act(late,"retrieve")
	var q: Dictionary = late.preview("show",{"who":"salt","item":"F"})
	check(q.text.contains("无剩余行动") and q.text.contains("无法远程"),"Last AP warning exposes lack of remedy")
	act(late,"show",{"who":"salt","item":"F"})
	late.end_day()
	check(late.snapshot.warnings.salt==26 and not late.people.salt.reported,"Warning translated to global turn, not prematurely resolved")

	var s = State.new()
	reject(s,"family"); reject(s,"withdraw"); reject(s,"cancel_neighbor")
	act(s,"feed"); act(s,"listen"); reject(s,"family")
	check(s.ap==1 and s.food==1,"Failed 2 AP action does not consume food")
	var closed = route([[],[],[],[]])
	check(not closed.travel("ruins"),"No entrance after day4")
	closed.location = "ruins"
	reject(closed,"survey")
	check(closed.travel("fishing_village"),"Can leave closed ruins at zero travel cost")
	var stored = route(base+[["heirloom",["record",{"item":"H"}]]])
	act(stored,"store",{"who":"salt","items":["H","F"]})
	check(stored.ap==2 and stored.sources()==["H"],"Batch storage costs 1; only held record available")
	reject(stored,"record",{"item":"F"})
	act(stored,"neighbor",{"item":"H"})
	reject(stored,"take",{"item":"H"})
	act(stored,"take",{"item":"F"})
	check(stored.owned("F") and stored.items.H.holder=="salt","Storage take cannot cancel spread")
	act(stored,"public_salt")
	check(stored.spread.is_empty() and stored.owned("H"),"Permanent exposure returns materials immediately")
	var paused = route(base+[["heirloom",["record",{"item":"H"}]]])
	act(paused,"neighbor",{"item":"H_r"})
	act(paused,"show",{"who":"salt","item":"H"})
	check(paused.people.salt.a==60 and not paused.spread.is_empty(),"Temporary suspension keeps materials until settlement")
	paused.end_day(); paused.end_day()
	check(not paused.snapshot.chapter_progress.propagated,"Invalid private spread does not meet propagation goal")
	check(paused.owned("H_r") and paused.spread.is_empty() and paused.belief==0,"Invalid spread refunds material without belief")
	var once = route(base+[["heirloom","waterline"]])
	act(once,"public_material")
	reject(once,"public_salt")
	check(once.belief==60,"Only one public statement")
	var same = route(base+[["heirloom",["record",{"item":"H"}]]])
	act(same,"show",{"who":"child","item":"H"})
	reject(same,"show",{"who":"child","item":"H_r"})
	check(same.sources().size()==2,"Record doesn't multiply evidence sources")

	check(Save.save_to(file_path,safe)==OK,"Save completed chapter")
	var loaded := Save.load_from(file_path)
	check(loaded.ok and loaded.state.to_data()==safe.to_data(),"Save roundtrip")
	check(Save.save_to(file_path,modest)==OK,"Second save creates backup")
	var file := FileAccess.open(file_path,FileAccess.WRITE)
	file.store_string("broken"); file.close()
	loaded = Save.load_from(file_path)
	check(loaded.ok and loaded.get("backup",false) and loaded.state.belief==70,"Corrupt primary restores backup")
	check(not safe.restore({"day":1}),"Malformed data rejected")
	check(Save.save_to("/does-not-exist/village.json",safe)!=OK,"Save failure is reported")
	await ui_checks()
	print("VILLAGE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func settle_frames(count := 5) -> void:
	for i in range(count): await process_frame

func click(node: Control) -> void:
	check(node != null,"Pointer target exists")
	if node == null: return
	await settle_frames()
	var point := node.get_global_transform_with_canvas() * (node.size*0.5)
	var motion := InputEventMouseMotion.new(); motion.position=point; root.push_input(motion)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down
		root.push_input(event)
		await process_frame

func button(parent: Node,id: String):
	for child in parent.get_children():
		if child is Button and child.get_meta("action_id","")==id: return child
	return null

func finish_dialogue() -> void:
	var guard := 0
	while scene.busy() and guard < 30:
		var e := InputEventKey.new(); e.keycode=KEY_ENTER; e.pressed=true; root.push_input(e)
		await process_frame
		e = InputEventKey.new(); e.keycode=KEY_ENTER; e.pressed=false; root.push_input(e)
		await process_frame
		guard += 1
	check(not scene.busy(),"Return key advances and completes dialogue")

func capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshot"): return
	await settle_frames(12)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var path := "/tmp/village-%s-%d.png" % [name,root.size.x]
	check(root.get_texture().get_image().save_png(path)==OK,"Screenshot "+path)

func ui_checks() -> void:
	root.size = Vector2i(1920,1080) if OS.get_cmdline_user_args().has("--large") else Vector2i(1280,720)
	scene = load("res://scenes/trial1.tscn").instantiate()
	check(scene != null,"Trial1 scene instantiates")
	if scene == null: return
	scene.save_path = "/tmp/village-ui-%d.json" % OS.get_process_id()
	root.add_child(scene)
	await settle_frames(10)
	check(scene.busy(),"New game opens with tutorial")
	await finish_dialogue()
	var cards = scene.get_node("Design/CharacterRail/Cards").get_children()
	check(cards.size()==3,"Three existing character cards")
	await click(cards[0])
	check(scene.busy() and scene.get_node("Design/PortraitPanel").character=="盐嫂","Card click slides in matching portrait")
	await capture("portrait")
	await finish_dialogue()
	check(scene.state.ap==3,"Greeting is free")
	var before_options: Dictionary = scene.state.to_data()
	scene.state.day = 4
	scene.state.ap = 1
	scene.state.items["H"] = {"holder":"player"}
	scene.state.flags["listen"] = true
	scene.state.selected = ""
	scene._refresh()
	check(not button(scene.actions,"public").disabled and not button(scene.actions,"public").text.contains("不足"),"One-AP public version keeps public entry available")
	scene.state.restore(before_options)
	scene._refresh()
	check(scene.completed_button.visible and scene.completed_button.get_parent()==scene.get_node("Design"),"History is a fixed global control")
	check(button(scene.actions,"village")==null,"No redundant village return button")
	check(button(scene.actions,"heirloom").disabled,"Unavailable NPC action disabled")
	check(button(scene.actions,"show").disabled,"No evidence disables private show")
	check(button(scene.actions,"store")==null,"Storage moved out of NPC action list")
	await click(button(scene.actions,"heirloom"))
	check(not scene.overlay.visible and scene.state.ap==3,"Disabled action cannot open or spend")
	await click(scene.completed_button)
	check(scene.overlay.visible,"Global history opens (disabled=%s, hovered=%s)" % [scene.completed_button.disabled,root.gui_get_hovered_control()])
	scene.overlay.hide()
	await click(button(scene.actions,"feed"))
	check(scene.overlay.visible and scene.state.ap==3,"Action click previews before cost")
	check(scene.end_button.get_index() < scene.overlay.get_index(),"Modal layers above end-day button")
	check(not scene.end_button.get_global_rect().intersects(scene.get_node("Design/MiniMap/Upper").get_global_rect()),"End-day button does not cover minimap satellite")
	await capture("preview")
	await click(button(scene.overlay_actions,"execute"))
	check(scene.state.ap==2 and scene.busy(),"Confirmation settles before dialogue")
	var in_dialogue := Save.load_from(scene.save_path)
	check(in_dialogue.ok and not in_dialogue.state.presentation.is_empty() and in_dialogue.state.ap==2,"Paid dialogue saved with settled AP")
	var old_path: String = scene.save_path
	root.remove_child(scene); scene.queue_free(); await process_frame
	scene = load("res://scenes/trial1.tscn").instantiate()
	scene.save_path = old_path; root.add_child(scene); await settle_frames(8)
	check(scene.busy() and scene.state.ap==2,"Actual scene reload resumes settled dialogue")
	cards = scene.get_node("Design/CharacterRail/Cards").get_children()
	# Actual mouse on text box advances without a second deduction.
	await click(scene.get_node("Design/DialogueBox"))
	await finish_dialogue()
	check(scene.state.ap==2,"Reading result does not settle twice")
	await click(cards[1]); await finish_dialogue()
	check(scene.state.selected=="elder","Other character can be selected same day")
	await click(scene.get_node("Design/MiniMap/Compass")); await settle_frames()
	check(scene.map_modal.visible,"Existing map opens")
	await capture("map")
	await click(scene.map_modal.get_node("Panel/Map/Locations/ruins/Hit"))
	check(scene.state.location=="fishing_village","Preview does not move")
	await click(button(scene.overlay_actions,"enter_ruins"))
	check(scene.state.location=="ruins" and scene.state.ap==2 and not scene.get_node("Design/CharacterRail").visible,"Enter ruins preserves AP and hides village cards")
	await capture("ruins")
	scene._toolbar("map"); scene._map_place("market")
	check(button(scene.overlay_actions,"enter_market")==null,"Other regions remain previews")
	scene.overlay.hide()
	scene._toolbar("map"); scene._map_place("fishing_village")
	await click(button(scene.overlay_actions,"enter_fishing_village"))
	await click(scene.end_button)
	check(scene.overlay.visible and scene.state.day==1,"End day asks before discarding AP")
	await click(button(scene.overlay_actions,"confirm_day")); await finish_dialogue()
	check(scene.state.day==2 and scene.state.ap==3,"New day restores AP")
	await capture("village")
	# Full safe route through UI controller, including save/reload and final result.
	scene.state = State.new(); scene._refresh()
	var days: Array = [["feed","listen","repair"],["family","survey"],["clear","search","identify"],["heirloom","waterline"],["public_material"],[["record",{"item":"H"}],["neighbor",{"item":"H_r"}]]]
	for actions in days:
		for entry in actions:
			var id: String = entry if entry is String else entry[0]
			var args: Dictionary = {} if entry is String else entry[1]
			scene._travel("ruins" if State.ACTIONS[id].group=="ruins" else "fishing_village")
			scene._preview_action(id,args)
			await click(button(scene.overlay_actions,"execute"))
			await finish_dialogue()
		await click(scene.end_button)
		await click(button(scene.overlay_actions,"confirm_day"))
		await finish_dialogue()
	check(scene.state.finished and scene.state.belief==70 and scene.state.spent==17,"Complete playable safe route through UI")
	await click(button(scene.actions,"report"))
	await capture("report")
	check(scene.overlay.visible and scene.state.snapshot.neighbor_valid,"Departure report reachable")
	var bounds := Rect2(Vector2.ZERO,Vector2(root.size))
	for item in [scene.end_button,scene.get_node("Design/DialogueBox"),scene.get_node("Design/PortraitPanel"),scene.overlay_actions]:
		check(bounds.encloses(item.get_global_rect()),"UI bounds at %s: %s" % [root.size,item.name])
	scene.queue_free()
	await settle_frames()
