extends Control
## 一张人物卡。只有立绘和名字，没有卡框。
## 介绍、禁用和显隐都由调用方传入。disabled 时整张置灰，并且不弹出介绍。
## visible 为假时从横排里抽走，不留空位。

const NAME_PLATE := Color(0.93, 0.88, 0.78, 1)
const INK := Color(0.28, 0.16, 0.05, 1)
const DISABLED_TINT := Color(0.55, 0.55, 0.55, 1)
const HOVER_TINT := Color(1.08, 1.08, 1.08, 1)

var _disabled := false
var _hovered := false
var _pending := {}
## 点选时给出人物索引，由 character_row 转发。
signal pressed(index: int)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	_apply_name_plate()
	_apply_look()
	%Name.add_theme_font_override("font", _font())
	%Name.add_theme_font_size_override("font_size", 22)
	%Name.add_theme_color_override("font_color", INK)
	%Name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	%Portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	%Portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not _pending.is_empty():
		_apply_pending()


func _on_gui_input(event: InputEvent) -> void:
	if _disabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit(int(_pending.get("index", -1)))


func configure(person_name: String, portrait: Texture2D, person_summary: String, is_disabled: bool = false, is_visible: bool = true, index: int = -1) -> void:
	_pending = {
		"name": person_name,
		"portrait": portrait,
		"summary": person_summary,
		"disabled": is_disabled,
		"visible": is_visible,
		"index": index,
	}
	if is_node_ready():
		_apply_pending()


func summary() -> String:
	return str(_pending.get("summary", ""))


func is_disabled() -> bool:
	return _disabled


func _apply_pending() -> void:
	%Name.text = str(_pending.get("name", ""))
	var portrait = _pending.get("portrait", null)
	%Portrait.texture = portrait if portrait is Texture2D else null
	_disabled = bool(_pending.get("disabled", false))
	visible = bool(_pending.get("visible", true))
	_hovered = false
	_apply_look()


func _on_mouse_entered() -> void:
	_hovered = true
	_apply_look()


func _on_mouse_exited() -> void:
	_hovered = false
	_apply_look()


func _apply_look() -> void:
	if _disabled:
		modulate = DISABLED_TINT
	elif _hovered:
		modulate = HOVER_TINT
	else:
		modulate = Color.WHITE


func _apply_name_plate() -> void:
	var flat := StyleBoxFlat.new()
	flat.bg_color = NAME_PLATE
	flat.corner_radius_top_left = 3
	flat.corner_radius_top_right = 3
	flat.corner_radius_bottom_right = 3
	flat.corner_radius_bottom_left = 3
	flat.content_margin_left = 4
	flat.content_margin_right = 4
	flat.content_margin_top = 0
	flat.content_margin_bottom = 0
	%NamePlate.add_theme_stylebox_override("panel", flat)


func _font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "Microsoft YaHei", "微软雅黑"])
	return font
