extends Control
## 不能前往时盖住地点。和 Hit 同宽同高。没有图时画半透明灰椭圆。
## 停住，不跟悬停变化。

const VEIL := Color(0.45, 0.45, 0.47, 0.55)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func _has_point(point: Vector2) -> bool:
	var rx := size.x * 0.5
	var ry := size.y * 0.5
	if rx < 1.0 or ry < 1.0:
		return false
	var delta := point - size * 0.5
	return (delta.x / rx) * (delta.x / rx) + (delta.y / ry) * (delta.y / ry) <= 1.0


func _draw() -> void:
	var rx := size.x * 0.5
	var ry := size.y * 0.5
	if rx < 1.0 or ry < 1.0:
		return
	var center := size * 0.5
	var points := PackedVector2Array()
	var count := 64
	for i in count:
		var angle := TAU * float(i) / float(count)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_colored_polygon(points, VEIL)
