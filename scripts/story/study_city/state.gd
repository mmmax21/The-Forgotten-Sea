extends RefCounted
## 旧学城章节状态机。规则集 study_city_v1。
## 复用 trail2 的 trust/alert/informed/exposed/reported/warning_day 概念,
## 但完全独立实现。所有数值与事件流都不依赖 trail2 文件。
##
## 章节长度 5 天,每天 3 AP。
## 三 NPC:墨先生(mo)、二笔(er)、高帽子(gao)。
## 四类主张:P1(海洋踪迹不止渔村)、P2(海洋信息被针对性限制)、
##         P3(同批制度删改已追溯)、P4(跨日观测 + 历史资料 + 异域传播)。
##
## 末日事件:第 4 天末馆藏清理,旧版本与执行记录被销毁,玩家需在此前保全。

const VERSION := 1
const RULESET := "study_city_v1"
const TOTAL_DAYS := 5

## NPC 配置
const NAMES := {"mo": "墨先生", "er": "二笔", "gao": "高帽子"}
const NPC_IDS := ["mo", "er", "gao"]

## 初始 NPC 状态模板(每个新 State 实例都会从这深拷贝)
const INITIAL_NPCS := {
	"mo": {"t": 45, "a": 30, "informed": false, "warning_day": 0, "reported": false, "exposed": false},
	"er": {"t": 40, "a": 25, "informed": false, "warning_day": 0, "reported": false, "exposed": false},
	"gao": {"t": 35, "a": 35, "informed": false, "warning_day": 0, "reported": false, "exposed": false},
}

## 关键主张
const CLAIMS := ["P1", "P2", "P3", "P4"]

# ─── 实例字段 ───────────────────────────────────────────

# 三 NPC 当前状态(每个值是 dict):
#   t: int 信任 [0,100]
#   a: int 警戒 [0,100]
#   informed: bool 已知道调查
#   warning_day: int 0=无;>0 表示"当地第 N 天末复查"
#   reported: bool (永久)已告密
#   exposed: bool (永久)身份已曝光
var people: Dictionary = {}

# 物品账本:key -> {name, source, kind, holder, confirmed}
#   kind: "original" / "record" / "museum"
#   holder: "player" / "mo" / "er" / "gao"
#   confirmed: 玩家是否已确认有效
var inventory: Dictionary = {}

# 主张 / 验证标志
var flags: Dictionary = {}        # 例:flags.P3_versions = true
var claims: Dictionary = {}       # 例:claims.P3 = true

# 已知地点
var locations: Dictionary = {}    # 例:locations.versions = true 表示玩家知道旧版本馆藏位置

# 末日事件
var archive_destroyed := false
var archive_warning_day := 0

# 当前状态
var day := 1
var ap := 3
var spent := 0
var food := 0
var selected := ""
var finished := false
var presentation: Dictionary = {}

# 调试用:可注入的起点物品
var evidence_seed: Dictionary = {}


# ─── 构造 / 重置 ───────────────────────────────────────

func _init() -> void:
	reset()


func reset() -> void:
	people = INITIAL_NPCS.duplicate(true)
	inventory = {}
	flags = {}
	claims = {}
	locations = {}
	archive_destroyed = false
	archive_warning_day = 0
	day = 1
	ap = 3
	spent = 0
	selected = ""
	finished = false
	presentation = {}
	_setup_demo_seeds()


func _setup_demo_seeds() -> void:
	# 玩家自带渔村手记副本 + 一个未确认的港城文物。
	# 这样学城可以独立试玩,不需要前置章节。
	if not inventory.is_empty():
		return
	inventory["demo_reliquary"] = {
		"name": "前任村民手记(副本)",
		"source": "husband_relic",
		"kind": "record",
		"confirmed": true,
		"holder": "player",
	}
	inventory["demo_antique"] = {
		"name": "港城出土古物铜牌",
		"source": "antique_port",
		"kind": "original",
		"confirmed": false,    # 玩家还需去验证这个是不是真品
		"holder": "player",
	}


# ─── NPC 状态判定 ──────────────────────────────────────

func cooperative(who: String) -> bool:
	var p: Dictionary = people[who]
	return p.informed and p.t >= 60 and p.a < 60 and not p.exposed and not p.reported


func at_risk(who: String) -> bool:
	var p: Dictionary = people[who]
	return p.informed and p.t < 60 and p.a >= 60 and not p.reported


func status(who: String) -> String:
	var p: Dictionary = people[who]
	if p.reported: return "已告密,不再合作"
	if p.exposed: return "身份已曝光"
	if p.warning_day > 0:
		return "告密预警 · 第%d天末复查" % p.warning_day
	if p.informed and p.t >= 60 and p.a >= 60:
		return "相信你但这次不敢承担"
	if p.informed and p.t >= 60 and p.a < 60:
		return "愿意合作"
	if p.informed and p.t < 60 and p.a >= 60:
		return "害怕受牵连"
	if not p.informed:
		return "尚未知情"
	return "陪你观望"


# ─── 物品 / 证据 ───────────────────────────────────────

func owned(key: String) -> bool:
	return inventory.has(key) and inventory[key].get("holder", "player") == "player"


func source_of(key: String) -> String:
	if not inventory.has(key): return ""
	var item: Dictionary = inventory[key]
	return item.get("source", "")


func sources_held() -> Array:
	# 原物才计独立来源。记录 / 副本不算。
	var result: Array = []
	for key in inventory:
		var item: Dictionary = inventory[key]
		if item.get("holder", "player") != "player": continue
		if item.get("kind", "original") != "original": continue
		var src: String = source_of(key)
		if not result.has(src) and not src.is_empty():
			result.append(src)
	return result


func has_claim(p: String) -> bool:
	return claims.has(p) and bool(claims[p])


func has_flag(name: String) -> bool:
	return flags.has(name) and bool(flags[name])


# ─── 通用 ───────────────────────────────────────────────

func busy() -> bool:
	return not presentation.is_empty() or finished


# ─── 序列化 / 反序列化 ─────────────────────────────────

func to_data() -> Dictionary:
	return {
		"version": VERSION,
		"ruleset": RULESET,
		"day": day,
		"ap": ap,
		"spent": spent,
		"selected": selected,
		"finished": finished,
		"presentation": presentation.duplicate(true),
		"people": people.duplicate(true),
		"inventory": inventory.duplicate(true),
		"flags": flags.duplicate(true),
		"claims": claims.duplicate(true),
		"locations": locations.duplicate(true),
		"archive_destroyed": archive_destroyed,
		"archive_warning_day": archive_warning_day,
	}


func restore(data: Dictionary) -> bool:
	if data.get("ruleset") != RULESET or int(data.get("version", 0)) != VERSION:
		return false
	if not data.has("people") or not data.has("inventory"):
		return false
	day = int(data.day)
	ap = int(data.ap)
	spent = int(data.spent)
	selected = str(data.selected)
	finished = bool(data.finished)
	presentation = data.presentation.duplicate(true) if data.has("presentation") else {}
	people = data.people.duplicate(true)
	inventory = data.inventory.duplicate(true)
	flags = data.flags.duplicate(true) if data.has("flags") else {}
	claims = data.claims.duplicate(true) if data.has("claims") else {}
	locations = data.locations.duplicate(true) if data.has("locations") else {}
	archive_destroyed = bool(data.archive_destroyed)
	archive_warning_day = int(data.archive_warning_day)
	return true
