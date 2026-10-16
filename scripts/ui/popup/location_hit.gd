extends Control
## 地点点击范围。节点的宽和高就是椭圆的宽和高，四角点不中。
## 悬停时在椭圆外缘画一圈半透明米黄光圈，宽高比范围大约大 16。
## 能前往时，椭圆内按下发出 pressed。这里不打开界面。

signal pressed

const EXTRA := 16.0
const STROKE := 8.0
const GLOW := Color(0.95, 0.86, 0.62, 0.62)
const GLOW_SOFT := Color(0.95, 0.86, 0.62, 0.28)

var _halo: Control
var _reachable := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_show_halo)
	mouse_exited.connect(_hide_halo)
	set_reachable(_reachable)
	resized.connect(_layout_halo)
	_halo = Control.new()
	_halo.name = "Halo"
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_halo.draw.connect(_draw_halo)
	add_child(_halo)
	_layout_halo()
	_halo.hide()


func _gui_input(event: InputEvent) -> void:
	if not _reachable:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			pressed.emit()


func _has_point(point: Vector2) -> bool:
	var rx := size.x * 0.5
	var ry := size.y * 0.5
	if rx < 1.0 or ry < 1.0:
		return false
	var delta := point - size * 0.5
	return (delta.x / rx) * (delta.x / rx) + (delta.y / ry) * (delta.y / ry) <= 1.0


func _layout_halo() -> void:
	var pad := EXTRA * 0.5 + STROKE
	_halo.position = Vector2(-pad, -pad)
	_halo.size = size + Vector2(pad, pad) * 2.0
	_halo.queue_redraw()


## 不能前往时不接收指针，光圈收起。
func set_reachable(enabled: bool) -> void:
	_reachable = enabled
	if not enabled:
		_hide_halo()
	if is_node_ready():
		mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func _show_halo() -> void:
	if not _reachable:
		return
	_layout_halo()
	_halo.show()


func _hide_halo() -> void:
	if _halo != null:
		_halo.hide()


func _draw_halo() -> void:
	var center := _halo.size * 0.5
	var rx := size.x * 0.5 + EXTRA * 0.5
	var ry := size.y * 0.5 + EXTRA * 0.5
	_halo.draw_polyline(_ellipse(center, rx + 5.0, ry + 5.0), GLOW_SOFT, STROKE + 10.0, true)
	_halo.draw_polyline(_ellipse(center, rx, ry), GLOW, STROKE, true)


func _ellipse(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := 64
	for i in count + 1:
		var angle := TAU * float(i) / float(count)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points
