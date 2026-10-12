extends Control
## 独立的渔村—遗迹剧情入口，复用现有 UI 组件。
const DefaultCharacters := preload("res://scripts/ui/character_card/default_characters.gd")
const State := preload("res://scripts/story/ruins_state.gd")
const Modal := preload("res://scripts/ui/story_modal.gd")
const ACTION_LABELS := {"guide": "哑伯的指引", "plank": "出示船歌", "perform": "按照曲谱演奏", "blueprint": "询问船的构造", "investigate": "对照图纸调查", "verify": "请哑伯辨认", "fisher": "询问老渔夫"}
const ITEM_TEXT := {
	"古老的船歌": "字迹漫漶，隐约可以识读——「向您致敬，深蓝发的神明！蒙您庇佑，我们在波涛之间……」",
	"旧木板": "形状奇怪的旧木板，似乎是某种大型物件的碎片，上面刻有形似音符的符号。",
	"造船图纸": "记录着船只的构造与制作方法，还有一些难以理解的词句。",
}
@export var save_path := "user://ruins_story_v1.json"
var state = State.new()
var story: Dictionary
var selected_actor := -1
var busy := false
var move_target := ""
var after_notice := ""
var modal
var action_row: HBoxContainer
var task_label: Label
var end_day: Button
var continue_hint: Label
var ruins_background: TextureRect
var save_error := false

func _ready() -> void:
	story = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/ya_bo.json"))
	_build_controls()
	resized.connect(_fit_design)
	_fit_design()
	%CharacterRail.configure(_people())
	%CharacterRail.character_selected.connect(_on_character_selected)
	%TopBar.action_pressed.connect(_on_toolbar)
	%MiniMap.action_pressed.connect(_on_minimap)
	%MiniMap.get_node("Compass").tooltip_text = "打开地图"
	%MiniMap.get_node("Upper").tooltip_text = "物品"
	%MiniMap.get_node("Lower").tooltip_text = "结束今日行动"
	%DialogueBox.dialogue_finished.connect(_on_dialogue_finished)
	%MapModal.place_chosen.connect(_on_map_location)
	state.load_from(save_path)
	_refresh()
	%DialogueBox.show_text("点击哑伯，了解他手中的旧木板。")
	if not state.pending.is_empty():
		_play(state.pending)
	elif state.stage == 1 and state.location == "ruins":
		_start("song")
	else:
		%DialogueBox.show_text(state.objective())

func _build_controls() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Kaiti SC", "Songti SC", "Microsoft YaHei"])
	var skin := Theme.new()
	skin.default_font = font
	skin.default_font_size = 24
	skin.set_color("font_color", "Label", Color(0.96, 0.9, 0.76))
	for kind in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.19, 0.15, 0.11, 0.96) if kind != "hover" else Color(0.32, 0.25, 0.16)
		style.border_color = Color(0.6, 0.46, 0.25)
		style.set_border_width_all(2)
		style.set_corner_radius_all(5)
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		skin.set_stylebox(kind, "Button", style)
	theme = skin
	ruins_background = TextureRect.new()
	ruins_background.name = "RuinsBackground"
	%Design.add_child(ruins_background)
	%Design.move_child(ruins_background, 0)
	ruins_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ruins_background.texture = preload("res://assets/backgrounds/ruins-v1.png")
	ruins_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ruins_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ruins_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	task_label = Label.new()
	task_label.position = Vector2(250, 245)
	task_label.size = Vector2(1100, 85)
	task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	task_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	task_label.add_theme_constant_override("shadow_offset_x", 2)
	task_label.add_theme_constant_override("shadow_offset_y", 2)
	%Design.add_child(task_label)
	action_row = HBoxContainer.new()
	action_row.position = Vector2(250, 580)
	action_row.add_theme_constant_override("separation", 12)
	%Design.add_child(action_row)
	end_day = Button.new()
	end_day.position = Vector2(1535, 650)
	end_day.text = "结束今日行动"
	end_day.pressed.connect(_ask_end_day)
	%Design.add_child(end_day)
	continue_hint = Label.new()
	continue_hint.position = Vector2(1070, 950)
	continue_hint.text = "点击文字框 / 回车继续 ›"
	continue_hint.add_theme_font_size_override("font_size", 20)
	continue_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%Design.add_child(continue_hint)
	# All dialogs are above text, portraits and action buttons.
	%Design.move_child(%MapModal, %Design.get_child_count() - 1)
	%Design.move_child(%Notice, %Design.get_child_count() - 1)
	modal = Modal.new()
	modal.name = "StoryModal"
	%Design.add_child(modal)
	modal.selected.connect(_on_modal_selected)

func _fit_design() -> void:
	var factor := minf(size.x / 1920.0, size.y / 1032.0)
	%Design.scale = Vector2.ONE * factor
	%Design.position = (size - Vector2(1920, 1032) * factor) / 2.0

