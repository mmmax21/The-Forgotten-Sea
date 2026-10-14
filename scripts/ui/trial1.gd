extends Control
## Standalone MVP scene; does not change the existing chapter or its save.
const Dialogue := preload("res://scripts/story/trial1_dialogue.gd")
const Art := preload("res://scripts/ui/trial1_art.gd")
const State := preload("res://scripts/story/trial1_state.gd")
const Characters := preload("res://scripts/ui/character_card/default_characters.gd")
const MapScene := preload("res://scenes/ui/popup/map_modal.tscn")
const GOLD := Color("d5bb83")
const PAPER := Color("ece2cd")
const MUTED := Color("b5c4c0")
@export var save_path := "user://trial1_v1.json"
var state = State.new()
var heading: Label
var subtitle: Label
var choice_scroll: ScrollContainer
var continue_hint: Label
var dialogue = Dialogue.new()
var actions: VBoxContainer
var side: VBoxContainer
var save_label: Label
var map_modal
var overlay: Control
var overlay_body: VBoxContainer
var overlay_actions: VBoxContainer
var save_error := ""
var rail_names: Array = []

func _ready() -> void:
	_build_theme()
	_build_ui()
	resized.connect(_fit)
	_fit()
	%TopBar.action_pressed.connect(_toolbar)
	%CharacterRail.character_selected.connect(_on_character_selected)
	%DialogueBox.dialogue_finished.connect(_on_dialogue_finished)
	%DialogueBox.line_presented.connect(_on_line_presented)
	%MiniMap.action_pressed.connect(_minimap)
	%MiniMap.get_node("Compass").tooltip_text = "地图"
	%MiniMap.get_node("Upper").tooltip_text = "证据"
	%MiniMap.get_node("Lower").tooltip_text = "调查手记"
	if FileAccess.file_exists(save_path) and not state.load_from(save_path):
		save_error = "旧试玩存档无法读取。已打开新流程；原文件会保留备份。"
		var backup_error := DirAccess.copy_absolute(save_path, save_path + ".unreadable")
		if backup_error != OK:
			save_error = "存档无法读取，且无法备份。请在设置中重开前检查保存目录。"
			save_path += ".recovered"
	_refresh()

func _build_theme() -> void:
	var skin := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC", "Microsoft YaHei", "Noto Sans CJK SC"])
	skin.default_font = font
	skin.default_font_size = 25
	skin.set_color("font_color", "Label", PAPER)
	for kind in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("213b40") if kind == "normal" else Color("315259")
		if kind == "disabled":
			style.bg_color = Color("202b2d")
		style.border_color = GOLD if kind in ["hover", "focus"] else Color("52635b")
		style.set_border_width_all(2 if kind == "focus" else 1)
		style.set_corner_radius_all(8)
		style.content_margin_left = 24
		style.content_margin_right = 24
		style.content_margin_top = 14
		style.content_margin_bottom = 14
		skin.set_stylebox(kind, "Button", style)
	skin.set_color("font_color", "Button", PAPER)
	skin.set_color("font_hover_color", "Button", Color.WHITE)
	skin.set_color("font_disabled_color", "Button", Color("95a09b"))
	theme = skin

func _panel(pos: Vector2, extent: Vector2, parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.position = pos
	panel.size = extent
	var style := StyleBoxFlat.new()
	style.bg_color = Color("11262d")
	style.border_color = Color("68766a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	return box

func _text(parent: Node, value: String, font_size := 25, color := PAPER) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.03, 0.03, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.03, 0.8))
	label.add_theme_constant_override("outline_size", 3)
	parent.add_child(label)
	return label

func _button(parent: Node, value: String, id: String, callback: Callable, disabled := false) -> Button:
	var button := Button.new()
	button.text = value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 60
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled
	button.set_meta("action_id", id)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _scroll_column(parent: Node) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 18)
	scroll.add_child(column)
	return column

