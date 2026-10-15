extends Control
## 游戏开始界面。进入正式游玩走 SceneFader.enter_game()。

const TITLE_COLOR := Color(0.98, 0.9, 0.68, 1)
const TITLE_OUTLINE := Color(0.4, 0.24, 0.1, 1)
const TITLE_SHADOW := Color(0.18, 0.09, 0.04, 0.88)

const IDLE_SIZE := 40
const HOVER_SIZE := 48
const PRESS_SIZE := 36
const IDLE_COLOR := Color(1, 1, 1, 1)
const HOVER_COLOR := Color(1, 1, 1, 1)
const PRESS_COLOR := Color(0.82, 0.82, 0.82, 1)
const OUTLINE_COLOR := Color(0.07, 0.09, 0.08, 1)
const IDLE_SHADOW := Color(0, 0, 0, 0.92)
const HOVER_SHADOW := Color(0, 0, 0, 1)
const PRESS_SHADOW := Color(0, 0, 0, 0.8)
const IDLE_OFFSET := Vector2(3, 6)
const HOVER_OFFSET := Vector2(5, 12)
const PRESS_OFFSET := Vector2(1, 2)
const IDLE_OUTLINE := 8.0
const HOVER_OUTLINE := 12.0
const PRESS_OUTLINE := 5.0

var _looks: Dictionary = {}


func _ready() -> void:
	_style_title()
	_prepare_button(%StartGame)
	_prepare_button(%Quit)
	%StartGame.pressed.connect(_on_start_pressed)
	%Quit.pressed.connect(_on_quit_pressed)


func _style_title() -> void:
	%Title.add_theme_font_override("font", _title_font())
	%Title.add_theme_font_size_override("font_size", 128)
	%Title.add_theme_color_override("font_color", TITLE_COLOR)
	%Title.add_theme_color_override("font_outline_color", TITLE_OUTLINE)
	%Title.add_theme_constant_override("outline_size", 10)
	%Title.add_theme_color_override("font_shadow_color", TITLE_SHADOW)
	%Title.add_theme_constant_override("shadow_offset_x", 0)
	%Title.add_theme_constant_override("shadow_offset_y", 10)
	%Title.add_theme_constant_override("shadow_outline_size", 14)


func _prepare_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, empty)
	button.add_theme_font_override("font", _kai_font(4))
	_apply_look(button, IDLE_SIZE, IDLE_COLOR, IDLE_SHADOW, IDLE_OFFSET, IDLE_OUTLINE)
	button.mouse_entered.connect(_on_hover.bind(button))
	button.mouse_exited.connect(_on_idle.bind(button))
	button.button_down.connect(_on_press.bind(button))
	button.button_up.connect(_on_release.bind(button))


func _on_hover(button: Button) -> void:
	if button.button_pressed:
		return
	_tween_look(button, HOVER_SIZE, HOVER_COLOR, HOVER_SHADOW, HOVER_OFFSET, HOVER_OUTLINE)


func _on_idle(button: Button) -> void:
	if button.button_pressed:
		return
	_tween_look(button, IDLE_SIZE, IDLE_COLOR, IDLE_SHADOW, IDLE_OFFSET, IDLE_OUTLINE)


func _on_press(button: Button) -> void:
	_tween_look(button, PRESS_SIZE, PRESS_COLOR, PRESS_SHADOW, PRESS_OFFSET, PRESS_OUTLINE)


func _on_release(button: Button) -> void:
	if button.is_hovered():
		_tween_look(button, HOVER_SIZE, HOVER_COLOR, HOVER_SHADOW, HOVER_OFFSET, HOVER_OUTLINE)
	else:
		_tween_look(button, IDLE_SIZE, IDLE_COLOR, IDLE_SHADOW, IDLE_OFFSET, IDLE_OUTLINE)


func _tween_look(button: Button, size: float, color: Color, shadow_color: Color, shadow: Vector2, outline: float) -> void:
	var from: Dictionary = _looks[button]
	if button.has_meta("look_tween"):
		var existing := button.get_meta("look_tween") as Tween
		if existing != null and existing.is_valid():
			existing.kill()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(
		func(weight: float) -> void:
			_apply_look(
				button,
				lerpf(from["size"], size, weight),
				(from["color"] as Color).lerp(color, weight),
				(from["shadow_color"] as Color).lerp(shadow_color, weight),
				(from["shadow"] as Vector2).lerp(shadow, weight),
				lerpf(from["outline"], outline, weight)
			),
		0.0,
		1.0,
		0.16
	)
	button.set_meta("look_tween", tween)


func _apply_look(button: Button, size: float, color: Color, shadow_color: Color, shadow: Vector2, outline: float) -> void:
	_looks[button] = {
		"size": size,
		"color": color,
		"shadow_color": shadow_color,
		"shadow": shadow,
		"outline": outline,
	}
	var edge := int(round(outline))
	button.add_theme_font_size_override("font_size", int(round(size)))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, color)
	button.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	button.add_theme_constant_override("outline_size", edge)
	button.add_theme_color_override("font_shadow_color", shadow_color)
	button.add_theme_constant_override("shadow_offset_x", int(round(shadow.x)))
	button.add_theme_constant_override("shadow_offset_y", int(round(shadow.y)))
	button.add_theme_constant_override("shadow_outline_size", edge + 4)


func _on_start_pressed() -> void:
	SceneFader.enter_game()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _title_font() -> Font:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"STXingkai", "华文行楷",
		"STXinwei", "华文新魏",
		"LiSu", "隶书",
		"KaiTi", "楷体",
		"Microsoft YaHei", "微软雅黑",
	])
	var varied := FontVariation.new()
	varied.base_font = font
	varied.spacing_glyph = 32
	return varied


func _kai_font(glyph_spacing: int) -> Font:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "楷体", "STKaiti", "Microsoft YaHei", "微软雅黑"])
	if glyph_spacing == 0:
		return font
	var varied := FontVariation.new()
	varied.base_font = font
	varied.spacing_glyph = glyph_spacing
	return varied
