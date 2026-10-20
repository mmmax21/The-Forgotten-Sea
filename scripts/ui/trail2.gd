extends Control
## 十五天MVP主界面：仅呈现状态，规则与存档由独立模块负责。

const Save := preload("res://scripts/story/trail2_save.gd")
@export var save_path := "user://trail2_v1.json"
@export var persistence_enabled := true
var save_blocked := false
var save_label: Label

const Art := preload("res://scripts/ui/trial1_art.gd")
const Academy := preload("res://scripts/story/trail2_academy.gd")
const Business := preload("res://scripts/story/trail2_market_business.gd")
const Market := preload("res://scripts/story/trail2_market.gd")
const VillageStory := preload("res://scripts/story/trail2_village_story.gd")
const State := preload("res://scripts/story/trail2_state.gd")
const PERSON_IDS := ["salt", "mute", "luo"]

const Characters := preload("res://scripts/ui/character_card/default_characters.gd")
const Modal := preload("res://scripts/ui/story_modal.gd")
const PEOPLE := [
	{"name": "盐嫂", "portrait_index": 1, "trust": 40, "alert": 50, "intro": "盐嫂家里缺粮。你可以从帮助她的生活开始。"},
	{"name": "哑伯", "portrait_index": 3, "trust": 50, "alert": 40, "intro": "哑伯正在修整旧物，也许能辨认你找到的碎片。"},
	{"name": "螺螺", "portrait_index": 2, "trust": 35, "alert": 20, "intro": "螺螺提到遗迹附近的见闻。"},
]

var state = State.new()
var selected_group := ""
var action_list: VBoxContainer
var action_scroll: ScrollContainer
var modal: Control
var context_label: Label
var deadlines: Label
var region_background: TextureRect
var card_names: Array = []
var warehouse: Button
var next_day: Button
var material_request: Dictionary = {}
var feedback: Label
var scroll_hint: Label


func _ready() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Kaiti SC", "Songti SC", "Microsoft YaHei"])
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 24
	_build_context()
	modal = Modal.new()
	%Design.add_child(modal)
	resized.connect(_fit_design)
	_fit_design()
	modal.selected.connect(_modal_selected)
	_refresh()
	%CharacterRail.character_selected.connect(_select_person)
	%TopBar.action_pressed.connect(_toolbar)
	%MiniMap.action_pressed.connect(_minimap)
	%MiniMap.get_node("Compass").tooltip_text = "地图"
	%MiniMap.get_node("Upper").tooltip_text = "材料"
	%MiniMap.get_node("Lower").tooltip_text = "结束今日"
	%MapModal.configure({"show_ocean": false, "places": [{"id": "fishing_village", "reachable": true}, {"id": "ruins", "reachable": true}]})
	%MapModal.location_selected.connect(_select_map_location)
	%DialogueBox.show_text(VillageStory.OPENING)

	_load_progress()


func _build_context() -> void:
	region_background = TextureRect.new()
	region_background.size = Vector2(1920, 1032)
	region_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	region_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	region_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	region_background.modulate = Color(0.40, 0.40, 0.40, 1)
	%Design.add_child(region_background)
	%Design.move_child(region_background, 0)
	context_label = Label.new()
	context_label.position = Vector2(250, 210)
	context_label.size = Vector2(590, 95)
	context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_label.text = "渔村 · 第1—5天\n选择人物或遗迹，自由安排今天的3 AP。"
	%Design.add_child(context_label)
	warehouse = Button.new()
	warehouse.position = Vector2(250, 608)
	warehouse.size = Vector2(500, 42)
	region_background.texture = Art.BACKGROUNDS[state.current_location]
	warehouse.text = "返回渔村 · 1 AP" if state.current_location == "ruins" else "前往遗迹 · 1 AP"
	warehouse.pressed.connect(_select_warehouse)
	%Design.add_child(warehouse)
	action_scroll = ScrollContainer.new()
	action_scroll.position = Vector2(250, 305)
	action_scroll.size = Vector2(600, 265)
	action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	%Design.add_child(action_scroll)
	scroll_hint = Label.new()
	scroll_hint.position = Vector2(250, 572)
	scroll_hint.size = Vector2(600, 30)
	scroll_hint.add_theme_font_size_override("font_size", 22)
	%Design.add_child(scroll_hint)
	action_scroll.get_v_scroll_bar().changed.connect(_update_scroll_hint)
	action_scroll.get_v_scroll_bar().value_changed.connect(func(_value): _update_scroll_hint())
	feedback = Label.new()
	feedback.position = Vector2(1440, 730)
	feedback.size = Vector2(420, 240)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.add_theme_font_size_override("font_size", 24)
	feedback.text = "先选人物了解线索，或打开地图前往遗迹。\n查看免费，移动1 AP。"
	%Design.add_child(feedback)
	action_list = VBoxContainer.new()
	action_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_list.add_theme_constant_override("separation", 10)
	action_scroll.add_child(action_list)
	var deadline_scroll := ScrollContainer.new()
	deadline_scroll.position = Vector2(1440, 240)
	deadline_scroll.size = Vector2(420, 380)
	deadline_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	%Design.add_child(deadline_scroll)
	deadlines = Label.new()
	deadlines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deadlines.add_theme_font_size_override("font_size", 26)
	deadlines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	deadlines.text = "本地期限\n\n第3天开始：知情者警戒＋10\n第3天结束：安置窗口关闭\n第4天结束：遗迹关闭\n第5天结束：离开渔村"
	deadline_scroll.add_child(deadlines)
	next_day = Button.new()
	next_day.position = Vector2(1535, 650)
	next_day.text = "结束今日"
	next_day.pressed.connect(_ask_end_day)
	%Design.add_child(next_day)
	save_label = Label.new()
	save_label.position = Vector2(250, 1000)
	save_label.size = Vector2(1500, 30)
	save_label.add_theme_font_size_override("font_size", 18)
	save_label.text = "尚无存档；确认行动后自动保存"
	%Design.add_child(save_label)
	%Design.move_child(%MapModal, %Design.get_child_count() - 1)
	%Design.move_child(%Notice, %Design.get_child_count() - 1)


