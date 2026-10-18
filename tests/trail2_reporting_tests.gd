extends SceneTree
var failures := 0
var scene
func check(ok: bool, label: String):
	if not ok:
		failures += 1
		push_error(label)
func _initialize(): call_deferred("run")
func action(id: String):
	scene._preview_action(id)
	scene.modal._select("execute:" + id)
	check(scene.state.completed.has(id), "实际行动成功：" + id)
func move(destination: String):
	scene._select_map_location(destination)
	scene.modal._select("travel:%s:-1" % destination)
	check(scene.state.current_location == destination, "实际移动成功：" + destination)
func end():
	scene._ask_end_day()
	scene.modal._select("end_day:%d" % scene.state.day)
	scene.modal._select("close")
func run():
	scene = load("res://scenes/trail2.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	await process_frame
	# 不改数值、天数或位置，完整计入往返路费。
	action("repair")
	move("ruins")
	action("survey")
	check(scene.state.ap == 0, "第一天3AP")
	end()
	action("clear")
	action("search")
	move("fishing_village")
	check(scene.state.ap == 0, "第二天3AP")
	end()
	action("identify")
	scene._select_person(0, "", "", null)
	scene._begin_material("show", "salt")
	scene.modal._select("pick_material:fragment")
	check(scene.modal.body.get_child(1).text.contains("告密预警：第4天末"), "确认前明确预告告密期限")
	scene.modal._select("confirm_material")
	var p: Dictionary = scene.state.people.salt
	check(p.trust == 50 and p.alert == 65 and p.informed and p.warning_day == 4, "第3天展示后T50/A65/知情，预警第4天末")
	print("D3 salt: ", p)
	var risky_save: Dictionary = scene.state.to_save_data()
	end()
	check(not scene.state.people.salt.reported, "第3天末不提前告密")
	end()
	check(scene.state.people.salt.reported and scene.state.day == 5 and scene.state.ap == 2, "第4天末告密，第5天少1AP")
	print("D5 salt: ", scene.state.people.salt, " AP=", scene.state.ap)
	# 同一真实路线的补救分支。
	check(scene.state.restore_save_data(risky_save), "恢复分支起点")
	scene._refresh()
	action("feed")
	check(scene.state.people.salt.trust == 65 and scene.state.people.salt.warning_day == 0, "送粮后解除预警")
	check(scene.state.status(scene.state.people.salt) == "沉默", "高信任高警戒只会沉默")
	end()
	end()
	check(not scene.state.people.salt.reported and scene.state.ap == 3, "补救分支没有告密或处罚")
	# 新捷径：从新游戏直接逼问，不注入人物数值。
	scene.state = scene.State.new()
	scene.selected_group = "salt"
	scene._refresh()
	scene._preview_action("press_relic")
	check(scene.modal.body.get_child(1).text.contains("不补救将在第2天结束时告密"), "捷径确认前显示准确告密期限")
	scene.modal._select("close")
	check(scene.state.ap == 3 and scene.state.inventory.is_empty(), "取消逼问不扣费不发遗物")
	action("press_relic")
	check(scene.state.people.salt.trust == 30 and scene.state.people.salt.alert == 65 and scene.state.people.salt.warning_day == 2, "逼问后T30/A65且第2天末预警")
	check(scene.state.inventory.relic.confirmed and scene.state.ap == 2, "1AP获得已确认遗物")
	var pressure: Dictionary = scene.state.to_save_data()
	check(not scene.state.execute("press_relic").ok and not scene.state.execute("relic").ok and scene.state.ap == 2, "两条取得路线互斥，不重复扣费或发物")
	end()
	check(not scene.state.people.salt.reported, "第1天末给出补救窗口")
	end()
	check(scene.state.people.salt.reported and scene.state.ap == 2 and scene.state.inventory.relic.holder == "player", "第2天末告密，第3天处罚且保留遗物")
	check(scene.state.restore_save_data(pressure), "捷径存档恢复")
	scene._refresh()
	action("feed")
	check(scene.state.people.salt.trust == 45 and scene.state.people.salt.warning_day == 2, "仅赔礼送粮不足以解除")
	action("listen")
	check(scene.state.people.salt.trust == 60 and scene.state.people.salt.alert == 70 and scene.state.people.salt.warning_day == 0, "完整补救准确达到60，解除预警但沉默")
	end()
	action("protect")
	check(scene.state.people.salt.alert == 50 and scene.state.status(scene.state.people.salt) == "支持", "安置降低警戒，恢复当前支持")
	end()
	check(not scene.state.people.salt.reported and scene.state.ap == 3, "巡查可能沉默，但不再告密或罚点")
	# 正常路线领取遗物后不能再走捷径，即使遗物已经交给NPC。
	scene.state = scene.State.new()
	for id in ["feed", "listen", "relic"]: check(scene.state.execute(id).ok, "普通路线不变：" + id)
	scene.state.end_day()
	var before_normal := JSON.stringify(scene.state.to_save_data())
	check(not scene.state.execute("press_relic").ok and JSON.stringify(scene.state.to_save_data()) == before_normal, "正常取得后不能逼问刷遗物")
	scene.queue_free()
	await process_frame
	print("Reporting checks: ", "PASS" if failures == 0 else "FAIL %d" % failures)
	quit(1 if failures else 0)
