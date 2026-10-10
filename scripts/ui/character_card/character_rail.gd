extends Control
## 顶栏下方的人物竖栏。人数由调用方决定，隐藏的卡不留空位。不读存档。

const CARD_SCENE := preload("res://scenes/ui/character_card/character_card.tscn")
const TOOLTIP_WIDTH := 320.0
const TOOLTIP_HEIGHT := 160.0
const TEXT_WIDTH := 280.0
const GAP := 8.0
const PARCHMENT := Color(0.93, 0.88, 0.78, 1)
const EDGE := Color(0.28, 0.22, 0.16, 1)
const INK := Color(0.28, 0.16, 0.05, 1)

var _pending: Array = []
var _active = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	_apply_tooltip_plate()
	%Summary.add_theme_font_override("font", _font())
	%Summary.add_theme_font_size_override("font_size", 16)
	%Summary.add_theme_color_override("font_color", INK)
	%Summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	%Tooltip.top_level = true
	%Tooltip.visible = false
	%Tooltip.mouse_exited.connect(_on_tooltip_mouse_exited)
	%Scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	%Scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	%Scroll.get_v_scroll_bar().custom_minimum_size.x = 10
	%Summary.custom_minimum_size.x = TEXT_WIDTH
	if not _pending.is_empty():
		_apply_pending()


func configure(people: Array) -> void:
	_pending = people
	if is_node_ready():
		_apply_pending()


func _apply_pending() -> void:
	_hide_tooltip()
	for child in %Cards.get_children():
		%Cards.remove_child(child)
		child.free()
	for person in _pending:
		if typeof(person) != TYPE_DICTIONARY:
			continue
		var card := CARD_SCENE.instantiate()
		%Cards.add_child(card)
		var portrait = person.get("portrait", null)
		card.configure(
			str(person.get("name", "")),
			portrait if portrait is Texture2D else null,
			str(person.get("summary", "")),
			bool(person.get("disabled", false)),
			bool(person.get("visible", true)),
		)
		card.mouse_entered.connect(_on_card_mouse_entered.bind(card))
		card.mouse_exited.connect(_on_card_mouse_exited)


func _on_card_mouse_entered(card) -> void:
	if card.is_disabled() or not card.visible:
		_hide_tooltip()
		return
	_active = card
	_show_tooltip(card)


func _on_card_mouse_exited() -> void:
	set_process(true)


func _on_tooltip_mouse_exited() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	if not %Tooltip.visible:
		set_process(false)
		return
	if _pointer_inside(get_global_mouse_position()):
		return
	_hide_tooltip()


func _pointer_inside(mouse: Vector2) -> bool:
	if _active != null and is_instance_valid(_active) and _active.visible and not _active.is_disabled():
		var card_rect: Rect2 = _active.get_global_rect()
		if card_rect.has_point(mouse):
			return true
		var bridge := Rect2(card_rect.end.x, card_rect.position.y, GAP, card_rect.size.y)
		if bridge.has_point(mouse):
			return true
	return %Tooltip.get_global_rect().has_point(mouse)


func _show_tooltip(card) -> void:
	%Summary.text = card.summary()
	%Summary.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	%Scroll.scroll_vertical = 0
	var height: float = TOOLTIP_HEIGHT if card.size.y <= 1.0 else card.size.y
	%Tooltip.custom_minimum_size = Vector2(TOOLTIP_WIDTH, height)
	%Tooltip.size = Vector2(TOOLTIP_WIDTH, height)
	%Tooltip.global_position = card.global_position + Vector2(card.size.x + GAP, 0)
	%Tooltip.visible = true
	set_process(true)


func _hide_tooltip() -> void:
	%Tooltip.visible = false
	_active = null
	set_process(false)


func _apply_tooltip_plate() -> void:
	var flat := StyleBoxFlat.new()
	flat.bg_color = PARCHMENT
	flat.border_color = EDGE
	flat.border_width_left = 2
	flat.border_width_top = 2
	flat.border_width_right = 2
	flat.border_width_bottom = 2
	flat.corner_radius_top_left = 4
	flat.corner_radius_top_right = 4
	flat.corner_radius_bottom_right = 4
	flat.corner_radius_bottom_left = 4
	flat.content_margin_left = 14
	flat.content_margin_right = 14
	flat.content_margin_top = 14
	flat.content_margin_bottom = 14
	%Tooltip.add_theme_stylebox_override("panel", flat)


func _font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "Microsoft YaHei", "微软雅黑"])
	return font
