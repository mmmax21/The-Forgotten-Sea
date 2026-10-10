extends Control
## 一张人物卡。头像、名字、介绍、禁用和显隐都由调用方传入。
## 人像画在 120×104 上，只比木框窗口大出约 4px，边缘被卡框盖住。disabled 时整张置灰，并且不弹出介绍。
## visible 为假时从竖栏里抽走，不留空位。

const NAME_PLATE := Color(0.93, 0.88, 0.78, 1)
const INK := Color(0.28, 0.16, 0.05, 1)
const DISABLED_TINT := Color(0.55, 0.55, 0.55, 1)

## 卡框 144×160，画在人像上面。四边各 16px 是木边，中间透明。
@export var frame_texture: Texture2D:
	set(value):
		frame_texture = value
		if is_node_ready():
			_apply_frame()

var _disabled := false
var _hovered := false
var _pending := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_apply_frame()
	_apply_name_plate()
	%Name.add_theme_font_override("font", _font())
	%Name.add_theme_font_size_override("font_size", 20)
	%Name.add_theme_color_override("font_color", INK)
	%Name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	%Portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	%Portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if not _pending.is_empty():
		_apply_pending()


func configure(person_name: String, portrait: Texture2D, person_summary: String, is_disabled: bool = false, is_visible: bool = true) -> void:
	_pending = {
		"name": person_name,
		"portrait": portrait,
		"summary": person_summary,
		"disabled": is_disabled,
		"visible": is_visible,
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
	_apply_frame()


func _on_mouse_entered() -> void:
	_hovered = true
	_apply_frame()


func _on_mouse_exited() -> void:
	_hovered = false
	_apply_frame()


func _apply_frame() -> void:
	%Frame.texture = frame_texture
	%Frame.visible = frame_texture != null
	if _disabled:
		modulate = DISABLED_TINT
	elif _hovered and frame_texture != null:
		modulate = Color(1.12, 1.1, 1.04, 1)
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
