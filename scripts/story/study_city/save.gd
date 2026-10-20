extends RefCounted
## 学城章节存档 IO。信封式 + checksum + tmp + bak,
## 与 village_save / market_chapter_save 同模式,但独立路径。
const State := preload("res://scripts/story/study_city/state.gd")

const VERSION := 1


static func read_one(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "missing": true}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {"ok": false}
	var envelope = parser.data
	if not envelope is Dictionary: return {"ok": false}
	if envelope.get("game") != State.RULESET: return {"ok": false}
	if int(envelope.get("version", 0)) != VERSION: return {"ok": false}
	if not envelope.get("payload") is String: return {"ok": false}
	if envelope.get("checksum") != envelope.payload.sha256_text(): return {"ok": false}
	if parser.parse(envelope.payload) != OK: return {"ok": false}
	var data: Dictionary = parser.data
	var state := State.new()
	if not state.restore(data):
		return {"ok": false}
	return {"ok": true, "state": state}


static func load_from(path: String) -> Dictionary:
	var main := read_one(path)
	if main.ok: return main
	var backup := read_one(path + ".bak")
	if backup.ok:
		backup["backup"] = true
		return backup
	return {"ok": false, "missing": main.get("missing", false) and backup.get("missing", false)}


static func save_to(path: String, state) -> Error:
	var payload := JSON.stringify(state.to_data())
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	var envelope := {
		"game": State.RULESET,
		"version": VERSION,
		"payload": payload,
		"checksum": payload.sha256_text(),
	}
	file.store_string(JSON.stringify(envelope))
	file.flush()
	var err := file.get_error()
	file.close()
	if err != OK: return err
	# 校验 tmp
	if not read_one(temp).ok: return ERR_FILE_CORRUPT
	# 主路径已存在 → 备份(原地重命名)
	if FileAccess.file_exists(path):
		var copy_err := DirAccess.copy_absolute(path, path + ".bak.tmp")
		if copy_err != OK: return copy_err
		var ren_err := DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak")
		if ren_err != OK: return ren_err
	return DirAccess.rename_absolute(temp, path)
