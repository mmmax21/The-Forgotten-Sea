extends RefCounted
## 独立剧情存档；不与旧版十日规划的状态混用。
const MAX_AP := 3
const NAMES := {"home": "哑伯住处", "ruins": "遗迹"}
const TITLES := ["哑伯的指引", "寻找古老的船歌", "获取旧木板", "按照曲谱演奏", "获得造船图纸", "找到船骨", "请哑伯辨认", "谁愿意记得"]
var day := 1
var ap := MAX_AP
var location := "home"
var stage := 0
var inventory: Array = []
var support := 0
## 地区支持度与全局警戒值。算法在 region_stance.gd，不替代上面的哑伯支持度。
var stance := {}
var pending := ""
var choice := ""
var history: Array = []

func expected_action() -> String:
	return ["guide", "song", "plank", "perform", "blueprint", "investigate", "verify", "fisher", "choice", "done"][stage]

func can_begin(id: String) -> bool:
	if not pending.is_empty() or id != expected_action() or stage >= 8:
		return false
	var target := "ruins" if id in ["song", "investigate"] else "home"
	return location == target and (id == "song" or ap >= 1)

func begin(id: String) -> bool:
	if not can_begin(id):
		return false
	pending = id
	return true

func finish() -> Dictionary:
	if pending.is_empty() or pending != expected_action():
		return {}
	var id := pending
	var reward := ""
	if id != "song":
		ap -= 1
	match id:
		"song": reward = "古老的船歌"
		"plank": reward = "旧木板"
		"blueprint": reward = "造船图纸"
		"perform": support += 10
	if not reward.is_empty() and not inventory.has(reward):
		inventory.append(reward)
	history.append(TITLES[stage])
	stage += 1
	pending = ""
	return {"id": id, "item": reward}

func can_move(target: String) -> bool:
	return pending.is_empty() and stage >= 1 and ap >= 1 and NAMES.has(target) and target != location

func move_to(target: String) -> bool:
	if not can_move(target):
		return false
	ap -= 1
	location = target
	return true

func next_day() -> bool:
	if not pending.is_empty():
		return false
	day += 1
	ap = MAX_AP
	return true

func choose(value: String) -> bool:
	if stage != 8 or value not in ["private", "protect", "later"]:
		return false
	if value == "later":
		return true
	choice = value
	stage = 9
	history.append("私下求证" if value == "private" else "保护家人")
	return true

func objective() -> String:
	match stage:
		0: return "与哑伯交谈，了解他手中的旧木板。"
		1: return "前往遗迹，寻找哑伯指向的线索。"
		2: return "将古老的船歌带回哑伯住处。"
		3: return "对照船歌与木板上的刻痕，按照曲谱演奏。"
		4: return "询问哑伯关于船的构造。"
		5: return "石拱下的船骨：重返遗迹，对照图纸调查。"
		6: return "返回住处，请哑伯辨认船骨的接缝。"
		7, 8: return "询问老渔夫，船歌是否曾在村里传唱。"
		_: return "已得到私下线索；下一步寻找更多航行记忆。" if choice == "private" else "已了解老渔夫的顾虑；下一步寻找保护孙子的办法。"

func save_to(path: String) -> Error:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": 1, "day": day, "ap": ap, "location": location, "stage": stage, "inventory": inventory, "support": support, "pending": pending, "choice": choice, "history": history, "stance": stance}))
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path)

func load_from(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or value.get("version") != 1:
		return false
	if not NAMES.has(str(value.get("location", ""))) or not value.get("inventory") is Array or not value.get("history") is Array:
		return false
	day = maxi(1, int(value.get("day", 1)))
	ap = clampi(int(value.get("ap", MAX_AP)), 0, MAX_AP)
	location = str(value.location)
	stage = clampi(int(value.get("stage", 0)), 0, 9)
	inventory = value.inventory
	support = int(value.get("support", 0))
	var raw_stance = value.get("stance", {})
	stance = raw_stance if raw_stance is Dictionary else {}
	choice = str(value.get("choice", ""))
	history = value.history
	pending = str(value.get("pending", ""))
	if pending != expected_action() or stage >= 8:
		pending = ""
	return true
