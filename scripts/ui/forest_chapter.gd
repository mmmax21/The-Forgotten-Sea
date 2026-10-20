extends "res://scripts/ui/trial1.gd"
## Uses the same scene components and input gestures, with independent chapter rules.
const Forest := preload("res://scripts/story/forest_chapter_state.gd")
const ForestStory := preload("res://scripts/story/forest_chapter_story.gd")
const ForestSave := preload("res://scripts/story/forest_chapter_save.gd")
var academy_snapshot: Dictionary = {}
const STORY_PICTURES := {
	"training": {"title":"普通人也曾飞行", "path":"res://assets/feather_forest/羽之森_旧训练场.png"},
	"flight": {"title":"第一次短暂腾空", "path":"res://assets/feather_forest/羽之森_首次腾空.png"},
	"ban": {"title":"从不许飞到不能飞", "path":"res://assets/feather_forest/羽之森_禁飞规定与讲义.png"},
	"tower": {"title":"高塔远眺", "path":"res://assets/feather_forest/羽之森_高塔远眺.png"},
}
var active_story_picture := ""

func _ready() -> void:
	if save_path=="user://trial1_village_v1.json": save_path = "user://trial1_forest_v2.json"
	state = Forest.new()
	_build_theme()
	_build_ui()
	overlay.visibility_changed.connect(_story_picture_visibility_changed)
	for child in %Design.get_children():
		if child is Label and child.text=="渔村六日 · 调查与抉择": child.text = "羽之森五日 · 羽翼与边界"
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
	var loaded := ForestSave.load_from(save_path)
	if loaded.ok:
		state = loaded.state
		if loaded.get("backup",false): save_error = "已从上一份有效备份恢复羽之森进度。"
	elif not loaded.get("missing",false):
		save_blocked = true
		save_error = "羽之森存档损坏，原文件保留。可在设置中重新开始临时进度。"
		state.initialize(academy_snapshot)
	else:
		state.initialize(academy_snapshot)
		state.presentation = {"lines":ForestStory.opening(state),"index":0,"kind":"opening","portrait":""}
	_refresh()

func _show_portrait(person: String) -> void:
	if person.is_empty(): %PortraitPanel.clear_character()
	else: %PortraitPanel.present(person,null)

func _refresh_people() -> void:
	var ids := ["el","lo","ika"]
	var people: Array = []
	for who in ids:
		var p: Dictionary = state.people[who]
		people.append({"name":Forest.NAMES[who],"portrait":null,"summary":"信任%d / 警戒%d\n%s" % [p.t,p.a,state.status(who)],"disabled":busy() or state.finished,"visible":true})
	if rail_names!=ids:
		rail_names = ids
		%CharacterRail.configure(people)
	else:
		var cards := %CharacterRail.get_node("Cards").get_children()
		for i in people.size(): cards[i].configure(people[i].name,null,people[i].summary,people[i].disabled,true,i)
	var forest_cards := %CharacterRail.get_node("Cards").get_children()
	for i in forest_cards.size():
		if forest_cards[i].has_node("RolePlaceholder"): continue
		var role := Label.new()
		role.name = "RolePlaceholder"
		role.text = ["向往飞行","普通居民","羽族贵族"][i]
		role.position = Vector2(16,35)
		role.size = Vector2(112,60)
		role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		role.add_theme_font_size_override("font_size",21)
		role.add_theme_color_override("font_color",Color("d5bb83"))
		role.mouse_filter = Control.MOUSE_FILTER_IGNORE
		forest_cards[i].add_child(role)
	%CharacterRail.visible = not state.finished

