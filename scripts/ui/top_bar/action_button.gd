extends Button
## 顶栏操作按钮。按下后由 TopBar 转成 action_pressed(id)，这里不打开任何界面。

const PLATE := Color(0.78, 0.78, 0.78, 1)
const HOVER := Color(0.62, 0.62, 0.62, 1)
## button_states.png 是 560×76，从左到右三枚，中间各空 7px。
const NORMAL_REGION := Rect2(0, 0, 186, 76)
const HOVER_REGION := Rect2(193, 0, 178, 76)
const PRESSED_REGION := Rect2(378, 0, 182, 76)

## 三态合图。常规、悬停、按下从左到右。圆角两端各留 40px，不跟着拉长。
@export var state_sheet: Texture2D:
	set(value):
		state_sheet = value
		if is_node_ready():
			_apply_plate()

## 没有三态合图时，四枚按钮可以共用这一张，悬停只把颜色压暗。
@export var background: Texture2D:
	set(value):
		background = value
		if is_node_ready():
			_apply_plate()

var action_id := ""


func _ready() -> void:
	# flat 为真时 Button 不绘制 StyleBox，三态底图会全部消失。
	flat = false
	focus_mode = Control.FOCUS_NONE
	_apply_plate()
	add_theme_font_override("font", _font())
	add_theme_font_size_override("font_size", 22)
	add_theme_color_override("font_color", Color(0.12, 0.12, 0.12, 1))
	add_theme_color_override("font_hover_color", Color(0.12, 0.12, 0.12, 1))
	add_theme_color_override("font_pressed_color", Color(0.12, 0.12, 0.12, 1))
	mouse_entered.connect(_paint)
	mouse_exited.connect(_paint)
	_paint()


func configure(id: String, label: String) -> void:
	action_id = id
	text = label


func _apply_plate() -> void:
	if state_sheet != null:
		add_theme_stylebox_override("normal", _state_box(NORMAL_REGION))
		add_theme_stylebox_override("disabled", _state_box(NORMAL_REGION))
		add_theme_stylebox_override("hover", _state_box(HOVER_REGION))
		add_theme_stylebox_override("focus", _state_box(HOVER_REGION))
		add_theme_stylebox_override("pressed", _state_box(PRESSED_REGION))
		return
	var box: StyleBox = _plate_box()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, box)


func _state_box(region: Rect2) -> StyleBoxTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = state_sheet
	atlas.region = region
	var textured := StyleBoxTexture.new()
	textured.texture = atlas
	textured.texture_margin_left = 40
	textured.texture_margin_right = 40
	textured.texture_margin_top = 10
	textured.texture_margin_bottom = 10
	textured.content_margin_left = 16
	textured.content_margin_right = 16
	textured.content_margin_top = 6
	textured.content_margin_bottom = 6
	return textured


func _plate_box() -> StyleBox:
	if background != null:
		var textured := StyleBoxTexture.new()
		textured.texture = background
		textured.texture_margin_left = 16
		textured.texture_margin_right = 16
		textured.texture_margin_top = 16
		textured.texture_margin_bottom = 16
		return textured
	var flat := StyleBoxFlat.new()
	flat.bg_color = PLATE
	flat.corner_radius_top_left = 6
	flat.corner_radius_top_right = 6
	flat.corner_radius_bottom_right = 6
	flat.corner_radius_bottom_left = 6
	flat.content_margin_left = 12
	flat.content_margin_right = 12
	flat.content_margin_top = 8
	flat.content_margin_bottom = 8
	return flat


func _paint() -> void:
	if state_sheet != null:
		modulate = Color.WHITE
		return
	modulate = HOVER if is_hovered() else Color.WHITE


func _font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "Microsoft YaHei", "微软雅黑"])
	return font
