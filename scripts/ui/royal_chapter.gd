extends "res://scripts/ui/trial1.gd"
## Uses the same scene components and input gestures, with independent chapter rules.
const Royal := preload("res://scripts/story/royal_chapter_state.gd")
const RoyalStory := preload("res://scripts/story/royal_chapter_story.gd")
const RoyalSave := preload("res://scripts/story/royal_chapter_save.gd")
var forest_snapshot: Dictionary = {}

func _ready() -> void:
	if save_path=="user://trial1_village_v1.json": save_path = "user://trial1_royal_v1.json"
	state = Royal.new()
	_build_theme()
	_build_ui()
	for child in %Design.get_children():
		if child is Label and child.text=="渔村六日 · 调查与抉择": child.text = "王城六日 · 边界与选择"
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
	var loaded := RoyalSave.load_from(save_path)
	if loaded.ok:
		state = loaded.state
		if loaded.get("backup",false): save_error = "已从上一份有效备份恢复王城进度。"
	elif not loaded.get("missing",false):
		save_blocked = true
		save_error = "王城存档损坏，原文件保留。可在设置中重新开始临时进度。"
		state.initialize(forest_snapshot)
	else:
		state.initialize(forest_snapshot)
		state.presentation = {"lines":RoyalStory.opening(state),"index":0,"kind":"opening","portrait":""}
	_refresh()

func _show_portrait(person: String) -> void:
	if person.is_empty(): %PortraitPanel.clear_character()
	else: %PortraitPanel.present(person,null)

func _refresh_people() -> void:
	var ids := ["priest","inspector","king"]
	var people: Array = []
	for who in ids:
		people.append({"name":Royal.NAMES[who],"portrait":null,"summary":state.status(who),"disabled":busy() or state.finished,"visible":true})
	if rail_names!=ids:
		rail_names = ids
		%CharacterRail.configure(people)
	else:
		var cards := %CharacterRail.get_node("Cards").get_children()
		for i in people.size(): cards[i].configure(people[i].name,null,people[i].summary,people[i].disabled,true,i)
	var royal_cards := %CharacterRail.get_node("Cards").get_children()
	for i in royal_cards.size():
		if royal_cards[i].has_node("RolePlaceholder"): continue
		var role := Label.new()
		role.name = "RolePlaceholder"
		role.text = ["禁令制定者","禁令执行者","王国统治者"][i]
		role.position = Vector2(16,35)
		role.size = Vector2(112,60)
		role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		role.add_theme_font_size_override("font_size",21)
		role.add_theme_color_override("font_color",Color("d5bb83"))
		role.mouse_filter = Control.MOUSE_FILTER_IGNORE
		royal_cards[i].add_child(role)
	%CharacterRail.visible = not state.finished

func _refresh() -> void:
	%LocationBackground.texture = Art.BACKGROUNDS.royal_city
	%LocationBackground.modulate = Color(0.55,0.58,0.62,1)
	%TopBar.apply_engine({"stats":[{"label":"王城海洋认知","value":state.belief}],"buttons":[{"id":"journal","text":"进度"},{"id":"evidence","text":"材料"},{"id":"people","text":"人物"},{"id":"settings","text":"设置"}],"day":state.day,"total":6,"ap":state.ap,"ap_max":3})
	%TopBar.get_node("DayBadge/Caption").text = "%d / 6" % state.day
	for button in %TopBar.button_row().get_children(): button.disabled = busy()
	_refresh_people()
	var guidance: Dictionary = _chapter_guidance()
	_render_progress_side()
	end_button.visible = not state.finished
	end_button.disabled = busy()
	end_button.text = "结束大典并结算" if state.day==6 else "结束当天 · 剩%d AP" % state.ap
	subtitle.text = "王城六日 · 阅读与切换免费"
	heading.text = "王城调查" if state.selected.is_empty() else Royal.NAMES[state.selected]
	_clear(actions)
	choice_scroll.visible = not busy()
	continue_hint.text = ""
	if busy():
		_show_portrait(state.presentation.get("portrait",""))
		%DialogueBox.show_from(state.presentation.lines,state.presentation.index)
	elif state.finished:
		_show_portrait("")
		%DialogueBox.show_text(state.result_text())
		_button(actions,"查看终局结果","report",_show_report)
		_button(actions,"重新开始王城…","restart",_restart_ask)
	else:
		_show_portrait(Royal.NAMES.get(state.selected,""))
		%DialogueBox.show_text(guidance.next)
		_build_actions()
		_empty_actions_hint()
	choice_scroll.scroll_vertical = 0
	_save_caption()

func _build_actions() -> void:
	var group: String = "research" if state.selected.is_empty() else state.selected
	if state.day==6 and group=="research": _button(actions,"查看四种最终选择与条件","endings",_ending_options)
	for id in Royal.ACTIONS:
		if Royal.ACTIONS[id].group!=group or (state.completed(id) and id!="protect_source"): continue
		var reasons: Array=state.blocked(id)
		var label: String=Royal.ACTIONS[id].title+" · %d AP" % state.cost(id)
		if not reasons.is_empty(): label+="\n"+str(reasons[0])
		_button(actions,label,id,_royal_preview.bind(id),not reasons.is_empty())

func _ending_options() -> void:
	_popup("定界大典 · 选择之前")
	_text(overlay_body,state.progress_text(),23)
	for ending_id in Royal.ENDINGS:
		var id: String="final_"+ending_id
		var reasons: Array=state.blocked(id)
		_text(overlay_body,Royal.ENDINGS[ending_id]+"："+("条件已满足" if reasons.is_empty() else "；".join(reasons)),23)
		_button(overlay_actions,Royal.ACTIONS[id].title+" · %d AP" % state.cost(id),id,_royal_preview.bind(id),not reasons.is_empty())