func _refresh() -> void:
	%TopBar.apply_engine({"day": state.day, "ap": state.ap, "ap_max": 3})
	%TopBar.get_node("DayBadge/Ap").show()
	%CharacterRail.visible = state.location == "home"
	%PortraitPanel.visible = state.location == "home"
	ruins_background.visible = state.location == "ruins"
	task_label.text = "%s   ·   第 %d 天   ·   AP %d/3\n%s" % [State.NAMES[state.location], state.day, state.ap, state.objective()]
	if save_error:
		task_label.text += "\n存档失败，请检查保存目录权限。"
	end_day.disabled = busy
	continue_hint.visible = busy
	for child in action_row.get_children():
		action_row.remove_child(child)
		child.queue_free()
	if busy:
		return
	var id: String = state.expected_action()
	if state.stage == 8 and state.location == "home":
		_add_action("继续与老渔夫交谈", _show_choices)
	elif ACTION_LABELS.has(id):
		var in_ruins: bool = id == "investigate"
		var actor_ok: bool = selected_actor == (0 if id == "fisher" else 3)
		if (in_ruins and state.location == "ruins") or (not in_ruins and state.location == "home" and actor_ok):
			_add_action(ACTION_LABELS[id] + "（1 AP）", _start.bind(id), state.ap < 1)
			if state.ap < 1:
				action_row.get_child(0).tooltip_text = "行动点不足，请结束今日行动后继续"
	if state.location == "ruins":
		_add_action("返回哑伯住处…", _request_move.bind("home"))

func _add_action(label: String, callback: Callable, disabled := false) -> void:
	var button := Button.new()
	button.text = label
	button.disabled = disabled
	button.pressed.connect(callback)
	action_row.add_child(button)

func _on_character_selected(index: int, actor_name: String, summary: String, _portrait: Texture2D) -> void:
	if busy or modal.visible or %MapModal.visible or state.location != "home":
		return
	selected_actor = index
	%PortraitPanel.show_portrait(index, actor_name, " ")
	%DialogueBox.show_text(summary)
	_refresh()

func _start(id: String) -> void:
	if not state.begin(id):
		return
	_save()
	_play(id)

func _play(id: String) -> void:
	busy = true
	_refresh()
	var ids := ["guide", "song", "plank", "perform", "blueprint"]
	var lines: Array = story.events[ids.find(id)].lines if ids.has(id) else story.continuation[id]
	if state.location == "home":
		%PortraitPanel.show_portrait(0 if id == "fisher" else 3, "老渔夫" if id == "fisher" else "哑伯", " ")
	%DialogueBox.show_lines(lines)

func _on_dialogue_finished() -> void:
	if not busy:
		return
	busy = false
	var result: Dictionary = state.finish()
	_save()
	_refresh()
	if result.is_empty():
		if state.stage == 9:
			_message("本章完成", state.objective() + "\n\n你已完成当前章节。后续任务尚未开放，可以回看任务与物品。")
		return
	match result.id:
		"guide": _request_move("ruins")
		"song":
			after_notice = "return"
			_show_item("古老的船歌", true)
		"plank", "blueprint": _show_item(result.item, true)
		"perform": _message("记忆苏醒", "哑伯支持度 +10\n\n下一步：询问船的构造。")
		"investigate": _message("已记录：船骨的接缝", "返回哑伯住处，请他辨认这段船体结构。")
		"verify": _message("石拱下的船骨 · 完成", "哑伯证实了你的发现。下一步：与老渔夫交谈。")
		"fisher": _show_choices()

func _request_move(target: String) -> void:
	if busy:
		return
	if state.stage < 1:
		_message("尚无线索", "先与哑伯交谈，了解他指向的地方。")
		return
	if target == state.location:
		_message("当前位置", "你已经在%s。" % State.NAMES[target])
		return
	move_target = target
	modal.open("是否前往%s？" % State.NAMES[target], "本次移动消耗 1 点行动点。\n当前剩余：%d/3 AP%s" % [state.ap, "\n行动点不足，请结束今日行动后继续。" if state.ap < 1 else ""], [
		{"id": "move", "text": "前往%s（1 AP）" % State.NAMES[target], "disabled": not state.can_move(target)},
		{"id": "cancel", "text": "暂不前往"},
	])

func _on_minimap(id: String) -> void:
	if busy or modal.visible:
		return
	match id:
		"compass":
			%MapModal.configure({"show_ocean": false, "places": [{"id": "ruins", "reachable": state.stage >= 1}, {"id": "fishing_village", "reachable": true}]})
			%MapModal.open()
		"rim_upper": _show_inventory()
		"rim_lower": _ask_end_day()

func _on_map_location(id: String, _place_name: String) -> void:
	%MapModal.close()
	if id == "fishing_village":
		modal.open("渔村", "目的地：哑伯住处\n当前所在地：%s" % State.NAMES[state.location], [{"id": "home", "text": "哑伯住处…"}, {"id": "cancel", "text": "返回"}])
	elif id == "ruins":
		_request_move("ruins")

