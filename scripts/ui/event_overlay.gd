extends Control
signal chosen(event_id: String, choice: String)
var event: Dictionary = {}
var page := 0
var title_label: Label
var body: Label
var portrait: Label
var illustration: TextureRect
var actions: HBoxContainer
var previous: Button
var next: Button
var content: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.05, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.15
	panel.anchor_right = 0.85
	panel.anchor_top = 0.12
	panel.anchor_bottom = 0.88
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)
	title_label = Label.new()
	content.add_child(title_label)
	portrait = Label.new()
	portrait.modulate = Color(0.55, 0.75, 0.73)
	content.add_child(portrait)
	illustration = TextureRect.new()
	illustration.custom_minimum_size.y = 100
	illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(illustration)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	body = Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	actions = HBoxContainer.new()
	content.add_child(actions)
	hide()

func show_event(value: Dictionary) -> void:
	event = value.duplicate(true)
	page = 0
	show()
	render()

func render() -> void:
	title_label.text = "%s  ·  %d / %d" % [event.title, page + 1, event.pages.size()]
	portrait.text = event.get("portrait", "配图占位")
	var image_path: String = event.get("image", "")
	illustration.texture = load(image_path) if not image_path.is_empty() and ResourceLoader.exists(image_path) else null
	illustration.visible = illustration.texture != null
	body.text = event.pages[page]
	body.get_parent().scroll_vertical = 0
	for node in actions.get_children():
		actions.remove_child(node)
		node.queue_free()
	previous = Button.new()
	previous.text = "上一页"
	previous.disabled = page == 0
	previous.pressed.connect(func(): page = maxi(0, page - 1); render())
	actions.add_child(previous)
	if page < event.pages.size() - 1:
		next = Button.new()
		next.text = "继续阅读"
		next.pressed.connect(func(): page = mini(event.pages.size() - 1, page + 1); render())
		actions.add_child(next)
	else:
		for choice in event.choices:
			var button := Button.new()
			button.text = choice.text
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect(_choose.bind(event.id, choice.id))
			actions.add_child(button)

func _choose(id: String, choice: String) -> void:
	if not visible or event.get("id", "") != id:
		return
	hide()
	chosen.emit(id, choice)