func _refresh() -> void:
	%LocationBackground.texture = Art.BACKGROUNDS.feather_forest
	%TopBar.apply_engine({"stats":[{"label":"公众海洋认知","value":state.belief}],"buttons":[{"id":"journal","text":"进度"},{"id":"evidence","text":"材料"},{"id":"people","text":"人物"},{"id":"settings","text":"设置"}],"day":state.day,"total":5,"ap":state.ap,"ap_max":3})
	%TopBar.get_node("DayBadge/Caption").text = "%d / 5" % state.day
	for button in %TopBar.button_row().get_children(): button.disabled = busy()
	_refresh_people()
	var guidance: Dictionary = _chapter_guidance()
	_render_progress_side()
	end_button.visible = not state.finished
	end_button.disabled = busy()
	end_button.text = "离林交接与结算" if state.day==5 else "结束当天 · 剩%d AP" % state.ap
	subtitle.text = "羽之森五日 · 阅读与切换免费"
	heading.text = "羽之森调查" if state.selected.is_empty() else Forest.NAMES[state.selected]
	_clear(actions)
	choice_scroll.visible = not busy()
	continue_hint.text = ""
	if busy():
		_show_portrait(state.presentation.get("portrait",""))
		%DialogueBox.show_from(state.presentation.lines,state.presentation.index)
	elif state.finished:
		_show_portrait("")
		%DialogueBox.show_text("高塔证据已核实并保全，羽之森基本目标完成。" if state.success() else "你离开了羽之森。未完成的调查与传播会分别记入结果。")
		_button(actions,"前往 / 继续王城","royal",_enter_royal)
		_button(actions,"查看离林结果","report",_show_report)
		_button(actions,"重新开始羽之森…","restart",_restart_ask)
	else:
		_show_portrait(Forest.NAMES.get(state.selected,""))
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
	for id in Forest.ACTIONS:
		if Forest.ACTIONS[id].group!=group: continue
		if id in ["er_prepare","er_receive"] and not state.er_investigated(): continue
		if state.completed(id): continue
		var reasons: Array = state.blocked(id)
		var label: String = Forest.ACTIONS[id].title+" · %d AP" % state.cost(id)
		var aided: bool = state.support_available(id) and state.preview(id,true).allowed
		if state.support_available(id): label+=" · 可选学城帮助减1 AP"
		if not reasons.is_empty() and not aided: label+="\n"+str(reasons[0])
		_button(actions,label,id,_forest_preview.bind(id),not reasons.is_empty() and not state.preview(id,true).allowed)

func _research() -> void:
	state.selected=""
	_save()
	_refresh()

func _forest_preview(id: String, reviewed := false) -> void:
	if id=="verify_history" and not reviewed and state.preview(id).allowed:
		_forest_compare(id)
		return
	_popup(Forest.ACTIONS[id].title)
	var preview: Dictionary=state.preview(id)
	if not preview.allowed and state.support_available(id) and state.preview(id,true).allowed:
		preview.text=preview.text.replace("不能执行：", "直接执行条件不足：")+"\n可选择下方学城帮助，以%d AP完成本次行动。" % state.cost(id,true)
	_text(overlay_body,preview.text,24)
	if preview.allowed: _button(overlay_actions,"确认执行 · %d AP" % state.cost(id),"execute",_forest_execute.bind(id,false))
	if state.support_available(id):
		var aided: Dictionary=state.preview(id,true)
		if aided.allowed: _button(overlay_actions,"使用学城帮助 · %d AP（节省1 AP）" % state.cost(id,true),"execute_support",_forest_execute.bind(id,true))

func _forest_compare(id: String, retry := false) -> void:
	_popup("核对翅骨与文书 · 阅读与作答免费")
	_text(overlay_body,"古老骨架有完整翼骨，如今羽人只留下骨痕。修建记录写着阻止飞往外界、删除相关历史。这些材料能说明什么？",24)
	if retry: _text(overlay_body,"它们支持过去能够飞行、后来受到人为限制；不能证明贵族有特殊血统，也不能保证所有人立刻恢复。重试免费。",24,GOLD)
	_button(overlay_actions,"羽族过去能飞，人为限制和身体变化仍需继续追查","compare_correct",_forest_preview.bind(id,true))
	_button(overlay_actions,"只有贵族祖先能飞，取得骨头就能立刻恢复飞行","compare_retry",_forest_compare.bind(id,true))

func _forest_execute(id: String, use_support := false) -> void:
	if not state.execute(id,use_support):
		_forest_preview(id)
		return
	overlay.hide()
	_play(ForestStory.action(state,id),"action",Forest.NAMES.get(state.selected,""))

func _on_character_selected(index: int, _person: String, _summary: String, _texture: Texture2D) -> void:
	if busy() or state.finished or overlay.visible or map_modal.visible: return
	state.selected = ["el","lo","ika"][index]
	_play(ForestStory.greeting(state,state.selected),"greeting",Forest.NAMES[state.selected])

func _on_line_presented(index: int, speaker: String) -> void:
	if not busy(): return
	state.presentation.index = index
	if speaker in Forest.NAMES.values(): _show_portrait(speaker)
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
	_popup("离林交接" if state.day==5 else "结束当天？")
	_text(overlay_body,state.end_preview(),24)
	_text(overlay_body,"时间提醒\n"+"\n".join(_time_notices()),23,GOLD)
	_button(overlay_actions,"确认离林" if state.day==5 else "确认结束当天","confirm_day",_end_day)

