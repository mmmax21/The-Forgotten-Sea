extends SceneTree
const State := preload("res://scripts/story/ruins_state.gd")
var failures := 0
var scene
var checkpoint: String

func _initialize() -> void:
	checkpoint = "/private/tmp/taptap-ruins-test-%d.json" % OS.get_process_id()
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func finish_dialogue() -> void:
	for i in range(80):
		if not scene.busy:
			return
		scene.get_node("Design/DialogueBox").advance()
	check(false, "Dialogue never finished")

func select_modal(id: String) -> void:
	if not scene.modal.visible:
		check(false, "Expected visible modal: " + id)
		return
	for button in scene.modal.choices.get_children():
		if button.get_meta("choice_id", "") == id:
			await click(button)
			return
	check(false, "Missing modal button: " + id)

func click(node: Control) -> void:
	for frame in range(3):
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

func run() -> void:
	# Rules: invalid actions and insufficient AP have no effects.
	var model = State.new()
	check(not model.move_to("ruins"), "Cannot travel before guide")
	check(not model.begin("blueprint"), "Cannot skip story requirements")
	check(model.begin("guide"), "Guide starts")
	check(not model.begin("guide") and not model.next_day(), "Pending dialogue locks mutation")
	check(model.save_to(checkpoint) == OK, "Pending action saves")
	var restored = State.new()
	check(restored.load_from(checkpoint) and restored.pending == "guide" and restored.ap == 3, "Resume unpaid dialogue")
	restored.finish()
	restored.finish()
	check(restored.ap == 2 and restored.stage == 1, "Completion charges exactly once")
	restored.ap = 1
	check(restored.move_to("ruins"), "Last AP can be spent reaching ruins")
	check(restored.begin("song"), "Automatic pickup starts at zero AP")
	restored.finish()
	check(restored.ap == 0 and restored.inventory.has("古老的船歌"), "Pickup is free")
	check(not restored.move_to("home"), "Insufficient AP blocks travel")
	check(restored.next_day() and restored.location == "ruins" and restored.ap == 3, "Next day preserves ruins location")
	# Use a fresh UI save, independent from the model checkpoint.
	scene = load("res://scenes/ui/component_gallery.tscn").instantiate()
	scene.save_path = checkpoint + ".ui"
	root.add_child(scene)
	current_scene = scene
	root.size = Vector2i(1920, 1080) if OS.get_cmdline_user_args().has("--large") else Vector2i(1280, 720)
	for frame in range(6):
		await process_frame
	# Real pointer input: choose Yabo and the priced action, then advance inside the textbox.
	await click(scene.get_node("Design/CharacterRail/Cards").get_child(3))
	check(scene.selected_actor == 3, "Character card click selects Yabo")
	await click(scene.action_row.get_child(0))
	check(scene.busy, "Action click starts dialogue")
	var box = scene.get_node("Design/DialogueBox")
	await click(box.get_node("Text"))
	check(box.dialogue_text == "哑伯手中拿着一块形状奇怪的旧木板。", "Text click advances one line")
	finish_dialogue()
	check(scene.state.stage == 1 and scene.state.ap == 2 and scene.modal.visible, "Guide completes before travel prompt")
	await select_modal("cancel")
	check(scene.state.ap == 2 and scene.state.location == "home", "Cancel costs nothing")
	# Map hit must dispatch destination selection through its actual clickable area.
	scene._on_minimap("compass")
	await process_frame
	await click(scene.get_node("Design/MapModal/Panel/Map/Locations/ruins/Hit"))
	check(scene.modal.visible and scene.move_target == "ruins", "Map click opens travel confirmation")
	await select_modal("move")
	check(scene.state.location == "ruins" and scene.busy and scene.state.ap == 1, "Travel starts arrival dialogue")
	check(scene.ruins_background.visible and not scene.get_node("Design/CharacterRail").visible, "Ruins switches background and hides absent people")
	finish_dialogue()
	check(scene.state.inventory == ["古老的船歌"] and scene.state.ap == 1, "Arrival gives song once")
	await select_modal("item_closed")
	await select_modal("move")
	check(scene.state.location == "home" and scene.state.ap == 0, "Return costs one AP")
	scene._ask_end_day()
	await select_modal("day")
	check(scene.state.day == 2 and scene.state.ap == 3, "End day restores AP")
	for id in ["plank", "perform", "blueprint"]:
		scene._start(id)
		finish_dialogue()
		await select_modal("item_closed" if id != "perform" else "cancel")
	check(scene.state.stage == 5 and scene.state.ap == 0 and scene.state.support == 10, "First chapter costs six AP and adds only Yabo support")
	check(scene.state.inventory.size() == 3, "Three unique items")
	scene._start("perform")
	check(not scene.busy and scene.state.support == 10, "Cannot repeat reward")
	# Subsequent investigation, return, verification and fisherman choices.
	scene._ask_end_day()
	await select_modal("day")
	scene._request_move("ruins")
	await select_modal("move")
	check(not scene.busy, "Revisiting does not repeat pickup")
	scene._start("investigate")
	finish_dialogue()
	await select_modal("cancel")
	scene._request_move("home")
	await select_modal("move")
	scene._ask_end_day()
	await select_modal("day")
	scene._start("verify")
	finish_dialogue()
	await select_modal("cancel")
	scene._start("fisher")
	finish_dialogue()
	check(scene.state.stage == 8 and scene.state.ap == 1, "Fisher dialogue charges once")
	await select_modal("choice:later")
	check(scene.state.stage == 8 and scene.state.next_day(), "Defer choice permits next day")
	scene._show_choices()
	await select_modal("choice:protect")
	finish_dialogue()
	check(scene.state.stage == 9 and scene.state.choice == "protect" and scene.state.ap == 3, "Choice is free and persistent")
	var loaded = State.new()
	check(loaded.load_from(scene.save_path), "UI save can be read")
	check(loaded.stage == 9 and loaded.inventory.size() == 3 and loaded.support == 10, "Full state survives reload")
	# Alternate final choice.
	loaded.stage = 8
	check(loaded.choose("private") and loaded.choice == "private", "Private enquiry branch available")
	print("Ruins story checks: %d failures" % failures)
	quit(1 if failures else 0)
