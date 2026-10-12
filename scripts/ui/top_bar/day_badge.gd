extends Control
## 右侧天数。贴图是 208×210 的右上四分之一圆，控件与图同大。
## 天数下面是行动点：文字「当前/上限」，再加一排圆点。圆点亮着的是还没用的点数。
## 「结束当天」按下后，本控件里的确认弹窗先写明结果。确认才发出 end_day_confirmed。
## 弹窗铺满窗口，避免被角标自己的圆裁掉。没有贴图时，在右上角画一块绿色四分之一圆。

signal end_day_confirmed

const AP_MAX := 3
const SUN := Color(0.35, 0.62, 0.28, 1)
const INK := Color(0.28, 0.16, 0.05, 1)
const PIP_ON := Color(0.62, 0.34, 0.08, 1)
const PIP_OFF := Color(0.45, 0.32, 0.16, 0.28)
const PLATE := Color(0.98, 0.94, 0.84, 0.94)
const EDGE := Color(0.45, 0.30, 0.14, 1)

@export var background: Texture2D:
	set(value):
		background = value
		if is_node_ready():
			_apply_background()

var _ap := AP_MAX
var _ap_max := AP_MAX


func _ready() -> void:
	resized.connect(queue_redraw)
	_apply_background()
	_style_day()
	_style_ap()
	_style_end_day()
	%EndDayButton.pressed.connect(ask_end_day)
	%ConfirmDialog.confirmed.connect(_release_dialog)
	%ConfirmDialog.cancelled.connect(_release_dialog)
	%ConfirmDialog.hide()
	if _ap_max > 0:
		_show_ap(_ap, _ap_max)


func configure(day: int, _total: int, ap: int = AP_MAX, ap_max: int = AP_MAX) -> void:
	_ap = ap
	_ap_max = maxi(1, ap_max)
	if is_node_ready():
		%Caption.text = "第%d天" % day
		_show_ap(ap, _ap_max)


func set_end_day_enabled(enabled: bool) -> void:
	if is_node_ready():
		%EndDayButton.disabled = not enabled


func is_confirm_open() -> bool:
	return is_node_ready() and %ConfirmDialog.visible


func ask_end_day() -> void:
	if not is_node_ready() or %ConfirmDialog.visible or %EndDayButton.disabled:
		return
	_place_dialog()
	%ConfirmDialog.configure({
		"title": "结束今日行动？",
		"text": "当前剩余 %d AP。次日恢复至 %d AP，所在地、物品与剧情进度保留。\n确认后进入下一天。取消则留在今天。" % [_ap, _ap_max],
		"on_confirm": _confirm_end_day,
	})
	%ConfirmDialog.open()


func _confirm_end_day() -> void:
	end_day_confirmed.emit()


func _show_ap(ap: int, ap_max: int) -> void:
	%Ap.text = "%d/%d" % [ap, ap_max]
	%Ap.add_theme_color_override("font_color", Color(0.55, 0.16, 0.1, 1) if ap <= 0 else INK)
	for child in %Pips.get_children():
		%Pips.remove_child(child)
		child.free()
	for index in ap_max:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(12, 12)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dot := StyleBoxFlat.new()
		dot.bg_color = PIP_ON if index < ap else PIP_OFF
		dot.set_corner_radius_all(6)
		if index >= ap:
			dot.border_color = EDGE
			dot.set_border_width_all(1)
		pip.add_theme_stylebox_override("panel", dot)
		%Pips.add_child(pip)


func _place_dialog() -> void:
	clip_contents = false
	var dialog: Control = %ConfirmDialog
	dialog.top_level = true
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.offset_left = 0
	dialog.offset_top = 0
	dialog.offset_right = 0
	dialog.offset_bottom = 0


func _release_dialog() -> void:
	clip_contents = true


func _apply_background() -> void:
	%Art.texture = background
	%Art.visible = background != null
	queue_redraw()


func _style_day() -> void:
	var font := _font()
	%Caption.add_theme_font_override("font", font)
	%Caption.add_theme_font_size_override("font_size", 30)
	%Caption.add_theme_color_override("font_color", INK)


func _style_ap() -> void:
	var font := _font()
	var plate := StyleBoxFlat.new()
	plate.bg_color = PLATE
	plate.border_color = EDGE
	plate.set_border_width_all(2)
	plate.set_corner_radius_all(10)
	plate.content_margin_left = 10
	plate.content_margin_right = 10
	plate.content_margin_top = 4
	plate.content_margin_bottom = 6
	%ApPlate.add_theme_stylebox_override("panel", plate)
	%ApCaption.add_theme_font_override("font", font)
	%ApCaption.add_theme_font_size_override("font_size", 14)
	%ApCaption.add_theme_color_override("font_color", INK)
	%Ap.add_theme_font_override("font", font)
	%Ap.add_theme_font_size_override("font_size", 22)
	%Ap.add_theme_color_override("font_color", INK)


func _style_end_day() -> void:
	var button: Button = %EndDayButton
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", _font())
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", Color(INK.r, INK.g, INK.b, 0.45))
	var normal := _button_box(PLATE)
	var hover := _button_box(Color(0.9, 0.82, 0.66, 0.96))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_stylebox_override("disabled", _button_box(Color(PLATE.r, PLATE.g, PLATE.b, 0.55)))


func _button_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = EDGE
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	return box


func _draw() -> void:
	if background != null or size.x < 2.0 or size.y < 2.0:
		return
	draw_circle(Vector2(size.x, 0.0), minf(size.x, size.y), SUN)


func _font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "Microsoft YaHei", "微软雅黑"])
	return font