func _end_day() -> void:
	if not state.end_day(): return
	overlay.hide()
	if state.finished:
		_play(ForestStory.departure(state),"departure")
	else: _play(ForestStory.day_start(state),"day")

func _show_report() -> void:
	_popup("离林结果")
	_text(overlay_body,state.report(),24)

func _toolbar(id: String) -> void:
	if busy() or overlay.visible or map_modal.visible: return
	match id:
		"journal": _show_progress()
		"people": _show_people_page()
		"evidence":
			_popup("羽之森材料与观察")
			for doc in Forest.DOCS: _text(overlay_body,Forest.DOCS[doc]+"："+("已取得" if state.docs.has(doc) else "未取得"),23)
			_text(overlay_body,"当前海洋说明：小范围+%d，公开+%d。新增依据需补充说明才给原读者增加差额。\n学城帮助剩余%d AP，由行动确认页主动选择。" % [state.reward("small"),state.reward("public"),2-state.discount_used],23)
			_text(overlay_body,state.report(),23)
		"map":
			var places: Array=[]
			for place in Art.BACKGROUNDS: places.append({"id":place,"reachable":true})
			map_modal.configure({"show_ocean":false,"places":places})
			map_modal.open()
		"settings":
			_popup("羽之森设置")
			_text(overlay_body,"五天，每天3 AP。阅读与区域内切换免费。第四天末封锁高塔，第五天安翼礼后离林。已取得的证据与传播不会被撤回。新版从同一学城成果另存开始，旧版存档保留。",24)
			_button(overlay_actions,"保存进度","save",_manual_save)
			_button(overlay_actions,"读取最近进度","load",_load_ask)
			_button(overlay_actions,"重新开始羽之森…","restart",_restart_ask)

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
	if id=="royal_city" and state.finished: _button(overlay_actions,"前往 / 继续王城","enter_royal",_enter_royal_from_map)
	elif id=="feather_forest" and not state.finished: _button(overlay_actions,"回到羽之森公共调查 · 免费","enter_forest",_open_research)
	else: _text(overlay_body,"地点预览。当前不能返回前章补做行动，完成羽之森后可前往王城。",24)

func _save() -> void:
	if save_blocked: return
	var error := ForestSave.save_to(save_path,state)
	save_error = "保存失败，当前行动已执行，可在设置中重试："+error_string(error) if error!=OK else ""

func _save_caption() -> void:
	save_label.text = save_error if not save_error.is_empty() else "羽之森进度自动保存到当前对白 · 第4天末高塔封锁 · 第5天末离林"

func _load_ask() -> void:
	_popup("读取羽之森进度？")
	_button(overlay_actions,"确认读取","confirm_load",_load)

func _load() -> void:
	var loaded := ForestSave.load_from(save_path)
	if not loaded.ok:
		_popup("未能读取，原文件与当前进度保留")
		return
	state = loaded.state
	save_blocked = false
	overlay.hide()
	_refresh()

func _restart_ask() -> void:
	_popup("重新开始羽之森五天？")
	_text(overlay_body,"以同一份学城离城结果重新开始羽之森；前章存档不变。")
	_button(overlay_actions,"确认重新开始","confirm_restart",_restart)

func _restart() -> void:
	var seed: Dictionary = state.origin.duplicate(true)
	# Fresh replay restores one-use offers from the original entry snapshot.

	if save_blocked: save_path += ".recovered"
	save_blocked = false
	state = Forest.new()
	state.initialize(seed)
	overlay.hide()
	_play(ForestStory.opening(state),"opening")

func _enter_royal() -> void:
	if not state.finished or busy() or overlay.visible or map_modal.visible: return
	var seed: Dictionary=state.snapshot.duplicate(true)
	var identity:=JSON.stringify(seed).sha256_text().substr(0,16)
	var next=load("res://scenes/royal_chapter.tscn").instantiate()
	next.save_path=save_path+".royal-"+identity+".json"
	next.forest_snapshot=seed
	get_parent().add_child(next)
	if get_tree().current_scene==self: get_tree().current_scene=next
	queue_free()

func _enter_royal_from_map() -> void:
	overlay.hide()
	_enter_royal()

func _chapter_guidance() -> Dictionary:
	return ForestStory.stage(state)
