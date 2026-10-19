extends Control
## Six-day village, retaining Trial1's map, cards, portraits and dialogue gestures.
const State := preload("res://scripts/story/village_state.gd")
const Story := preload("res://scripts/story/village_story.gd")
const Save := preload("res://scripts/story/village_save.gd")
const Art := preload("res://scripts/ui/trial1_art.gd")
const Characters := preload("res://scripts/ui/character_card/default_characters.gd")
const MapScene := preload("res://scenes/ui/popup/map_modal.tscn")
const GOLD := Color("d5bb83")
const PAPER := Color("ece2cd")
const MUTED := Color("b5c4c0")
@export var save_path := "user://trial1_village_v1.json"
var state = State.new()
var heading: Label
var subtitle: Label
var choice_scroll: ScrollContainer
var continue_hint: Label
var actions: VBoxContainer
var side: VBoxContainer
var save_label: Label
var map_modal
var overlay: Control
var overlay_body: VBoxContainer
var overlay_actions: VBoxContainer
var end_button: Button
var save_error := ""
var save_blocked := false
var rail_names: Array = []
const VILLAGE_PICTURES := {
	"heirloom": {"title":"丈夫留下的手记", "path":"res://assets/fishing_village/渔村_丈夫的手记.png"},
	"identify": {"title":"哑伯辨认木件", "path":"res://assets/fishing_village/渔村_哑伯辨认木件.png"},
	"waterline": {"title":"无雨的水位涨落", "path":"res://assets/fishing_village/渔村_无雨的水线.png"},
	"shells": {"title":"旧水线之外的贝壳", "path":"res://assets/fishing_village/渔村_水线外的贝壳.png"},
}
var active_village_picture := ""

func _ready() -> void:
	_build_theme()
	_build_ui()
	overlay.visibility_changed.connect(_village_picture_visibility_changed)
	end_button = _button(%Design,"结束当天","end_day",_ask_end)
	end_button.position = Vector2(1450,690)
	end_button.size = Vector2(420,60)
	%Design.move_child(end_button,map_modal.get_index())
	resized.connect(_fit)
	_fit()
	%TopBar.action_pressed.connect(_toolbar)
	%CharacterRail.character_selected.connect(_on_character_selected)
	%DialogueBox.dialogue_finished.connect(_on_dialogue_finished)
	%DialogueBox.line_presented.connect(_on_line_presented)
	%MiniMap.action_pressed.connect(_minimap)
	%MiniMap.get_node("Compass").tooltip_text = "地图"
	%MiniMap.get_node("Upper").tooltip_text = "证据与材料"
	%MiniMap.get_node("Lower").tooltip_text = "调查进度"
	var loaded := Save.load_from(save_path)
	if loaded.ok:
		state = loaded.state
		if loaded.get("backup",false): save_error = "主存档不可用，已从上一份有效备份恢复。"
	elif not loaded.get("missing",false):
		save_blocked = true
		save_error = "存档与备份不可用，原文件已保留。当前为临时新局；请在设置中明确重新开始后保存。"
	else:
		state.presentation = {"lines":Story.opening(),"index":0,"portrait":"","kind":"opening"}
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
	button.visible = not disabled
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
	var edition := _text(%Design, "渔村六日 · 调查与抉择", 24, MUTED)
	edition.position = Vector2(1025, 120)
	edition.size = Vector2(600, 40)
	subtitle = _text(%Design, "", 24, GOLD)
	subtitle.position = Vector2(250, 238)
	subtitle.size = Vector2(730, 38)
	heading = _text(%Design, "", 34)
	heading.position = Vector2(250, 280)
	heading.size = Vector2(440, 62)
	choice_scroll = ScrollContainer.new()
	%Design.add_child(choice_scroll)
	choice_scroll.position = Vector2(250, 350)
	choice_scroll.size = Vector2(730, 320)
	choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	actions = VBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 12)
	choice_scroll.add_child(actions)
	var scroll_hint := _text(%Design,"只显示当前可做的行动 · 下一步与期限见「进度」",19,MUTED)
	scroll_hint.position = Vector2(250,675)
	scroll_hint.size = Vector2(730,25)
	scroll_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

