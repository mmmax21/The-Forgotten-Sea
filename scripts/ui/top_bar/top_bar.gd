extends Control
## 地图界面顶栏。不读取游戏状态，调用方传入数值、按钮和天数。
##
## 场景结构（scenes/ui/top_bar/top_bar.tscn）：
## - RowsPlate：左侧两行共用的底，包住数值和按钮。
## - StatPlate / StatRow：第一行数值。三项共用一条更窄的底。
## - ButtonRow：第二行操作按钮。按下发出 action_pressed(id)。
## - DayBadge：右侧天数，下面是剩余行动点「ap/ap_max」。
##
## 数据引擎以后只调用 apply_engine(data)。字段见 docs/data_formats.md 的「顶栏」。
## 顶栏不读存档，也不打开按钮对应的界面。按下只发出 action_pressed(id)。
## 本场景不替换 main.tscn 里的旧顶栏。
signal action_pressed(id: String)

const STAT_SCENE := preload("res://scenes/ui/top_bar/stat_readout.tscn")
const BUTTON_SCENE := preload("res://scenes/ui/top_bar/action_button.tscn")
const PLATE := Color(0.97, 0.95, 0.9, 1)
const ROWS := Color(0.28, 0.22, 0.16, 1)

## 左侧两行的外框。当前图约 620×150。左右各留 108px、上下各留 64px，盖住四角藤蔓。
@export var rows_texture: Texture2D:
	set(value):
		rows_texture = value
		if is_node_ready():
			_apply_rows_plate()

## 整行数值条。当前图 560×72。左右卷轴各 64px，上下木边各 16px。
@export var stat_bar_texture: Texture2D:
	set(value):
		stat_bar_texture = value
		if is_node_ready():
			_apply_stat_plate()

## 操作按钮底。四个按钮共用；没有这张图时，按钮用自己的浅灰底。
@export var button_texture: Texture2D

var _pending := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_rows_plate()
	_apply_stat_plate()
	if get_tree().current_scene == self:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _pending.is_empty():
		apply_engine(_preview_payload())
	else:
		_apply_pending()


## 数据引擎入口。只接收下面这一份字典，缺的字段用预览值补上。
## stats: [{label, value}]  左侧第一行。value 原样转成文字。
## buttons: [{id, text}]    左侧第二行。id 会随 action_pressed 交回。
## day: int                 角标上的「第N天」。
## total: int               总天数。角标目前不显示，先留给引擎。
## ap: int                  剩余行动点，角标写成「ap/ap_max」。
## ap_max: int              行动点上限。缺省 3。
func apply_engine(data: Dictionary) -> void:
	var fallback := _preview_payload()
	configure(
		data.get("stats", fallback.stats),
		data.get("buttons", fallback.buttons),
		int(data.get("day", fallback.day)),
		int(data.get("total", fallback.total)),
		int(data.get("ap", fallback.ap)),
		int(data.get("ap_max", fallback.ap_max)),
	)


## 把引擎字典拆给数值行、按钮行和天数角标。数据引擎不要直接调用。
func configure(stats: Array, buttons: Array, day: int, total: int, ap: int = 3, ap_max: int = 3) -> void:
	_pending = {
		"stats": stats,
		"buttons": buttons,
		"day": day,
		"total": total,
		"ap": ap,
		"ap_max": ap_max,
	}
	if is_node_ready():
		_apply_pending()


func _apply_pending() -> void:
	_refill(stat_row(), _pending.stats, true)
	_refill(button_row(), _pending.buttons, false)
	%DayBadge.configure(
		int(_pending.day),
		int(_pending.total),
		int(_pending.ap),
		int(_pending.ap_max),
	)


func _refill(row: Node, items: Array, stats: bool) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.free()
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if stats:
			var readout = STAT_SCENE.instantiate()
			row.add_child(readout)
			readout.configure(str(item.get("label", "")), item.get("value", ""))
			readout.set_plate_visible(false)
		else:
			var button = BUTTON_SCENE.instantiate()
			row.add_child(button)
			if button_texture != null:
				button.background = button_texture
			button.configure(str(item.get("id", "")), str(item.get("text", "")))
			button.pressed.connect(_on_action.bind(button))


func _on_action(button) -> void:
	action_pressed.emit(str(button.action_id))


func _apply_rows_plate() -> void:
	var plate: PanelContainer = %RowsPlate
	if rows_texture != null:
		plate.add_theme_stylebox_override("panel", _rows_slice(rows_texture))
		return
	var flat := StyleBoxFlat.new()
	flat.bg_color = ROWS
	flat.corner_radius_top_left = 8
	flat.corner_radius_top_right = 8
	flat.corner_radius_bottom_right = 8
	flat.corner_radius_bottom_left = 8
	flat.content_margin_left = 22
	flat.content_margin_right = 22
	flat.content_margin_top = 16
	flat.content_margin_bottom = 16
	plate.add_theme_stylebox_override("panel", flat)


func _apply_stat_plate() -> void:
	var plate: PanelContainer = %StatPlate
	if stat_bar_texture != null:
		plate.add_theme_stylebox_override("panel", _stat_slice(stat_bar_texture))
		return
	var flat := StyleBoxFlat.new()
	flat.bg_color = PLATE
	flat.content_margin_left = 20
	flat.content_margin_right = 20
	flat.content_margin_top = 12
	flat.content_margin_bottom = 12
	plate.add_theme_stylebox_override("panel", flat)


## 藤蔓大约延伸到左侧 x=103、上侧 y=74。文字从藤蔓内侧开始排。
func _rows_slice(texture: Texture2D) -> StyleBoxTexture:
	var textured := StyleBoxTexture.new()
	textured.texture = texture
	textured.texture_margin_left = 108
	textured.texture_margin_right = 108
	textured.texture_margin_top = 64
	textured.texture_margin_bottom = 64
	textured.content_margin_left = 108
	textured.content_margin_right = 108
	textured.content_margin_top = 12
	textured.content_margin_bottom = 12
	return textured


## 羊皮纸在卷轴内侧。文字不要压到左右卷边。
func _stat_slice(texture: Texture2D) -> StyleBoxTexture:
	var textured := StyleBoxTexture.new()
	textured.texture = texture
	textured.texture_margin_left = 64
	textured.texture_margin_right = 64
	textured.texture_margin_top = 16
	textured.texture_margin_bottom = 16
	textured.content_margin_left = 72
	textured.content_margin_right = 72
	textured.content_margin_top = 8
	textured.content_margin_bottom = 8
	return textured


func stat_row() -> HBoxContainer:
	return %StatRow


func button_row() -> HBoxContainer:
	return %ButtonRow


## 单独预览顶栏时用。正式运行由数据引擎调用 apply_engine，不要改这里代替存档。
func _preview_payload() -> Dictionary:
	return {
		"stats": [
			{"label": "说服力", "value": "0"},
			{"label": "影响力", "value": "0"},
			{"label": "曝光度", "value": "0"},
		],
		"buttons": [
			{"id": "tasks", "text": "任务"},
			{"id": "items", "text": "物品"},
			{"id": "status", "text": "状态"},
			{"id": "settings", "text": "设置"},
		],
		"day": 1,
		"total": 10,
		"ap": 3,
		"ap_max": 3,
	}