func _build_ui() -> void:
	var title := _text(%Design, "被 遗 忘 的 海", 42, GOLD)
	title.position = Vector2(1020, 42)
	title.size = Vector2(600, 70)
	var edition := _text(%Design, "十五回合 · 调查手记", 24, MUTED)
	edition.position = Vector2(1025, 120)
	edition.size = Vector2(600, 40)
	subtitle = _text(%Design, "", 24, GOLD)
	subtitle.position = Vector2(250, 238)
	subtitle.size = Vector2(730, 38)
	heading = _text(%Design, "", 34)
	heading.position = Vector2(250, 280)
	heading.size = Vector2(730, 62)
	choice_scroll = ScrollContainer.new()
	%Design.add_child(choice_scroll)
	choice_scroll.position = Vector2(250, 350)
	choice_scroll.size = Vector2(730, 340)
	choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	actions = VBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 12)
	choice_scroll.add_child(actions)
	var right := _panel(Vector2(1440, 260), Vector2(450, 420), %Design)
	side = _scroll_column(right)
	continue_hint = _text(%Design, "", 22, GOLD)
	continue_hint.position = Vector2(340, 950)
	continue_hint.size = Vector2(950, 35)
	continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	continue_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	save_label = _text(%Design, "", 20, MUTED)
	save_label.position = Vector2(250, 1042)
	save_label.size = Vector2(1640, 30)
	map_modal = MapScene.instantiate()
	%Design.add_child(map_modal)
	map_modal.hide()
	map_modal.location_selected.connect(_map_place)
	overlay = Control.new()
	%Design.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.025, 0.03, 0.93)
	var box := _panel(Vector2(360, 110), Vector2(1200, 860), overlay)
	overlay_body = _scroll_column(box)
	overlay_actions = VBoxContainer.new()
	overlay_actions.add_theme_constant_override("separation", 12)
	box.add_child(overlay_actions)
	overlay.hide()

func _fit() -> void:
	var factor := minf(size.x / 1920.0, size.y / 1080.0)
	%Design.scale = Vector2.ONE * factor
	%Design.position = (size - Vector2(1920, 1080) * factor) / 2.0

func _clear(parent: Node) -> void:
	for node in parent.get_children():
		parent.remove_child(node)
		node.queue_free()

func stage() -> String:
	return str(state.presentation.get("stage", "idle"))

func busy() -> bool:
	return stage() in ["opening", "result", "closing", "ending"]

func current_actor() -> String:
	return {4: "河边村民", 5: "集会村民", 14: "档案管理员", 15: "学者"}.get(state.round_number, str(state.event().actor))

func portrait_index(person: String) -> int:
	return int({"螺螺": 2, "哑伯": 3, "盐嫂": 1, "老渔夫": 0}.get(person, -1))

func _people() -> Array:
	var active := current_actor()
	var names: Array = ["螺螺", "哑伯", "盐嫂", "集会村民" if state.round_number == 5 else "河边村民"]
	if state.region() == 1:
		names = ["钱伯", "阿香", "刀郎", "巡查队" if state.round_number == 9 else "商队领队"]
	elif state.region() == 2:
		names = ["墨先生", "二笔", "高帽子", active if state.round_number >= 14 else "档案管理员"]
	var people: Array = []
	for person in names:
		var index := portrait_index(person)
		people.append({"name": person, "portrait": Characters.portrait(index) if index >= 0 else null, "summary": "点击开始：" + str(state.event().title) if person == active else "当前回合的交谈对象是" + active, "disabled": person != active or stage() != "idle", "visible": true})
	return people

func _ensure_presentation() -> void:
	if not state.presentation.is_empty():
		return
	# v1 saves migrate without changing AP, evidence, or completed actions.
	match state.phase:
		"ready": state.presentation = {"stage": "idle"}
		"result": state.presentation = {"stage": "result", "lines": dialogue.lines_for(state, state.pending), "index": 0, "portrait": current_actor()}
		"aftermath": state.presentation = {"stage": "aftermath"}
		"ending": state.presentation = {"stage": "ending", "lines": dialogue.lines_for(state, "ending"), "index": 0, "portrait": ""}