func busy() -> bool:
	return not state.presentation.is_empty()

func portrait_index(person: String) -> int:
	return int({"螺螺":2,"哑伯":3,"盐嫂":1}.get(person,-1))

func _show_portrait(person: String) -> void:
	if person.is_empty():
		%PortraitPanel.clear_character()
		return
	var index := portrait_index(person)
	%PortraitPanel.present(person,Characters.wholebody(index) if index >= 0 else null)

func _refresh_people() -> void:
	var ids := ["salt","elder","child"]
	var people: Array = []
	for who in ids:
		var p: Dictionary = state.people[who]
		people.append({"name":State.NAMES[who],"portrait":Characters.portrait(portrait_index(State.NAMES[who])),"summary":"信任 %d / 警戒 %d\n%s\n点击交谈不消耗AP" % [p.t,p.a,state.status(who)],"disabled":busy() or state.finished,"visible":true})
	if rail_names.is_empty():
		rail_names = ids
		%CharacterRail.configure(people)
	else:
		var cards := %CharacterRail.get_node("Cards").get_children()
		for i in people.size(): cards[i].configure(people[i].name,people[i].portrait,people[i].summary,people[i].disabled,true,i)
	%CharacterRail.visible = state.location == "fishing_village" and not state.finished

func _refresh() -> void:
	%LocationBackground.texture = Art.BACKGROUNDS[state.location]
	%TopBar.apply_engine({"stats":[{"label":"认知 B","value":state.belief},{"label":"粮食","value":state.food}],"buttons":[{"id":"journal","text":"进度"},{"id":"evidence","text":"材料"},{"id":"people","text":"人物"},{"id":"settings","text":"设置"}],"day":state.day,"total":6,"ap":state.ap,"ap_max":3})
	%TopBar.get_node("DayBadge/Caption").text = "%d / 6" % state.day
	for button in %TopBar.button_row().get_children(): button.disabled = busy()
	_refresh_people()
	_render_progress_side()
	end_button.visible = not state.finished
	end_button.disabled = busy()
	end_button.text = "离村交接与结算" if state.day == 6 else "结束当天 · 剩%d AP" % state.ap
	subtitle.text = "渔村 / 第%02d天　·　移动与交谈预览免费" % state.day
	heading.text = "遗迹调查" if state.location == "ruins" else (State.NAMES[state.selected] if not state.selected.is_empty() else "今天从哪里开始？")
	_clear(actions)
	choice_scroll.visible = not busy()
	continue_hint.text = ""
	if busy():
		_show_portrait(str(state.presentation.get("portrait","")))
		%DialogueBox.show_from(state.presentation.lines,int(state.presentation.index))
	elif state.finished:
		heading.text = "渔村章节结束"
		_show_portrait("")
		%DialogueBox.show_text("%s\n证据、人物与公共认知的结果已经保存。可以继续前往集市。" % state.outcome_text())
		_button(actions,"前往 / 继续集市","market",_enter_market)
		_button(actions,"查看离村结果","report",_show_report)
		_button(actions,"查看调查进度","journal",_toolbar.bind("journal"))
		_button(actions,"重新开始这六天…","restart",_restart_ask)
	else:
		_show_portrait(State.NAMES.get(state.selected,"") if state.location == "fishing_village" else "")
		%DialogueBox.show_text(_idle_text())
		_build_actions()
		_empty_actions_hint()
	choice_scroll.scroll_vertical = 0
	_save_caption()

func _idle_text() -> String:
	if state.location == "ruins":
		return "遗迹已经封闭；你仍可以通过地图免费返回渔村。" if state.day > 4 else "风穿过残破石墙。根据已知入口推进调查，或通过地图免费返回渔村。"
	return "可以继续选择行动，或切换人物。点击预览不扣费，确认执行才结算。" if not state.selected.is_empty() else "点击左侧任意人物卡，立绘滑入后开始交谈。也可以从地图进入遗迹，或在村口查看公开说明。"

