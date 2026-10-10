extends RefCounted
## 默认四人横图。原图 1024×242，人与人之间有一条黑线，切的时候把黑线和旁边的暗边去掉。
## 顺序从左到右：老渔夫、盐嫂、螺螺、哑伯。以后换别的人像时，调用方自己传 portrait。

const SHEET := preload("res://assets/portraits/default_characters.png")

const REGIONS: Array[Rect2] = [
	Rect2(0, 0, 259, 242),
	Rect2(263, 0, 245, 242),
	Rect2(511, 0, 244, 242),
	Rect2(758, 0, 265, 242),
]


static func portrait(index: int) -> AtlasTexture:
	var region: Rect2 = REGIONS[clampi(index, 0, REGIONS.size() - 1)]
	var atlas := AtlasTexture.new()
	atlas.atlas = SHEET
	atlas.region = region
	return atlas
