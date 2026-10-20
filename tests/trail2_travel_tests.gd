extends SceneTree
const State := preload("res://scripts/story/trail2_state.gd")
const Save := preload("res://scripts/story/trail2_save.gd")
var failures := 0
func check(ok: bool, label: String):
	if not ok:
		failures += 1
		push_error(label)
func _initialize():
	call_deferred("run")
func run():
	var s = State.new()
	check(not s.execute("survey").ok and s.ap == 3, "未移动不能远程勘察")
	check(s.travel_preview("ruins").allowed and s.ap == 3, "预览无副作用")
	check(s.travel("ruins").ok and s.ap == 2, "单程1AP")
	check(not s.travel("ruins").ok and s.ap == 2, "同地不重复扣点")
	check(not s.execute("feed").ok and s.ap == 2, "遗迹不能远程送粮")
	check(not s.material_preview("record_scribe", "", []).allowed, "遗迹不能远程使用村口摊位")
	check(s.execute("survey").ok and s.execute("clear").ok and s.ap == 0, "路程和行动独立计费")
	check(not s.travel("fishing_village").ok and s.current_location == "ruins", "0AP不能移动")
	s.end_day()
	check(s.current_location == "ruins" and s.ap == 3, "跨日不免费传送")
	check(s.travel("fishing_village").ok and s.ap == 2, "返程1AP")
	s.day = 5
	check(not s.travel("ruins").ok and s.ap == 2, "封闭不能进入且不扣费")
	# 保存真实位置，旧版根据查看地点迁移且不补扣费用。
	s = State.new()
	s.travel("ruins")
	var path := "/tmp/trail2-travel-%d.json" % OS.get_process_id()
	check(Save.save_to(path, s, {"selected_group": "warehouse", "text": "遗迹"}) == OK, "位置存档")
	var loaded := Save.load_from(path)
	check(loaded.ok and loaded.state.current_location == "ruins" and loaded.state.ap == 2, "读档不重新收费")
	var data: Dictionary = s.to_save_data()
	data.erase("current_location")
	var payload := JSON.stringify({"state": data, "view": {"selected_group": "warehouse", "text": "遗迹"}})
	var legacy_path := path + ".v3"
	var file := FileAccess.open(legacy_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"game": "trail2", "version": 3, "payload": payload, "checksum": payload.sha256_text()}))
	file.close()
	loaded = Save.load_from(legacy_path)
	check(loaded.ok and loaded.state.current_location == "ruins" and loaded.state.ap == 2, "v3恢复位置，不追扣AP")
	# 地图、快捷入口、人物入口共用同一移动规则。
	var scene = load("res://scenes/trail2.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	await process_frame
	check(scene.get_node("%MapModal")._reachable.ruins, "地图遗迹已开放")
	scene._select_map_location("ruins")
	check(scene.modal.visible and scene.state.ap == 3, "地图移动预览")
	scene.modal._select("close")
	check(scene.state.current_location == "fishing_village" and scene.state.ap == 3, "取消移动不扣点")
	scene._select_warehouse()
	scene.modal._select("travel:ruins:-1")
	check(scene.state.ap == 2 and scene.region_background.texture == scene.Art.BACKGROUNDS.ruins and scene.selected_group == "warehouse", "遗迹背景、行动及扣点同步")
	scene._select_person(0, "", "", null)
	check(scene.modal.visible and scene.state.current_location == "ruins", "点村民不会免费传送")
	scene.modal._select("travel:fishing_village:0")
	check(scene.state.ap == 1 and scene.selected_group == "salt" and scene.region_background.texture == scene.Art.BACKGROUNDS.fishing_village, "人物入口付费返回")
	scene._select_person(1, "", "", null)
	check(scene.state.ap == 1 and not scene.modal.visible, "同地切换人物免费")
	scene._select_map_location("fishing_village")
	scene.modal._select("close")
	check(scene.state.ap == 1, "地图点击当前位置免费")
	scene.state.ap = 0
	scene._select_map_location("ruins")
	scene.modal._select("travel:ruins:-1")
	check(scene.state.ap == 0 and scene.state.current_location == "fishing_village", "绕过禁用按钮也不能负AP移动")
	scene.queue_free()
	await process_frame
	print("Travel checks: ", "PASS" if failures == 0 else "FAIL %d" % failures)
	quit(1 if failures else 0)
