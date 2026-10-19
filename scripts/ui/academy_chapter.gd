extends "res://scripts/ui/trial1.gd"
## Uses the same scene components and input gestures, with independent chapter rules.
const Academy := preload("res://scripts/story/academy_chapter_state.gd")
const AcademyStory := preload("res://scripts/story/academy_chapter_story.gd")
const AcademySave := preload("res://scripts/story/academy_chapter_save.gd")
var market_snapshot: Dictionary = {}
const STORY_PICTURES := {
	"harbor": {"title":"旧书里的港口", "path":"res://assets/study_city/学城_旧港口图_剧情弹窗.png"},
	"compare": {"title":"新旧书页的差异", "path":"res://assets/study_city/学城_新旧书校对_剧情弹窗.png"},
	"consult": {"title":"向墨先生求证", "path":"res://assets/study_city/学城_向莫先生求证_剧情弹窗.png"},
}
var active_story_picture := ""

func _ready() -> void:
	if save_path=="user://trial1_village_v1.json": save_path = "user://trial1_academy_v1.json"
	state = Academy.new()
	_build_theme()
	_build_ui()
	overlay.visibility_changed.connect(_story_picture_visibility_changed)
	for child in %Design.get_children():
		if child is Label and child.text=="渔村六日 · 调查与抉择": child.text = "学城五日 · 旧史与抉择"
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
	var loaded := AcademySave.load_from(save_path)
	if loaded.ok:
		state = loaded.state
		if loaded.get("backup",false): save_error = "已从上一份有效备份恢复学城进度。"
	elif not loaded.get("missing",false):
		save_blocked = true
		save_error = "学城存档损坏，原文件保留。可在设置中重新开始临时进度。"
		state.initialize(market_snapshot)
	else:
		state.initialize(market_snapshot)
		state.presentation = {"lines":AcademyStory.opening(state),"index":0,"kind":"opening","portrait":""}
	_refresh()

func _show_portrait(person: String) -> void:
	if person.is_empty(): %PortraitPanel.clear_character()
	else: %PortraitPanel.present(person,null)

func _refresh_people() -> void:
	var ids := ["mo","er","gao"]
	var people: Array = []
	for who in ids:
		var p: Dictionary = state.people[who]
		people.append({"name":Academy.NAMES[who],"portrait":null,"summary":"信任%d / 警戒%d\n%s" % [p.t,p.a,state.status(who)],"disabled":busy() or state.finished,"visible":true})
	if rail_names!=ids:
		rail_names = ids
		%CharacterRail.configure(people)
	else:
		var cards := %CharacterRail.get_node("Cards").get_children()
		for i in people.size(): cards[i].configure(people[i].name,null,people[i].summary,people[i].disabled,true,i)
	var academy_cards := %CharacterRail.get_node("Cards").get_children()
	for i in academy_cards.size():
		if academy_cards[i].has_node("RolePlaceholder"): continue
		var role := Label.new()
		role.name = "RolePlaceholder"
		role.text = ["历史学者","抄写员","历史维护者"][i]
		role.position = Vector2(16,35)
		role.size = Vector2(112,60)
		role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		role.add_theme_font_size_override("font_size",21)
		role.add_theme_color_override("font_color",Color("d5bb83"))
		role.mouse_filter = Control.MOUSE_FILTER_IGNORE
		academy_cards[i].add_child(role)
	%CharacterRail.visible = not state.finished

func _refresh() -> void:
	%LocationBackground.texture = Art.BACKGROUNDS.old_academy
	%TopBar.apply_engine({"stats":[{"label":"公众海洋认知","value":state.belief}],"buttons":[{"id":"journal","text":"进度"},{"id":"evidence","text":"材料"},{"id":"people","text":"人物"},{"id":"settings","text":"设置"}],"day":state.day,"total":5,"ap":state.ap,"ap_max":3})
	%TopBar.get_node("DayBadge/Caption").text = "%d / 5" % state.day
	for button in %TopBar.button_row().get_children(): button.disabled = busy()
	_refresh_people()
	var guidance: Dictionary = _chapter_guidance()
	_render_progress_side()
	end_button.visible = not state.finished
	end_button.disabled = busy()
	end_button.text = "离城交接与结算" if state.day==5 else "结束当天 · 剩%d AP" % state.ap
	subtitle.text = "学城五日 · 阅读与切换免费"
	heading.text = "学城调查" if state.selected.is_empty() else Academy.NAMES[state.selected]
	_clear(actions)
	choice_scroll.visible = not busy()
	continue_hint.text = ""
	if busy():
		_show_portrait(state.presentation.get("portrait",""))
		%DialogueBox.show_from(state.presentation.lines,state.presentation.index)
	elif state.finished:
		_show_portrait("")
		%DialogueBox.show_text("学城调查成功。已查明有意删改，并留下有效成果。" if state.success() else "你离开了学城。未完成的调查与传播会分别记入结果。")
		_button(actions,"前往 / 继续羽之森","forest",_enter_forest)
		_button(actions,"查看离城结果","report",_show_report)
		_button(actions,"重新开始学城…","restart",_restart_ask)
	else:
		_show_portrait(Academy.NAMES.get(state.selected,""))
		%DialogueBox.show_text(guidance.next)
		_build_actions()
		_empty_actions_hint()
	choice_scroll.scroll_vertical = 0
	_save_caption()

