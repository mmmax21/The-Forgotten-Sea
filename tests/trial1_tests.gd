<<<<<<< HEAD
extends SceneTree
const Dialogue := preload("res://scripts/story/trial1_dialogue.gd")
const State := preload("res://scripts/story/trial1_state.gd")
var failures := 0
var checks := 0
var checkpoint: String
var scene

func _initialize() -> void:
	checkpoint = "/tmp/trial1-test-%d.json" % OS.get_process_id()
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func play_route(choices: String):
	var model = State.new()
	for id in choices:
		check(model.begin(id), "Route choice allowed: %d %s" % [model.round_number, id])
		check(model.settle(), "Route settles")
		if model.phase == "ending":
			break
		if model.can_generic("notes"):
			model.generic("notes")
		elif model.can_generic("careful"):
			model.generic("careful")
		model.next_round()
	return model

func click(node: Control) -> void:
	# Font wrapping and container layout settle asynchronously with real rendering.
	for i in range(10):
		await process_frame
	var point := node.get_global_transform_with_canvas() * (node.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
		await process_frame

func action(id: String) -> Button:
	for button in scene.actions.get_children():
		if button.get_meta("action_id") == id:
			return button
	if scene.event_modal != null:
		var row: Node = scene.event_modal.get_node_or_null("Panel/CardRow")
		if row != null:
			for button in row.get_children():
				if button.get_meta("action_id") == id:
					return button
	return null

func run() -> void:
	var model = State.new()
	check(model.data.events.size() == 15, "15 events")
	for entry in model.data.events:
		check(entry.options.size() == 3 and not str(entry.intro).is_empty(), "Complete event intro and options")
		for choice in entry.options:
			check(not str(choice.text).is_empty(), "Every option has result dialogue")
			for key in choice.evidence + choice.clues:
				check(model.data.evidence.has(key), "Evidence reference exists")
	check(not model.next_round() and not model.generic("careful"), "Cannot skip event or take generic first")
	check(model.begin("A") and not model.begin("B"), "One choice only")
	check(model.ap == 3 and model.faith == 0, "Result is not charged before read")
	check(model.save_to(checkpoint) == OK, "Save pending result")
	var restored = State.new()
	check(restored.load_from(checkpoint) and restored.phase == "result" and restored.pending == "A", "Restore pending choice")
	check(restored.settle() and not restored.settle(), "Settle exactly once")
	check(restored.faith == 2 and restored.ap == 1 and restored.alert == 1, "Correct first option effect")
	check(restored.registered().is_empty() and restored.turn_clues == ["shell"], "Spreading shell only yields clue")
	check(restored.generic("notes") and not restored.generic("careful"), "Only one generic action")
	check(restored.evidence.shell and restored.categories().size() == 1, "Notes register shell")
	restored.save_to(checkpoint)
	model = State.new()
	check(model.load_from(checkpoint) and model.generic_used and model.evidence.shell, "Restore aftermath without duplicate generic")
	check(model.next_round() and model.ap == 3 and model.round_number == 2, "Next round resets exactly 3 AP")
	model.begin("B")
	model.settle()
	check(model.categories().size() == 3, "Song and blueprint are distinct categories")
	model.evidence.copper = true
	check(model.categories().size() == 3, "Second physical evidence doesn't inflate class count")
	model.round_number = 15
	model.phase = "ready"
	model.ap = 3
	check(not model.blocked_reason("A").is_empty(), "Final public requires two regions")
	model.evidence.antique = true
	check(model.blocked_reason("A").is_empty(), "Final unlocks with three classes across two regions")
	for turn in [7, 8, 10]:
		model = State.new()
		model.round_number = turn
		model.evidence.shell = true
		var id := "B" if turn == 8 else "A"
		model.alert = 13
		check(model.blocked_reason(id).is_empty(), "Hidden route open below 14")
		model.alert = 14
		check(not model.blocked_reason(id).is_empty(), "Hidden route closes at 14")
		model.alert = 13
		check(model.blocked_reason(id).is_empty(), "Hidden route reopens below 14")
	model = State.new()
	model.alert = 17
	model.begin("A")
	model.settle()
	check(model.ending == "forgotten" and model.phase == "ending" and model.ap == 1, "18 immediately ends even with AP remaining")
	check(not model.generic("careful") and not model.next_round() and not model.begin("C"), "No recovery after forgetting")
	model.save_to(checkpoint)
	restored = State.new()
	check(restored.load_from(checkpoint) and restored.ending == "forgotten", "Ending persists")
	model = State.new()
	model.begin("C")
	model.settle()
	model.generic("careful")
	check(model.alert == 0 and model.evidence.is_empty(), "Zero alert floor, discarded shell not recoverable")
	model = State.new()
	model.round_number = 5
	model.flags = ["salt_hurt"]
	check(model.option("B").cost == 2, "Apology changes fifth round cost")
	model.begin("B")
	model.settle()
	check(model.evidence.copper and model.evidence.chart and model.npc["盐嫂"] == "愿意协助", "Apology recovers relics")
	model = State.new()
	model.round_number = 5
	model.evidence = {"shell": true, "song": true}
	model.flags = ["salt_help", "children", "public_tide"]
	check(model.option("A").f == 4 and model.option("A").a == 1, "Tide and Salt bonuses reflected before choice")
	model.begin("A")
	model.settle()
	check(model.flags.has("salt_help_used") and model.faith == 4 and model.alert == 1, "Help consumed once")
	# Every configured option can settle under its stated prerequisites.
	for turn in range(1, 16):
		for id in ["A", "B", "C"]:
			model = State.new()
			model.round_number = turn
			for key in model.data.evidence:
				model.evidence[key] = true
			check(model.begin(id) and model.settle(), "Executable option %d %s" % [turn, id])
			check(model.ap >= 0 and model.ap <= 3, "Valid AP")
			for name in model.npc:
				check(model.npc[name] in State.NPC_STATES, "Canonical NPC state")
	var liberation = play_route("BBBBBBBBBBBBBBB")
	check(liberation.ending == "liberation" and liberation.faith == 18, "Cautious route reaches liberation F18")
	var sea = play_route("BBABABBBBBBBBBB")
	check(sea.ending == "sea" and sea.faith == 21, "Mixed route reaches sea F21")
	var forgotten = play_route("CCCCCCCCCCCCCCC")
	check(forgotten.ending == "forgotten" and forgotten.ending_cause == "final", "Avoidance reaches slow forgetting")
	var exposed = State.new()
	while exposed.phase != "ending":
		var id := "A" if exposed.blocked_reason("A").is_empty() else "B"
		check(exposed.begin(id) and exposed.settle(), "High exposure route advances")
		if exposed.phase != "ending":
			if exposed.round_number == 1:
				exposed.generic("notes")
			exposed.next_round()
	check(exposed.ending == "forgotten" and exposed.ending_cause == "alert" and exposed.round_number < 15, "Natural route reaches immediate forgetting before finale")
	# Threshold and priority boundaries.
	for triple in [[40, 18, "forgotten"], [20, 17, "sea"], [19, 10, "liberation"], [12, 10, "liberation"], [19, 11, "forgotten"], [11, 0, "forgotten"]]:
		model = State.new()
		model.round_number = 15
		model.phase = "aftermath"
		model.faith = triple[0]
		model.alert = triple[1]
		model.next_round()
		check(model.ending == triple[2], "Final boundary " + str(triple))
	# Conditional scripts never introduce absent evidence or skip the apology branch.
	var script = Dialogue.new()
	check(script.script_data.rounds.size() == 5, "Only first five rounds expanded")
	model = State.new()
	model.round_number = 2
	check(not JSON.stringify(script.lines_for(model, "opening")).contains("你翻开贝壳那一页"), "No shell without registered evidence")
	model.evidence.shell = true
	check(JSON.stringify(script.lines_for(model, "opening")).contains("你翻开贝壳那一页"), "Registered shell changes opening")
	model.round_number = 5
	model.evidence = {"copper": true, "chart": true}
	var public_lines := JSON.stringify(script.lines_for(model, "A"))
	check(not public_lines.contains("这是在河滩发现的贝壳") and not public_lines.contains("船棚里还留下这几句"), "Gathering displays only owned evidence")
	model.flags = ["salt_hurt"]
	check(JSON.stringify(script.lines_for(model, "B")).contains("上次在你家"), "Apology script selected")
	model.round_number = 4
	model.pending = "A"
	check(JSON.stringify(script.lines_for(model, "closing")).contains("我会把昨晚记的水位带去"), "Closing before settlement resolves choice")
	model.pending = ""
	model.history = [{"round": 4, "choice": "C"}]
	check(not JSON.stringify(script.lines_for(model, "closing")).contains("我会把昨晚记的水位带去"), "Closing after settlement resolves historical choice")
	# v1 saves remain readable, presentation is initialized by the scene.
	var old_save: Dictionary = model.snapshot()
	old_save.version = 1
	old_save.erase("presentation")
	var file := FileAccess.open(checkpoint + ".legacy", FileAccess.WRITE)
	file.store_string(JSON.stringify(old_save))
	file.close()
	restored = State.new()
	check(restored.load_from(checkpoint + ".legacy") and restored.presentation.is_empty(), "Legacy save migration")
	# Actual scene and pointer input at small / large window sizes.
	scene = load("res://scenes/trial1.tscn").instantiate()
	scene.save_path = checkpoint + ".ui"
	root.add_child(scene)
	current_scene = scene
	root.size = Vector2i(1920, 1080) if OS.get_cmdline_user_args().has("--large") else Vector2i(1280, 720)
	for i in range(8):
		await process_frame
	check(scene.stage() == "idle" and action("A") == null, "No choices until actor conversation")
	scene._choose("B")
	check(scene.state.phase == "ready" and scene.state.ap == 3, "Cannot bypass opening")
	await click(scene.get_node("Design/CharacterRail/Cards").get_child(0))
	check(scene.stage() == "opening" and scene.get_node("Design/PortraitPanel").character == "螺螺", "Card click shows character and opens dialogue")
	check(scene.get_node("Design/PortraitPanel/Image").texture != null, "Existing fullbody portrait used")
	await click(scene.get_node("Design/DialogueBox/Text"))
	check(int(scene.state.presentation.index) == 1, "Text click advances a single segment")
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	root.push_input(key)
	await process_frame
	check(int(scene.state.presentation.index) == 2, "Enter advances dialogue")
	key.pressed = false
	root.push_input(key)
	var cursor := int(scene.state.presentation.index)
	var shown: String = scene.get_node("Design/DialogueBox").dialogue_text
	scene._toolbar("map")
	scene._on_character_selected(0, "螺螺", "", null)
	check(not scene.map_modal.visible and int(scene.state.presentation.index) == cursor, "Dialogue locks map and repeated actor selection")
	await reload_ui()
	check(scene.stage() == "opening" and int(scene.state.presentation.index) == cursor and scene.get_node("Design/DialogueBox").dialogue_text == shown, "Actual scene reload resumes same opening line")
	finish_sequence()
	check(scene.stage() == "choices" and action("A") != null, "Choices appear after full opening")
	await click(action("B"))
	check(scene.stage() == "result" and scene.state.phase == "result" and scene.state.ap == 3, "Branch starts without early settlement")
	await click(scene.get_node("Design/DialogueBox/Text"))
	shown = scene.get_node("Design/DialogueBox").dialogue_text
	await reload_ui()
	check(scene.stage() == "result" and scene.get_node("Design/DialogueBox").dialogue_text == shown and scene.state.ap == 3, "Branch resumes uncharged at same sentence")
	finish_sequence()
	check(scene.stage() == "closing" and scene.state.faith == 1 and scene.state.ap == 2 and scene.state.history.size() == 1, "Only branch completion settles")
	await click(scene.get_node("Design/DialogueBox/Text"))
	shown = scene.get_node("Design/DialogueBox").dialogue_text
	await reload_ui()
	check(scene.stage() == "closing" and scene.get_node("Design/DialogueBox").dialogue_text == shown and scene.state.history.size() == 1, "Closing resumes without duplicate settlement")
	finish_sequence()
	check(scene.stage() == "aftermath" and action("notes").disabled, "Common actions follow closing")
	scene._on_dialogue_finished()
	check(scene.state.faith == 1 and scene.state.history.size() == 1, "Repeated completion cannot grant rewards")
	await click(action("careful"))
	check(scene.state.generic_used and action("careful") == null, "Generic removed after one use")
	await reload_ui()
	check(scene.stage() == "aftermath" and scene.state.generic_used, "Generic use persists")
	await click(action("next"))
	check(scene.state.round_number == 2 and scene.state.ap == 3 and scene.stage() == "idle", "Next round requires new card selection")
	var before: Dictionary = scene.state.snapshot().duplicate(true)
	scene._toolbar("map")
	check(scene.map_modal.visible, "Map opens outside dialogue")
	scene._map_place("fishing_village")
	check(scene.state.snapshot() == before and scene.overlay.visible, "Map remains free")
	scene.overlay.hide()
	# Full run through all dialogue and round stages, including old prose for 6–15.
	for step in range(250):
		if scene.stage() == "finished":
			break
		match scene.stage():
			"idle": scene._on_character_selected(0, scene.current_actor(), "", null)
			"choices": scene._choose("B")
			"opening", "result", "closing", "ending": finish_sequence()
			"aftermath":
				if scene.state.can_generic("notes"):
					scene._generic("notes")
				elif scene.state.can_generic("careful"):
					scene._generic("careful")
				scene._next()
		await process_frame
	check(scene.stage() == "finished" and scene.state.ending == "liberation" and scene.heading.text == "王国获得解放", "Dialogue UI completes all 15 rounds")
	scene._toolbar("evidence")
	check(scene.overlay_body.get_child_count() > 2, "Evidence journal renders")
	scene.overlay.hide()
	scene._toolbar("journal")
	check(scene.overlay_body.get_child_count() > 15, "Full history renders")
	scene.overlay.hide()
	# Unknown NPCs have a name, never borrow a different person's portrait.
	scene.state = State.new()
	scene.state.round_number = 8
	scene.state.alert = 14
	scene._refresh()
	scene._on_character_selected(0, scene.current_actor(), "", null)
	check(scene.get_node("Design/PortraitPanel").character == "刀郎" and scene.get_node("Design/PortraitPanel/Image").texture == null, "Missing art is a named character, not someone else's portrait")
	finish_sequence()
	check(action("A").disabled and action("B").disabled and not action("C").disabled, "Evidence and alert gates render after opening")
	for i in range(4):
		await process_frame
	check(scene.choice_scroll.size.y <= 340.1, "Long locked options remain scrollable within reserved area")
	# Immediate forgetting bypasses normal closing and common actions.
	scene.state = State.new()
	scene.state.alert = 17
	scene._refresh()
	scene._on_character_selected(0, "螺螺", "", null)
	finish_sequence()
	scene._choose("A")
	finish_sequence()
	check(scene.stage() == "ending" and scene.state.ending == "forgotten" and action("careful") == null, "18 immediately starts forgetting dialogue")
	await reload_ui()
	check(scene.stage() == "ending" and scene.state.alert == 18 and scene.state.history.size() == 1, "Immediate ending resumes safely")
	finish_sequence()
	check(scene.heading.text == "遗忘重临" and scene.stage() == "finished", "Ending completes with correct title")
	scene.state = sea
	scene._refresh()
	finish_sequence()
	scene._toolbar("map")
	check(scene.map_modal._show_ocean, "Sea ending restores ocean on map")
	scene.map_modal.hide()
	# Rendering: capture idle, actor dialogue, and choices in the actual window.
	scene._restart()
	await screenshot("idle")
	await click(scene.get_node("Design/CharacterRail/Cards").get_child(0))
	for i in range(30):
		await process_frame
	check(scene.get_node("Design/DialogueBox").get_global_rect().end.y <= root.size.y, "Dialogue stays inside viewport")
	await screenshot("dialogue")
	finish_sequence()
	await screenshot("choices")
	print("Trial1: %d checks, %d failures. Routes: sea F%d/A%d; liberation F%d/A%d; forgetting F%d/A%d" % [checks, failures, sea.faith, sea.alert, liberation.faith, liberation.alert, forgotten.faith, forgotten.alert])
	quit(1 if failures else 0)

func finish_sequence() -> void:
	var initial: String = scene.stage()
	for i in range(200):
		if scene.stage() != initial or not scene.busy():
			return
		scene.get_node("Design/DialogueBox").advance()
	check(false, "Dialogue did not finish: " + initial)

func reload_ui() -> void:
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	scene = load("res://scenes/trial1.tscn").instantiate()
	scene.save_path = checkpoint + ".ui"
	root.add_child(scene)
	current_scene = scene
	for i in range(6):
		await process_frame

func screenshot(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshot"):
		return
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/trial1-%s-%d.png" % [label, root.size.x])
=======
extends "res://tests/village_chapter_tests.gd"
## The trial1 entry now runs the six-day chapter. Keep the established test command.
## Previous fifteen-turn expectations are superseded; old rules/data remain isolated.
>>>>>>> origin/dev-max
