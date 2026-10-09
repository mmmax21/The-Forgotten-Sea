extends Control
## 右侧天数。贴图是 208×210 的右上四分之一圆，控件与图同大。
## 没有贴图时，在本控件右上角画一块绿色四分之一圆。

const SUN := Color(0.35, 0.62, 0.28, 1)

@export var background: Texture2D:
	set(value):
		background = value
		if is_node_ready():
			_apply_background()


func _ready() -> void:
	resized.connect(queue_redraw)
	_apply_background()
	%Caption.add_theme_font_override("font", _font())
	%Caption.add_theme_font_size_override("font_size", 32)
	%Caption.add_theme_font_size_override("outline_size", 2)
	%Caption.add_theme_color_override("font_color", Color(0.28, 0.16, 0.05, 1))


func configure(day: int, _total: int) -> void:
	%Caption.text = "第%d天" % day


func _apply_background() -> void:
	%Art.texture = background
	%Art.visible = background != null
	queue_redraw()


func _draw() -> void:
	if background != null or size.x < 2.0 or size.y < 2.0:
		return
	# 圆心在右上角，圆只留下控件内部的那一角。
	draw_circle(Vector2(size.x, 0.0), minf(size.x, size.y), SUN)


func _font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "Microsoft YaHei", "微软雅黑"])
	return font