func _show_story_picture(line: Dictionary) -> void:
	var id := str(line.get("illustration",""))
	if not STORY_PICTURES.has(id) or state.flags.has("seen_picture_"+id): return
	active_story_picture = id
	_popup(STORY_PICTURES[id].title)
	var picture := TextureRect.new()
	picture.name = "StoryPicture"
	picture.texture = load(STORY_PICTURES[id].path)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size.y = 530
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_body.add_child(picture)
	_text(overlay_body,str(line.get("text","")),24)
	_clear(overlay_actions)
	var close := _button(overlay_actions,"继续阅读 · 回车 / Esc","close",overlay.hide)
	close.focus_mode = Control.FOCUS_NONE

func _story_picture_visibility_changed() -> void:
	if overlay.visible or active_story_picture.is_empty(): return
	state.flags["seen_picture_"+active_story_picture] = true
	active_story_picture = ""
	_save()

func _unhandled_key_input(event: InputEvent) -> void:
	if not active_story_picture.is_empty() and overlay.visible:
		if (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")) and not event.is_echo():
			overlay.hide()
			get_viewport().set_input_as_handled()
		return
	super._unhandled_key_input(event)

func _build_actions() -> void:
	var group: String = "research" if state.selected.is_empty() else state.selected
	for id in Academy.ACTIONS:
		if Academy.ACTIONS[id].group!=group: continue
		if state.flags.has(state.action_key(id)): continue
		var reasons: Array = state.blocked(id)
		var label: String = Academy.ACTIONS[id].title+" · %d AP" % state.cost(id)
		if not reasons.is_empty(): label+="\n"+str(reasons[0])
		_button(actions,label,id,_academy_preview.bind(id),not reasons.is_empty())

func _research() -> void:
	state.selected=""
	_save()
	_refresh()

func _academy_preview(id: String, reviewed := false) -> void:
	if id in ["verify","trace"] and not reviewed and state.preview(id).allowed:
		_academy_compare(id)
		return
	_popup(Academy.ACTIONS[id].title)
	var preview: Dictionary = state.preview(id)
	_text(overlay_body,preview.text,24)
	if preview.allowed: _button(overlay_actions,"确认执行","execute",_academy_execute.bind(id))

func _academy_compare(id: String, retry := false) -> void:
	_popup("核对依据 · 阅读与作答免费")
	_text(overlay_body,"新旧版本保留相同姓名、年代与货数，海港和远航却被改为内河。" if id=="verify" else "三处藏书馆换了同一批书，通知要求删改海洋内容，编号与书页、交接记录相同。它们合起来说明什么？",24)
	if retry: _text(overlay_body,"书页能证明改了什么，换书记录和通知才能说明怎样发生。不能把所有历史都当作假的，重试不扣AP。",24,GOLD)
	_button(overlay_actions,"同一件事里，海洋与远航内容被改掉了" if id=="verify" else "这些书按同一份通知被改写并替换","compare_correct",_academy_preview.bind(id,true))
	_button(overlay_actions,"只要版本不同，就证明所有历史都是伪造","compare_retry",_academy_compare.bind(id,true))

func _academy_execute(id: String) -> void:
	if not state.execute(id):
		_academy_preview(id)
		return
	overlay.hide()
	_play(AcademyStory.action(state,id),"action",Academy.NAMES.get(state.selected,""))

func _on_character_selected(index: int, _person: String, _summary: String, _texture: Texture2D) -> void:
	if busy() or state.finished or overlay.visible or map_modal.visible: return
	state.selected = ["mo","er","gao"][index]
	_play(AcademyStory.greeting(state,state.selected),"greeting",Academy.NAMES[state.selected])

func _on_line_presented(index: int, speaker: String) -> void:
	if not busy(): return
	state.presentation.index = index
	if speaker in Academy.NAMES.values(): _show_portrait(speaker)
	state.presentation.portrait = %PortraitPanel.character
	continue_hint.text = "点击文字框 / 回车继续　%d / %d ›" % [index+1,state.presentation.lines.size()]
	_save()
	_save_caption()
	_show_story_picture(state.presentation.lines[index])

func _on_dialogue_finished() -> void:
	if not busy(): return
	state.presentation = {}
	_save()
	_refresh()

func _ask_end() -> void:
	if busy() or state.finished or overlay.visible or map_modal.visible: return
	_popup("离城交接" if state.day==5 else "结束当天？")
	_text(overlay_body,state.end_preview(),24)
	_text(overlay_body,"时间提醒\n"+"\n".join(_time_notices()),23,GOLD)
	_button(overlay_actions,"确认离城" if state.day==5 else "确认结束当天","confirm_day",_end_day)

func _end_day() -> void:
	if not state.end_day(): return
	overlay.hide()
	if state.finished:
		_play(AcademyStory.departure(state),"departure")
	else: _play(AcademyStory.day_start(state),"day")

func _show_report() -> void:
	_popup("离城结果")
	_text(overlay_body,state.report(),24)

func _toolbar(id: String) -> void:
	if busy() or overlay.visible or map_modal.visible: return
	match id:
		"journal": _show_progress()
		"people": _show_people_page()
		"evidence":
			_popup("档案与来源")
			for doc in Academy.DOCS: _text(overlay_body,Academy.DOCS[doc]+"："+("随身保全" if state.docs.has(doc) else "尚未取得"),23)
			_text(overlay_body,"同一旧文的抄本只算同一来源。随身渔村实证或馆藏器具经过核验，可使讲读与质证各多10认知；已传播需另花1 AP补充说明。",23)
			_text(overlay_body,"来件与交接\n"+state.report(),23)
		"map":
			var places: Array = []
			for place in Art.BACKGROUNDS: places.append({"id":place,"reachable":true})
			map_modal.configure({"show_ocean":false,"places":places})
			map_modal.open()
		"settings":
			_popup("学城设置")
			_text(overlay_body,"五天，每天3 AP。阅读与区域内切换免费。第三天停止普通旧稿调阅，第四天末清理，第五天审议。已保全或传播的成果不会被撤回。",24)
			_button(overlay_actions,"保存进度","save",_manual_save)
			_button(overlay_actions,"读取最近进度","load",_load_ask)
			_button(overlay_actions,"重新开始学城…","restart",_restart_ask)

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
	if id=="feather_forest" and state.finished: _button(overlay_actions,"前往 / 继续羽之森","enter_forest",_enter_forest_from_map)
	elif id=="old_academy" and not state.finished: _button(overlay_actions,"回到学城公共档案 · 免费","enter_archive",_open_research)
	else: _text(overlay_body,"地点预览。当前章节不能回到渔村补做行动，离城后可前往羽之森，羽之森结束后可进入王城。",24)

func _save() -> void:
	if save_blocked: return
	var error := AcademySave.save_to(save_path,state)
	save_error = "保存失败，当前行动已执行，可在设置中重试："+error_string(error) if error!=OK else ""

func _save_caption() -> void:
	save_label.text = save_error if not save_error.is_empty() else "学城进度自动保存到当前对白 · 第4天末清理旧稿 · 第5天末离城"

func _load_ask() -> void:
	_popup("读取学城进度？")
	_button(overlay_actions,"确认读取","confirm_load",_load)

func _load() -> void:
	var loaded := AcademySave.load_from(save_path)
	if not loaded.ok:
		_popup("未能读取，原文件与当前进度保留")
		return
	state = loaded.state
	save_blocked = false
	overlay.hide()
	_refresh()

func _restart_ask() -> void:
	_popup("重新开始学城五天？")
	_text(overlay_body,"以同一份集市离市结果重新开始学城；前章存档不变。")
	_button(overlay_actions,"确认重新开始","confirm_restart",_restart)

func _restart() -> void:
	var seed: Dictionary = state.origin.duplicate(true)
	# Fresh replay restores one-use offers from the original entry snapshot.

	if save_blocked: save_path += ".recovered"
	save_blocked = false
	state = Academy.new()
	state.initialize(seed)
	overlay.hide()
	_play(AcademyStory.opening(state),"opening")

func _enter_forest() -> void:
	if not state.finished or busy() or overlay.visible or map_modal.visible: return
	var seed: Dictionary=state.snapshot.duplicate(true)
	var identity:=JSON.stringify(seed).sha256_text().substr(0,16)
	var next=load("res://scenes/forest_chapter.tscn").instantiate()
	next.save_path=save_path+".forest-v2-"+identity+".json"
	next.academy_snapshot=seed
	get_parent().add_child(next)
	if get_tree().current_scene==self: get_tree().current_scene=next
	queue_free()

func _enter_forest_from_map() -> void:
	overlay.hide()
	_enter_forest()

func _chapter_guidance() -> Dictionary:
	return AcademyStory.stage(state)