func _fit_design() -> void:
	var factor := minf(size.x / 1920.0, size.y / 1032.0)
	%Design.scale = Vector2.ONE * factor
	%Design.position = (size - Vector2(1920, 1032) * factor) / 2.0


func _summary(index: int) -> String:
	var person: Dictionary = state.people[PERSON_IDS[index]]
	var summary := "信任 %d · 警戒 %d · %s · %s" % [person.trust, person.alert, "已知情" if person.informed else "未知情", state.status(person)]
	if person.warning_day > 0:
		summary += " · 第%d天末复查" % person.warning_day
	return summary


func _refresh() -> void:
	if not state.academy.is_empty():
		_refresh_academy()
		return
	if not state.market.is_empty():
		_refresh_market()
		return
	region_background.texture = Art.BACKGROUNDS[state.current_location]
	warehouse.text = "返回渔村 · 1 AP" if state.current_location == "ruins" else "前往遗迹 · 1 AP"
	%MapModal.configure({"show_ocean": false, "places": [{"id": "fishing_village", "reachable": true}, {"id": "ruins", "reachable": true}]})
	%TopBar.apply_engine({
		"stats": [{"label": "粮食", "value": state.food}, {"label": "地区", "value": State.PLACE_NAMES[state.current_location]}],
		"buttons": [{"id": "tasks", "text": "手记"}, {"id": "items", "text": "材料"}, {"id": "status", "text": "人物"}, {"id": "settings", "text": "设置"}],
		"day": state.day, "total": 15, "ap": state.ap, "ap_max": 3,
	})
	var cards: Array = []
	for index in PEOPLE.size():
		var person: Dictionary = PEOPLE[index]
		cards.append({"name": person.name, "portrait": Characters.portrait(person.portrait_index), "summary": _summary(index)})
	_update_cards(cards)
	next_day.text = "查看阶段记录" if state.village_finished else ("结束第5天 · 离场" if state.day == 5 else "结束今日")
	var today := "第%d天 · 今日提醒" % state.day
	if state.village_finished:
		today += "\n渔村旅程已结束，查看交接记录后前往集市。"
	elif state.day == 5:
		today += "\n今晚离村：核对材料持有人与待执行安排。"
	elif state.day == 4:
		today += "\n遗迹今晚封闭，尚未搜查请抓紧。" if not state.completed.has("search") else "\n遗迹已搜查，可回村辨认或整理记录。"
	elif state.day == 3:
		today += "\n巡查已入村。安置窗口今晚关闭。"
	else:
		today += "\n安置需要同一天2 AP＋1粮食；第3天结束截止。"
	deadlines.text = today + "\n\n" + state.warning_text()
	deadlines.text += "\n\n本地期限\n第3天开始：巡查%s\n第3天末：安置%s\n第4天末：遗迹%s\n第5天末：离村" % ["（已发生）" if state.patrol_applied else "", "（已完成）" if state.completed.has("protect") else ("（已关闭）" if state.day > 3 else ""), "（已搜查）" if state.completed.has("search") else ("（已封闭）" if state.day > 4 else "")]
	if not state.report_penalty.is_empty():
		deadlines.text += "\n\n渔村处罚：第%d天少1 AP（%s）" % [state.report_penalty.due_day, "已执行" if state.report_penalty.applied else "待承接"]
	_refresh_actions()


