extends Control
## 居中的证据栏。不读存档，也不使用证据。
##
## 场景结构（scenes/ui/popup/evidence_modal.tscn）：
## - Shade：全屏遮罩，挡住底层点击，点遮罩不关闭。
## - Panel：宽 560。里面是标题、4×4 格子、翻页条。
## - CloseButton：右上角。图标是 Icons.png 第 3 行第 5 格。
## - PrevButton / NextButton：Icons.png 第 5 行第 5、第 6 格。
## - Tooltip：悬停有证据的格子时出现在格子右侧。
##
## 数据引擎只调用 apply_engine(data)。字段见 docs/data_formats.md 的「证据栏」。
## open() 负责显示。按下关闭后 hide()，发出 closed。

signal closed

const PAGE_SIZE := 16
const COLUMNS := 4
const CELL := 96.0
const GAP := 12.0
const PANEL_SIZE := Vector2(560, 640)
const TOOLTIP_WIDTH := 320.0
const TOOLTIP_MARGIN := 22.0
const PARCHMENT := Color(0.93, 0.88, 0.78, 1)
const PARCHMENT_EMPTY := Color(0.84, 0.78, 0.66, 1)
const EDGE := Color(0.28, 0.22, 0.16, 1)
const INK := Color(0.28, 0.16, 0.05, 1)
const ICON_SIZE := 48
const ICON_HOVER := Color(0.62, 0.62, 0.62, 1)
const ICON_DISABLED := Color(1, 1, 1, 0.35)

var _items: Array = []
var _page := 0
var _shown := false
var _has_data := false
var _hovered: Control = null
var _slots: Array = []
var _textures := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	%Shade.color = Color(0.03, 0.04, 0.05, 0.62)
	%Shade.mouse_filter = Control.MOUSE_FILTER_STOP
	%Shade.z_index = -1
	_layout_panel()
	_build_slots()
	_style_panel()
	_style_icons()
	_style_tooltip()
	_apply_fonts()
	%CloseButton.pressed.connect(_close)
	%PrevButton.pressed.connect(_turn.bind(-1))
	%NextButton.pressed.connect(_turn.bind(1))
	%Tooltip.hide()
	if not _has_data and get_tree().current_scene == self:
		apply_engine(_preview_payload())
		_shown = true
	_render()
	visible = _shown


## items 是数组。非对象跳过。不接收页码，页码留在控件里。
func apply_engine(data: Dictionary) -> void:
	var raw = data.get("items", [])
	var items: Array = []
	if raw is Array:
		for entry in raw:
			var item: Dictionary = _item_or_empty(entry)
			if not item.is_empty():
				items.append(item)
	_items = items
	_has_data = true
	_clamp_page()
	if is_node_ready():
		_hide_tooltip()
		_render()


func open() -> void:
	if not _has_data:
		apply_engine(_preview_payload())
	_shown = true
	if is_node_ready():
		_render()
		show()


func _close() -> void:
	_hide_tooltip()
	_shown = false
	hide()
	closed.emit()


func _turn(step: int) -> void:
	var next := _page + step
	var last := _page_count() - 1
	if next < 0 or next > last:
		return
	_page = next
	_hide_tooltip()
	_render()


func _render() -> void:
	var visible_items := _items
	var start := _page * PAGE_SIZE
	for index in PAGE_SIZE:
		var item: Dictionary = {}
		var source := start + index
		if source < visible_items.size():
			item = visible_items[source]
		_fill_slot(_slots[index], item)
	var pages := _page_count()
	%PageLabel.text = "%d/%d" % [_page + 1, pages]
	%PrevButton.disabled = _page <= 0
	%NextButton.disabled = _page >= pages - 1
	_paint_icon(%PrevButton)
	_paint_icon(%NextButton)


func _page_count() -> int:
	var count := _items.size()
	return maxi(1, int(ceil(float(count) / float(PAGE_SIZE))))


func _clamp_page() -> void:
	_page = clampi(_page, 0, _page_count() - 1)


func _item_or_empty(entry) -> Dictionary:
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	var item_name: String = str(entry.get("name", "")).strip_edges()
	if item_name.is_empty():
		return {}
	return {
		"id": str(entry.get("id", "")),
		"name": item_name,
		"icon": entry.get("icon", ""),
		"description": str(entry.get("description", "")),
	}


