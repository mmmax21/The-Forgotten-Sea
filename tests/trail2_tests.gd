extends SceneTree
const State := preload("res://scripts/story/trail2_state.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state = State.new()
	var initial: String = JSON.stringify([state.ap, state.food, state.people, state.completed, state.inventory])
	state.preview("feed")
	check(initial == JSON.stringify([state.ap, state.food, state.people, state.completed, state.inventory]), "预览不能修改状态")
	check(not state.execute("relic").ok, "未倾听不能取得遗物")
	check(state.ap == 3 and state.food == 2, "失败不扣费")
	check(state.execute("feed").ok and state.execute("listen").ok and state.execute("repair").ok, "第一天代表路线")
	check(state.ap == 0 and state.food == 1, "代表路线资源")
	check(state.people.salt.trust == 65 and state.people.salt.alert == 55 and not state.people.salt.informed, "盐嫂代表路线数值及知情")
	check(state.people.mute.trust == 65 and state.people.mute.alert == 40, "哑伯代表路线数值")
	check(not state.execute("relic").ok and not state.execute("feed").ok, "AP不足和一次性奖励")
	check(state.inventory.is_empty() and state.history.size() == 3, "失败不能产出材料或历史")
	state = State.new()
	state.current_location = "ruins" # 本地行动单元夹具，移动另测。
	check(state.execute("survey").ok and state.execute("clear").ok and state.execute("search").ok, "仓库三步路线")
	check(state.ap == 0 and state.food == 2 and state.inventory.fragment.holder == "player" and not state.inventory.fragment.confirmed, "碎片归属与未确认状态")
	state = State.new()
	check(state.execute("rumor").ok and state.execute("retrieve").ok, "螺螺入口路线")
	check(state.entrance_known and state.people.luo.trust == 60 and not state.people.luo.informed, "入口不使螺螺知情")
	check(not state.execute("survey").ok and state.ap == 1, "入口共享，不能重复勘察扣费")
	state.current_location = "ruins"
	check(state.execute("clear").ok, "螺螺入口可直接清障")
	state = State.new()
	state.execute("feed")
	state.execute("listen")
	check(not state.execute("protect").ok and state.ap == 1 and state.food == 1, "2 AP必须同日完整支付")
	check(state.execute("relic").ok, "查看遗物")
	check(state.status(state.people.salt) == "沉默" and state.people.salt.alert == 65 and state.people.salt.informed, "取得遗物后沉默")
	check(state.inventory.relic.confirmed and state.people.salt.warning_day == 0, "沉默不告密，既成材料保留")
	# 独立夹具验证成本边界；完整跨日路线另测。
	state = State.new()
	state.completed = {"feed": true, "listen": true}
	state.food = 0
	check(not state.execute("protect").ok and state.ap == 3, "粮食不足不扣费")
	state.food = 1
	state.day = 4
	check(not state.execute("protect").ok and state.food == 1, "过期不扣费")
	state.day = 2
	check(state.execute("protect").ok and state.food == 0 and state.ap == 1 and state.people.salt.alert == 30, "安置成本和降警戒")
	state = State.new()
	state.inventory.fragment = {"name": "刻痕碎片", "source": "warehouse_fragment", "confirmed": false, "holder": "player"}
	state.execute("repair")
	check(state.execute("identify").ok, "辨认资格")
	check(state.inventory.size() == 1 and state.inventory.fragment.confirmed and state.people.mute.informed and state.people.mute.alert == 50, "辨认不增加独立来源")
	check(not state.execute("identify").ok and state.ap == 1, "不能重复辨认刷取")
	await check_saves()
	check_materials()
	check_days()
	var scene = load("res://scenes/trail2.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	await process_frame
	scene._select_person(0, "", "", null)
	check(scene.action_list.get_child_count() == 9, "盐嫂基础行动及材料行动")
	scene._preview_action("feed")
	check(scene.modal.visible and scene.state.ap == 3, "UI预览不扣费")
	scene.modal._select("close")
	check(scene.state.ap == 3 and scene.state.food == 2, "取消预览不扣费")
	scene._preview_action("feed")
	scene.modal._select("execute:feed")
	check(scene.state.ap == 2 and scene.state.food == 1, "UI确认执行")
	scene._select_warehouse()
	check(scene.state.ap == 2 and scene.modal.visible, "移动预览免费")
	scene.modal._select("travel:ruins:-1")
	check(scene.state.ap == 1 and scene.state.current_location == "ruins" and scene.action_list.get_child_count() == 3, "确认移动消耗1 AP")
	scene._toolbar("items")
	check(scene.modal.visible, "材料弹窗")
	scene.modal._select("close")
	scene._modal_selected("restart")
	check(scene.state.ap == 3 and scene.state.food == 2 and scene.state.history.is_empty(), "重新试玩重置")
	scene._ask_end_day()
	check(scene.modal.visible and scene.state.day == 1, "日末预览不推进日期")
	scene.modal._select("close")
	check(scene.state.day == 1 and scene.state.ap == 3, "取消结束保留AP")
	scene._ask_end_day()
	scene.modal._select("end_day:1")
	check(scene.state.day == 2 and scene.state.ap == 3 and scene.modal.visible, "UI确认跨日并显示结算")
	scene.modal._select("close")
	scene._modal_selected("end_day:1")
	check(scene.state.day == 2, "重复旧确认不能推进两天")
	scene.modal._select("close")
	for today in [2, 3, 4, 5]:
		scene._ask_end_day()
		scene.modal._select("end_day:%d" % today)
		scene.modal._select("close")
	check(scene.state.village_finished and scene.state.day == 5, "UI停在渔村结束")
	scene._ask_end_day()
	check(scene.modal.visible and scene.next_day.text == "查看阶段记录", "阶段记录可查看")
	scene.modal._select("close")
	scene.state = route_a()
	scene._refresh()
	scene._begin_material("store", "mute")
	scene.modal._select("pick_material:relic")
	scene.modal._select("pick_material:fragment")
	check(scene.state.ap == 3 and scene.material_request.ids.size() == 2, "UI多选保管预览前不扣费")
	scene.modal._select("review_material")
	scene.modal._select("confirm_material")
	check(scene.state.ap == 2 and scene.state.storage.mute.size() == 2, "UI多选保管共1AP")
	scene._toolbar("items")
	scene.modal._select("material_kind:retrieve")
	scene.modal._select("pick_material:relic")
	scene.modal._select("confirm_material")
	check(scene.state.ap == 2 and scene.state.inventory.relic.holder == "player", "UI材料页免费取回")
	scene._begin_material("spread", "salt")
	scene.modal._select("pick_material:record_1")
	scene.modal._select("close")
	check(scene.state.spread.is_empty() and scene.state.ap == 2, "UI取消材料预览不执行")
	scene.queue_free()
	await process_frame
	print("Trail2 checks: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(1 if failures else 0)


func check_days() -> void:
	var state = State.new()
	state.execute("feed")
	var before := JSON.stringify([state.day, state.ap, state.food, state.people, state.history])
	check(state.end_day_preview().allowed, "允许提前结束")
	check(before == JSON.stringify([state.day, state.ap, state.food, state.people, state.history]), "日末预览只读")
	state.end_day()
	check(state.day == 2 and state.ap == 3 and state.food == 1 and state.completed.has("feed"), "AP不累计、粮食不补满、完成标记保留")
	state.end_day()
	check(state.patrol_applied and state.people.salt.alert == 50 and state.people.mute.alert == 40, "未知情不涨警戒")
	state.execute("listen")
	state.execute("relic")
	check(state.people.salt.alert == 65, "巡查后新知情不追补")
	state.end_day()
	check(state.people.salt.alert == 65, "巡查仅一次")
	check(not state.execute("protect").ok, "第4天安置窗口关闭")
	state = State.new()
	state.execute("feed")
	state.execute("listen")
	state.execute("relic")
	state.end_day()
	state.end_day()
	check(state.people.salt.alert == 75 and state.people.mute.alert == 40 and state.people.luo.alert == 20, "日初巡查只对已知情者加10")
	check(state.people.salt.warning_day == 0 and not state.people.salt.reported, "高信任沉默不告密")
	# 真实跨日路线：先取碎片，第5天仍可以辨认。
	state = State.new()
	state.current_location = "ruins"
	state.execute("survey")
	state.execute("clear")
	state.execute("search")
	for i in 4:
		state.end_day()
	check(state.day == 5 and not state.execute("survey").ok, "第5天仓库关闭")
	check(state.travel("fishing_village").ok, "遗迹封闭后仍可返回村庄")
	check(state.execute("repair").ok and state.execute("identify").ok, "遗迹关闭不妨碍辨认已有碎片")
	state.end_day()
	check(state.village_finished and state.day == 5 and state.ap == 0, "第5天完成不虚构可操作第6天")
	check(state.departure_snapshot.inventory.fragment.confirmed, "阶段快照保存材料")
	var count: int = state.history.size()
	check(not state.end_day().ok and not state.execute("hide_old").ok and state.history.size() == count, "结束后不能重复结算或继续行动")
	state.inventory.fragment.name = "测试修改"
	check(state.departure_snapshot.inventory.fragment.name == "船体构件", "快照与当前状态深拷贝隔离")
	# 展示证据尚未接入：注入高危状态验证时序，不声称当前基础路线自然会告密。
	state = State.new()
	state.people.salt.informed = true
	state.people.salt.alert = 65
	state.refresh_warnings()
	check(state.people.salt.warning_day == 2, "第N天高危于N+1日末到期")
	state.end_day()
	check(not state.people.salt.reported and state.people.salt.warning_day == 2, "不提前告密且不刷新期限")
	check(state.end_day_preview().text.contains("2 AP"), "结束预览预测首次处罚")
	state.end_day()
	check(state.people.salt.reported and state.day == 3 and state.ap == 2 and state.report_penalty.applied, "到期告密及次日一次处罚")
	check(not state.people.mute.informed and not state.people.luo.informed, "告密不自动传播知情")
	state.people.luo.informed = true
	state.people.luo.alert = 65
	state.refresh_warnings()
	state.end_day()
	check(state.day == 4 and state.ap == 3, "首次处罚只持续一天")
	state.end_day()
	check(state.people.luo.reported and state.ap == 3 and state.report_penalty.due_day == 3, "后续告密不重复处罚")
	state.refresh_warnings()
	check(state.people.salt.warning_day == 0, "已告密不会生成新预警")
	# 提高T只解除告密；降低A可解除，再次高危获得新期限。
	state = State.new()
	state.people.salt.informed = true
	state.people.salt.trust = 50
	state.people.salt.alert = 65
	state.refresh_warnings()
	state.end_day()
	check(state.execute("feed").ok and state.people.salt.warning_day == 0 and state.status(state.people.salt) == "沉默", "送粮达到T65后解除预警但仍沉默")
	state.end_day()
	check(not state.people.salt.reported and state.ap == 3, "到期前补救避免处罚")
	state = State.new()
	state.people.luo.informed = true
	state.people.luo.alert = 65
	state.refresh_warnings()
	state.end_day()
	check(state.execute("clarify").ok and state.people.luo.warning_day == 0, "降警戒解除")
	state.people.luo.alert = 65
	state.refresh_warnings()
	check(state.people.luo.warning_day == 3, "真正解除再进入高危获得新窗口")
	# 巡查触发预警，不能在当天结束即告密。
	state = State.new()
	state.people.luo.informed = true
	state.people.luo.alert = 50
	state.end_day()
	state.end_day()
	check(state.people.luo.alert == 60 and state.people.luo.warning_day == 4, "巡查新高危次日到期")
	state.end_day()
	check(not state.people.luo.reported, "巡查新预警不提前结算")
	# 第5天到期处罚与第5天新预警分别承接到第6天。
	state = State.new()
	for i in 3:
		state.end_day()
	state.people.salt.informed = true
	state.people.salt.alert = 65
	state.refresh_warnings()
	state.end_day()
	state.people.luo.informed = true
	state.people.luo.alert = 65
	state.refresh_warnings()
	state.end_day()
	check(state.departure_snapshot.people.salt.reported, "第4天预警第5天末告密")
	check(state.departure_snapshot.report_penalty.due_day == 6 and not state.departure_snapshot.report_penalty.applied, "第5天处罚保留到第6天，不提前执行")
	check(state.departure_snapshot.people.luo.warning_day == 6 and not state.departure_snapshot.people.luo.reported, "第5天新预警保留原期限")


# 材料/风险单元夹具保留3 AP以独立检查交接；完整含移动路线在full及travel套件验证。
func route_a():
	var state = State.new()
	for id in ["feed", "listen", "repair"]:
		check(state.execute(id).ok, "材料夹具第1天：" + id)
	state.end_day()
	check(state.execute("protect").ok, "材料夹具安置")
	state.current_location = "ruins"
	check(state.execute("survey").ok, "材料夹具勘察")
	state.end_day()
	for id in ["clear", "search", "identify"]:
		state.current_location = "fishing_village" if id == "identify" else "ruins"
		check(state.execute(id).ok, "材料夹具：" + id)
	state.end_day()
	check(state.execute("relic").ok, "材料夹具第4天取得遗物")
	check(state.execute_material("record_self", "", ["relic"]).ok, "材料夹具第4天记录")
	state.end_day()
	return state


func route_warning():
	var state = State.new()
	state.current_location = "ruins" # 风险单元夹具
	for id in ["survey", "clear", "search"]:
		state.execute(id)
	state.end_day()
	state.current_location = "fishing_village"
	state.execute("repair")
	state.execute("identify")
	check(state.execute_material("show", "salt", ["fragment"]).ok, "展示触发预警")
	check(state.people.salt.trust == 50 and state.people.salt.alert == 65 and state.people.salt.warning_day == 3, "真实预警数值与期限")
	state.end_day()
	return state


func check_materials() -> void:
	var state = route_a()
	var before := JSON.stringify([state.ap, state.people, state.inventory, state.spread])
	state.material_preview("spread", "salt", ["record_1"])
	check(before == JSON.stringify([state.ap, state.people, state.inventory, state.spread]), "材料预览无副作用")
	check(state.execute_material("spread", "salt", ["record_1"]).ok, "材料夹具第5天安排传播")
	check(state.ap == 2 and state.food == 0 and state.people.salt.alert == 55, "材料夹具费用")
	check(state.publications.is_empty(), "安排不等于已经传播")
	state.end_day()
	check(state.publications.size() == 1 and state.spread.status == "completed", "离场传播成功")
	check(state.inventory.relic.holder == "player" and state.inventory.fragment.holder == "player" and state.inventory.record_1.holder == "salt", "原物随身，记录留给盐嫂")
	check(state.inventory.record_1.source == state.inventory.relic.source and state.departure_report.contains("随身2个独立确认来源"), "记录不增加独立来源")
	check(state.departure_report.contains("进阶目标：完成"), "真实传播完成进阶目标")
	check(not state.execute_material("retrieve", "", ["record_1"]).ok, "离场后不可取回或回滚传播")
	state = route_warning()
	check(state.people.salt.alert == 75 and state.people.mute.alert == 60, "风险夹具巡查")
	check(state.execute("feed").ok, "提高信任补救")
	check(state.people.salt.warning_day == 0 and state.status(state.people.salt) == "沉默", "风险夹具只解除告密")
	check(state.execute("hide_old").ok, "哑伯补救")
	check(not state.execute_material("show", "salt", ["fragment"]).ok, "每人展示仅一次")
	state.end_day()
	check(not state.people.salt.reported, "补救后不告密")
	state = route_warning()
	state.execute("hide_old")
	check(state.execute_material("record_self", "", ["fragment"]).ok, "不补救路线制作记录")
	state.end_day()
	check(state.people.salt.reported and state.ap == 2, "风险夹具第4天首次处罚")
	check(state.execute_material("store", "mute", ["fragment"]).ok, "告密不阻止无关人物保管")
	state.end_day()
	state.end_day()
	check(state.inventory.fragment.holder == "mute" and state.inventory.record_1.holder == "player", "保管夹具原物与记录分离")
	check(state.departure_report.contains("基本目标：完成（随身1个独立确认来源）"), "携带记录完成基本目标")
	# 两件原物同一批次交接仅1AP；普通取回免费且不回滚数值。
	state = route_a()
	check(state.execute_material("store", "mute", ["fragment", "relic"]).ok and state.ap == 2, "两件一次托管只收1AP")
	check(not state.execute_material("record_scribe", "", ["relic"]).ok, "托管原物不能远程制作记录")
	check(not state.execute_material("show", "luo", ["relic"]).ok, "托管原物不能远程展示")
	check(state.execute_material("retrieve", "", ["relic"]).ok and state.ap == 2, "免费取回")
	check(state.execute_material("store", "mute", ["relic"]).ok and state.ap == 1, "重新托管重新付费")
	check(state.storage.mute.size() == 2 and state.inventory.size() == 3, "无重复材料或多持有人")
	state = route_a()
	state.execute_material("spread", "salt", ["record_1"])
	check(state.execute_material("retrieve", "", ["record_1"]).ok and state.ap == 2 and state.people.salt.alert == 55 and state.people.salt.informed, "普通撤回不退AP不降警戒不抹知情")
	check(state.spread.is_empty() and state.inventory.record_1.holder == "player", "撤回归还材料")
	check(state.execute_material("spread", "salt", ["record_1"]).ok and state.people.salt.alert == 65, "重新安排收费并进入暂停")
	state.end_day()
	check(state.spread.status == "failed" and state.publications.is_empty() and state.inventory.record_1.holder == "player", "传播暂停记录退还")
	check(state.departure_report.contains("进阶目标：未完成"), "暂停不计传播成果")
	# 专属撤回与普通取回不同。
	state = route_a()
	state.execute_material("store", "salt", ["relic"])
	state.execute_material("spread", "salt", ["record_1"])
	check(state.execute("withdraw").ok and state.ap == 0 and state.people.salt.alert == 45, "盐嫂专属撤回收费降警戒")
	check(state.salt_assistance_revoked and state.storage.salt.is_empty() and state.spread.is_empty() and state.inventory.relic.holder == "player" and state.inventory.record_1.holder == "player", "专属撤回归还全部材料并撤销资格")
	state = route_a()
	check(not state.execute_material("spread", "luo", ["record_1"]).ok, "螺螺不能传播")
	check(not state.execute_material("store", "mute", ["record_1"]).ok, "记录不能当原物托管")
	check(not state.execute_material("store", "mute", ["relic", "relic"]).ok, "不能重复选择同一材料")
	state.execute_material("store", "salt", ["relic"])
	check(state.execute_material("spread", "salt", ["relic"]).ok, "已经托管的同一原物可付费安排传播")
	state.people.salt.alert = 65
	state.end_day()
	check(state.inventory.relic.holder == "player" and state.storage.salt.is_empty() and state.publications.is_empty(), "离场协助失效原物退回，不没收")
	# 抄写摊无额外知情或警戒，记录也可展示。
	state = State.new()
	state.execute("feed")
	state.execute("listen")
	state.execute("relic")
	state.end_day()
	before = JSON.stringify(state.people)
	check(state.execute_material("record_scribe", "", ["relic"]).ok and state.food == 0 and state.ap == 2, "抄写摊费用")
	check(before == JSON.stringify(state.people), "抄写不增加知情警戒")
	check(state.execute_material("show", "luo", ["record_1"]).ok and state.people.luo.trust == 45 and state.people.luo.alert == 35, "记录可展示")
	check(not state.execute_material("show", "luo", ["relic"]).ok and state.ap == 1, "换来源类型不能重复展示")


func check_saves() -> void:
	var saver = load("res://scripts/story/trail2_save.gd")
	var folder := "/tmp/trail2-save-tests-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder + "/roundtrip.json"
	var view := {"selected_group": "salt", "text": "行动结果待阅读"}
	check(saver.load_from(path).missing, "无存档正常开始")
	var state = route_a()
	state.execute_material("store", "mute", ["fragment"])
	state.execute_material("spread", "salt", ["record_1"])
	check(saver.save_to(path, state, view) == OK, "写入复杂协助状态")
	var loaded: Dictionary = saver.load_from(path)
	check(loaded.ok and loaded.state.to_save_data() == state.to_save_data() and loaded.view == view, "所有状态和界面数据往返一致")
	check(not loaded.state.execute_material("show", "luo", ["fragment"]).ok, "读档后远处原物不可用")
	loaded.state.end_day()
	check(loaded.state.publications.size() == 1, "读档后待发传播正常结算一次")
	check(saver.save_to(path, loaded.state, view) == OK, "离场成果存档")
	var finished: Dictionary = saver.load_from(path)
	check(finished.ok and finished.state.village_finished and finished.state.to_save_data() == loaded.state.to_save_data(), "离场快照与成果往返一致")
	check(not finished.state.end_day().ok and finished.state.publications.size() == 1, "读档不重复离场发布")
	state = route_warning()
	var risk_path := folder + "/risk.json"
	saver.save_to(risk_path, state, view)
	loaded = saver.load_from(risk_path)
	check(loaded.ok and loaded.state.people.salt.warning_day == 3 and loaded.state.people.salt.alert == 75, "预警期限与巡查状态保留")
	loaded.state.end_day()
	check(loaded.state.ap == 2 and loaded.state.report_penalty.applied, "读档后到期处罚执行")
	saver.save_to(risk_path, loaded.state, view)
	loaded = saver.load_from(risk_path)
	loaded.state.end_day()
	check(loaded.state.ap == 3, "已执行处罚读档不重复扣除")
	# 末日预警不能因为读档提前到期。
	state = route_a()
	state.execute_material("show", "luo", ["relic"])
	state.people.luo.alert = 65
	state.refresh_warnings()
	state.end_day()
	saver.save_to(folder + "/pending.json", state, view)
	loaded = saver.load_from(folder + "/pending.json")
	check(loaded.state.people.luo.warning_day == 6 and not loaded.state.people.luo.reported, "第6天预警跨读档保留")
	# 主档损坏回退上一份；恢复后保存不能让损坏主档覆盖有效备份。
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	loaded = saver.load_from(path)
	check(loaded.ok and loaded.backup and not loaded.state.village_finished, "损坏主档恢复上一份备份")
	check(saver.save_to(path, loaded.state, view) == OK and saver.load_from(path).ok, "恢复后可以安全继续保存")
	check(saver.load_from(path + ".bak").ok, "有效备份未被损坏主档覆盖")
	var invalid_path := folder + "/invalid.json"
	file = FileAccess.open(invalid_path, FileAccess.WRITE)
	file.store_string("not json")
	file.close()
	check(not saver.load_from(invalid_path).ok and not saver.load_from(invalid_path).missing, "损坏存档区别于无存档")
	check(saver.save_to(folder + "/missing/slot.json", State.new(), view) != OK, "写入失败返回错误")
	var unsupported := folder + "/unsupported.json"
	saver.save_to(unsupported, State.new(), view)
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(unsupported))
	envelope.version = 99
	file = FileAccess.open(unsupported, FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope))
	file.close()
	check(not saver.load_from(unsupported).ok, "不兼容版本不错误读取")
	envelope.version = 1
	envelope.payload += " "
	file = FileAccess.open(unsupported, FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope))
	file.close()
	check(not saver.load_from(unsupported).ok, "校验和不匹配拒绝读取")
	# 校验失败必须原子拒绝，不部分覆盖当前状态。
	var untouched = State.new()
	var invalid: Dictionary = state.to_save_data()
	invalid.people.salt.alert = "bad"
	check(not untouched.restore_save_data(invalid) and untouched.day == 1 and untouched.people.salt.alert == 50, "无效字段不部分恢复")
	# 两次实例化模拟真正退出重进；预览确认前不扣费、不写入新行动。
	var scene = load("res://scenes/trail2.tscn").instantiate()
	scene.save_path = folder + "/ui.json"
	root.add_child(scene)
	await process_frame
	scene._select_person(0, "", "", null)
	scene._preview_action("feed")
	scene.modal._select("execute:feed")
	scene._preview_action("listen")
	scene.queue_free()
	await process_frame
	scene = load("res://scenes/trail2.tscn").instantiate()
	scene.save_path = folder + "/ui.json"
	root.add_child(scene)
	await process_frame
	check(scene.state.ap == 2 and scene.state.food == 1 and scene.state.completed.has("feed") and not scene.state.completed.has("listen"), "退出重进只恢复已确认行动")
	check(scene.selected_group == "salt" and not scene.modal.visible and scene.material_request.is_empty(), "恢复选择对象，不恢复未确认弹窗")
	scene._modal_selected("ask_restart")
	scene.modal._select("close")
	check(saver.load_from(scene.save_path).state.ap == 2, "取消重新开始不改存档")
	scene._modal_selected("ask_restart")
	scene.modal._select("restart")
	check(saver.load_from(scene.save_path).state.ap == 3 and scene.state.history.is_empty(), "确认重新开始写入新旅程")
	scene.queue_free()
	await process_frame
	scene = load("res://scenes/trail2.tscn").instantiate()
	scene.save_path = invalid_path
	root.add_child(scene)
	await process_frame
	check(scene.save_blocked, "坏档自动保存被暂停")
	scene._select_warehouse()
	check(FileAccess.get_file_as_string(invalid_path) == "not json", "坏档不被初始状态静默覆盖")
	scene.queue_free()
	await process_frame