func _refresh_actions() -> void:
	for child in action_list.get_children():
		action_list.remove_child(child)
		child.queue_free()
	if selected_group.is_empty():
		context_label.text = "渔村阶段已结束，可查看阶段记录。" if state.village_finished else "渔村 · 第%d天\n选择人物或遗迹，自由安排行动。" % state.day
		return
	if selected_group == "warehouse":
		context_label.text = "遗迹 · " + ("已封闭，可返回渔村" if state.day > 4 else "第4天结束关闭") + "\n" + ("已搜查" if state.completed.has("search") else ("已找到准确入口" if state.entrance_known else "尚不知道准确入口"))
	else:
		var index: int = PERSON_IDS.find(selected_group)
		var person: Dictionary = state.people[selected_group]
		context_label.text = "%s · 信任%d · 警戒%d\n%s · %s" % [PEOPLE[index].name, person.trust, person.alert, state.status(person), "已知情" if person.informed else "未知情"]
	if state.village_finished:
		context_label.text = "渔村阶段已结束，可查看材料、人物及阶段记录。"
		return
	if state.ap == 0:
		context_label.text += " · AP 0"
	var pending: Array = []
	var done: Array = []
	for id in state.actions_for(selected_group):
		if state.completed.has(id):
			done.append(id)
		else:
			pending.append(id)
	pending.sort_custom(func(a, b): return _action_priority(a) < _action_priority(b))
	for id in pending:
		var action: Dictionary = state.action_definition(id)
		var reasons: PackedStringArray = state.blocked_reasons(id)
		var button := Button.new()
		var note := "查看效果与风险" if reasons.is_empty() else reasons[0]
		if id == "press_relic" and reasons.is_empty():
			var projected: Dictionary = state._person_after(action)
			note = "风险：第%d天末可能告密" % projected.warning_day if projected.warning_day > 0 else "风险：信任−10、警戒＋15"
		if id == "protect" and state.day <= 3:
			note = "今晚截止" if state.day == 3 else "第3天末截止，需同日留足2 AP"
			if state.food == 0:
				note += " · 缺少粮食"
		button.text = "%s · %d AP%s\n%s" % [action.title, action.ap, "＋%d粮食" % action.food if action.get("food", 0) > 0 else "", note]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 82
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 26)
		button.set_meta("action_id", id)
		button.tooltip_text = "；".join(reasons)
		button.pressed.connect(_preview_action.bind(id))
		action_list.add_child(button)
	if selected_group in PERSON_IDS:
		var kinds := ["show"]
		if selected_group in ["salt", "mute"]:
			kinds.append("store")
		if selected_group == "salt":
			kinds.append("spread")
		for kind in kinds:
			var button := Button.new()
			button.text = State.MATERIAL_ACTIONS[kind].title + " · 1 AP · 选材料…"
			button.custom_minimum_size.y = 60
			button.pressed.connect(_begin_material.bind(kind, selected_group))
			action_list.add_child(button)

	if not done.is_empty():
		var completed_button := Button.new()
		completed_button.text = "已完成 %d 项 · 查看记录" % done.size()
		completed_button.custom_minimum_size.y = 54
		completed_button.pressed.connect(_show_completed.bind(done))
		action_list.add_child(completed_button)
	_update_scroll_hint.call_deferred()


func _action_priority(id: String) -> int:
	if id == "protect" and state.completed.has("listen") and state.day <= 3:
		return -1
	if state.blocked_reasons(id).is_empty():
		return 0
	return 2 if state.day > int(State.ACTIONS[id].get("last_day", 5)) else 1


func _show_completed(ids: Array) -> void:
	var lines := PackedStringArray()
	for id in ids:
		lines.append("✓ " + State.ACTIONS[id].title + "\n" + VillageStory.action(state, id))
	_message("已完成的行动", "\n\n".join(lines))


func _update_scroll_hint() -> void:
	if not is_instance_valid(scroll_hint) or not is_instance_valid(action_scroll):
		return
	var bar := action_scroll.get_v_scroll_bar()
	scroll_hint.text = "↓ 下方还有行动，滚动查看" if bar.max_value > bar.page + bar.value + 2 else ("↑ 可向上查看其他行动" if bar.value > 0 else "点击行动查看条件，确认后才扣点")


func _show_feedback(before: Dictionary, title: String) -> void:
	action_scroll.scroll_vertical = 0
	var changes := PackedStringArray([title + " · 已完成", "消耗%d AP · 剩余%d AP" % [int(before.ap) - state.ap, state.ap]])
	if int(before.food) != state.food:
		changes.append("粮食 %d → %d" % [before.food, state.food])
	for npc in PERSON_IDS:
		var old: Dictionary = before.people[npc]
		var now: Dictionary = state.people[npc]
		if old != now:
			changes.append("%s：信任%d→%d\n警戒%d→%d · %s" % [State.NAMES[npc], old.trust, now.trust, old.alert, now.alert, state.status(now)])
	feedback.text = "\n".join(changes)