func _add_action(id: String, args: Dictionary = {}) -> void:
	var reasons: Array = state.blocked(id,args)
	var definition: Dictionary = State.ACTIONS[id]
	if state.flags.has(state.action_key(id,args)) and id not in ["store","take"]: return
	var label := "%s · %d AP" % [definition.title,definition.ap]
	if int(definition.get("food",0)) > 0: label += " + %d粮食" % definition.food
	if not reasons.is_empty(): label += "\n" + str(reasons[0])
	_button(actions,label,id,_preview_action.bind(id,args),not reasons.is_empty())

func _condition_button(parent: Node, label: String, id: String, args: Dictionary, button_id := "") -> void:
	var reasons: Array = state.blocked(id,args)
	if not reasons.is_empty(): label += "\n" + str(reasons[0])
	var control := _button(parent,label,id if button_id.is_empty() else button_id,_preview_action.bind(id,args),not reasons.is_empty())
	control.tooltip_text = "\n".join(reasons)

func _any_public_available() -> bool:
	for id in ["public_material","public_anonymous","public_salt","public_elder"]:
		if state.blocked(id).is_empty(): return true
	return false

func _material_entry(parent: Node, kind: String, who: String, label: String) -> void:
	var reasons: Array = []
	var available := false
	for key in state.items:
		if not state.owned(key) and not (kind == "neighbor" and state.storage.salt.has(key)): continue
		if kind in ["record","scribe","store"] and key not in ["H","F"]: continue
		if kind in ["show","neighbor"] and key == "fragment": continue
		var args := {"item":key,"who":who,"items":[key]}
		reasons = state.blocked(kind,args)
		if reasons.is_empty():
			available = true
			break
	if not available: label += "\n" + (str(reasons[0]) if not reasons.is_empty() else "暂无可用于此行动的材料")
	_button(parent,label,kind,_pick_material.bind(kind,who),not available)

func _build_actions() -> void:
	if state.location == "ruins":
		for id in ["survey","clear","search"]: _add_action(id)
		return
	if not state.selected.is_empty():
		for id in State.ACTIONS:
			if State.ACTIONS[id].group == state.selected: _add_action(id)
		if state.people[state.selected].exposed: _add_action("apology",{"who":state.selected})
		_material_entry(actions,"show",state.selected,"出示证据，争取信任 · 1 AP\n信任+10 / 警戒+15 · 材料留在身上")
		if state.selected == "salt": _material_entry(actions,"neighbor","salt","安排邻里传播 · 1 AP")
	else:
		_add_action("waterline")
		var public_reasons: Array = state.blocked("public_material")
		var public_available := _any_public_available()
		_button(actions,"村口公开说明 · 第4—5天" + ("" if public_available else "\n" + str(public_reasons[0])),"public",_public_options,not public_available)
		_button(actions,"材料与抄写摊","evidence",_toolbar.bind("evidence"))

func _on_character_selected(index: int, _person: String, _summary: String, _texture: Texture2D) -> void:
	if busy() or state.finished or overlay.visible or map_modal.visible or state.location != "fishing_village": return
	state.selected = ["salt","elder","child"][index]
	_play(Story.greeting(state,state.selected),"greeting",State.NAMES[state.selected])

func _play(lines: Array, kind := "action", portrait := "") -> void:
	state.presentation = {"lines":lines,"index":0,"kind":kind,"portrait":portrait}
	_save()
	_refresh()

func _on_line_presented(index: int, speaker: String) -> void:
	if not busy(): return
	state.presentation.index = index
	if speaker in State.NAMES.values(): _show_portrait(speaker)
	state.presentation.portrait = %PortraitPanel.character
	continue_hint.text = "点击文字框 / 回车继续　%d / %d ›" % [index+1,state.presentation.lines.size()]
	_save()
	_save_caption()
	_show_village_picture(state.presentation.lines[index])

