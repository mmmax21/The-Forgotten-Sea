extends SceneTree
## 学城章节测试套件 - SceneTree 模式,与 trail2 一致。

const State := preload("res://scripts/story/study_city/state.gd")
const Actions := preload("res://scripts/story/study_city/actions.gd")
const Flow := preload("res://scripts/story/study_city/flow.gd")
const Save := preload("res://scripts/story/study_city/save.gd")

var failures := 0
var file_path := "/tmp/study_city_test_%d.json" % OS.get_process_id()


func _initialize() -> void:
	call_deferred("run")


func check(c: bool, m: String) -> void:
	if not c:
		failures += 1
		push_error(m)


func run() -> void:
	var s = State.new()
	check(s.day == 1 and s.ap == 3, "T1 init day 1, 3 AP")
	check(s.people.size() == 3, "T1 three NPCs")
	check(s.inventory.has("demo_reliquary"), "T1 demo reliquary seeded")
	check(s.inventory.has("demo_antique"), "T1 demo antique seeded")

	# T2: status fns
	check(s.cooperative("mo") == false, "T2 mo not cooperative initially")

	# T3: warning day 3
	s.day = 3
	Flow.on_end_day(s)
	check(s.archive_warning_day == 4, "T3 warning at day 4")
	check(s.flags.archive_warning_set, "T3 warning flag set")

	# T4: destruction without saving
	s.day = 4
	Flow.on_end_day(s)
	check(s.archive_destroyed, "T4 destroyed")
	check(s.flags.versions_lost, "T4 versions lost")
	check(s.flags.execution_lost, "T4 execution lost")

	# T5: destruction with saving
	s = State.new()
	s.day = 3
	Flow.on_end_day(s)
	s.day = 4
	s.inventory["versions_saved"] = {"name": "saved", "kind": "museum", "source": "versions", "confirmed": true, "holder": "player"}
	Flow.on_end_day(s)
	check(not s.flags.get("versions_lost", true), "T5 versions not lost")
	check(s.flags.execution_lost, "T5 execution still lost")

	# T6: advance day
	s = State.new()
	var result = Flow.advance_day(s)
	check(result.day == 2, "T6 advance to day 2")

	# T7: P3 claim
	s = State.new()
	s.inventory["versions"] = {"name": "V", "kind": "original", "source": "v", "confirmed": true, "holder": "player"}
	s.inventory["execution"] = {"name": "X", "kind": "original", "source": "x", "confirmed": true, "holder": "player"}
	s.inventory["command"] = {"name": "C", "kind": "original", "source": "c", "confirmed": true, "holder": "player"}
	check(Actions.execute(s, "verify_contradiction"), "T7 verify OK")
	check(Actions.execute(s, "trace_command_chain"), "T7 trace OK")
	check(s.has_claim("P3"), "T7 P3 claim")

	# T8: blocked when missing materials
	s = State.new()
	var reasons = Actions.blocked(s, "verify_contradiction")
	check(not reasons.is_empty(), "T8 verify blocked when missing")

	# T9: exposed npc
	s = State.new()
	s.people.mo.exposed = true
	reasons = Actions.blocked(s, "mo_help")
	check(not reasons.is_empty(), "T9 mo blocked when exposed")

	# T10: day window
	s = State.new()
	s.day = 5
	reasons = Actions.blocked(s, "save_versions_self")
	check(not reasons.is_empty(), "T10 save blocked day 5")

	# T11: full flow
	s = State.new()
	s.inventory["versions"] = {"name": "V", "kind": "original", "source": "v", "confirmed": true, "holder": "player"}
	s.inventory["execution"] = {"name": "X", "kind": "original", "source": "x", "confirmed": true, "holder": "player"}
	for npc in State.NPC_IDS:
		s.people[npc].informed = true
	s.ap = 3
	check(Actions.execute(s, "mo_help"), "T11 mo_help")
	check(Actions.execute(s, "er_help"), "T11 er_help")
	s.ap = 3
	check(Actions.execute(s, "get_versions"), "T11 get_versions")
	check(Actions.execute(s, "get_execution"), "T11 get_execution")
	s.ap = 3
	check(Actions.execute(s, "verify_contradiction"), "T11 verify")
	s.inventory["command"] = {"name": "C", "kind": "original", "source": "c", "confirmed": true, "holder": "player"}
	s.ap = 3
	check(Actions.execute(s, "trace_command_chain"), "T11 trace")
	s.day = 3
	Flow.on_end_day(s)
	s.day = 4
	s.ap = 3
	check(Actions.execute(s, "save_versions_self"), "T11 save versions")
	check(Actions.execute(s, "save_execution_self"), "T11 save execution")
	Flow.on_end_day(s)
	check(not s.flags.get("versions_lost", true), "T11 saved versions kept")
	check(not s.flags.get("execution_lost", true), "T11 saved execution kept")
	s.ap = 3
	check(Actions.execute(s, "publish_statement"), "T11 publish")
	s.day = 5
	var report = Flow.settle(s)
	check(s.finished, "T11 finished")
	check(report.ending == "制度突破", "T11 best ending")

	# T12: save roundtrip
	s = State.new()
	s.day = 4
	s.ap = 2
	var data = s.to_data()
	check(Save.save_to(file_path, s) == OK, "T12 save OK")
	var loaded = Save.load_from(file_path)
	check(loaded.ok, "T12 load OK")
	if loaded.ok:
		var restored: State = loaded.state
		check(restored.day == 4 and restored.ap == 2, "T12 roundtrip state")

	# T13: corrupt save
	s = State.new()
	Save.save_to(file_path, s)
	var f = FileAccess.open(file_path, FileAccess.WRITE)
	f.store_string("broken")
	f.close()
	Save.load_from(file_path)
	check(true, "T13 corrupt save handled")

	# T14: tampered version
	s = State.new()
	Save.save_to(file_path, s)
	var f2 = FileAccess.open(file_path, FileAccess.READ)
	var text = f2.get_as_text()
	f2.close()
	var tampered = text.replace('"version": 1', '"version": 99')
	var f3 = FileAccess.open(file_path, FileAccess.WRITE)
	f3.store_string(tampered)
	f3.close()
	var result3 = Save.load_from(file_path)
	check(not result3.ok, "T14 tampered rejected")

	print("StudyCity checks: %d checks, %d failures" % [40, failures])
	quit(1 if failures else 0)
