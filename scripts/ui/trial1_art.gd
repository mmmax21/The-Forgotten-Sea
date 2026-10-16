extends RefCounted
## Supplied location art. Previewing a location does not move the story.
const BACKGROUNDS := {
 "fishing_village": preload("res://assets/ui/map_modal/区域场景交付 2/渔村.png"),
 "market": preload("res://assets/ui/map_modal/区域场景交付 2/集市.png"),
 "old_academy": preload("res://assets/ui/map_modal/区域场景交付 2/老学城.png"),
 "ruins": preload("res://assets/ui/map_modal/区域场景交付 2/遗迹.png"),
 "feather_forest": preload("res://assets/ui/map_modal/区域场景交付 2/羽之森.png"),
}
const REGION_IDS := ["fishing_village", "market", "old_academy"]
const PLACE_NAMES := {"fishing_village": "渔村", "market": "集市", "old_academy": "旧学城", "ruins": "遗迹", "feather_forest": "羽之森"}