func _research() -> void:
	state.selected=""
	_save()
	_refresh()

func _royal_preview(id: String) -> void:
	_popup(Royal.ACTIONS[id].title)
	var preview: Dictionary=state.preview(id)
	_text(overlay_body,preview.text,24)
	if id.begins_with("final_"): _text(overlay_body,"此操作会结束故事并保存结局。可先返回继续调查。",24,GOLD)
	if preview.allowed: _button(overlay_actions,"确认选择" if id.begins_with("final_") else "确认执行 · %d AP" % state.cost(id),"execute",_royal_execute.bind(id))

func _royal_execute(id: String) -> void:
	if not state.execute(id):
		_royal_preview(id)
		return
	overlay.hide()
	_play(RoyalStory.action(state,id),"ending" if state.finished else "action",Royal.NAMES.get(state.selected,""))

func _on_character_selected(index: int, _person: String, _summary: String, _texture: Texture2D) -> void:
	if busy() or state.finished or overlay.visible or map_modal.visible: return
	state.selected = ["priest","inspector","king"][index]
	_play(RoyalStory.greeting(state,state.selected),"greeting",Royal.NAMES[state.selected])

func _on_line_presented(index: int, speaker: String) -> void:
	if not busy(): return
	state.presentation.index = index
	if speaker in Royal.NAMES.values(): _show_portrait(speaker)
	state.presentation.portrait = %PortraitPanel.character
	continue_hint.text = "点击文字框 / 回车继续　%d / %d ›" % [index+1,state.presentation.lines.size()]
	_save()
	_save_caption()

func _on_dialogue_finished() -> void:
	if not busy(): return
	state.presentation = {}
	_save()
	_refresh()

func _ask_end() -> void:
	if busy() or state.finished or overlay.visible or map_modal.visible: return
	_popup("结束大典？" if state.day==6 else "结束当天？")
	_text(overlay_body,state.end_preview(),24)
	_text(overlay_body,"时间提醒\n"+"\n".join(_time_notices()),23,GOLD)
	_button(overlay_actions,"确认结束大典" if state.day==6 else "确认结束当天","confirm_day",_end_day)

func _end_day() -> void:
	if not state.end_day(): return
	overlay.hide()
	if state.finished:
		var text: Array = state.events.duplicate()
		text.append(state.result_text())
		text.append("各地认知、人物处境和最终选择已保存。")
		_play(Story.lines(text),"departure")
	else: _play(RoyalStory.day_start(state),"day")

func _show_report() -> void:
	_popup("终局结果")
	_text(overlay_body,state.report(),24)

func _toolbar(id: String) -> void:
	if busy() or overlay.visible or map_modal.visible: return
	match id:
		"journal": _show_progress()
		"people": _show_people_page()
		"evidence":
			_popup("王城材料与各地认知")
			for doc in Royal.DOCS: _text(overlay_body,Royal.DOCS[doc]+"："+("已取得" if state.docs.has(doc) else "未取得"),23)
			_text(overlay_body,state.report(),23)
		"map":
			var places: Array=[]
			for place in Art.BACKGROUNDS: places.append({"id":place,"reachable":true})
			map_modal.configure({"show_ocean":state.ending=="sea","places":places})
			map_modal.open()
		"settings":
			_popup("王城设置")
			_text(overlay_body,"六天，每天3 AP。阅读与区域内切换免费，第6天选择终局。原章节存档保留，重新开始只影响本章。",24)
			_button(overlay_actions,"保存进度","save",_manual_save)
			_button(overlay_actions,"读取最近进度","load",_load_ask)
			_button(overlay_actions,"重新开始王城…","restart",_restart_ask)

func _open_research() -> void:
	overlay.hide()
	_research()

func _map_place(id: String) -> void:
	map_modal.hide()
	_popup(Art.PLACE_NAMES[id])
	var picture := TextureRect.new()
	picture.texture = Art.BACKGROUNDS[id]
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size.y = 350
	overlay_body.add_child(picture)
	if id=="royal_city" and not state.finished: _button(overlay_actions,"回到王城公共调查 · 免费","enter_royal",_open_research)
	else: _text(overlay_body,"地点预览。前区成果已承接，不能返回前章补做行动。",24)

func _save() -> void:
	if save_blocked: return
	var error := RoyalSave.save_to(save_path,state)
	save_error = "保存失败，当前行动已执行，可在设置中重试："+error_string(error) if error!=OK else ""

func _save_caption() -> void:
	save_label.text = save_error if not save_error.is_empty() else "王城进度自动保存 · 第5天末查封 · 第6天最终选择"

func _load_ask() -> void:
	_popup("读取王城进度？")
	_button(overlay_actions,"确认读取","confirm_load",_load)

func _load() -> void:
	var loaded := RoyalSave.load_from(save_path)
	if not loaded.ok:
		_popup("未能读取，原文件与当前进度保留")
		return
	state = loaded.state
	save_blocked = false
	overlay.hide()
	_refresh()

func _restart_ask() -> void:
	_popup("重新开始王城六天？")
	_text(overlay_body,"以同一份羽之森离林结果重新开始王城；前章存档不变。")
	_button(overlay_actions,"确认重新开始","confirm_restart",_restart)

func _restart() -> void:
	var seed: Dictionary = state.origin.duplicate(true)
	# Fresh replay restores one-use offers from the original entry snapshot.

	if save_blocked: save_path += ".recovered"
	save_blocked = false
	state = Royal.new()
	state.initialize(seed)
	overlay.hide()
	_play(RoyalStory.opening(state),"opening")

func _chapter_guidance() -> Dictionary:
	return RoyalStory.stage(state)