func _select_person(index: int, _name: String, _summary_text: String, _portrait: Texture2D) -> void:
	if modal.visible or %MapModal.visible:
		return
	if not state.academy.is_empty():
		selected_group = Academy.IDS[index]
		%PortraitPanel.hide_portrait()
		_refresh_academy()
		%DialogueBox.show_text("%s：请查看当前可提供的协助和行动条件。" % Academy.NAMES[selected_group])
		_autosave()
		return
	if not state.market.is_empty():
		selected_group = Market.IDS[index]
		%PortraitPanel.hide_portrait()
		_refresh_market()
		%DialogueBox.show_text("%s：可以免费了解合作条件，再决定行动。" % Market.NAMES[selected_group])
		_autosave()
		return
	if state.current_location != "fishing_village" and not state.village_finished:
		_request_travel("fishing_village", index)
		return
	var person: Dictionary = PEOPLE[index]
	selected_group = PERSON_IDS[index]
	%PortraitPanel.show_portrait(person.portrait_index, person.name, " ")
	_refresh_actions()
	action_scroll.scroll_vertical = 0
	%DialogueBox.show_text(VillageStory.greeting(state, selected_group))
	_autosave()


func _select_warehouse() -> void:
	if modal.visible or %MapModal.visible:
		return
	if not state.academy.is_empty():
		selected_group = "archive"
		%PortraitPanel.hide_portrait()
		_refresh_academy()
		%DialogueBox.show_text(Academy.archive_status(state))
		_autosave()
		return
	if not state.market.is_empty():
		selected_group = "research"
		%PortraitPanel.hide_portrait()
		_refresh_market()
		%DialogueBox.show_text(Market.DECREE)
		_autosave()
		return
	_request_travel("fishing_village" if state.current_location == "ruins" else "ruins")


func _show_ruins() -> void:
	selected_group = "warehouse"
	%PortraitPanel.hide_portrait()
	_refresh_actions()
	action_scroll.scroll_vertical = 0
	%DialogueBox.show_text(VillageStory.ruins(state))
	_autosave()


func _preview_action(id: String) -> void:
	if modal.visible or %MapModal.visible:
		return
	var preview: Dictionary = state.preview(id)
	modal.open(state.action_definition(id).title, preview.text, [
		{"id": "execute:" + id, "text": "确认执行", "disabled": not preview.allowed},
		{"id": "close", "text": "返回，不执行"},
	])


