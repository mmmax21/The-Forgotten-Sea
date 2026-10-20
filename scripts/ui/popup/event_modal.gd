extends Control
## 居中的事件弹窗。不读存档，也不结算选项。
##
## 场景结构（scenes/ui/popup/event_modal.tscn）：
## - Shade：全屏遮罩，挡住底层点击，点遮罩不关闭。
## - Panel：1180×680。标题、固定高度的说明、横排卡牌。
## - CloseButton：右上角。图标是 assets/icons/close.png。
## - TextScroll：说明区，高 160。超出只在这里滚动。
## - CardRow：2 到 4 张卡，运行时按数据生成。
##
## 数据引擎调用 apply_engine(data)，再 open()。字段见 docs/data_formats.md 的「事件弹窗」。
## 点能选的卡先隐藏，发出 option_chosen(id)。点关闭只发 closed。

signal option_chosen(id: String)
signal closed

const PANEL_SIZE := Vector2(1180, 680)
const TEXT_HEIGHT := 160.0
const CARD_SIZE := Vector2(240, 240)
const CARD_GAP := 16
const MAX_CARDS := 4
const PARCHMENT := Color(0.93, 0.88, 0.78, 1)
const EDGE := Color(0.28, 0.22, 0.16, 1)
const INK := Color(0.28, 0.16, 0.05, 1)
const SHADOW := Color(0.15, 0.1, 0.05, 0.45)
const ICON_SIZE := 48
const ICON_HOVER := Color(0.62, 0.62, 0.62, 1)

var _title := ""
var _text := ""
var _options: Array = []
var _shown := false
var _has_data := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Theme.new()
	%Shade.color = Color(0.03, 0.04, 0.05, 0.62)
	%Shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_layout_panel()
	_style_panel()
	_style_close()
	_style_text()
	_apply_fonts()
	%CloseButton.pressed.connect(close)
	%CardRow.add_theme_constant_override("separation", CARD_GAP)
	%CardRow.alignment = BoxContainer.ALIGNMENT_CENTER
	if not _has_data and get_tree().current_scene == self:
		apply_engine(_preview_payload())
		_shown = true
	_render()
	visible = _shown


## 换成这一次的标题、说明和卡牌。不负责显示。
func apply_engine(data: Dictionary) -> void:
	_title = str(data.get("title", "")).strip_edges()
	_text = str(data.get("text", "")).strip_edges()
	_options = _options_from(data.get("options", []))
	_has_data = true
	if is_node_ready():
		_render()


func open() -> void:
	if not _has_data:
		apply_engine(_preview_payload())
	_shown = true
	if is_node_ready():
		_render()
		%TextScroll.scroll_vertical = 0
		show()


## 关闭等于这次不选。不发 option_chosen。
func close() -> void:
	_shown = false
	hide()
	closed.emit()


func _options_from(raw) -> Array:
	var options: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return options
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var title: String = str(entry.get("title", "")).strip_edges()
		if title.is_empty():
			continue
		options.append({
			"id": str(entry.get("id", "")),
			"title": title,
			"detail": str(entry.get("detail", "")).strip_edges(),
			"disabled": bool(entry.get("disabled", false)),
		})
		if options.size() >= MAX_CARDS:
			break
	return options


func _render() -> void:
	%Title.visible = not _title.is_empty()
	%Title.text = _title
	%TextScroll.visible = not _text.is_empty()
	%Body.text = _text
	%TextScroll.scroll_vertical = 0
	for child in %CardRow.get_children():
		%CardRow.remove_child(child)
		child.free()
	for option in _options:
		var record: Dictionary = option
		%CardRow.add_child(_card(record))