func _on_toolbar(id: String) -> void:
	if busy or modal.visible or %MapModal.visible:
		return
	match id:
		"tasks": _message("任务", state.objective() + "\n\n已完成：\n" + ("暂无" if state.history.is_empty() else "\n".join(state.history)))
		"items": _show_inventory()
		"status": _message("人物状态", "哑伯支持度：%d\n第 %d 天 · AP %d/3\n所在地：%s" % [state.support, state.day, state.ap, State.NAMES[state.location]])
		"settings": modal.open("设置", "进度在行动完成、移动和跨日后自动保存。", [{"id": "restart_ask", "text": "重新开始本章…"}, {"id": "cancel", "text": "返回游戏"}])

func _show_inventory() -> void:
	var options: Array = []
	for item in state.inventory:
		options.append({"id": "item:" + item, "text": item})
	options.append({"id": "cancel", "text": "返回游戏"})
	modal.open("物品", "暂无物品。" if state.inventory.is_empty() else "选择物品查看图像与说明。出示物品不会消耗它。", options)

func _show_item(item: String, acquired := false) -> void:
	modal.open(("获得 · " if acquired else "") + item, ITEM_TEXT[item], [{"id": "item_closed" if acquired else "inventory", "text": "收好" if acquired else "返回物品"}], load(story.item_icons[item]))

func _show_choices() -> void:
	modal.open("老渔夫的顾虑", "你找到的是一张纸。他担心的却是家人的平安。\n本次选择不额外消耗行动点。", [{"id": "choice:private", "text": "我只想私下问清楚。"}, {"id": "choice:protect", "text": "您担心的人，我能帮上什么？"}, {"id": "choice:later", "text": "今天先到这里。"}])

func _ask_end_day() -> void:
	if busy or modal.visible or %MapModal.visible:
		return
	modal.open("结束今日行动？", "当前剩余 %d AP。次日恢复至 3 AP，所在地、物品与任务进度保留。" % state.ap, [{"id": "day", "text": "结束今日行动", "disabled": false}, {"id": "cancel", "text": "继续探索"}])

func _on_modal_selected(id: String) -> void:
	if id.begins_with("item:"):
		_show_item(id.trim_prefix("item:"))
	elif id.begins_with("choice:"):
		var choice_id := id.trim_prefix("choice:")
		if state.choose(choice_id):
			_save()
			_refresh()
			if choice_id != "later":
				busy = true
				_refresh()
				%DialogueBox.show_lines(story.choice_lines[choice_id])
	match id:
		"move":
			if state.move_to(move_target):
				selected_actor = -1
				%PortraitPanel.hide_portrait()
				_save()
				_refresh()
				%DialogueBox.show_text(state.objective())
				if state.stage == 1 and state.location == "ruins":
					_start("song")
		"home": _request_move("home")
		"inventory": _show_inventory()
		"item_closed":
			if after_notice == "return":
				after_notice = ""
				_request_move("home")
		"day":
			if state.next_day():
				_save()
				_refresh()
				%DialogueBox.show_text("第 %d 天。行动点已恢复，继续你的探索。\n%s" % [state.day, state.objective()])
		"restart_ask": modal.open("重新开始本章？", "当前章节的存档将被重置。", [{"id": "restart", "text": "重新开始"}, {"id": "cancel", "text": "保留进度"}])
		"restart":
			state = State.new()
			selected_actor = -1
			after_notice = ""
			%PortraitPanel.hide_portrait()
			_save()
			_refresh()
			%DialogueBox.show_text(state.objective())

func _message(title: String, text: String) -> void:
	modal.open(title, text, [{"id": "cancel", "text": "返回"}])

func _save() -> void:
	var error: Error = state.save_to(save_path)
	save_error = error != OK
	if error != OK:
		push_warning("剧情存档失败：%s" % error_string(error))
		task_label.text += "\n存档失败，请检查保存目录权限。"

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not event.is_echo() and busy and not modal.visible and not %MapModal.visible:
		%DialogueBox.advance()
		get_viewport().set_input_as_handled()

func _people() -> Array:
	return [
		{
			"name": "老渔夫",
			"portrait": DefaultCharacters.portrait(0),
			"summary": "镇上的老渔夫，小时候见过海，也记得潮汐歌。父亲因公开说海存在被处决，所以他不敢再提。他想把记忆留下来，却害怕连累孙子。若不能先保证孙子安全，他只肯私下透露片段，不愿公开作证，更不会跟着去传播。",
			"disabled": false,
			"visible": true,
		},
		{
			"name": "盐嫂",
			"portrait": DefaultCharacters.portrait(1),
			"summary": "丈夫因调查海被处决。她恨王权，也怕自己再没有活路。这条是置灰示例，悬停不会弹出介绍。",
			"disabled": true,
			"visible": true,
		},
		{
			"name": "螺螺",
			"portrait": DefaultCharacters.portrait(2),
			"summary": "十二岁，捡到一枚贝壳，不相信大人说的「海不存在」。胆子大，也最容易被牵连。",
			"disabled": false,
			"visible": true,
		},
		{
			"name": "哑伯",
			"portrait": DefaultCharacters.portrait(3),
			"summary": "年老的船匠，不能说话，双手受过重伤。他把船体和航线刻在木头上。",
			"disabled": false,
			"visible": true,
		},
	]