func _modal_selected(id: String) -> void:
	if id.begins_with("travel:"):
		var parts := id.split(":")
		var result: Dictionary = state.travel(parts[1])
		if result.ok:
			selected_group = "warehouse" if state.current_location == "ruins" else ""
			%PortraitPanel.hide_portrait()
			_refresh()
			if state.current_location == "ruins":
				_show_ruins()
			elif int(parts[2]) >= 0:
				_select_person(int(parts[2]), "", "", null)
			feedback.text = result.text
			if state.current_location == "fishing_village" and int(parts[2]) < 0:
				%DialogueBox.show_text("你沿小路回到渔村。带回来的发现，可以找村民辨认，也可以在材料页整理成记录。")
			_autosave()
		else:
			_message("无法移动", result.text)
	elif id == "enter_academy":
		var result: Dictionary = Academy.enter(state)
		if result.ok:
			selected_group = "archive"
			%PortraitPanel.hide_portrait()
			_refresh()
			%DialogueBox.show_text(result.text)
			_autosave()
	elif id.begins_with("academy_execute:"):
		var result: Dictionary = Academy.execute(state, id.trim_prefix("academy_execute:"))
		_refresh()
		%DialogueBox.show_text(result.text)
		if result.ok:
			_autosave()
	elif id.begins_with("ending:"):
		var result: Dictionary = Academy.finish(state, id.trim_prefix("ending:"))
		_refresh()
		%DialogueBox.show_text(result.text)
		if result.ok:
			_autosave()
			_message("终局与后日谈", result.text)
	elif id == "enter_market":
		var result: Dictionary = Market.enter(state)
		if result.ok:
			selected_group = "research"
			%PortraitPanel.hide_portrait()
			_refresh()
			%DialogueBox.show_text(result.text)
			_autosave()
	elif id.begins_with("business_execute:"):
		var result: Dictionary = Business.execute(state, id.trim_prefix("business_execute:"))
		_refresh()
		%DialogueBox.show_text(result.text)
		if result.ok:
			_autosave()
	elif id.begins_with("market_execute:"):
		var result: Dictionary = Market.execute(state, id.trim_prefix("market_execute:"))
		_refresh()
		%DialogueBox.show_text(result.text)
		if result.ok:
			_autosave()
	elif id == "retry_save":
		_autosave()
	elif id == "ask_load":
		modal.open("读取最近存档？", "将恢复最近一次成功保存的进度；未保存的本次变化将丢失。", [{"id": "load", "text": "确认读取"}, {"id": "close", "text": "取消"}])
	elif id == "load":
		_load_progress()
	elif id.begins_with("material_kind:"):
		var parts := id.split(":")
		_begin_material(parts[1], "")
	elif id.begins_with("pick_material:"):
		var key := id.trim_prefix("pick_material:")
		if material_request.is_empty():
			return
		if material_request.kind == "store":
			if material_request.ids.has(key):
				material_request.ids.erase(key)
			elif material_request.ids.size() < 2:
				material_request.ids.append(key)
			_material_picker()
		else:
			material_request.ids = [key]
			_review_material()
	elif id in ["material_next", "material_previous"] and not material_request.is_empty():
		material_request.page += 1 if id == "material_next" else -1
		_material_picker()
	elif id == "review_material":
		_review_material()
	elif id == "choose_material_again":
		_material_picker()
	elif id == "confirm_material" and not material_request.is_empty():
		var before := state.to_save_data()
		var kind: String = material_request.kind
		var npc: String = material_request.npc
		var result: Dictionary = state.execute_material(material_request.kind, material_request.npc, material_request.ids)
		material_request.clear()
		_refresh()
		%DialogueBox.show_text(VillageStory.material(kind, npc, state) if result.ok else result.text)
		if result.ok:
			_show_feedback(before, State.MATERIAL_ACTIONS[kind].title)
			_autosave()
	elif id == "ask_restart":
		modal.open("重新试玩第1天？", "这会重置当前旅程，并用新进度替换当前存档。是否从第1天重新开始？", [{"id": "restart", "text": "确定重新开始"}, {"id": "close", "text": "取消"}])
	elif id == "restart":
		state = State.new()
		save_blocked = false
		material_request.clear()
		selected_group = ""
		%PortraitPanel.hide_portrait()
		context_label.text = "渔村 · 第1天\n选择人物或遗迹，自由安排今天的3 AP。"
		_refresh()
		%DialogueBox.show_text(VillageStory.OPENING)
		feedback.text = "新旅程 · 3 AP · 2份粮食\n查看免费；移动1 AP。"
		_autosave()
	elif id == "village_report":
		_ask_end_day()
	elif id.begins_with("end_day:"):
		var result: Dictionary = state.end_day(int(id.trim_prefix("end_day:")))
		_refresh()
		if result.ok and state.market.is_empty():
			feedback.text = "渔村旅程结束 · 可查看交接记录" if state.village_finished else "第%d天开始 · %d AP · %d粮食\n%s" % [state.day, state.ap, state.food, state.warning_text()]
			%DialogueBox.show_text("离村前，你回望这五天结识的人。交接记录会列出带走和留下的材料。" if state.village_finished else VillageStory.morning(state))
			if state.village_finished:
				modal.open("第五天 · 离村", VillageStory.farewell(state), [{"id": "village_report", "text": "查看交接记录与下一站"}, {"id": "close", "text": "留在这里回看"}])
			else:
				_message("昨夜结算与今日事件", result.text)
		else:
			%DialogueBox.show_text(result.text)
			_message("每日结算", result.text)
		if result.ok:
			_autosave()
	elif id.begins_with("execute:"):
		var action_id := id.trim_prefix("execute:")
		var before := state.to_save_data()
		var result: Dictionary = state.execute(action_id)
		_refresh()
		%DialogueBox.show_text(VillageStory.action(state, action_id) if result.ok else result.text)
		if result.ok:
			_show_feedback(before, state.action_definition(action_id).title)
			_autosave()


func _message(title: String, message: String) -> void:
	modal.open(title, message, [{"id": "close", "text": "返回"}])


func _toolbar(id: String) -> void:
	if modal.visible or %MapModal.visible:
		return
	match id:
		"tasks": _message("调查手记", "基本目标：带走已确认的海洋证据或记录。\n进阶目标：建立有效保管或传播安排。\n记录制作：顶部「材料」→自行记录或村口抄写摊。\n移动每次1 AP；同一天内付清行动成本。\n\n调查历程：\n" + ("尚无行动" if state.history.is_empty() else "\n\n".join(state.history)))
		"items":
			var entries := PackedStringArray(["粮食%d份 · 自带调查笔记" % state.food])
			for item in state.inventory.values():
				entries.append("%s · %s · %s\n持有人：%s · 位置：%s\n来源：%s" % [item.name, "已确认" if item.confirmed else "待辨认", {"original": "原物", "record": "记录", "draft": "调查底稿"}.get(item.kind, item.kind), State.NAMES.get(item.holder, "玩家"), ("随身携带" if item.location == "inventory" else item.location), _source_name(item.source)])
			if state.inventory.is_empty():
				entries.append("尚无海洋证据。")
			entries.append(state.arrangements_text())
			if not state.market.is_empty():
				entries.append(Business.summary(state))
			var options: Array = []
			if not state.village_finished:
				for kind in ["record_self", "record_scribe", "retrieve"]:
					options.append({"id": "material_kind:" + kind, "text": State.MATERIAL_ACTIONS[kind].title})
			options.append({"id": "close", "text": "返回"})
			modal.open("材料与安排", "\n\n".join(entries), options)
		"status":
			var lines := PackedStringArray()
			for npc in state.people:
				var person: Dictionary = state.people[npc]
				lines.append("%s：T%d / A%d · %s" % [State.NAMES[npc], person.trust, person.alert, state.status(person)])
			_message("人物状态", "\n\n".join(lines))
		"settings": modal.open("试玩设置", "当前可试玩渔村、集市、旧学城共15天，以及终局和人物后日谈。查看信息、同地切换人物免费；移动到其他地点消耗1 AP，区域间移动从抵达当天扣除。\n\n已开放制作记录、展示、托管、传播与渔村离场结算。行动及每日结算后自动保存，重新打开场景会恢复进度。预览未确认的行动不会执行。渔村离场报告可进入集市。集市已开放传播与商队；旧学城包含档案、观测、发布和法器线。", [{"id": "retry_save", "text": "保存当前进度"}, {"id": "ask_load", "text": "读取最近存档…"}, {"id": "ask_restart", "text": "重新试玩第1天…"}, {"id": "close", "text": "返回"}])


