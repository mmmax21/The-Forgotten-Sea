extends Control
## 按天翻页的手记弹窗。不读存档。
##
## 场景结构（scenes/ui/popup/journal_book.tscn）：
## - Shade：全屏遮罩，挡住底层点击，点遮罩不关闭。
## - Book：书本范围。PageAnim 播摊开和翻页。
## - DayTitle：当前页标题，写成 Day N。
## - PageScroll：当天的事件和操作。超出时只在这块里滚动。
## - PrevButton / NextButton：上一天、下一天。图标是 assets/icons/prev.png、assets/icons/next.png。
## - CloseButton：右上角。图标是 assets/icons/close.png。
##
## 数据引擎调用 apply_engine(data)，再 open()。字段见 docs/data_formats.md 的「手记弹窗」。
## 按下关闭后 hide()，发出 closed。

signal closed

const CELL := 256.0
const PAGE_RECT := Rect2(12, 80, 230, 170)
const TURN_DISTANCE := 56.0
const TURN_TIME := 0.2
const INK := Color(0, 0, 0, 1)
const TITLE_SIZE := 34
const HEADING_SIZE := 22
const BODY_SIZE := 20
const PAGE_SIZE := 18
const ICON_SIZE := 48
const ICON_HOVER := Color(0.62, 0.62, 0.62, 1)
const ICON_DISABLED := Color(1, 1, 1, 0.35)

var _days: Array = []
var _page := 0
var _shown := false
var _has_data := false
var _turn: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	%Shade.mouse_filter = Control.MOUSE_FILTER_STOP
	%CloseButton.pressed.connect(_close)
	%PrevButton.pressed.connect(_turn_page.bind(-1))
	%NextButton.pressed.connect(_turn_page.bind(1))
	%PageAnim.animation_finished.connect(_on_page_anim_finished)
	%Book.resized.connect(_fit_book_anim)
	_apply_fonts()
	_style_icon_buttons()
	_fit_book_anim()
	_reset_slide()
	if not _has_data and get_tree().current_scene == self:
		apply_engine(_preview_payload())
		_shown = true
		_page = maxi(_days.size() - 1, 0)
	_render()
	visible = _shown


## days 是数组，一项是一天，顺序就是翻页顺序。不接收页码。
func apply_engine(data: Dictionary) -> void:
	_days = _days_from(data.get("days", []))
	_has_data = true
	_page = clampi(_page, 0, maxi(_days.size() - 1, 0))
	if is_node_ready() and visible:
		_render()


## 显示当前书页。还没有传入数据时用预览。打开后停在最后一天。
func open() -> void:
	if not _has_data:
		apply_engine(_preview_payload())
	_shown = true
	_page = maxi(_days.size() - 1, 0)
	_reset_slide()
	if %PageAnim.sprite_frames != null:
		%PageAnim.play(&"idle")
	if is_node_ready():
		_render()
		show()


func show_day(day: int) -> void:
	for index in _days.size():
		var page: Dictionary = _days[index]
		if int(page.get("day", 0)) == day:
			_show_index(index)
			return


func _close() -> void:
	_shown = false
	hide()
	closed.emit()


func _turn_page(step: int) -> void:
	_show_index(_page + step)


func _show_index(index: int) -> void:
	if _days.is_empty():
		_render()
		return
	var next := clampi(index, 0, _days.size() - 1)
	var direction := next - _page
	var turning := visible and direction != 0
	_page = next
	_render()
	if turning:
		_play_turn(direction)


func _days_from(raw) -> Array:
	var days: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return days
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var day: int = int(entry.get("day", 0))
		if day < 1:
			continue
		days.append({
			"day": day,
			"events": _events_from(entry.get("events", [])),
			"actions": _actions_from(entry.get("actions", [])),
		})
	return days


func _events_from(raw) -> Array:
	var events: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return events
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var title: String = str(entry.get("title", "")).strip_edges()
		var text: String = str(entry.get("text", "")).strip_edges()
		if title.is_empty() and text.is_empty():
			continue
		events.append({
			"id": str(entry.get("id", "")),
			"title": title,
			"text": text,
		})
	return events


func _actions_from(raw) -> Array:
	var actions: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return actions
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var action: String = str(entry.get("action", "")).strip_edges()
		var result: String = str(entry.get("result", "")).strip_edges()
		if action.is_empty() and result.is_empty():
			continue
		actions.append({
			"id": str(entry.get("id", "")),
			"action": action,
			"result": result,
		})
	return actions