func _card(option: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = CARD_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var detail: String = str(option.get("detail", ""))
	button.text = str(option.get("title", "")) if detail.is_empty() else "%s\n\n%s" % [option.get("title", ""), detail]
	button.disabled = bool(option.get("disabled", false))
	button.set_meta("action_id", str(option.get("id", "")))
	button.add_theme_font_override("font", _font())
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", Color(INK.r, INK.g, INK.b, 0.45))
	button.mouse_entered.connect(_paint_card.bind(button))
	button.mouse_exited.connect(_paint_card.bind(button))
	button.button_down.connect(_paint_card.bind(button))
	button.button_up.connect(_paint_card.bind(button))
	button.pressed.connect(_pick.bind(str(option.get("id", "")), button))
	_paint_card(button)
	return button


func _pick(id: String, button: Button) -> void:
	if button.disabled:
		return
	_shown = false
	hide()
	option_chosen.emit(id)


func _paint_card(button: Button) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = PARCHMENT
	box.border_color = EDGE
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 18
	box.content_margin_bottom = 18
	var shadow := 2
	if button.disabled:
		shadow = 0
		button.modulate = Color(1, 1, 1, 0.45)
	elif button.button_pressed:
		shadow = 4
		button.modulate = Color.WHITE
	elif button.is_hovered():
		shadow = 14
		button.modulate = Color.WHITE
	else:
		button.modulate = Color.WHITE
	box.shadow_color = SHADOW
	box.shadow_size = shadow
	box.shadow_offset = Vector2(0, 4 if shadow > 0 else 0)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, box)


func _layout_panel() -> void:
	var panel: Control = %Panel
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_bottom = PANEL_SIZE.y * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP


func _style_panel() -> void:
	var flat := StyleBoxFlat.new()
	flat.bg_color = PARCHMENT
	flat.border_color = EDGE
	flat.set_border_width_all(2)
	flat.set_corner_radius_all(8)
	%Panel.add_theme_stylebox_override("panel", flat)


func _style_close() -> void:
	var button: Button = %CloseButton
	button.flat = true
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_constant_override("icon_max_width", ICON_SIZE)
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, empty)
	button.mouse_entered.connect(_paint_close)
	button.mouse_exited.connect(_paint_close)
	_paint_close()


func _paint_close() -> void:
	%CloseButton.modulate = ICON_HOVER if %CloseButton.is_hovered() else Color.WHITE


func _style_text() -> void:
	%TextScroll.custom_minimum_size.y = TEXT_HEIGHT
	%TextScroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	%Body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	%Body.custom_minimum_size.x = PANEL_SIZE.x - 96.0


func _apply_fonts() -> void:
	var font := _font()
	%Title.add_theme_font_override("font", font)
	%Title.add_theme_font_size_override("font_size", 32)
	%Title.add_theme_color_override("font_color", INK)
	%Body.add_theme_font_override("font", font)
	%Body.add_theme_font_size_override("font_size", 20)
	%Body.add_theme_color_override("font_color", INK)


func _font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "Microsoft YaHei", "微软雅黑"])
	return font


func _preview_payload() -> Dictionary:
	return {
		"title": "螺螺发现贝壳",
		"text": "一个孩子在河滩上捡到一枚奇怪的贝壳。它呈螺旋状，表面有淡蓝色纹路，与河里的生物完全不同。\n\n螺螺：「你看！这是从河里捡到的！它好漂亮，像故事里的东西！」\n\n河滩上的泥沙还没被冲走。你得决定这枚贝壳接下来要不要让别人看见，以及要不要现在就给它一个说法。",
		"options": [
			{
				"id": "A",
				"title": "让螺螺拿给其他孩子看，一起寻找相似的东西",
				"detail": "2 AP · F +2 · A +1",
				"disabled": false,
			},
			{
				"id": "B",
				"title": "先记录贝壳的特征，暂不告诉其他人",
				"detail": "1 AP · F +1 · A +0",
				"disabled": false,
			},
			{
				"id": "C",
				"title": "劝螺螺把贝壳放回河里",
				"detail": "行动点不足",
				"disabled": true,
			},
		],
	}
