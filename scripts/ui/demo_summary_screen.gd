extends CenterContainer
signal records_requested
signal menu_requested
var snapshot: Dictionary = {}
var title: Label
var subtitle: Label
var tabs: Array[Button] = []
var heading: Label
var content: VBoxContainer
var scroll: ScrollContainer
var records: Button
var menu_button: Button
var footer: HBoxContainer
var category := 0
var frame: VBoxContainer

func _ready() -> void:
	frame = $Layout
	title = $Layout/Title
	subtitle = $Layout/Description
	title.add_theme_font_size_override("font_size", 32)
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	frame.add_child(row)
	for i in range(5):
		var button := Button.new()
		button.text = ["玛瑞斯的痕迹","人物记录","现实变化","当前阻碍","待查方向"][i]
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(select_category.bind(i))
		row.add_child(button)
		tabs.append(button)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 24)
	frame.add_child(heading)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	footer = HBoxContainer.new()
	frame.add_child(footer)
	records = Button.new()
	records.text = "查看本局记录"
	records.pressed.connect(func(): if is_visible_in_tree(): records_requested.emit())
	footer.add_child(records)
	$Layout/RestartButton.reparent(footer)
	menu_button = Button.new()
	menu_button.text = "返回主菜单"
	menu_button.pressed.connect(func(): if is_visible_in_tree(): menu_requested.emit())
	footer.add_child(menu_button)
	for button in footer.get_children():
		button.custom_minimum_size = Vector2(0, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resized.connect(_resize)
	_resize()

func _resize() -> void:
	frame.custom_minimum_size = Vector2(maxf(0,size.x - 96), maxf(0,size.y - 64))

func present(value: Dictionary) -> void:
	snapshot = value.duplicate(true)
	title.text = "十日行记 · Demo 总结"
	subtitle.text = "已完成全部 10 天 · 旅程在此暂告一段落，世界仍会继续。"
	if snapshot.preview_only:
		subtitle.text = "开发预览结果 · 不代表正式剧情进展"
	if not snapshot.night_complete:
		subtitle.text = "DEBUG 流程结束 · 未完成第 10 天夜间结算，不作为正式通关记录。"
	select_category(0)

func select_category(index: int) -> void:
	if snapshot.is_empty(): return
	category = clampi(index,0,4)
	for i in range(tabs.size()):
		tabs[i].set_pressed_no_signal(i == category)
		tabs[i].text = ("✓ " if i == category else "") + ["玛瑞斯的痕迹","人物记录","现实变化","当前阻碍","待查方向"][i]
	for node in content.get_children():
		content.remove_child(node)
		node.queue_free()
	heading.text = snapshot.sections[category].title
	for text in snapshot.sections[category].items:
		var panel := PanelContainer.new()
		content.add_child(panel)
		var label := Label.new()
		label.text = text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 18)
		panel.add_child(label)
	scroll.scroll_vertical = 0
