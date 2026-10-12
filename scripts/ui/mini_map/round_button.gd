extends Control
## 圆形按钮。不用 Button：占位圆要自己画，点击区域也要按圆裁切。
## 外接方框的四角会透给下面的控件。没有贴图时画淡彩纸心和旧黄铜环。
## 三态图都在时：常规、悬停、按下各用一格。没有三态图时，悬停把整颗钮压暗。

signal pressed

const PAPER := Color(0.86, 0.82, 0.71, 1)
const BRASS := Color(0.64, 0.50, 0.27, 1)
const HOVER := Color(0.62, 0.62, 0.62, 1)

var _inside := false
var _down := false

## 整张圆形图。透明角落不会扩大点击区域。空着就用占位圆。
@export var background: Texture2D:
	set(value):
		background = value
		if is_node_ready():
			queue_redraw()

## 三态合图切出来的三格。都空着就不用。
@export var state_normal: Texture2D:
	set(value):
		state_normal = value
		if is_node_ready():
			queue_redraw()

@export var state_hover: Texture2D:
	set(value):
		state_hover = value
		if is_node_ready():
			queue_redraw()

@export var state_pressed: Texture2D:
	set(value):
		state_pressed = value
		if is_node_ready():
			queue_redraw()

## 为真时在纸心画一根朝上的铜针。指南针用，小钮不用。
@export var draw_needle := false:
	set(value):
		draw_needle = value
		if is_node_ready():
			queue_redraw()

## 纸心上的字。图内不写字，小钮的「集」「隐」从这里画。
@export var caption := "":
	set(value):
		caption = value
		if is_node_ready():
			queue_redraw()

var _caption_font: SystemFont


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_enter)
	mouse_exited.connect(_leave)
	resized.connect(queue_redraw)
	queue_redraw()
	_show_state()


func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= _radius()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		_down = mouse.pressed
		_show_state()
		if mouse.pressed:
			pressed.emit()
			accept_event()


func _draw() -> void:
	var radius := _radius()
	if radius < 1.0:
		return
	var center := size * 0.5
	var frame := _frame()
	if frame != null:
		draw_texture_rect(frame, Rect2(Vector2.ZERO, size), false)
	else:
		var ring := clampf(radius * 0.09, 3.0, 14.0)
		draw_circle(center, radius, BRASS)
		var inner := radius - ring
		draw_circle(center, inner, PAPER)
		if draw_needle:
			var tip := center + Vector2(0.0, -inner * 0.72)
			var tail := center + Vector2(0.0, inner * 0.22)
			draw_line(tail, tip, BRASS, maxf(2.0, radius * 0.035), true)
			draw_circle(center, maxf(3.0, radius * 0.045), BRASS)
	_draw_caption()


func _enter() -> void:
	_inside = true
	_show_state()


func _leave() -> void:
	_inside = false
	_down = false
	_show_state()


func _show_state() -> void:
	if _has_states():
		modulate = Color.WHITE
		queue_redraw()
		return
	modulate = HOVER if _inside else Color.WHITE


func _has_states() -> bool:
	return state_normal != null or state_hover != null or state_pressed != null


func _frame() -> Texture2D:
	if _down and _inside and state_pressed != null:
		return state_pressed
	if _inside and state_hover != null:
		return state_hover
	if state_normal != null:
		return state_normal
	return background


func _draw_caption() -> void:
	if caption == "":
		return
	var font := _font()
	var font_size := clampi(int(round(minf(size.x, size.y) * 0.36)), 16, 36)
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var baseline := size.y * 0.5 + (ascent - descent) * 0.5
	draw_string(font, Vector2(0, baseline), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color(0.28, 0.16, 0.05, 1))


func _font() -> SystemFont:
	if _caption_font == null:
		_caption_font = SystemFont.new()
		_caption_font.font_names = PackedStringArray(["KaiTi", "Microsoft YaHei", "微软雅黑"])
	return _caption_font


func _radius() -> float:
	return minf(size.x, size.y) * 0.5
