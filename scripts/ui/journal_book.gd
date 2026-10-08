extends Control
## 按天翻页的手记。只显示调用方给的书页，不读取世界状态。
##
## 场景结构（scenes/ui/journal_book.tscn）：
## - Shade：全屏遮罩，点击关闭。
## - Book：书本占位，锚点沿用旧弹窗（左 0.22、上 0.14、右 0.78、下 0.86）。
## - Book/PageAnim：翻页精灵。idle 是摊开的书，next 是下一天，prev 是上一天。
## - Book/TextFrame：文字区域。锚点居中。
##   宽度 = offset_right - offset_left，高度 = offset_bottom - offset_top。
## - Footer：左箭头、页码、右箭头。图标来自 assets/Icons.png 的 16×16 格子。
## - Book/CloseButton：右上角关闭，不在文字流里。
##
## 一页的数据是 {day, entries:[{id, title, text}]}。
## seen 用 id → 正文判断未读；正文变了会再次算未读。
signal read_changed

const CELL := 256.0
## 打开的书在 256 格里的可见范围，用来把书放大到原来的弹窗位置。
const PAGE_RECT := Rect2(12, 80, 230, 170)
const TURN_DISTANCE := 56.0
const TURN_TIME := 0.2
const INK := Color(0, 0, 0, 1)
const TEST_DATA := "res://data/journal_test.json"
const TITLE_SIZE := 34
const HEADING_SIZE := 22
const BODY_SIZE := 20
const PAGE_SIZE := 18
## 图标格子是正方形，只提高 icon_max_width，高度会按同样比例放大。
const ICON_SIZE := 48
const ICON_HOVER := Color(0.62, 0.62, 0.62, 1)
const ICON_DISABLED := Color(1, 1, 1, 0.35)

enum FontPreset { KAI, FANGSONG, YAHEI }
## 在检查器里切换。楷体、仿宋、微软雅黑都使用系统里已安装的字体。
@export var font_preset: FontPreset = FontPreset.KAI

var _body_font: Font

var pages: Array = []
var seen: Dictionary = {}
var page_index := 0
var _turn: Tween

@onready var shade: ColorRect = %Shade
@onready var day_title: Label = %DayTitle
@onready var page_body: VBoxContainer = %PageBody
@onready var prev_button: Button = %PrevButton
@onready var next_button: Button = %NextButton
@onready var page_label: Label = %PageLabel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_on_shade_input)
	%CloseButton.pressed.connect(hide)
	prev_button.pressed.connect(func(): show_index(page_index - 1))
	next_button.pressed.connect(func(): show_index(page_index + 1))
	%PageAnim.animation_finished.connect(_on_page_anim_finished)
	%Book.resized.connect(_fit_book_anim)
	_apply_fonts()
	_style_icon_buttons()
	_fit_book_anim()
	_reset_slide()
	# 用 F6 直接运行本场景时，读测试手记；挂在游戏里则等叙事控制器打开。
	if get_tree().current_scene == self:
		_open_test_data()
	else:
		hide()


func _open_test_data() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(TEST_DATA))
	var grouped := {}
	var last_day := 1
	if parsed is Dictionary:
		for item in parsed.get("journal_log", []):
			var day := int(item.get("day", 1))
			last_day = maxi(last_day, day)
			if not grouped.has(day):
				grouped[day] = []
			grouped[day].append({"id": str(item.get("id", "")), "title": str(item.get("title", "")), "text": str(item.get("text", ""))})
	var built: Array = []
	for day in range(1, last_day + 1):
		built.append({"day": day, "entries": grouped.get(day, [])})
	refresh(built)
	open()


## 换成新的书页。游戏进行中由叙事控制器调用，不负责打开窗口。
func refresh(values: Array) -> void:
	pages = values.duplicate(true)
	page_index = clampi(page_index, 0, maxi(pages.size() - 1, 0))
	if visible:
		_render()
	read_changed.emit()


## 任一页的正文和上次看到的不同，手记按钮就显示未读。
func unread() -> bool:
	for page in pages:
		for item in page.get("entries", []):
			if seen.get(item.id, "") != item.text:
				return true
	return false


## 打开并停在最后一页（当前天）。打开本身不播放翻页动画。
func open() -> void:
	_reset_slide()
	if %PageAnim.sprite_frames != null:
		%PageAnim.play(&"idle")
	show()
	page_index = maxi(pages.size() - 1, 0)
	_render()
	_mark_current()


