extends RefCounted
## Declarative event transactions. Reading pages never calls resolve.
var definitions: Array = []

func _init() -> void:
	definitions = JSON.parse_string(FileAccess.get_file_as_string("res://data/events.json"))

func due(day: int, world: Dictionary) -> Dictionary:
	if world.get("preview_only", false):
		return {}
	for event in definitions:
		if world.get("resolved_events", {}).has(event.id):
			continue
		if event.type == "date" and int(event.day) == day:
			return event.duplicate(true)
		if event.type == "condition" and world.get("event_signals", {}).get(event.signal, false) and world.get("known_targets", {}).has(event.target):
			return event.duplicate(true)
	return {}

func resolve(event: Dictionary, choice: String, world: Dictionary) -> Dictionary:
	if event.is_empty() or world.get("resolved_events", {}).has(event.id):
		return {}
	if not event.choices.any(func(item): return item.id == choice):
		return {}
	var result := world.duplicate(true)
	if not result.has("resolved_events"):
		result.resolved_events = {}
	result.resolved_events[event.id] = choice
	var effects: Dictionary = event.get("effects", {})
	for key in effects:
		if key == "known_targets":
			for id in effects[key]:
				result.known_targets[id] = effects[key][id].duplicate(true)
		elif key == "journal_entries":
			if not result.has(key): result[key] = {}
			result[key].merge(effects[key], true)
		else:
			result[key] = effects[key].duplicate(true) if effects[key] is Dictionary or effects[key] is Array else effects[key]
	return result
