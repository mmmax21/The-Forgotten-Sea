extends RefCounted
## 唯一游戏状态：位置始终在 0～29，天数和节点均从位置派生。

signal changed

const TOTAL_DAYS: int = 10
const SLOTS_PER_DAY: int = 3
const TOTAL_SLOTS: int = TOTAL_DAYS * SLOTS_PER_DAY
const SLOT_NAMES: Array[String] = ["上午", "下午", "晚上"]

var _position: int = 0
var _finished: bool = false


func get_day() -> int:
	return floori(float(_position) / SLOTS_PER_DAY) + 1


func get_slot() -> int:
	return _position % SLOTS_PER_DAY


func get_slot_name() -> String:
	return SLOT_NAMES[get_slot()]


func get_progress() -> int:
	return _position + 1


func is_finished() -> bool:
	return _finished


func can_skip_day() -> bool:
	return not _finished and get_day() < TOTAL_DAYS


func advance() -> void:
	if _finished:
		return
	# 已经位于最后一个节点时，再次推进才结算；位置不增加到 30。
	if _position == TOTAL_SLOTS - 1:
		_finished = true
	else:
		_position += 1
	changed.emit()


func skip_day() -> void:
	if not can_skip_day():
		return
	_position = get_day() * SLOTS_PER_DAY
	changed.emit()


func restart() -> void:
	_position = 0
	_finished = false
	changed.emit()