func _build_slots() -> void:
	for index in PAGE_SIZE:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(CELL, CELL)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.set_meta("index", index)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 8
		icon.offset_top = 8
		icon.offset_right = -8
		icon.offset_bottom = -8
		slot.add_child(icon)
		var name_label := Label.new()
		name_label.name = "Name"
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		name_label.offset_left = 6
		name_label.offset_top = 6
		name_label.offset_right = -6
		name_label.offset_bottom = -6
		name_label.add_theme_font_override("font", _font())
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", INK)
		slot.add_child(name_label)
		slot.mouse_entered.connect(_on_slot_entered.bind(slot))
		slot.mouse_exited.connect(_on_slot_exited.bind(slot))
		slot.gui_input.connect(_on_slot_gui_input.bind(slot))
		%Grid.add_child(slot)
		_slots.append(slot)


func _fill_slot(slot: Panel, item: Dictionary) -> void:
	var filled: bool = not item.is_empty()
	slot.set_meta("item", item)
	var icon: TextureRect = slot.get_node("Icon")
	var name_label: Label = slot.get_node("Name")
	var texture: Texture2D = null
	if filled:
		texture = _texture_for(item.get("icon", ""))
	icon.texture = texture
	icon.visible = texture != null
	name_label.visible = filled and texture == null
	name_label.text = str(item.get("name", "")) if filled else ""
	_paint_slot(slot, false)


func _texture_for(icon) -> Texture2D:
	if icon is Texture2D:
		return icon
	var path: String = str(icon).strip_edges() if icon != null else ""
	if path.is_empty():
		return null
	if _textures.has(path):
		return _textures[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is Texture2D:
			texture = loaded
	_textures[path] = texture
	return texture


func _on_slot_entered(slot: Panel) -> void:
	_hovered = slot
	var item = slot.get_meta("item", {})
	if typeof(item) != TYPE_DICTIONARY or item.is_empty():
		_hide_tooltip()
		_paint_slot(slot, false)
		return
	_paint_slot(slot, true)
	_show_tooltip(slot, item)


func _on_slot_exited(slot: Panel) -> void:
	_paint_slot(slot, false)
	if _hovered != slot:
		return
	_hovered = null
	_hide_tooltip()


func _show_tooltip(slot: Control, item: Dictionary) -> void:
	%TipTitle.text = str(item.get("name", ""))
	var description := str(item.get("description", "")).strip_edges()
	%TipBody.text = description
	%TipScroll.visible = description != ""
	%TipScroll.scroll_vertical = 0
	if description != "":
		var text_height: float = %TipBody.get_minimum_size().y
		%TipScroll.custom_minimum_size.y = clampf(text_height, 1.0, 140.0)
	%Tooltip.visible = true
	%Tooltip.reset_size()
	var origin := slot.global_position + Vector2(slot.size.x + 8.0, 0.0)
	var view := get_viewport_rect().size
	if origin.x + TOOLTIP_WIDTH > view.x - 8.0:
		origin.x = slot.global_position.x - 8.0 - TOOLTIP_WIDTH
	origin.x = clampf(origin.x, 8.0, maxf(8.0, view.x - TOOLTIP_WIDTH - 8.0))
	origin.y = clampf(origin.y, 8.0, maxf(8.0, view.y - %Tooltip.size.y - 8.0))
	%Tooltip.global_position = origin


func _hide_tooltip() -> void:
	%Tooltip.hide()


func _layout_panel() -> void:
	var panel: Control = %Panel
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_bottom = PANEL_SIZE.y * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 1
	%Grid.columns = COLUMNS
	%Grid.add_theme_constant_override("h_separation", int(GAP))
	%Grid.add_theme_constant_override("v_separation", int(GAP))


func _style_panel() -> void:
	var flat := StyleBoxFlat.new()
	flat.bg_color = PARCHMENT
	flat.border_color = EDGE
	flat.set_border_width_all(2)
	flat.set_corner_radius_all(8)
	%Panel.add_theme_stylebox_override("panel", flat)


func _on_slot_gui_input(event: InputEvent, slot: Control) -> void:
	if _hovered != slot or not %Tooltip.visible:
		return
	var wheel: InputEventMouseButton = event as InputEventMouseButton
	if wheel == null or not wheel.pressed:
		return
	if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
		%TipScroll.scroll_vertical -= 28
		slot.accept_event()
	elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		%TipScroll.scroll_vertical += 28
		slot.accept_event()


func _paint_slot(slot: Panel, hovered: bool) -> void:
	var item = slot.get_meta("item", {})
	var filled: bool = typeof(item) == TYPE_DICTIONARY and not item.is_empty()
	var box := StyleBoxFlat.new()
	box.bg_color = PARCHMENT if filled else PARCHMENT_EMPTY
	box.border_color = Color(0.55, 0.38, 0.16, 1) if hovered and filled else EDGE
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	slot.add_theme_stylebox_override("panel", box)


func _style_icons() -> void:
	for button in [%CloseButton, %PrevButton, %NextButton]:
		button.flat = true
		button.text = ""
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_constant_override("icon_max_width", ICON_SIZE)
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, empty)
		button.mouse_entered.connect(_paint_icon.bind(button))
		button.mouse_exited.connect(_paint_icon.bind(button))
		_paint_icon(button)


