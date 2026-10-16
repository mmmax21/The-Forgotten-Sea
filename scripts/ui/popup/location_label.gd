@tool
extends PanelContainer
## 地图地名。固定 112×40，居中放 2 到 3 个汉字。
## 没有底板图时用淡羊皮纸和细暗边。图到了拖到 plate_texture。
## 图按 112×40 画，左右各 16、上下各 10 不拉伸。不挡地图点击。

const PLATE_SIZE := Vector2(112, 40)
const PAPER := Color(0.93, 0.88, 0.78, 1)
const EDGE := Color(0.28, 0.22, 0.16, 1)
const INK := Color(0.28, 0.16, 0.05, 1)
const PATCH_LEFT := 16
const PATCH_RIGHT := 16
const PATCH_TOP := 10
const PATCH_BOTTOM := 10

## 和地点父节点同名，例如 ruins。遮挡物、点击范围以后也用这个 id。
@export var location_id := ""

## 这一条上的地名。改这里，编辑器里的字会跟着变。
@export var place_name := "地点名":
	set(value):
		place_name = value
		if is_node_ready():
			_apply_name()

## 以后的地名底板。空着就用纯色占位。
@export var plate_texture: Texture2D:
	set(value):
		plate_texture = value
		if is_node_ready():
			_apply_plate()


func _ready() -> void:
	custom_minimum_size = PLATE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_plate()
	_apply_font()
	_apply_name()


## 调用方也可以改字。编辑器里直接改 place_name 即可。
func configure(label: String) -> void:
	place_name = label


func _apply_name() -> void:
	%Name.text = place_name


func _apply_font() -> void:
	var label: Label = %Name
	label.add_theme_font_override("font", _font())
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _apply_plate() -> void:
	if plate_texture != null:
		var textured := StyleBoxTexture.new()
		textured.texture = plate_texture
		textured.texture_margin_left = PATCH_LEFT
		textured.texture_margin_right = PATCH_RIGHT
		textured.texture_margin_top = PATCH_TOP
		textured.texture_margin_bottom = PATCH_BOTTOM
		_set_content_margin(textured)
		add_theme_stylebox_override("panel", textured)
		return
	var flat := StyleBoxFlat.new()
	flat.bg_color = PAPER
	flat.border_color = EDGE
	flat.set_border_width_all(2)
	flat.set_corner_radius_all(4)
	_set_content_margin(flat)
	add_theme_stylebox_override("panel", flat)


func _set_content_margin(box: StyleBox) -> void:
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 6
	box.content_margin_bottom = 6


func _font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "Microsoft YaHei", "微软雅黑"])
	return font