func _minimap(id: String) -> void:
	if modal.visible or %MapModal.visible:
		return
	match id:
		"compass": %MapModal.open()
		"rim_upper": _toolbar("items")
		"rim_lower": _ask_end_day()


func _ask_end_day() -> void:
	if modal.visible or %MapModal.visible:
		return
	if not state.academy.is_empty() and state.academy.ended:
		if state.academy.finished:
			_message("终局与后日谈", state.academy.report)
		else:
			modal.open("法器最终处置", "你已经取得法器。以下选择不消耗AP，也不能补做调查。现实与制度成果分别保留。", [{"id": "ending:take", "text": "接管认知控制", "disabled": not Academy.active_channel(state)}, {"id": "ending:keep", "text": "保留法器，拒绝操控"}, {"id": "ending:return", "text": "交还疯祭司"}, {"id": "close", "text": "先回看材料"}])
		return
	if state.academy.is_empty() and not state.market.is_empty() and state.market.finished:
		modal.open("集市离场记录", state.market.report, [{"id": "enter_academy", "text": "前往旧学城 · 第11天扣1 AP"}, {"id": "close", "text": "返回查看"}])
		return
	if state.village_finished and state.market.is_empty():
		modal.open("渔村离场报告", state.departure_report, [{"id": "enter_market", "text": "前往集市 · 第6天扣1 AP"}, {"id": "close", "text": "返回查看"}])
		return
	var preview: Dictionary = state.end_day_preview()
	modal.open("结束第%d天？" % state.day, preview.text, [
		{"id": "end_day:%d" % state.day, "text": "确认结束", "disabled": not preview.allowed},
		{"id": "close", "text": "继续今天的行动"},
	])


func _request_travel(destination: String, person_index: int = -1) -> void:
	var preview: Dictionary = state.travel_preview(destination)
	modal.open("前往" + str(State.PLACE_NAMES.get(destination, destination)), preview.text, [
		{"id": "travel:%s:%d" % [destination, person_index], "text": "确认移动 · 1 AP", "disabled": not preview.allowed},
		{"id": "close", "text": "返回"},
	])


func _select_map_location(id: String) -> void:
	%MapModal.hide()
	if id == state.current_location:
		_message("当前位置", "你已经在%s，查看地图不消耗AP。" % State.PLACE_NAMES[id])
	elif state.market.is_empty() and not state.village_finished:
		_request_travel(id)
	else:
		_message("地图", "当前地区：%s。查看地图免费；离场报告中的跨区移动消耗抵达当天的1 AP。" % State.PLACE_NAMES[state.current_location])


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		modal.hide()
		%MapModal.hide()
		get_viewport().set_input_as_handled()


func _begin_material(kind: String, npc: String) -> void:
	if modal.visible or %MapModal.visible:
		return
	material_request = {"kind": kind, "npc": npc, "ids": [], "page": 0}
	_material_picker()


func _material_picker() -> void:
	if material_request.is_empty():
		return
	var options: Array = []
	var keys: Array = state.inventory.keys()
	var first: int = int(material_request.page) * 4
	for id in keys.slice(first, first + 4):
		var item: Dictionary = state.inventory[id]
		options.append({"id": "pick_material:" + id, "text": ("✓ " if material_request.ids.has(id) else "") + item.name + " · " + str(State.NAMES.get(item.holder, "玩家")) + "持有"})
	if first > 0:
		options.append({"id": "material_previous", "text": "上一页"})
	if first + 4 < keys.size():
		options.append({"id": "material_next", "text": "下一页"})
	if material_request.kind == "store":
		options.append({"id": "review_material", "text": "预览所选材料的保管安排", "disabled": material_request.ids.is_empty()})
	options.append({"id": "close", "text": "返回，不执行"})
	modal.open(State.MATERIAL_ACTIONS[material_request.kind].title, "请选择材料。保管可勾选最多两件原物，一次交接共1 AP。其余行动选择一件后查看详情。\n不满足条件的材料会说明原因，不能确认执行。" if not state.inventory.is_empty() else "尚无材料，请先调查遗迹或取得遗物。", options)


