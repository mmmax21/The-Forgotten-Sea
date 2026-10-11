extends Control
## 圆形按钮。不用 Button：占位圆要自己画，点击区域也要按圆裁切。
## 外接方框的四角会透给下面的控件。没有贴图时画淡彩纸心和旧黄铜环。
## 悬停把整颗钮压暗，不另做三态图。

signal pressed

const PAPER := Color(0.86, 0.82, 0.71, 1)
const BRASS := Color(0.64, 0.50, 0.27, 1)
const HOVER := Color(0.62, 0.62, 0.62, 1)

var _inside := false

## 整张圆形图。透明角落不会扩大点击区域。空着就用占位圆。
@export var background: Texture2D:
	set(value):
		background = value
		if is_node_ready():
			queue_redraw()

## 为真时在纸心画一根朝上的铜针。指南针用，小钮不用。
@export var draw_needle := false:
	set(value):
		draw_needle = value
		if is_node_ready():
			queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_enter)
	mouse_exited.connect(_leave)
	resized.connect(queue_redraw)
	queue_redraw()
	_paint()


func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= _radius()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			pressed.emit()
			accept_event()


func _draw() -> void:
	var radius := _radius()
	if radius < 1.0:
		return
	var center := size * 0.5
	if background != null:
		draw_texture_rect(background, Rect2(Vector2.ZERO, size), false)
		return
	var ring := clampf(radius * 0.09, 3.0, 14.0)
	draw_circle(center, radius, BRASS)
	var inner := radius - ring
	draw_circle(center, inner, PAPER)
	if not draw_needle:
		return
	var tip := center + Vector2(0.0, -inner * 0.72)
	var tail := center + Vector2(0.0, inner * 0.22)
	draw_line(tail, tip, BRASS, maxf(2.0, radius * 0.035), true)
	draw_circle(center, maxf(3.0, radius * 0.045), BRASS)


func _enter() -> void:
	_inside = true
	_paint()


func _leave() -> void:
	_inside = false
	_paint()


func _paint() -> void:
	modulate = HOVER if _inside else Color.WHITE


func _radius() -> float:
	return minf(size.x, size.y) * 0.5