func _show_village_picture(line: Dictionary) -> void:
	var id := str(line.get("illustration",""))
	if not VILLAGE_PICTURES.has(id) or state.flags.has("seen_picture_"+id): return
	active_village_picture = id
	_popup(VILLAGE_PICTURES[id].title)
	var picture := TextureRect.new()
	picture.name = "StoryPicture"
	picture.texture = load(VILLAGE_PICTURES[id].path)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size.y = 530
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_body.add_child(picture)
	_text(overlay_body,str(line.get("text","")),24)
	_clear(overlay_actions)
	var close := _button(overlay_actions,"继续阅读 · 回车 / Esc","close",overlay.hide)
	close.focus_mode = Control.FOCUS_NONE

func _village_picture_visibility_changed() -> void:
	if overlay.visible or active_village_picture.is_empty(): return
	state.flags["seen_picture_"+active_village_picture] = true
	active_village_picture = ""
	_save()

func _on_dialogue_finished() -> void:
	if not busy(): return
	if state.presentation.kind == "day" and not state.public_event.is_empty() and state.day > state.public_event.day:
		state.public_event.feedback_read = true
	state.presentation = {}
	_save()
	_refresh()

func _popup(title: String) -> void:
	_clear(overlay_body)
	_clear(overlay_actions)
	_text(overlay_body,title,34,GOLD)
	_button(overlay_actions,"返回","close",overlay.hide)
	overlay_body.get_parent().scroll_vertical = 0
	overlay.show()

func _preview_action(id: String, args: Dictionary = {}) -> void:
	if busy(): return
	var preview: Dictionary = state.preview(id,args)
	_popup(State.ACTIONS[id].title)
	_text(overlay_body,preview.text,24)
	if id.begins_with("public_") and not state.chapter_progress().verified: _text(overlay_body,"当前线索尚未完成交叉验证。此次公开可以提高认知，但不会单凭认知增长判定调查成功。",23,GOLD)
	if id == "public_material": _text(overlay_body,"村民会问：旧物是否相互印证？河里也有船，为什么想到海？\n已有的第二来源与水线记录会自动用于回应，不额外扣费。",23,MUTED)
	if preview.allowed: _button(overlay_actions,"确认执行","execute",_execute.bind(id,args))

func _execute(id: String, args: Dictionary = {}) -> void:
	if not state.execute(id,args):
		_preview_action(id,args)
		return
	overlay.hide()
	_play(Story.action(state,id),"action",State.NAMES.get(state.selected,""))

func _public_options() -> void:
	_popup("村口公开说明 · 只能执行一次")
	_text(overlay_body,"返回准备不扣费、不占用机会。认知增量取决于所选版本与已有材料，确认前会显示完整人物代价。",24)
	for id in ["public_material","public_anonymous","public_salt","public_elder"]:
		_condition_button(overlay_body,State.ACTIONS[id].title,id,{})

func _pick_material(kind: String, who := "") -> void:
	_popup(State.ACTIONS[kind].title)
	if kind == "show": _text(overlay_body,"只给这一个人看：信任+10、警戒+15，并让对方知晓调查。材料仍归你，不提高全村认知；每人只能获得一次效果。",23)
	if kind == "store": _text(overlay_body,"可选交接：原物留给对方，不增加信任或全村认知，也没有额外保护奖励。你暂时不能使用该原物，纯保管可免费取回；若还用于传播则不可撤回。",23)
	var available: Array = []
	for key in state.items:
		if state.owned(key) or (kind == "neighbor" and state.storage.salt.has(key)) or (kind == "take" and not state.owned(key)):
			if kind in ["record","scribe","store"] and key not in ["H","F"]: continue
			if kind in ["show","neighbor"] and key == "fragment": continue
			available.append(key)
			var args := {"item":key,"who":who}
			if kind == "store": args["items"] = [key]
			_condition_button(overlay_body,State.TITLES[key],kind,args,key)
	if kind == "store" and available.size() == 2:
		_condition_button(overlay_body,"同时交接两件原物 · 共1 AP",kind,{"who":who,"items":available},"store_both")
	if available.is_empty(): _text(overlay_body,"当前没有可选择的材料。先调查取得原物，或取回纯保管物品。",24,MUTED)

