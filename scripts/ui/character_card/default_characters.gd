extends RefCounted
## 默认四人横图。原图 1024×242，人与人之间有一条黑线，切的时候把黑线和旁边的暗边去掉。
## 顺序从左到右：老渔夫、盐嫂、螺螺、哑伯。以后换别的人像时，调用方自己传 portrait。

const SHEET := preload("res://assets/portraits/default_characters.png")
## 全身立绘：原图 1536×1024，四等分；宽 384 高 1024。
const WHOLEBODY_SHEET := preload("res://assets/portraits/charaterwholebody.png")
const WHOLEBODY_REGION_SIZE := Vector2(384, 1024)

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


## 全身立绘（右侧对话用）。原图 1536×1024，第 i 个角色从 x = i*384 取 384×1024。
static func wholebody(index: int) -> AtlasTexture:
	var i := clampi(index, 0, 3)
	var atlas := AtlasTexture.new()
	atlas.atlas = WHOLEBODY_SHEET
	atlas.region = Rect2(i * WHOLEBODY_REGION_SIZE.x, 0, WHOLEBODY_REGION_SIZE.x, WHOLEBODY_REGION_SIZE.y)
	return atlas
