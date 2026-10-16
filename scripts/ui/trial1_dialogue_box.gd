extends "res://scripts/ui/dialogue_box/dialogue_box.gd"
## Reuse main's click-to-advance box, adding a saveable cursor for trial1 only.
signal line_presented(index: int, speaker: String)

func _ready() -> void:
	super._ready()
	# The new supplied frame has its own opaque black center.
	$Backdrop.hide()

func show_from(lines: Array, index: int) -> void:
	_lines = lines.duplicate(true)
	_line_index = clampi(index, 0, maxi(0, _lines.size() - 1)) - 1
	advance()

func advance() -> void:
	var finishing := _lines.is_empty() or _line_index + 1 >= _lines.size()
	super.advance()
	# Completion can synchronously start another sequence; don't emit its line twice.
	if not finishing and _line_index >= 0:
		line_presented.emit(_line_index, str(_lines[_line_index].get("speaker", "")))