func _review_material() -> void:
	if material_request.is_empty():
		return
	var preview: Dictionary = state.material_preview(material_request.kind, material_request.npc, material_request.ids)
	modal.open(State.MATERIAL_ACTIONS[material_request.kind].title, preview.text, [
		{"id": "confirm_material", "text": "确认执行", "disabled": not preview.allowed},
		{"id": "choose_material_again", "text": "重新选择材料"},
		{"id": "close", "text": "返回，不执行"},
	])


func _autosave() -> void:
	if not persistence_enabled:
		return
	if save_blocked:
		save_label.text = "存档无法读取，自动保存已暂停以保留原文件。可在设置中重试读取，或确认重新开始。"
		return
	var error: Error = Save.save_to(save_path, state, {"selected_group": selected_group, "text": %DialogueBox.dialogue_text})
	save_label.text = "已自动保存 · 第%d天 · %d AP" % [state.day, state.ap] if error == OK else "保存失败（%s）：当前变化仅在内存中，请在设置中重试保存后再退出。" % error_string(error)


func _load_progress() -> void:
	if not persistence_enabled:
		return
	var loaded: Dictionary = Save.load_from(save_path)
	if not loaded.ok:
		if loaded.get("missing", false):
			save_label.text = "尚无存档；确认行动后自动保存"
		else:
			save_blocked = true
			save_label.text = "存档无法读取（损坏或版本不兼容），原文件已保留。请在设置中重试读取或确认重新开始。"
		return
	state = loaded.state
	selected_group = loaded.view.selected_group
	material_request.clear()
	save_blocked = false
	modal.hide()
	%MapModal.hide()
	_refresh()
	if selected_group in PERSON_IDS:
		var person: Dictionary = PEOPLE[PERSON_IDS.find(selected_group)]
		%PortraitPanel.show_portrait(person.portrait_index, person.name, " ")
	else:
		%PortraitPanel.hide_portrait()
	%DialogueBox.show_text(loaded.view.text)
	save_label.text = "主存档无法读取，已恢复上一份有效备份；请核对进度。" if loaded.backup else "已读取存档 · 第%d天 · %d AP" % [state.day, state.ap]


func _refresh_market() -> void:
	feedback.text = "集市 · 查看人物与材料，继续核验线索。"
	region_background.texture = Art.BACKGROUNDS.market
	warehouse.text = "核验材料／查看禁令"
	%TopBar.apply_engine({"stats": [{"label": "粮食", "value": state.food}, {"label": "地区", "value": "集市"}], "buttons": [{"id": "tasks", "text": "手记"}, {"id": "items", "text": "材料"}, {"id": "status", "text": "人物"}, {"id": "settings", "text": "设置"}], "day": state.day, "total": 15, "ap": state.ap, "ap_max": 3})
	var cards: Array = []
	for npc in Market.IDS:
		var person: Dictionary = state.people[npc]
		cards.append({"name": Market.NAMES[npc], "summary": "信任%d · 警戒%d · %s" % [person.trust, person.alert, state.status(person)], "portrait": null})
	_update_cards(cards)
	%MapModal.configure({"show_ocean": false, "places": [{"id": "market", "reachable": true}]})
	next_day.text = "查看集市记录" if state.market.finished else "结束今日"
	deadlines.text = "集市期限\n第8天末：旅客证言截止\n第9天：检查\n第10天末：商队出发\n\n已开放调查、传播与渠道。检查名单在当天开始时公布。\n\n%s\n\n已确认：%s" % [state.warning_text(), "、".join(state.market.claims.keys())]
	deadlines.text += "\n\n" + Business.inspection_text(state)
	for child in action_list.get_children():
		action_list.remove_child(child)
		child.queue_free()
	context_label.text = "集市 · 第%d天 · %d AP\n%s" % [state.day, state.ap, Market.NAMES.get(selected_group, "选择人物或核验材料")]
	if selected_group in Market.IDS:
		var person: Dictionary = state.people[selected_group]
		context_label.text += "\n信任%d · 警戒%d · %s" % [person.trust, person.alert, state.status(person)]
	if state.market.finished:
		return
	for id in Market.ACTIONS:
		var action: Dictionary = Market.ACTIONS[id]
		if action.get("npc", "research") == selected_group:
			_market_button(id, action.title)
	for option in Business.options(state, selected_group):
		var button := Button.new()
		button.text = option.title
		button.custom_minimum_size.y = 65
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_preview_business.bind(option.id))
		action_list.add_child(button)
	if state.day == 6:
		for npc in ["salt", "mute", "luo"]:
			if state.people[npc].warning_day == 6:
				_market_button("messenger_" + npc, "向%s传话补救" % State.NAMES[npc])