func _ask_end() -> void:
	if busy() or state.finished or overlay.visible or map_modal.visible: return
	_popup("离村交接" if state.day == 6 else "结束第%d天？" % state.day)
	_text(overlay_body,state.end_preview(),24)
	_text(overlay_body,"时间提醒\n"+"\n".join(_time_notices()),23,GOLD)
	if state.day == 6:
		_text(overlay_body,"结束后将复查协助并确认材料去向；此处不能免费补做记录或安排。",23,MUTED)
		_button(overlay_actions,"查看材料，先处理交接","materials",_open_materials)
	_button(overlay_actions,"确认离村" if state.day == 6 else "确认结束当天","confirm_day",_end_day)

func _open_materials() -> void:
	overlay.hide()
	_toolbar("evidence")

func _end_day() -> void:
	if not state.end_day(): return
	overlay.hide()
	if state.finished:
		var farewell: Array = [state.outcome_text(),"你走向村口。留下的材料、人物和风险，都将有自己的后续。"]
		if state.belief >= 60: farewell.append("水线之外，多了一圈湿亮的贝壳。大海尚未回归，但渔村已经发生变化。")
		_play(Story.lines(farewell),"departure")
	else: _play(Story.day_start(state),"day")

func _show_report() -> void:
	_popup("离村结果")
	_text(overlay_body,state.report(),24)

func _toolbar(id: String) -> void:
	if busy() or overlay.visible or map_modal.visible: return
	match id:
		"evidence":
			_popup("证据与材料")
			_text(overlay_body,"原物与其记录共用来源，不算两份独立证据。传播材料不能主动取回。",23,MUTED)
			if state.items.is_empty(): _text(overlay_body,"尚未取得材料。可先帮助村民或探索遗迹。")
			for key in state.items:
				var holder: String = state.items[key].holder
				var use := "随身" if holder == "player" else "保管"
				if not state.spread.is_empty() and state.spread.item == key: use = "邻里传播" + ("与保管" if state.storage.salt.has(key) else "")
				_text(overlay_body,"%s · %s\n来源：%s · 持有人：%s\n%s" % [State.TITLES[key],use,state.source(key),"玩家" if holder=="player" else State.NAMES[holder],State.DESCRIPTIONS.get(state.source(key),"")],23)
				if not state.finished and holder != "player": _condition_button(overlay_body,"取回保管物品 · 免费","take",{"item":key},"take_"+key)
			if not state.finished:
				_material_entry(overlay_body,"record","","自己制作记录 · 2 AP")
				_material_entry(overlay_body,"scribe","","抄写摊制作记录 · 1 AP + 1粮食")
				_text(overlay_body,"可选：把原物留在村内（不增加信任或认知）",23,MUTED)
				for who in ["salt","elder"]: _material_entry(overlay_body,"store",who,"交给"+State.NAMES[who]+"保管 · 1 AP")
		"journal": _show_progress()
		"people": _show_people_page()
		"map":
			var places: Array = []
			for place_id in Art.BACKGROUNDS: places.append({"id":place_id,"reachable":true})
			map_modal.configure({"show_ocean":false,"places":places})
			map_modal.open()
		"settings":
			_popup("渔村六回合 · 设置")
			_text(overlay_body,"每天3 AP；地图移动、人物问候、阅读免费。确认行动时扣费。\n\nT是对你的信任，A是对王权威胁的感知。知情且T<60、A≥60才会进入告密预警；高信任高警戒只暂停协助。\n\nB是渔村认知：30形成讨论，60出现局部变化，不是全游戏胜利。\n\n点击人物卡→立绘滑入→点击文字框或回车推进→自主选择行动。第6天结束离村，失败也可结算。\n\n盐嫂有效传播提供一次后续引荐帮助；哑伯安全支持提供一次来源核验帮助。实名公开会失去对应帮助。",24)
			_button(overlay_actions,"保存当前进度","save",_manual_save)
			_button(overlay_actions,"读取最近进度…","load",_load_ask)
			_button(overlay_actions,"重新开始六天…","restart",_restart_ask)