func show_day(day: int) -> void:
	for index in range(pages.size()):
		if int(pages[index].day) == day:
			show_index(index)
			return


func show_index(index: int) -> void:
	if pages.is_empty():
		_render()
		return
	var next := clampi(index, 0, pages.size() - 1)
	var direction := next - page_index
	var turning := visible and direction != 0
	page_index = next
	_render()
	_mark_current()
	if turning:
		_play_turn(direction)


func _mark_current() -> void:
	if pages.is_empty():
		return
	var changed := false
	for item in pages[page_index].get("entries", []):
		if seen.get(item.id, "") != item.text:
			seen[item.id] = item.text
			changed = true
	if changed:
		read_changed.emit()


func _render() -> void:
	if page_body == null:
		return
	for node in page_body.get_children():
		node.queue_free()
	var total := pages.size()
	var day := 1
	var entries: Array = []
	if not pages.is_empty():
		day = int(pages[page_index].day)
		entries = pages[page_index].get("entries", [])
	day_title.text = "第 %d 天" % day
	page_label.text = "%d / %d" % [day, total if total > 0 else day]
	prev_button.disabled = page_index <= 0
	next_button.disabled = pages.is_empty() or page_index >= total - 1
	_refresh_icon_button(prev_button)
	_refresh_icon_button(next_button)
	%PageScroll.scroll_vertical = 0
	if entries.is_empty():
		page_body.add_child(_label("这一天还没有记下新的事件。", BODY_SIZE))
		return
	for item in entries:
		page_body.add_child(_label(str(item.title), HEADING_SIZE))
		page_body.add_child(_label(str(item.text), BODY_SIZE))


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", INK)
	label.add_theme_font_size_override("font_size", font_size)
	if _body_font != null:
		label.add_theme_font_override("font", _body_font)
	return label


func _apply_fonts() -> void:
	_body_font = _system_font(_preset_names())
	_use_font(day_title, _body_font, TITLE_SIZE)
	_use_font(page_label, _body_font, PAGE_SIZE)


## 三个图标按钮都不画 Godot 默认底。悬停只把图标压暗，不换一张图。
func _style_icon_buttons() -> void:
	for button in [%CloseButton, prev_button, next_button]:
		button.flat = true
		button.text = ""
		button.add_theme_constant_override("icon_max_width", ICON_SIZE)
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, empty)
		button.mouse_entered.connect(_refresh_icon_button.bind(button))
		button.mouse_exited.connect(_refresh_icon_button.bind(button))
		_refresh_icon_button(button)


func _refresh_icon_button(button: Button) -> void:
	if button.disabled:
		button.modulate = ICON_DISABLED
	elif button.is_hovered():
		button.modulate = ICON_HOVER
	else:
		button.modulate = Color.WHITE


func _preset_names() -> Array:
	match font_preset:
		FontPreset.FANGSONG:
			return ["FangSong", "STFangsong", "仿宋"]
		FontPreset.YAHEI:
			return ["Microsoft YaHei", "微软雅黑"]
		_:
			return ["KaiTi", "STKaiti", "楷体"]


func _system_font(names: Array) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(names)
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return font


func _use_font(control: Control, font: Font, size: int) -> void:
	control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", INK)
	control.add_theme_color_override("font_hover_color", Color(0.28, 0.18, 0.1, 1))
	control.add_theme_color_override("font_pressed_color", INK)


func _reset_slide() -> void:
	if _turn != null and _turn.is_valid():
		_turn.kill()
	var slide: Control = %PageSlide
	slide.offset_left = 0.0
	slide.offset_right = 0.0
	slide.modulate.a = 1.0


## direction > 0 是下一天：文字从右侧滑入，同时播 next。上一天相反。
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


## 按 PAGE_RECT 等比放大，让摊开的书贴住 Book 的范围。文字框不跟着缩放。
func _fit_book_anim() -> void:
	var size: Vector2 = %Book.size
	if size.x < 8.0 or size.y < 8.0:
		return
	var fitted := minf(size.x / PAGE_RECT.size.x, size.y / PAGE_RECT.size.y)
	var page_anim: AnimatedSprite2D = %PageAnim
	page_anim.scale = Vector2(fitted, fitted)
	var content_center := PAGE_RECT.position + PAGE_RECT.size * 0.5
	page_anim.position = size * 0.5 - (content_center - Vector2(CELL, CELL) * 0.5) * fitted


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


func _on_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide()
		shade.accept_event()
