extends SceneTree
const State := preload("res://scripts/story/ruins_state.gd")
var failures := 0
var checkpoint: String

func _initialize() -> void:
	checkpoint = OS.get_temp_dir().path_join("taptap-ruins-test-%d.json" % OS.get_process_id())
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

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
	var branch = State.new()
	branch.stage = 8
	check(branch.choose("private") and branch.choice == "private", "Private enquiry branch available")
	print("Ruins story checks: %d failures" % failures)
	quit(1 if failures else 0)
