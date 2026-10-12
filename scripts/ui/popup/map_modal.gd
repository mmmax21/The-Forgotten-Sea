extends Control
## 居中的大地图卷轴。不读存档，也不改游戏里的海。
##
## 场景结构（scenes/ui/popup/map_modal.tscn）：
## - Shade：全屏遮罩，挡住底层点击，点遮罩不关闭。
## - Panel：1600×900，与卷轴底同比例。纸面中心比整张图偏右，面板向左补上。
## - Background：整张卷轴，含右侧的轴。
## - Map：铺在纸面上。左、上、下贴住纸边，右边停在轴之前。鼠标穿透。
## - Locations：六个地点。父节点名就是 id。拖父节点来摆位置。
##   子节点固定叫 Label、Hit、Cover。Hit 是椭圆，能前往时悬停出米黄光圈。
##   不能前往时 Cover 盖住，和 Hit 同大，地名隐藏。
##   ruins 遗迹，fishing_village 渔村，market 集市，
##   old_academy 旧学城，feather_forest 羽之森，royal_city 王城。
## - CloseButton：纸面右上，轴的左边。图标是 Icons.png 第 3 行第 5 格。
##
## configure(data) 收 show_ocean 和 places。不传 places 时六地都能前往。
## open() 负责显示。close() 负责隐藏，并发出 closed。右上角关闭钮也走它。
## 点中能前往的地点发出 place_chosen(id, 地名)。不关闭地图，也不打开别的界面。

signal closed
signal location_selected(id: String)

const PANEL_SIZE := Vector2(1600, 900)
const TEX_SIZE := Vector2(1024, 576)
## 纸面左右不透明边不对称。中心大约在 x=561，整张图中心在 512。
const OPAQUE_CENTER_X := 561.0
const IMAGE_CENTER_X := 512.0
## 纸面槽位，按 1024×576 的纹理像素。右缘停在轴的深色网纹之前。
const SLOT_LEFT := 136.0
const SLOT_TOP := 24.0
const SLOT_RIGHT := 896.0
const SLOT_BOTTOM := 563.0
const CLOSE_SIZE := 48.0
const CLOSE_INSET := 8.0
const ICON_HOVER := Color(0.62, 0.62, 0.62, 1)
const PLACE_IDS: Array[String] = [
	"ruins", "fishing_village", "market", "old_academy", "feather_forest", "royal_city",
]
const CoverScript := preload("res://scripts/ui/popup/location_cover.gd")

@export var background: Texture2D:
	set(value):
		background = value
		if is_node_ready():
			_apply_background()

@export var map_without_ocean: Texture2D:
	set(value):
		map_without_ocean = value
		if is_node_ready():
			_apply_map()

@export var map_with_ocean: Texture2D:
	set(value):
		map_with_ocean = value
		if is_node_ready():
			_apply_map()

var _show_ocean := false
var _shown := false
var _places_given := false
var _reachable := {}
var _wired := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_layout_panel()
	_apply_background()
	_style_close()
	_apply_map()
	%CloseButton.pressed.connect(close)
	if not _places_given:
		_reachable = _all_open()
	_apply_places()
	for place in %Locations.get_children():
		var hit := place.get_node_or_null("Hit")
		if hit != null:
			hit.pressed.connect(_on_location_pressed.bind(String(place.name)))
	if get_tree().current_scene == self:
		_shown = true
	visible = _shown


func _on_location_pressed(id: String) -> void:
	location_selected.emit(id)


## data 可以只有 show_ocean。不带 places 时六个地点都能前往。
## 带了 places 时，没写到的地点不能前往。一项是 {id, reachable}。
func configure(data: Dictionary = {}) -> void:
	_show_ocean = bool(data.get("show_ocean", false))
	if data.has("places"):
		_places_given = true
		_reachable = _from_places(data.get("places", []))
	else:
		_places_given = false
		_reachable = _all_open()
	if is_node_ready():
		_apply_map()
		_apply_places()


func open() -> void:
	_shown = true
	if is_node_ready():
		_apply_map()
		_apply_places()
		show()


## 调用方也可以关。确认前往时，预览用这个方法把地图一起关掉。
func close() -> void:
	_shown = false
	hide()
	closed.emit()


