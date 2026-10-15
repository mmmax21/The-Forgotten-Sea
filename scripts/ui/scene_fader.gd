extends CanvasLayer
## 跨场景黑屏。换场景时这一层还在，所以能先暗下再亮起新界面。
## 临时游玩入口。以后换成正式场景时，只改 GAME_SCENE。
const GAME_SCENE := "res://scenes/trial1.tscn"

const FADE_OUT_SEC := 0.9
const FADE_IN_SEC := 1.1

var _veil: ColorRect
var _fade: Tween
var _busy := false


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = ColorRect.new()
	_veil.name = "Veil"
	_veil.color = Color(0, 0, 0, 0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## 从开始界面进入游戏：缓慢黑屏，黑屏期间可插入过场，再亮起游戏场景。
func enter_game() -> void:
	if _busy:
		return
	_busy = true
	await fade_to_black()
	await play_transition()
	var err := get_tree().change_scene_to_file(GAME_SCENE)
	if err != OK:
		push_error("无法进入游戏场景：%s" % GAME_SCENE)
		await fade_from_black()
		_busy = false
		return
	# change_scene_to_file 延迟到本帧结束才换场景，多等一帧再揭开黑幕。
	await get_tree().process_frame
	await get_tree().process_frame
	await fade_from_black()
	_busy = false


## 预留：全黑时播放 settlement 与游戏之间的过场。
## 以后在这里 await 动画结束即可，enter_game 的调用方不用改。
func play_transition() -> void:
	pass


func fade_to_black(duration := FADE_OUT_SEC) -> void:
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	await _tween_alpha(1.0, duration)


func fade_from_black(duration := FADE_IN_SEC) -> void:
	await _tween_alpha(0.0, duration)
	if _veil.color.a <= 0.001:
		_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _tween_alpha(target: float, duration: float) -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade.tween_property(_veil, "color:a", target, duration)
	await _fade.finished
