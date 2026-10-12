extends Control
signal selected(id: String)
var body: VBoxContainer
var choices: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.025, 0.03, 0.82)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	add_child(panel)
	panel.position = Vector2(510, 160)
	panel.size = Vector2(900, 710)
	var wood := StyleBoxTexture.new()
	wood.texture = preload("res://assets/ui/top_bar/rows_texture.png")
	wood.draw_center = false
	wood.texture_margin_left = 108
	wood.texture_margin_right = 108
	wood.texture_margin_top = 64
	wood.texture_margin_bottom = 64
	wood.content_margin_left = 124
	wood.content_margin_right = 124
	wood.content_margin_top = 80
	wood.content_margin_bottom = 80
	panel.add_theme_stylebox_override("panel", wood)
	var backdrop := Node2D.new()
	backdrop.show_behind_parent = true
	panel.add_child(backdrop)
	var fill := ColorRect.new()
	fill.position = Vector2(108, 64)
	fill.size = Vector2(684, 582)
	fill.color = Color(0.16, 0.125, 0.10)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(fill)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	scroll.add_child(body)
	choices = VBoxContainer.new()
	choices.add_theme_constant_override("separation", 10)
	column.add_child(choices)
	hide()

func open(title: String, message: String, options: Array, picture: Texture2D = null) -> void:
	for parent in [body, choices]:
		for child in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	_add_text(title, 30)
	if picture != null:
		var art := TextureRect.new()
		art.texture = picture
		art.custom_minimum_size = Vector2(0, 230)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		body.add_child(art)
	_add_text(message, 24)
	for option in options:
		var button := Button.new()
		button.text = str(option.text)
		button.set_meta("choice_id", str(option.id))
		button.custom_minimum_size.y = 48
		button.disabled = bool(option.get("disabled", false))
		button.pressed.connect(_select.bind(str(option.id)))
		choices.add_child(button)
	body.get_parent().scroll_vertical = 0
	show()

func _add_text(value: String, font_size: int) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	body.add_child(label)

func _select(id: String) -> void:
	hide()
	selected.emit(id)
