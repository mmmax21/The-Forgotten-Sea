extends RefCounted
## 独立版本与文件；临时写入后替换，保留上一份有效备份。
const State := preload("res://scripts/story/trail2_state.gd")
const VERSION := 4

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "missing": true}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "missing": false}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {"ok": false, "missing": false}
	var envelope = json.data
	if not envelope is Dictionary or (envelope.get("version") != 1 and envelope.get("version") != 2 and envelope.get("version") != 3 and envelope.get("version") != VERSION) or envelope.get("game") != "trail2":
		return {"ok": false, "missing": false}
	if not envelope.get("payload") is String or not envelope.get("checksum") is String or envelope.payload.sha256_text() != envelope.checksum:
		return {"ok": false, "missing": false}
	if json.parse(envelope.payload) != OK:
		return {"ok": false, "missing": false}
	var data = _integer_numbers(json.data)
	if not data is Dictionary or not data.get("state") is Dictionary or not data.get("view") is Dictionary:
		return {"ok": false, "missing": false}
	if envelope.version == 1 and not data.state.has("market"):
		data.state.market = {}
	if envelope.version < 3 and not data.state.has("academy"):
		data.state.academy = {}
	if envelope.version < 4 and not data.state.has("current_location"):
		data.state.current_location = "old_academy" if not data.state.academy.is_empty() else ("market" if not data.state.market.is_empty() else ("ruins" if data.view.get("selected_group") == "warehouse" else "fishing_village"))
	if envelope.version == VERSION and not data.state.has("current_location"):
		return {"ok": false, "missing": false}
	var state = State.new()
	if not state.restore_save_data(data.state):
		return {"ok": false, "missing": false}
	if not state.market.is_empty():
		state.Market.Business.initialize(state)
	if data.view.get("selected_group") not in ["", "salt", "mute", "luo", "warehouse", "qian", "xiang", "dao", "research", "mo", "er", "gao", "archive"] or not data.view.get("text") is String:
		return {"ok": false, "missing": false}
	return {"ok": true, "state": state, "view": data.view}


static func load_from(path: String) -> Dictionary:
	var primary := _read(path)
	if primary.ok:
		primary["backup"] = false
		return primary
	var backup := _read(path + ".bak")
	if backup.ok:
		backup["backup"] = true
		return backup
	return {"ok": false, "missing": primary.get("missing", false) and backup.get("missing", false)}


static func save_to(path: String, state, view: Dictionary) -> Error:
	var payload := JSON.stringify({"state": state.to_save_data(), "view": view})
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"game": "trail2", "version": VERSION, "payload": payload, "checksum": payload.sha256_text()}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	if not _read(temp).ok:
		return ERR_FILE_CORRUPT
	# 无效主档不覆盖有效备份（如刚从备份恢复）。
	if _read(path).ok:
		error = DirAccess.copy_absolute(path, path + ".bak.tmp")
		if error != OK:
			return error
		error = DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak")
		if error != OK:
			return error
	return DirAccess.rename_absolute(temp, path)


# JSON将数字读成浮点数；本版本规则只使用整数，恢复一致的数据类型。
static func _integer_numbers(value):
	if value is float and is_finite(value) and value == floor(value):
		return int(value)
	if value is Dictionary:
		for key in value:
			value[key] = _integer_numbers(value[key])
	elif value is Array:
		for index in value.size():
			value[index] = _integer_numbers(value[index])
	return value