func _map_place(id: String) -> void:
	map_modal.hide()
	if not Art.BACKGROUNDS.has(id): return
	_popup(Art.PLACE_NAMES[id])
	var picture := TextureRect.new()
	picture.texture = Art.BACKGROUNDS[id]
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size.y = 350
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_body.add_child(picture)
	if id=="market":
		if state.finished: _button(overlay_actions,"前往 / 继续集市","enter_market",_enter_market_from_map)
		else: _text(overlay_body,"集市将在第六天完成离村结算后开放。",24,GOLD)
	elif id in ["fishing_village","ruins"] and not state.finished:
		_text(overlay_body,"查看地点不移动、不扣AP。确认进入后切换背景及可用人物/行动。",23)
		if id == "ruins" and state.day > 4 and state.location != id: _text(overlay_body,"遗迹已封闭，不能再进入。已有碎片仍可辨认。",24,GOLD)
		else: _button(overlay_actions,"进入%s · 免费" % Art.PLACE_NAMES[id],"enter_"+id,_travel.bind(id))
	else: _text(overlay_body,"地点预览。后续地区尚未接入，不能进入或推进剧情。",24,GOLD)

func _travel(id: String) -> void:
	if not state.travel(id): return
	overlay.hide()
	_save()
	_refresh()

func _minimap(id: String) -> void:
	_toolbar({"compass":"map","rim_upper":"evidence","rim_lower":"journal"}.get(id,"map"))

func _save() -> void:
	if save_blocked: return
	var error := Save.save_to(save_path,state)
	save_error = "保存失败，本次行动已经执行但尚未保存；可在设置中重试。%s" % error_string(error) if error != OK else ""

func _save_caption() -> void:
	save_label.text = save_error if not save_error.is_empty() else "进度自动保存到当前对白 · 移动免费 · 第6天结束离村"

func _manual_save() -> void:
	_save()
	_save_caption()
	_popup("保存进度")
	_text(overlay_body,save_error if not save_error.is_empty() else "当前进度已保存。")

func _load_ask() -> void:
	_popup("读取最近进度？")
	_text(overlay_body,"当前未保存状态将由有效存档替换。旧十五回合存档不会被读取。")
	_button(overlay_actions,"确认读取","confirm_load",_load)

func _load() -> void:
	var loaded := Save.load_from(save_path)
	if not loaded.ok:
		_popup("未能读取")
		_text(overlay_body,"没有有效存档，当前游戏与原文件均保留。")
		return
	state = loaded.state
	save_blocked = false
	save_error = "已恢复上一份有效备份。" if loaded.get("backup",false) else ""
	overlay.hide()
	_refresh()

func _restart_ask() -> void:
	_popup("重新开始渔村六天？")
	_text(overlay_body,"这将重置本次六回合章节。旧十五回合试玩的存档不受影响。")
	_button(overlay_actions,"确认重新开始","confirm_restart",_restart)

func _restart() -> void:
	if save_blocked: save_path += ".recovered"
	save_blocked = false
	state = State.new()
	overlay.hide()
	_play(Story.opening(),"opening")

