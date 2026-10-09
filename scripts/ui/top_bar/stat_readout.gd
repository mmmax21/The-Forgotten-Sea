extends PanelContainer
## 一项数值，例如「说服力 0」。
## 单独使用时自带底；放进顶栏时由整行共用一张九宫格，调用 set_plate_visible(false)。

const PLATE := Color(0.97, 0.95, 0.9, 1)
const INK := Color(0.86, 0.42, 0.12, 1)

## 有贴图时换成九宫格。左右各 16px 不拉伸，对应约 96px 宽的数值条。
@export var background: Texture2D:
	set(value):
		background = value
		if is_node_ready():
			_apply_plate()

var _show_plate := true


func _ready() -> void:
	_apply_plate()
	%Caption.add_theme_font_override("font", _font())
	%Caption.add_theme_font_size_override("font_size", 26)
	%Caption.add_theme_color_override("font_color", INK)


func configure(label_text: String, value) -> void:
	%Caption.text = "%s %s" % [label_text, str(value)]


func set_plate_visible(show_plate: bool) -> void:
	_show_plate = show_plate
	if is_node_ready():
		_apply_plate()


func _apply_plate() -> void:
	if not _show_plate:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		return
	if background != null:
		var textured := StyleBoxTexture.new()
		textured.texture = background
		textured.texture_margin_left = 16
		textured.texture_margin_right = 16
		textured.texture_margin_top = 8
		textured.texture_margin_bottom = 8
		add_theme_stylebox_override("panel", textured)
		return
	var flat := StyleBoxFlat.new()
	flat.bg_color = PLATE
	flat.content_margin_left = 16
	flat.content_margin_right = 16
	flat.content_margin_top = 6
	flat.content_margin_bottom = 6
	add_theme_stylebox_override("panel", flat)


func _font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "Microsoft YaHei", "微软雅黑"])
	return font