func _layout_panel() -> void:
	var panel: Control = %Panel
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var scale := _scale()
	var shift := (OPAQUE_CENTER_X - IMAGE_CENTER_X) * scale
	panel.offset_left = -PANEL_SIZE.x * 0.5 - shift
	panel.offset_top = -PANEL_SIZE.y * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5 - shift
	panel.offset_bottom = PANEL_SIZE.y * 0.5
	_place_map(scale)
	_place_close(scale)


func _place_map(scale: float) -> void:
	var map: TextureRect = %Map
	map.set_anchors_preset(Control.PRESET_TOP_LEFT)
	map.offset_left = SLOT_LEFT * scale
	map.offset_top = SLOT_TOP * scale
	map.offset_right = SLOT_RIGHT * scale
	map.offset_bottom = SLOT_BOTTOM * scale
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED


func _place_close(scale: float) -> void:
	var button: Control = %CloseButton
	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var right := SLOT_RIGHT * scale - CLOSE_INSET
	var top := SLOT_TOP * scale + CLOSE_INSET
	button.offset_left = right - CLOSE_SIZE
	button.offset_top = top
	button.offset_right = right
	button.offset_bottom = top + CLOSE_SIZE


func _apply_background() -> void:
	%Background.texture = background
	%Background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	%Background.stretch_mode = TextureRect.STRETCH_SCALE


func _apply_map() -> void:
	%Map.texture = map_with_ocean if _show_ocean else map_without_ocean


func _all_open() -> Dictionary:
	var open := {}
	for place_id in PLACE_IDS:
		open[place_id] = true
	return open


func _from_places(places: Variant) -> Dictionary:
	var open := {}
	for place_id in PLACE_IDS:
		open[place_id] = false
	if places is Array:
		for item in places:
			if not item is Dictionary:
				continue
			var place_id := str(item.get("id", ""))
			if not PLACE_IDS.has(place_id):
				continue
			open[place_id] = bool(item.get("reachable", false))
	return open


func _apply_places() -> void:
	if not is_instance_valid(%Locations):
		return
	for place in %Locations.get_children():
		var place_id := String(place.name)
		if not PLACE_IDS.has(place_id):
			continue
		var reachable := bool(_reachable.get(place_id, false))
		var hit := place.get_node_or_null("Hit")
		var label := place.get_node_or_null("Label")
		var cover := _cover_for(place, hit)
		if label != null:
			label.visible = reachable
		if hit != null and hit.has_method("set_reachable"):
			hit.set_reachable(reachable)
			_wire_hit(hit, place_id)
		if cover == null:
			continue
		cover.visible = not reachable
		if not reachable:
			place.move_child(cover, place.get_child_count() - 1)


func _wire_hit(hit: Node, place_id: String) -> void:
	if _wired.has(place_id) or not hit.has_signal("pressed"):
		return
	_wired[place_id] = true
	hit.pressed.connect(_choose_place.bind(place_id))


func _choose_place(place_id: String) -> void:
	if not bool(_reachable.get(place_id, false)):
		return
	var place := %Locations.get_node_or_null(place_id)
	var label := place.get_node_or_null("Label") if place != null else null
	var place_name := place_id
	if label != null and "place_name" in label:
		var written := str(label.place_name).strip_edges()
		if written != "":
			place_name = written
	place_chosen.emit(place_id, place_name)


func _cover_for(place: Node, hit: Node) -> Control:
	if hit == null or not hit is Control:
		return null
	var cover := place.get_node_or_null("Cover")
	if cover == null:
		cover = Control.new()
		cover.name = "Cover"
		cover.set_script(CoverScript)
		place.add_child(cover)
	var area := hit as Control
	cover.set_anchors_preset(Control.PRESET_TOP_LEFT)
	cover.offset_left = area.offset_left
	cover.offset_top = area.offset_top
	cover.offset_right = area.offset_right
	cover.offset_bottom = area.offset_bottom
	return cover


func _style_close() -> void:
	var button: Button = %CloseButton
	button.flat = true
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_constant_override("icon_max_width", int(CLOSE_SIZE))
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, empty)
	button.mouse_entered.connect(_paint_close)
	button.mouse_exited.connect(_paint_close)
	_paint_close()


func _paint_close() -> void:
	%CloseButton.modulate = ICON_HOVER if %CloseButton.is_hovered() else Color.WHITE


func _scale() -> float:
	return PANEL_SIZE.x / TEX_SIZE.x