func _refresh_people() -> void:
	var people := _people()
	var names: Array = []
	for person in people:
		names.append(person.name)
	if names != rail_names:
		rail_names = names
		%CharacterRail.configure(people)
		return
	# A card may still be emitting its pressed signal. Update it in place,
	# rather than freeing the node through CharacterRail.configure().
	var cards := %CharacterRail.get_node("Cards").get_children()
	for i in people.size():
		var person: Dictionary = people[i]
		cards[i].configure(person.name, person.portrait, person.summary, person.disabled, true, i)

func _refresh() -> void:
	_ensure_presentation()
	%LocationBackground.texture = Art.BACKGROUNDS[Art.REGION_IDS[state.region()]]
	%TopBar.apply_engine({"stats": [{"label": "信仰 F", "value": state.faith}, {"label": "警戒 A", "value": state.alert}], "buttons": [{"id": "journal", "text": "手记"}, {"id": "evidence", "text": "证据"}, {"id": "map", "text": "地图"}, {"id": "settings", "text": "设置"}], "day": state.round_number, "total": 15, "ap": state.ap, "ap_max": 3})
	%TopBar.get_node("DayBadge/Caption").text = "%d / 15" % state.round_number
	%TopBar.get_node("DayBadge/Ap").text = "AP %d/3" % state.ap
	for button in %TopBar.button_row().get_children():
		button.disabled = busy()
	_refresh_people()
	%CharacterRail.visible = state.phase != "ending"
	_refresh_side()
	_clear(actions)
	subtitle.text = "%s　/　第 %02d 回合" % [state.data.regions[state.region()].name, state.round_number]
	heading.text = state.event().title
	continue_hint.text = ""
	choice_scroll.visible = not busy()
	match stage():
		"idle":
			%PortraitPanel.clear_character()
			%DialogueBox.show_text("点击左侧的「%s」人物卡，开始本回合的交谈。" % current_actor())
		"opening", "result", "closing", "ending":
			if state.phase == "ending":
				heading.text = state.data.endings[state.ending].title
				%PortraitPanel.clear_character()
			else:
				_show_portrait(str(state.presentation.get("portrait", current_actor())))
			%DialogueBox.show_from(state.presentation.lines, int(state.presentation.index))
		"choices":
			_show_portrait(str(state.presentation.get("portrait", current_actor())))
			%DialogueBox.show_text("你准备如何回应？请选择上方的一项行动。")
			for id in ["A", "B", "C"]:
				var value: Dictionary = state.option(id)
				var reason: String = state.blocked_reason(id)
				var cost := "%d AP · F %+d · A %+d" % [int(value.cost), int(value.f), int(value.a)]
				var label := "%s　%s\n%s" % [id, value.title, cost if reason.is_empty() else cost + "\n" + reason]
				_button(actions, label, id, _choose.bind(id), not reason.is_empty())
		"aftermath":
			%DialogueBox.show_text(str(state.report).replace("未接触", "尚未建立联系"))
			if state.ap > 0 and not state.generic_used:
				_button(actions, "整理调查笔记 · 1 AP" + ("\n本回合没有待整理线索" if state.turn_clues.is_empty() else "\n登记：" + state.evidence_names(state.turn_clues)), "notes", _generic.bind("notes"), not state.can_generic("notes"))
				_button(actions, "谨慎收尾 · 1 AP · A −1（最低为 0）", "careful", _generic.bind("careful"))
			var next := "结束旅程 · 查看结局 →" if state.round_number == 15 else ("结束本回合 · 前往%s →" % state.data.regions[state.region() + 1].name if state.round_number in [5, 10] else "结束本回合 →")
			_button(actions, next, "next", _next)
		"finished":
			heading.text = state.data.endings[state.ending].title
			%PortraitPanel.clear_character()
			%DialogueBox.show_text("%s\n信仰 F %d　警戒 A %d\n旅程已结束，可以回看调查手记，或重新开始。" % [state.data.endings[state.ending].title, state.faith, state.alert])
			_button(actions, "回看调查手记", "journal", _toolbar.bind("journal"))
			_button(actions, "再走一次这段旅程…", "restart", _restart_ask)
	choice_scroll.scroll_vertical = 0
	_save_caption()

