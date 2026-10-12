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


## 剧情、状态仍打开通知。物品打开物品栏，用弹窗自己的预览数据。设置走原来的窗口。
func _on_toolbar(id: String) -> void:
	if id == "settings":
		_open_settings()
		return
	if id == "items":
		_open_inventory()
		return
	_open_default_notice()


func _open_inventory() -> void:
	if _dialog_open():
		return
	%InventoryModal.open()


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
	return modal.visible or %MapModal.visible or %ConfirmDialog.visible or %Notice.visible or %InventoryModal.visible or %TopBar.is_end_day_confirm_open()


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
