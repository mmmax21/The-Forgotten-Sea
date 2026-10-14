extends "res://scripts/ui/portrait_panel/portrait_panel.gd"
## Character names map to assets rather than main's fixed four-person indices.
var character := ""

func present(person: String, texture: Texture2D) -> void:
	if person == character:
		return
	character = person
	_shown_index = 0
	_image.texture = texture
	_image.visible = texture != null
	_name_label.text = person
	_quote_label.text = ""
	_slide_in()

func clear_character() -> void:
	character = ""
	hide_portrait()