func _paint_icon(button: Button) -> void:
	if button.disabled:
		button.modulate = ICON_DISABLED
	elif button.is_hovered():
		button.modulate = ICON_HOVER
	else:
		button.modulate = Color.WHITE


func _style_tooltip() -> void:
	%Tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%Tooltip.z_index = 4
	var box := StyleBoxFlat.new()
	box.bg_color = PARCHMENT
	box.border_color = EDGE
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	%Tooltip.add_theme_stylebox_override("panel", box)
	%Tooltip.custom_minimum_size.x = TOOLTIP_WIDTH
	%TipScroll.custom_minimum_size = Vector2(TOOLTIP_WIDTH - TOOLTIP_MARGIN * 2.0, 96)
	%TipScroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED


func _apply_fonts() -> void:
	var font := _font()
	%Title.add_theme_font_override("font", font)
	%Title.add_theme_font_size_override("font_size", 32)
	%Title.add_theme_color_override("font_color", INK)
	%PageLabel.add_theme_font_override("font", font)
	%PageLabel.add_theme_font_size_override("font_size", 22)
	%PageLabel.add_theme_color_override("font_color", INK)
	%TipTitle.add_theme_font_override("font", font)
	%TipTitle.add_theme_font_size_override("font_size", 24)
	%TipTitle.add_theme_color_override("font_color", INK)
	%TipBody.add_theme_font_override("font", font)
	%TipBody.add_theme_font_size_override("font_size", 18)
	%TipBody.add_theme_color_override("font_color", INK)
	%TipBody.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	%TipBody.custom_minimum_size.x = TOOLTIP_WIDTH - TOOLTIP_MARGIN * 2.0


func _font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "Microsoft YaHei", "微软雅黑"])
	return font


func _preview_payload() -> Dictionary:
	var extra_names := [
		"麻绳", "干粮", "火折", "铜钱", "清水", "盐包", "鱼钩", "油灯",
		"布条", "木炭", "陶碗", "针线", "地图残页", "贝壳",
	]
	var items: Array = [
		{
			"id": "ancient_song",
			"name": "古老的船歌",
			"icon": "res://assets/items/ancient_song.tres",
			"description": "字迹漫漶，隐约可以识读——「向您致敬，深蓝发的神明！蒙您庇佑，我们在波涛之间……」",
		},
		{
			"id": "old_plank",
			"name": "旧木板",
			"icon": "res://assets/items/old_plank.tres",
			"description": "形状奇怪的旧木板，似乎是某种大型物件的碎片，上面刻有形似音符的符号。",
		},
		{
			"id": "ship_blueprint",
			"name": "造船图纸",
			"icon": "res://assets/items/ship_blueprint.tres",
			"description": "记录着船只的构造与制作方法，还有一些难以理解的词句。",
		},
	]
	for index in extra_names.size():
		var item_name: String = extra_names[index]
		items.append({
			"id": "evidence_%d" % index,
			"name": item_name,
			"icon": "",
			"description": "证据占位。%s还没有正式说明。" % item_name,
		})
	return {"items": items}