func _render() -> void:
	for node in %PageBody.get_children():
		node.queue_free()
	var total := _days.size()
	var day := 1
	var events: Array = []
	var actions: Array = []
	if not _days.is_empty():
		var page: Dictionary = _days[_page]
		day = int(page.get("day", 1))
		events = page.get("events", [])
		actions = page.get("actions", [])
	%DayTitle.text = "Day %d" % day
	%PageLabel.text = "%d/%d" % [_page + 1, maxi(total, 1)]
	%PrevButton.disabled = _page <= 0
	%NextButton.disabled = total <= 1 or _page >= total - 1
	_paint_icon(%PrevButton)
	_paint_icon(%NextButton)
	%PageScroll.scroll_vertical = 0
	_add_heading("当日事件")
	if events.is_empty():
		_add_body("这一天没有触发新的事件。")
	else:
		for event in events:
			var record: Dictionary = event
			if not str(record.get("title", "")).is_empty():
				_add_heading(str(record.get("title", "")))
			if not str(record.get("text", "")).is_empty():
				_add_body(str(record.get("text", "")))
	_add_heading("玩家操作")
	if actions.is_empty():
		_add_body("这一天没有记下操作。")
	else:
		for action in actions:
			var record: Dictionary = action
			if not str(record.get("action", "")).is_empty():
				_add_heading(str(record.get("action", "")))
			if not str(record.get("result", "")).is_empty():
				_add_body(str(record.get("result", "")))


func _add_heading(text: String) -> void:
	%PageBody.add_child(_label(text, HEADING_SIZE))


func _add_body(text: String) -> void:
	%PageBody.add_child(_label(text, BODY_SIZE))


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.x = 776.0
	label.add_theme_color_override("font_color", INK)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", _font())
	return label


func _apply_fonts() -> void:
	var font := _font()
	%DayTitle.add_theme_font_override("font", font)
	%DayTitle.add_theme_font_size_override("font_size", TITLE_SIZE)
	%DayTitle.add_theme_color_override("font_color", INK)
	%PageLabel.add_theme_font_override("font", font)
	%PageLabel.add_theme_font_size_override("font_size", PAGE_SIZE)
	%PageLabel.add_theme_color_override("font_color", INK)


func _style_icon_buttons() -> void:
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


func _font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "Microsoft YaHei", "微软雅黑"])
	return font


func _reset_slide() -> void:
	if _turn != null and _turn.is_valid():
		_turn.kill()
	var slide: Control = %PageSlide
	slide.offset_left = 0.0
	slide.offset_right = 0.0
	slide.modulate.a = 1.0


func _play_turn(direction: int) -> void:
	var slide: Control = %PageSlide
	if _turn != null and _turn.is_valid():
		_turn.kill()
	var from := TURN_DISTANCE if direction > 0 else -TURN_DISTANCE
	slide.offset_left = from
	slide.offset_right = from
	slide.modulate.a = 0.0
	_turn = create_tween()
	_turn.set_parallel(true)
	_turn.tween_property(slide, "offset_left", 0.0, TURN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_turn.tween_property(slide, "offset_right", 0.0, TURN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_turn.tween_property(slide, "modulate:a", 1.0, TURN_TIME)
	_play_book_anim(direction)


func _fit_book_anim() -> void:
	var book_size: Vector2 = %Book.size
	if book_size.x < 8.0 or book_size.y < 8.0:
		return
	var fitted := minf(book_size.x / PAGE_RECT.size.x, book_size.y / PAGE_RECT.size.y)
	var page_anim: AnimatedSprite2D = %PageAnim
	page_anim.scale = Vector2(fitted, fitted)
	var content_center := PAGE_RECT.position + PAGE_RECT.size * 0.5
	page_anim.position = book_size * 0.5 - (content_center - Vector2(CELL, CELL) * 0.5) * fitted


func _play_book_anim(direction: int) -> void:
	var page_anim: AnimatedSprite2D = %PageAnim
	if page_anim.sprite_frames == null:
		return
	var anim := &"next" if direction > 0 else &"prev"
	if page_anim.sprite_frames.has_animation(anim):
		page_anim.play(anim)


func _on_page_anim_finished() -> void:
	if %PageAnim.animation != &"idle":
		%PageAnim.play(&"idle")


func _preview_payload() -> Dictionary:
	return {
		"days": [
			{
				"day": 1,
				"events": [
					{
						"id": "tide_notice",
						"title": "潮汐告示",
						"text": "镇口贴出告示。北面的网已经收起，今天先不要出镇。",
					}
				],
				"actions": [
					{
						"id": "ask_fisher",
						"action": "向老渔夫打听潮汐",
						"result": "他只说今天不要出镇，没有再往下讲。",
					}
				],
			},
			{
				"day": 2,
				"events": [
					{
						"id": "song_found",
						"title": "遗迹里的船歌",
						"text": "石缝里露出一张受潮的纸。字迹漫漶，仍能认出那是一首船歌。",
					}
				],
				"actions": [
					{
						"id": "take_song",
						"action": "收好古老的船歌",
						"result": "船歌放进证据。哑伯还没有看见它。把纸摊平之后，边缘的句子比刚才更清楚：向您致敬，深蓝发的神明。蒙您庇佑，我们在波涛之间记住航线，也记住不该说出口的名字。纸背还有一行被水泡开的批注，一时读不全。",
					}
				],
			},
		]
	}