func _unhandled_key_input(event: InputEvent) -> void:
	if not active_village_picture.is_empty() and overlay.visible:
		if (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")) and not event.is_echo():
			overlay.hide()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept") and not event.is_echo() and busy() and not overlay.visible and not map_modal.visible:
		%DialogueBox.advance()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if overlay.visible: overlay.hide()
		elif map_modal.visible: map_modal.hide()
		get_viewport().set_input_as_handled()

func _enter_market() -> void:
	if not state.finished or busy() or overlay.visible or map_modal.visible: return
	var seed: Dictionary = state.snapshot.duplicate(true)
	seed["market_entry_turn"] = state.entry_turn+6
	var identity := JSON.stringify(seed).sha256_text().substr(0,16)
	var next = load("res://scenes/market_chapter.tscn").instantiate()
	next.save_path = save_path+".market-"+identity+".json"
	next.village_snapshot = seed
	get_parent().add_child(next)
	if get_tree().current_scene==self: get_tree().current_scene = next
	queue_free()

func _enter_market_from_map() -> void:
	overlay.hide()
	_enter_market()

# Shared navigation keeps all chapters consistent without altering their rules.
func _chapter_guidance() -> Dictionary:
	var p: Dictionary = state.chapter_progress()
	if state.finished: return {"title":"渔村调查已结束","next":"查看离村结果，或前往集市继续调查。"}
	if state.day>4 and not p.verified: return {"title":"遗迹与水线调查已截止","next":"缺少的关键证据已无法补取，可整理已有发现、照顾村民，再带着部分调查离村。"}
	if state.day==6 and not p.propagated: return {"title":"公开说明已经结束","next":"仍可检查盐嫂的邻里传播是否可安排；未留下有效传播则带着验证结果离村。"}
	if not p.lead_found: return {"title":"寻找关于海洋的线索","next":"可以帮助盐嫂、听她说话，或从地图进入遗迹调查。"}
	if not p.verified: return {"title":"线索还需要相互印证","next":"调查遗迹，请哑伯辨认船体构件，再与手记或水线记录核对。"}
	if not p.propagated: return {"title":"证据已经核实","next":"可在第4—5天公开说明，或争取盐嫂安排邻里传播。"}
	return {"title":"基本目标已经达成","next":"可补充调查、照顾村民，或检查传播与人物风险。"}

func _time_notices() -> Array:
	var schedules: Dictionary = {
		"fishing_village":[[3,"第3天末：家人安置截止"],[4,"第4天末：遗迹与水线调查截止"],[5,"第4—5天：村口公开说明"],[6,"第6天末：离村交接"]],
		"market":[[3,"第3天末搜查；公开回应需留足行动点"],[4,"第4天末：商队出发与离市交接"]],
		"old_academy":[[3,"第3天末：常规旧档调查截止"],[4,"第4天：按已知位置抢救；当天末旧稿清理"],[5,"第5天：公开质询与离城交接"]],
		"feather_forest":[[4,"第4天末：高塔封锁，须提前完成进入和取证"],[4,"想第5天公开，须先联系居民"],[5,"第5天：传播与离林交接"]],
		"royal_city":[[5,"第5天末：递送网络面临搜查"],[6,"第6天最终选择：海回归、接管需留1 AP"]]
	}
	var result: Array = []
	var place: String = "fishing_village" if state.location=="ruins" else state.location
	for entry in schedules.get(place,[]):
		if int(entry[0])>=state.day: result.append(entry[1])
	return result

func _risk_notices() -> Array:
	var result: Array = []
	var names: Dictionary = state.get_script().get_script_constant_map().get("NAMES",{})
	for who in state.people:
		var status: String = state.status(who)
		if "预警" in status or "到期" in status or "追查" in status:
			result.append(str(names.get(who,who))+"："+status)
	var data: Dictionary = state.to_data()
	if int(data.get("risk_due",0))>0: result.push_front("递送追查：第%d天末到期" % data.risk_due)
	if int(data.get("source_due",0))>0: result.push_front("证人保护：第%d天末到期" % data.source_due)
	return result

func _render_progress_side() -> void:
	_clear(side)
	side.add_theme_constant_override("separation",10)
	var guidance: Dictionary = _chapter_guidance()
	_text(side,"当前进展",20,MUTED)
	_text(side,guidance.title,25,GOLD)
	_text(side,"可以继续",20,MUTED)
	_text(side,str(guidance.next).split("。")[0]+"。",22)
	var notices: Array = _risk_notices()
	notices.append_array(_time_notices())
	if not notices.is_empty() and not state.finished:
		_text(side,"近期提醒",20,MUTED)
		for notice in notices.slice(0,2): _text(side,"• "+str(notice),20,GOLD)

func _empty_actions_hint() -> void:
	for child in actions.get_children():
		if child is Button and child.visible: return
	_text(actions,"这里暂时没有可执行的行动。\n可切换人物、从地图探索，或查看「进度」了解下一步。",24,MUTED)

func _show_progress() -> void:
	_popup("调查进度")
	var guidance: Dictionary = _chapter_guidance()
	_text(overlay_body,guidance.title,28,GOLD)
	_text(overlay_body,guidance.next,24)
	if state.has_method("progress_text"): _text(overlay_body,state.progress_text(),23)
	if state.has_method("result_text"): _text(overlay_body,state.result_text(),23)
	_text(overlay_body,"期限与风险",26,GOLD)
	_text(overlay_body,"\n".join(_time_notices()),23)
	_text(overlay_body,state.end_preview(),23)
	_text(overlay_body,"可推进事项",26,GOLD)
	_text(overlay_body,"行动点不足的事项，可在未过期限的下一天再做；已经关闭的机会不会重新出现。",22,MUTED)
	var definitions: Dictionary = state.get_script().get_script_constant_map().get("ACTIONS",{})
	for id in definitions:
		var definition: Dictionary = definitions[id]
		if definition.get("group","")=="material": continue
		var reasons: Array = state.blocked(id)
		if reasons.is_empty(): _text(overlay_body,"• "+str(definition.title),23)
	var tomorrow = state.get_script().new()
	if not state.finished and tomorrow.restore(state.to_data()):
		tomorrow.ap = 3
		var waiting: Array = []
		for id in definitions:
			if definitions[id].get("group","")=="material": continue
			if not state.blocked(id).is_empty() and tomorrow.blocked(id).is_empty(): waiting.append(str(definitions[id].title))
		if not waiting.is_empty():
			_text(overlay_body,"仅缺行动点的事项",26,GOLD)
			_text(overlay_body,"、".join(waiting)+"。请先核对以上期限，结束当天可能使机会关闭。",23)
	if not state.finished and has_method("_open_research"):
		_button(overlay_actions,"进入公共调查 · 免费","research",Callable(self,"_open_research"))
	# Existing reports retain facts and consequences without an action-history menu.
	if state.finished and state.has_method("report"): _text(overlay_body,state.report(),23)

func _show_people_page() -> void:
	_popup("人物与关系")
	var names: Dictionary = state.get_script().get_script_constant_map().get("NAMES",{})
	_text(overlay_body,"本地人物",27,GOLD)
	_text(overlay_body,"回到场景后，点击左侧人物卡即可交谈。",22,MUTED)
	for who in state.people:
		var person: Dictionary = state.people[who]
		_text(overlay_body,"%s · 信任%d / 警戒%d\n%s" % [names.get(who,who),person.get("t",0),person.get("a",0),state.status(who)],24)
	var data: Dictionary = state.to_data()
	var previous: Dictionary = data.get("origin",{})
	var all_names := {"salt":"盐嫂","elder":"哑伯","child":"螺螺","qian":"钱伯","xiang":"阿香","dao":"刀郎","mo":"墨先生","er":"二笔","gao":"高帽子","el":"艾尔","lo":"洛恩","ika":"伊卡恩"}
	var seen: Dictionary = {}
	if not previous.is_empty(): _text(overlay_body,"此前结识的人物",27,GOLD)
	while not previous.is_empty():
		var contacts: Dictionary = previous.get("people",previous.get("npc",{}))
		for who in contacts:
			if seen.has(who): continue
			seen[who] = true
			var person: Dictionary = contacts[who]
			var status := "离开当地时：信任%d / 警戒%d" % [person.get("t",0),person.get("a",0)]
			if person.get("reported",false): status+=" · 已告密"
			if person.get("closed",false): status+=" · 协助中断"
			var current = data.get("prior_contacts",{}).get(who,"")
			var contact_status: String = str(current.get("status","")) if current is Dictionary else str(current)
			if not contact_status.is_empty(): status+="\n目前："+str({"pending":"等待保护","protected":"已安排保护","suspended":"协助暂停","assisted":"接应已完成"}.get(contact_status,contact_status))
			if who=="er" and data.get("flags",{}).has("er_relieved"): status+="\n目前：接应已完成"
			_text(overlay_body,str(all_names.get(who,who))+"\n"+status,23)
		previous=previous.get("origin",{})
