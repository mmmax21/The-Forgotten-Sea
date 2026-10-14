extends Control
## 组件预览。F6 运行本场景，只展示界面样式，不跑剧情。

const DefaultCharacters := preload("res://scripts/ui/character_card/default_characters.gd")
const State := preload("res://scripts/story/ruins_state.gd")
const Modal := preload("res://scripts/ui/story_modal.gd")

@export var save_path := "user://ruins_story_v1.json"
var modal


func _ready() -> void:
	resized.connect(_fit_design)
	_fit_design()
	_build_settings_modal()
	%CharacterRail.configure(_people())
	%CharacterRail.character_selected.connect(_show_character)
	%TopBar.action_pressed.connect(_on_toolbar)
	%MiniMap.action_pressed.connect(_on_minimap)
	%DialogueBox.show_text("点选左侧人物，查看立绘和文本框。")


func _build_settings_modal() -> void:
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
	modal = Modal.new()
	modal.name = "StoryModal"
	modal.theme = skin
	%Design.add_child(modal)
	modal.selected.connect(_on_settings_selected)


func _fit_design() -> void:
	var factor := minf(size.x / 1920.0, size.y / 1032.0)
	%Design.scale = Vector2.ONE * factor
	%Design.position = (size - Vector2(1920, 1032) * factor) / 2.0


func _show_character(index: int, actor_name: String, summary: String, _portrait: Texture2D) -> void:
	if _dialog_open():
		return
	%PortraitPanel.show_portrait(index, actor_name)
	%DialogueBox.show_text(summary)
	%EventModal.apply_engine(_event_preview(actor_name))
	%EventModal.open()


## 手记打开手记弹窗，证据打开证据栏，都用弹窗自己的预览数据。状态打开通知。设置走原来的窗口。
func _on_toolbar(id: String) -> void:
	if id == "settings":
		_open_settings()
		return
	if id == "journal":
		_open_journal()
		return
	if id == "evidence":
		_open_evidence()
		return
	if id == "status":
		_open_default_notice()
		return


func _open_journal() -> void:
	if _dialog_open():
		return
	%JournalBook.open()


func _open_evidence() -> void:
	if _dialog_open():
		return
	%EvidenceModal.open()


func _open_default_notice() -> void:
	if _dialog_open():
		return
	%Notice.apply_engine({
		"title": "潮汐将至",
		"image": DefaultCharacters.portrait(0),
		"text": "北面的网已经收起。今天先不要出镇。",
	})
	%Notice.open()


func _open_settings() -> void:
	if _dialog_open():
		return
	modal.open("设置", "进度在行动完成、移动和跨日后自动保存。", [
		{"id": "restart_ask", "text": "重新开始本章…"},
		{"id": "cancel", "text": "返回游戏"},
	])


func _on_settings_selected(id: String) -> void:
	match id:
		"restart_ask":
			modal.open("重新开始本章？", "当前章节的存档将被重置。", [
				{"id": "restart", "text": "重新开始"},
				{"id": "cancel", "text": "保留进度"},
			])
		"restart":
			var error: Error = State.new().save_to(save_path)
			if error != OK:
				push_warning("剧情存档失败：%s" % error_string(error))
				modal.open("存档失败", "请检查保存目录权限。", [{"id": "cancel", "text": "返回"}])


func _dialog_open() -> bool:
	if _layer_open(modal):
		return true
	for path in ["%MapModal", "%ConfirmDialog", "%Notice", "%EvidenceModal", "%JournalBook", "%EventModal"]:
		if _layer_open(get_node_or_null(path)):
			return true
	return %TopBar.is_end_day_confirm_open()


func _layer_open(node: Node) -> bool:
	var layer: CanvasItem = node as CanvasItem
	return layer != null and layer.visible


## 指南针打开大地图。两个小钮打开确认弹窗，确认和取消都不改数据。
func _on_minimap(id: String) -> void:
	if _dialog_open():
		return
	if id == "compass":
		%MapModal.configure({
			"show_ocean": false,
			"places": [
				{"id": "ruins", "reachable": true},
				{"id": "fishing_village", "reachable": true},
				{"id": "market", "reachable": false},
				{"id": "old_academy", "reachable": false},
				{"id": "feather_forest", "reachable": false},
				{"id": "royal_city", "reachable": true},
			],
		})
		%MapModal.open()
		return
	var title := "集会" if id == "gather" else "隐藏"
	%ConfirmDialog.configure({
		"title": title,
		"text": "这是确认弹窗的样式。确认或取消都只关闭窗口。",
	})
	%ConfirmDialog.open()


## 画廊假数据。只用来看事件弹窗，选卡不会改进度。
func _event_preview(actor_name: String) -> Dictionary:
	match actor_name:
		"老渔夫":
			return {
				"title": "潮汐歌还在不在",
				"text": "老渔夫把孙子先支去后院，才肯低声说话。他说潮汐歌只剩三句，公开唱过的人没有一个回来。\n\n渔夫：「你要记，就记在自己的本子上。别在码头上念。」\n\n院子外面有人经过。你得决定这些句子现在落到哪里，以及要不要先把孩子安顿好。这段说明故意写长，用来看固定高度里的滚动。",
				"options": [
					{"id": "A", "title": "私下记下剩下的三句", "detail": "1 AP · F +1 · A +0", "disabled": false},
					{"id": "B", "title": "先把孙子送去盐嫂家", "detail": "2 AP · F +2 · A -1", "disabled": false},
					{"id": "C", "title": "让他在码头公开唱一遍", "detail": "警戒过高", "disabled": true},
				],
			}
		"哑伯":
			return {
				"title": "木头上的航线",
				"text": "哑伯把一块旧船板推过来。板上刻着弯弯的线，线旁是他用指甲掐出来的记号。他不能说话，只反复点那几个缺口。\n\n船棚里还有另外三块没刻完的木头。你一次只能带走能藏住的东西。",
				"options": [
					{"id": "A", "title": "把这块船板登记下来", "detail": "1 AP · F +1 · A +0", "disabled": false},
					{"id": "B", "title": "临摹记号，木头留在棚里", "detail": "1 AP · F +1 · A +0", "disabled": false},
					{"id": "C", "title": "问他缺口是不是浅滩", "detail": "1 AP · F +0 · A +1", "disabled": false},
					{"id": "D", "title": "把四块木头都搬走", "detail": "需要 2 类已登记证据，目前 0 类", "disabled": true},
				],
			}
		_:
			return {
				"title": "螺螺发现贝壳",
				"text": "一个孩子在河滩上捡到一枚奇怪的贝壳。它呈螺旋状，表面有淡蓝色纹路，与河里的生物完全不同。\n\n螺螺：「你看！这是从河里捡到的！它好漂亮，像故事里的东西！」\n\n河滩上的泥沙还没被冲走。你得决定这枚贝壳接下来要不要让别人看见，以及要不要现在就给它一个说法。",
				"options": [
					{"id": "A", "title": "让螺螺拿给其他孩子看，一起寻找相似的东西", "detail": "2 AP · F +2 · A +1", "disabled": false},
					{"id": "B", "title": "先记录贝壳的特征，暂不告诉其他人", "detail": "1 AP · F +1 · A +0", "disabled": false},
					{"id": "C", "title": "劝螺螺把贝壳放回河里", "detail": "行动点不足", "disabled": true},
				],
			}


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
