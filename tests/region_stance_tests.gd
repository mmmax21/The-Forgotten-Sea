extends SceneTree
const Stance := preload("res://scripts/story/region_stance.gd")
const State := preload("res://scripts/story/ruins_state.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var table = JSON.parse_string(FileAccess.get_file_as_string("res://data/region_stance.json"))
	check(table is Dictionary, "Stance table parses")
	check(int(table.actions.gather.support) == 1 and int(table.actions.gather.alert) == 1, "Gather defaults raise support and alert")
	check(int(table.actions.hide.support) == 0 and int(table.actions.hide.alert) == -1, "Hide default only lowers alert")
	check(int(table.ap_cost) == 1, "Both actions cost 1 AP")

	var fresh := Stance.normalize({})
	check(Stance.region_of("home") == "fishing_village", "Yabo's home counts as the fishing village")
	check(Stance.regional_support(fresh, "fishing_village") == 0 and Stance.alert_of(fresh) == 0, "New game starts at zero")
	check(Stance.regional_support(fresh, "ruins") == 0, "Ruins have no residents")

	var uneven := Stance.normalize({"alert": 5, "supports": {"fisher": 1, "salt": 2, "luoluo": 3, "yabo": 4}})
	check(Stance.regional_support(uneven, "fishing_village") == 3, "Regional support is the rounded average")
	var gathered := Stance.preview(uneven, "gather", "fishing_village", 3)
	check(gathered.ok and gathered.support_after == 4 and gathered.alert_after == 6 and gathered.ap_after == 2, "Gather adds the same amount to every resident")
	Stance.apply(uneven, "gather", "fishing_village")
	check(Stance.regional_support(uneven, "fishing_village") == 4 and Stance.alert_of(uneven) == 6, "Apply writes the previewed result")

	var ruins := Stance.preview(fresh, "gather", "ruins", 3)
	check(ruins.ok and ruins.support_after == 0 and ruins.alert_after == 1, "Empty region gather only raises alert")
	check(Stance.confirm_copy(ruins).text.contains("这里还没有居民"), "Empty region explains that support stays")

	var broke := Stance.preview(fresh, "gather", "fishing_village", 0)
	check(not broke.ok and broke.ap_after == 0, "No AP blocks the action")
	check(Stance.confirm_copy(broke).text.contains("行动点不足"), "Shortage is explained before confirm")

	var floor := Stance.preview(fresh, "hide", "fishing_village", 3)
	check(not floor.ok and floor.alert_after == 0 and floor.ap_after == 3, "Hide at the floor changes nothing and costs nothing")

	var lowered := Stance.preview(uneven, "hide", "fishing_village", 2)
	check(lowered.ok and lowered.support_after == 4 and lowered.alert_after == 5 and lowered.ap_after == 1, "Hide lowers alert without touching support")

	var checkpoint := OS.get_temp_dir().path_join("region-stance-%d.json" % OS.get_process_id())
	var model = State.new()
	model.stance = Stance.normalize({"alert": 4, "supports": {"yabo": 8, "fisher": 0, "salt": 0, "luoluo": 0}})
	check(model.save_to(checkpoint) == OK, "Stance can be saved")
	var restored = State.new()
	check(restored.load_from(checkpoint) and int(restored.stance.alert) == 4 and int(restored.stance.supports.yabo) == 8, "Stance survives reload")
	var legacy := FileAccess.open(checkpoint + ".old", FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"version": 1, "day": 1, "ap": 3, "location": "home", "stage": 0, "inventory": [], "support": 10, "pending": "", "choice": "", "history": []}))
	legacy.close()
	var old = State.new()
	check(old.load_from(checkpoint + ".old") and old.support == 10 and old.stance.is_empty(), "Old saves without stance still load")

	print("Region stance checks: %d failures" % failures)
	quit(1 if failures else 0)