func _refresh_side() -> void:
	_clear(side)
	_text(side, "渔村 → 集市 → 旧学城", 24, GOLD)
	_text(side, "已登记 %d 类证据 · %d 条渠道" % [state.categories().size(), state.channels.size()], 23)
	var actor := current_actor()
	var status: String = state.npc.get(str(state.event().actor), "未接触")
	_text(side, actor + " · " + ("尚未建立联系" if status == "未接触" else status), 23, MUTED)
	_text(side, state.warning_text(), 23, Color("e5bc93") if state.alert >= 10 else MUTED)
	side.get_parent().scroll_vertical = 0

func _show_portrait(person: String) -> void:
	if person.is_empty():
		return
	var index := portrait_index(person)
	%PortraitPanel.present(person, Characters.wholebody(index) if index >= 0 else null)

func _on_character_selected(_index: int, person: String, _summary: String, _texture: Texture2D) -> void:
	if stage() != "idle" or person != current_actor() or overlay.visible or map_modal.visible:
		return
	_show_portrait(person)
	_start_dialogue("opening", dialogue.lines_for(state, "opening"))

func _start_dialogue(kind: String, lines: Array) -> void:
	state.presentation = {"stage": kind, "lines": lines.duplicate(true), "index": 0, "portrait": %PortraitPanel.character}
	if lines.is_empty():
		_on_dialogue_finished()
		return
	_save()
	_refresh()

func _on_line_presented(index: int, speaker: String) -> void:
	if not busy():
		return
	state.presentation.index = index
	if state.phase != "ending" and speaker not in ["", "玩家", "你", "告示", "木牌"]:
		_show_portrait(speaker)
	state.presentation.portrait = %PortraitPanel.character
	continue_hint.text = "点击文字框 / 回车继续　%d / %d ›" % [index + 1, state.presentation.lines.size()]
	_save()
	_save_caption()

func _on_dialogue_finished() -> void:
	match stage():
		"opening": state.presentation = {"stage": "choices", "portrait": %PortraitPanel.character}
		"result":
			if not state.settle():
				return
			if state.phase == "ending":
				_start_dialogue("ending", dialogue.lines_for(state, "ending"))
			else:
				_start_dialogue("closing", dialogue.lines_for(state, "closing"))
			return
		"closing": state.presentation = {"stage": "aftermath"}
		"ending": state.presentation = {"stage": "finished"}
		_: return
	_save()
	_refresh()

func _save_caption() -> void:
	save_label.text = save_error if not save_error.is_empty() else "进度自动保存到当前对白　·　移动不消耗 AP　·　A≥18 遗忘重临"

func _minimap(id: String) -> void:
	_toolbar({"compass": "map", "rim_upper": "evidence", "rim_lower": "journal"}.get(id, "map"))

func _save() -> void:
	var error: Error = state.save_to(save_path)
	save_error = "进度保存失败：%s。请检查保存目录权限。" % error_string(error) if error != OK else ""

func _choose(id: String) -> void:
	if stage() != "choices" or overlay.visible or map_modal.visible:
		return
	if state.begin(id):
		_start_dialogue("result", dialogue.lines_for(state, id))

func _generic(id: String) -> void:
	if stage() == "aftermath" and state.generic(id):
		_save()
		_refresh()

func _next() -> void:
	if stage() != "aftermath" or not state.next_round():
		return
	state.presentation = {}
	_ensure_presentation()
	_save()
	_refresh()

func _popup(title: String) -> void:
	_clear(overlay_body)
	_clear(overlay_actions)
	_text(overlay_body, title, 36, GOLD)
	_button(overlay_actions, "返回旅程", "close", overlay.hide)
	overlay_body.get_parent().scroll_vertical = 0
	overlay.show()

