extends Control
## 组件预览。F6 运行本场景，不改主场景。

const DefaultCharacters := preload("res://scripts/ui/character_card/default_characters.gd")


func _ready() -> void:
	%CharacterRail.configure(_people())
	%TopBar.action_pressed.connect(_open_default_notice)


## 画廊临时入口。四个按钮都打开同一条通知，以后按 id 拆开。
func _open_default_notice(_id: String) -> void:
	%Notice.apply_engine({
		"title": "潮汐将至",
		"image": DefaultCharacters.portrait(0),
		"text": "北面的网已经收起。今天先不要出镇。",
	})
	%Notice.open()


func _people() -> Array:
	return [
		{
			"name": "老渔夫",
			"portrait": DefaultCharacters.portrait(0),
			"summary": "镇上的老渔夫，小时候见过海，也记得潮汐歌。父亲因公开说海存在被处决，所以他不敢再提。他想把记忆留下来，却害怕连累孙子。若不能先保证孙子安全，他只肯私下透露片段，不愿公开作证，更不会跟着去传播。",
			"disabled": false,
			"visible": true,
		},
		{
			"name": "盐嫂",
			"portrait": DefaultCharacters.portrait(1),
			"summary": "丈夫因调查海被处决。她恨王权，也怕自己再没有活路。这条是置灰示例，悬停不会弹出介绍。",
			"disabled": true,
			"visible": true,
		},
		{
			"name": "螺螺",
			"portrait": DefaultCharacters.portrait(2),
			"summary": "十二岁，捡到一枚贝壳，不相信大人说的「海不存在」。胆子大，也最容易被牵连。",
			"disabled": false,
			"visible": true,
		},
		{
			"name": "哑伯",
			"portrait": DefaultCharacters.portrait(3),
			"summary": "年老的船匠，不能说话，双手受过重伤。他把船体和航线刻在木头上。",
			"disabled": false,
			"visible": true,
		},
	]