func _market_button(id: String, title: String) -> void:
	var preview: Dictionary = Market.preview(state, id)
	var button := Button.new()
	button.text = title + (" · 查看并执行" if preview.allowed else " · 查看缺少条件")
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 70
	button.pressed.connect(_preview_market.bind(id))
	action_list.add_child(button)


func _preview_market(id: String) -> void:
	if modal.visible or %MapModal.visible:
		return
	var preview: Dictionary = Market.preview(state, id)
	modal.open("集市行动", preview.text, [{"id": "market_execute:" + id, "text": "确认执行", "disabled": not preview.allowed}, {"id": "close", "text": "返回，不执行"}])


func _preview_business(id: String) -> void:
	if modal.visible or %MapModal.visible:
		return
	var preview: Dictionary = Business.preview(state, id)
	modal.open("集市业务", preview.text, [{"id": "business_execute:" + id, "text": "确认执行", "disabled": not preview.allowed}, {"id": "close", "text": "返回"}])


func _refresh_academy() -> void:
	feedback.text = "旧学城 · 核对档案、观测与发布窗口。"
	region_background.texture = Art.BACKGROUNDS.old_academy
	warehouse.text = "档案、观测与法器调查"
	%TopBar.apply_engine({"stats": [{"label": "粮食", "value": state.food}, {"label": "地区", "value": "旧学城"}], "buttons": [{"id": "tasks", "text": "手记"}, {"id": "items", "text": "材料"}, {"id": "status", "text": "人物"}, {"id": "settings", "text": "设置"}], "day": state.day, "total": 15, "ap": state.ap, "ap_max": 3})
	var cards: Array = []
	for npc in Academy.IDS:
		var person: Dictionary = state.people[npc]
		cards.append({"name": Academy.NAMES[npc], "summary": "T%d / A%d · %s" % [person.trust, person.alert, state.status(person)], "portrait": null})
	_update_cards(cards)
	%MapModal.configure({"show_ocean": state.academy.flags.get("sea_returned", false), "places": [{"id": "old_academy", "reachable": true}]})
	next_day.text = ("查看终局" if state.academy.finished else "决定法器处置") if state.academy.ended else ("结束第15天 · 终局" if state.day == 15 else "结束今日")
	deadlines.text = "旧学城期限\n第13天末：关闭普通调阅\n第14天末：销毁指定材料\n第15天：定本审议\n\n%s\n\nP3：%s · P4：%s\n%s" % [Academy.archive_status(state), "已确认" if Academy.has(state, "P3") else "未确认", "已确认" if Academy.has(state, "P4") else "未确认", state.warning_text()]
	for child in action_list.get_children():
		action_list.remove_child(child)
		child.queue_free()
	context_label.text = "旧学城 · 第%d天 · %d AP\n%s" % [state.day, state.ap, Academy.NAMES.get(selected_group, "调查档案与观测")]
	if selected_group in Academy.IDS:
		var person: Dictionary = state.people[selected_group]
		context_label.text += "\nT%d / A%d · %s" % [person.trust, person.alert, state.status(person)]
	if state.academy.ended:
		return
	for option in Academy.options(state, selected_group):
		var button := Button.new()
		var preview: Dictionary = Academy.preview(state, option.id)
		button.text = option.title + (" · 查看并执行" if preview.allowed else " · 查看条件")
		button.custom_minimum_size.y = 65
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_preview_academy.bind(option.id))
		action_list.add_child(button)


func _preview_academy(id: String) -> void:
	if modal.visible or %MapModal.visible:
		return
	var preview: Dictionary = Academy.preview(state, id)
	modal.open("学城行动", preview.text, [{"id": "academy_execute:" + id, "text": "确认执行", "disabled": not preview.allowed}, {"id": "close", "text": "返回"}])


func _update_cards(cards: Array) -> void:
	var names: Array = []
	for card in cards:
		names.append(card.name)
	if names != card_names:
		card_names = names
		%CharacterRail.configure(cards)
		return
	# 点击信号仍在调用栈中时，不销毁正在发出信号的卡片。
	var nodes := %CharacterRail.get_node("Cards").get_children()
	for i in cards.size():
		var card: Dictionary = cards[i]
		nodes[i].configure(card.name, card.get("portrait"), card.summary, false, true, i)


func _source_name(source: String) -> String:
	return {"husband_relic": "盐嫂丈夫遗物", "warehouse_fragment": "渔村遗迹", "academy_antique_batch_a": "旧学城旧港古物批次", "traveler_east_port": "异地旅客亲历", "revision_batch_a": "海港篇修订批次A", "academy_revision_a": "学城修订批次A", "academy_museum": "旧港器具原始入藏记录", "academy_observations": "旧水槽历史观测", "academy_early": "早期封闭案卷", "academy_running": "法器维护档案"}.get(source, source)
