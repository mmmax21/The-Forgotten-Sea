extends Control
## 右下角指南针小地图。不读存档，不打开地图。
##
## 场景结构（scenes/ui/mini_map/mini_map.tscn）：
## - Compass：256×256 的圆形指南针。按下发出 action_pressed("compass")。
## - Upper / Lower：64×64 的小钮，和指南针同级，叠在左上侧铜环上。
##   大钮不当父节点，否则会把小钮的点击吃掉。
##
## 按下只发出 action_pressed(id)。打开什么界面由调用方决定。
## 上侧小钮是集会，下侧小钮是隐藏。纸心上的字由圆钮自己画。

signal action_pressed(id: String)

const COMPASS_SIZE := 256.0
const SATELLITE_SIZE := 64.0
const MARGIN := 16.0
## 底边比右边多留一截，指南针不贴屏幕下沿。
const BOTTOM_MARGIN := 48.0
const COMPASS_ID := "compass"
## 10 点半、9 点。角度 0 朝右，正角度朝下，所以左上用负角。
const UPPER_ANGLE := -135.0
const LOWER_ANGLE := 180.0

var _upper_id := "gather"
var _lower_id := "hide"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	%Compass.pressed.connect(press_compass)
	%Upper.pressed.connect(press_upper)
	%Lower.pressed.connect(press_lower)
	%Upper.caption = "集"
	%Lower.caption = "隐"
	%Upper.tooltip_text = "集会"
	%Lower.tooltip_text = "隐藏"
	_layout()


## 只改两个小钮的 id。指南针固定是 "compass"。
func configure(upper_id: String = "gather", lower_id: String = "hide") -> void:
	_upper_id = upper_id
	_lower_id = lower_id


## 预留入口。控件内部只把 id 交出去。
func press_compass() -> void:
	action_pressed.emit(COMPASS_ID)


func press_upper() -> void:
	action_pressed.emit(_upper_id)


func press_lower() -> void:
	action_pressed.emit(_lower_id)


func _layout() -> void:
	var compass_radius := COMPASS_SIZE * 0.5
	var satellite_radius := SATELLITE_SIZE * 0.5
	# 圆心落在铜环外侧一点，小钮直径的三分之一压进大圆。
	var distance := compass_radius + satellite_radius - SATELLITE_SIZE / 3.0
	var upper := Vector2.from_angle(deg_to_rad(UPPER_ANGLE)) * distance
	var lower := Vector2.from_angle(deg_to_rad(LOWER_ANGLE)) * distance
	var left := minf(-compass_radius, minf(upper.x, lower.x) - satellite_radius)
	var top := minf(-compass_radius, minf(upper.y, lower.y) - satellite_radius)
	var compass_center := Vector2(-left, -top)
	_place(%Compass, compass_center, COMPASS_SIZE)
	_place(%Upper, compass_center + upper, SATELLITE_SIZE)
	_place(%Lower, compass_center + lower, SATELLITE_SIZE)
	var right := maxf(compass_radius, maxf(upper.x, lower.x) + satellite_radius)
	var bottom := maxf(compass_radius, maxf(upper.y, lower.y) + satellite_radius)
	var widget := compass_center + Vector2(right, bottom)
	custom_minimum_size = widget
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -MARGIN - widget.x
	offset_top = -BOTTOM_MARGIN - widget.y
	offset_right = -MARGIN
	offset_bottom = -BOTTOM_MARGIN


func _place(node: Control, center: Vector2, diameter: float) -> void:
	var origin := center - Vector2(diameter, diameter) * 0.5
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.offset_left = origin.x
	node.offset_top = origin.y
	node.offset_right = origin.x + diameter
	node.offset_bottom = origin.y + diameter
