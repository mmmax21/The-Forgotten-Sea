extends RefCounted
const State := preload("res://scripts/story/village_state.gd")
const VERSION := 1

static func read_one(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"ok":false,"missing":true}
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return {"ok":false}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK: return {"ok":false}
	var envelope = parser.data
	if not envelope is Dictionary or envelope.get("game") != State.RULESET or envelope.get("version") != VERSION: return {"ok":false}
	if not envelope.get("payload") is String or envelope.get("checksum") != envelope.payload.sha256_text(): return {"ok":false}
	if parser.parse(envelope.payload) != OK: return {"ok":false}
	var data = normalize_numbers(parser.data)
	if not data is Dictionary: return {"ok":false}
	var state = State.new()
	if not state.restore(data): return {"ok":false}
	return {"ok":true,"state":state}

static func load_from(path: String) -> Dictionary:
	var main := read_one(path)
	if main.ok: return main
	var backup := read_one(path+".bak")
	if backup.ok:
		backup["backup"] = true
		return backup
	return {"ok":false,"missing":main.get("missing",false) and backup.get("missing",false)}

static func save_to(path: String, state) -> Error:
	if not state.valid_data(state.to_data()): return ERR_INVALID_DATA
	var payload := JSON.stringify(state.to_data())
	var temp := path+".tmp"
	var file := FileAccess.open(temp,FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"game":State.RULESET,"version":VERSION,"payload":payload,"checksum":payload.sha256_text()}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return error
	if not read_one(temp).ok: return ERR_FILE_CORRUPT
	if read_one(path).ok:
		error = DirAccess.copy_absolute(path,path+".bak.tmp")
		if error != OK: return error
		error = DirAccess.rename_absolute(path+".bak.tmp",path+".bak")
		if error != OK: return error
	return DirAccess.rename_absolute(temp,path)

static func normalize_numbers(value):
	if value is float and is_finite(value) and value == floor(value): return int(value)
	if value is Dictionary:
		for key in value: value[key] = normalize_numbers(value[key])
	elif value is Array:
		for i in value.size(): value[i] = normalize_numbers(value[i])
	return value
