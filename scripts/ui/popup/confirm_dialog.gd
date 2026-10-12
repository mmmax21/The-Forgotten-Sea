extends Control
## 居中的确认弹窗。不读存档，也不决定确认之后做什么。
##
## 场景结构（scenes/ui/popup/confirm_dialog.tscn）：
## - Shade：全屏透明遮罩。alpha 为 0，仍停住指针。点遮罩不关闭。
## - Panel：宽 560，高随正文。米色圆角占位，以后换成美术图。
## - Title、BodyText：标题和正文。正文空着就不显示。
## - CancelButton、ConfirmButton：文案固定为「取消」「确认」。
##
## configure(data) 收 title、text、on_confirm、on_cancel。
## 没传标题或标题为空时用「请确认」。两个方法都可选，没传就什么都不做。
## open() 负责显示。按下按钮后先 hide()，再调用对应方法，然后发出 confirmed 或 cancelled。

signal confirmed
signal cancelled

const PANEL_WIDTH := 560.0
const CONTENT_MARGIN := 32.0
const CONTENT_WIDTH := PANEL_WIDTH - CONTENT_MARGIN * 2.0
const PAPER := Color(0.93, 0.88, 0.78, 1)
const EDGE := Color(0.28, 0.22, 0.16, 1)
const INK := Color(0.28, 0.16, 0.05, 1)
const BUTTON := Color(0.78, 0.78, 0.78, 1)
const BUTTON_HOVER := Color(0.62, 0.62, 0.62, 1)
const DEFAULT_TITLE := "请确认"

var _title := DEFAULT_TITLE
var _text := ""
var _on_confirm := Callable()
var _on_cancel := Callable()
var _ready_to_show := false
var _shown := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	%Shade.color = Color(0, 0, 0, 0)
	%Shade.mouse_filter = Control.MOUSE_FILTER_STOP
	%Panel.custom_minimum_size.x = PANEL_WIDTH
	%Title.custom_minimum_size.x = CONTENT_WIDTH
	%BodyText.custom_minimum_size.x = CONTENT_WIDTH
	_apply_plate()
	_apply_fonts()
	_style_button(%CancelButton)
	_style_button(%ConfirmButton)
	%CancelButton.pressed.connect(_cancel)
	%ConfirmButton.pressed.connect(_confirm)
	if not _ready_to_show and get_tree().current_scene == self:
		configure(_preview_payload())
		_shown = true
	if _ready_to_show:
		_apply()
	visible = _shown


## title、text 缺省或空字符串：标题回到「请确认」，正文不显示。
## on_confirm、on_cancel 是 Callable。不是方法，或没传，就跳过。
func configure(data: Dictionary = {}) -> void:
	var title := _text_field(data, "title")
	_title = title if title != "" else DEFAULT_TITLE
	_text = _text_field(data, "text")
	_on_confirm = _callable_field(data, "on_confirm")
	_on_cancel = _callable_field(data, "on_cancel")
	_ready_to_show = true
	if is_node_ready():
		_apply()


func open() -> void:
	if not _ready_to_show:
		configure(_preview_payload())
	_shown = true
	if is_node_ready():
		_apply()
		show()


func _confirm() -> void:
	_close_then(_on_confirm)
	confirmed.emit()


func _cancel() -> void:
	_close_then(_on_cancel)
	cancelled.emit()


func _close_then(callback: Callable) -> void:
	_shown = false
	hide()
	if callback.is_valid():
		callback.call()


func _apply() -> void:
	%Title.text = _title
	%BodyText.text = _text
	%BodyText.visible = _text != ""


func _apply_plate() -> void:
	var flat := StyleBoxFlat.new()
	flat.bg_color = PAPER
	flat.border_color = EDGE
	flat.set_border_width_all(2)
	flat.set_corner_radius_all(8)
	%Panel.add_theme_stylebox_override("panel", flat)


func _apply_fonts() -> void:
	var font := _font()
	%Title.add_theme_font_override("font", font)
	%Title.add_theme_font_size_override("font_size", 32)
	%Title.add_theme_color_override("font_color", INK)
	%BodyText.add_theme_font_override("font", font)
	%BodyText.add_theme_font_size_override("font_size", 22)
	%BodyText.add_theme_color_override("font_color", INK)


func _style_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(140, 48)
	var flat := StyleBoxFlat.new()
	flat.bg_color = BUTTON
	flat.set_corner_radius_all(8)
	flat.content_margin_left = 16
	flat.content_margin_right = 16
	flat.content_margin_top = 8
	flat.content_margin_bottom = 8
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, flat)
	button.add_theme_font_override("font", _font())
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12, 1))
	button.add_theme_color_override("font_hover_color", Color(0.12, 0.12, 0.12, 1))
	button.add_theme_color_override("font_pressed_color", Color(0.12, 0.12, 0.12, 1))
	button.mouse_entered.connect(_paint_button.bind(button))
	button.mouse_exited.connect(_paint_button.bind(button))
	_paint_button(button)


func _paint_button(button: Button) -> void:
	button.modulate = BUTTON_HOVER if button.is_hovered() else Color.WHITE


func _text_field(data: Dictionary, key: String) -> String:
	var value = data.get(key, "")
	if value == null:
		return ""
	return str(value).strip_edges()


func _callable_field(data: Dictionary, key: String) -> Callable:
	var value = data.get(key, Callable())
	if value is Callable:
		return value
	return Callable()


## 单独用 F6 打开本场景时用。两个方法都空着。
func _preview_payload() -> Dictionary:
	return {
		"title": DEFAULT_TITLE,
		"text": "北面的网已经收起。今天先不要出镇。",
	}


func _font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "Microsoft YaHei", "微软雅黑"])
	return font
