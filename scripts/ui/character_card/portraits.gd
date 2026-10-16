extends RefCounted
## 立绘登记。新人物加一个 id 和一张贴图。
## 场景一只排哑伯、盐嫂、螺螺。旧的四人横图仍由 default_characters.gd 管。

const YABO := preload("res://assets/portraits/yabo.png")
const YANSAO := preload("res://assets/portraits/yansao.png")
const LUOLUO := preload("res://assets/portraits/luoluo.png")
const AXIANG := preload("res://assets/portraits/axiang.png")
const ERBI := preload("res://assets/portraits/erbi.png")
const GAOMAOZI := preload("res://assets/portraits/gaomaozi.png")
const MOXIANSHENG := preload("res://assets/portraits/moxiansheng.png")
const QIANBO := preload("res://assets/portraits/qianbo.png")
const DAOLANG := preload("res://assets/portraits/daolang.png")

const SCENE1: PackedStringArray = ["yabo", "yansao", "luoluo"]
## 阿香、二笔、高帽子、墨先生、钱伯、刀郎。
const LATER: PackedStringArray = ["axiang", "erbi", "gaomaozi", "moxiansheng", "qianbo", "daolang"]


static func texture(id: String) -> Texture2D:
	match id:
		"yabo":
			return YABO
		"yansao":
			return YANSAO
		"luoluo":
			return LUOLUO
		"axiang":
			return AXIANG
		"erbi":
			return ERBI
		"gaomaozi":
			return GAOMAOZI
		"moxiansheng":
			return MOXIANSHENG
		"qianbo":
			return QIANBO
		"daolang":
			return DAOLANG
		_:
			return null


static func display_name(id: String) -> String:
	match id:
		"yabo":
			return "哑伯"
		"yansao":
			return "盐嫂"
		"luoluo":
			return "螺螺"
		"axiang":
			return "阿香"
		"erbi":
			return "二笔"
		"gaomaozi":
			return "高帽子"
		"moxiansheng":
			return "墨先生"
		"qianbo":
			return "钱伯"
		"daolang":
			return "刀郎"
		_:
			return ""