func _toolbar(id: String) -> void:
	if busy() or overlay.visible or map_modal.visible:
		return
	match id:
		"evidence":
			_popup("证据与线索")
			_text(overlay_body, "同类证据只计一类。未登记的线索只可在获得当回合整理；副本不会增加类别。", 24, MUTED)
			if state.evidence.is_empty():
				_text(overlay_body, "尚未收集证据。")
			for key in state.evidence:
				var entry: Dictionary = state.data.evidence[key]
				_text(overlay_body, "%s · %s\n%s / %s\n%s" % [entry.name, "已登记" if state.evidence[key] else ("本回合待整理" if state.turn_clues.has(key) else "未登记 · 仅作背景线索"), entry.category, state.data.regions[int(entry.region)].name, entry.description])
			if state.flags.has("husband_background"):
				_text(overlay_body, "背景线索：盐嫂的丈夫因谈论禁忌故事被处死。此事本身不证明海洋存在。")
		"journal":
			_popup("调查手记")
			_text(overlay_body, "信仰 F %d　警戒 A %d\n传播渠道：%s" % [state.faith, state.alert, "暂无" if state.channels.is_empty() else "、".join(state.channels)])
			for name in state.npc:
				_text(overlay_body, "%s：%s%s" % [name, str(state.npc[name]).replace("未接触", "尚未建立联系"), "（保管原件的协助已使用）" if name == "盐嫂" and state.flags.has("salt_help_used") else ""], 23, MUTED)
			for entry in state.history:
				_text(overlay_body, "第 %d 回合 · %s\n%s · %s\n%s" % [int(entry.round), entry.title, entry.choice, entry.action, entry.report])
			if state.history.is_empty():
				_text(overlay_body, "旅程刚刚开始，尚无完成的调查。")
		"map":
			var places: Array = []
			for place_id in Art.BACKGROUNDS:
				places.append({"id": place_id, "reachable": true})
			map_modal.configure({"show_ocean": state.ending == "sea", "places": places})
			map_modal.open()
		"settings":
			_popup("试玩设置与规则")
			_text(overlay_body, "每回合 3 AP，只选择一个剧情行动。有余力时，可再执行一次整理笔记或谨慎收尾。移动免费，第 5、10 回合结束后自动转场。\n\nF 表示海洋真相进入共同认知的程度，A 表示调查引起的警戒。F 不设硬上限，A 最低为 0。\n\nA≥6 受到关注；A≥10 出现监视；A≥14 关闭客栈传播、小规模复制、商队托带；A≥18 立即遗忘重临。\n\n第 15 回合结算：F≥20 且 A<18，海回归；12≤F<20 且 A≤10，王国获得解放；其余为遗忘重临。\n\n点击当前角色卡开始交谈。点击文字框或按回车逐段推进，开场结束后选择行动，分支读完才结算。每段对白自动保存，退出后从当前句继续。")
			_button(overlay_actions, "重新开始这段旅程…", "restart", _restart_ask)

func _map_place(id: String) -> void:
	map_modal.hide()
	if not Art.BACKGROUNDS.has(id):
		return
	var index: int = Art.REGION_IDS.find(id)
	_popup(str(Art.PLACE_NAMES[id]))
	var picture := TextureRect.new()
	picture.texture = Art.BACKGROUNDS[id]
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size.y = 430
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_body.add_child(picture)
	if index >= 0:
		_text(overlay_body, str(state.data.regions[index].intro))
		_text(overlay_body, "这里是当前调查区域。" if index == state.region() else ("这段调查已完成，可在手记中回看。" if index < state.region() else "这里是后续调查区域，完成当前章节后前往。"), 24, GOLD)
	else:
		_text(overlay_body, "地点预览 · 当前十五回合旅程暂未开放这里的剧情。", 24, GOLD)
	_text(overlay_body, "查看地点不消耗 AP，也不会改变剧情进度。", 23, MUTED)

func _restart_ask() -> void:
	_popup("重新开始旅程？")
	_text(overlay_body, "这会清除当前试玩的进度，从螺螺发现贝壳的第 1 回合开始。")
	_button(overlay_actions, "确定，重新开始", "confirm_restart", _restart)

func _restart() -> void:
	state = State.new()
	_ensure_presentation()
	overlay.hide()
	_save()
	_refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not event.is_echo() and busy() and not overlay.visible and not map_modal.visible:
		%DialogueBox.advance()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if overlay.visible:
			overlay.hide()
		elif map_modal.visible:
			map_modal.hide()
		get_viewport().set_input_as_handled()
