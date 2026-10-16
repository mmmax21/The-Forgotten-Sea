# Component Gallery 文件依赖清单

从 `scenes/ui/component_gallery.tscn` 递归追踪场景、脚本、资源以及剧情 JSON 中的路径，共 50 个运行文件。包括场景内保留的隐藏节点资源和脚本默认预览资源。

## 场景（13 个）

- [`scenes/ui/character_card/character_card.tscn`](../scenes/ui/character_card/character_card.tscn)
- [`scenes/ui/character_card/character_rail.tscn`](../scenes/ui/character_card/character_rail.tscn)
- [`scenes/ui/component_gallery.tscn`](../scenes/ui/component_gallery.tscn)
- [`scenes/ui/dialogue_box/dialogue_box.tscn`](../scenes/ui/dialogue_box/dialogue_box.tscn)
- [`scenes/ui/mini_map/mini_map.tscn`](../scenes/ui/mini_map/mini_map.tscn)
- [`scenes/ui/popup/location_label.tscn`](../scenes/ui/popup/location_label.tscn)
- [`scenes/ui/popup/map_modal.tscn`](../scenes/ui/popup/map_modal.tscn)
- [`scenes/ui/popup/notice.tscn`](../scenes/ui/popup/notice.tscn)
- [`scenes/ui/portrait_panel/portrait_panel.tscn`](../scenes/ui/portrait_panel/portrait_panel.tscn)
- [`scenes/ui/top_bar/action_button.tscn`](../scenes/ui/top_bar/action_button.tscn)
- [`scenes/ui/top_bar/day_badge.tscn`](../scenes/ui/top_bar/day_badge.tscn)
- [`scenes/ui/top_bar/stat_readout.tscn`](../scenes/ui/top_bar/stat_readout.tscn)
- [`scenes/ui/top_bar/top_bar.tscn`](../scenes/ui/top_bar/top_bar.tscn)

## 脚本（19 个）

- [`scripts/story/ruins_state.gd`](../scripts/story/ruins_state.gd)
- [`scripts/ui/character_card/character_card.gd`](../scripts/ui/character_card/character_card.gd)
- [`scripts/ui/character_card/character_rail.gd`](../scripts/ui/character_card/character_rail.gd)
- [`scripts/ui/character_card/default_characters.gd`](../scripts/ui/character_card/default_characters.gd)
- [`scripts/ui/component_gallery.gd`](../scripts/ui/component_gallery.gd)
- [`scripts/ui/dialogue_box/dialogue_box.gd`](../scripts/ui/dialogue_box/dialogue_box.gd)
- [`scripts/ui/mini_map/mini_map.gd`](../scripts/ui/mini_map/mini_map.gd)
- [`scripts/ui/mini_map/round_button.gd`](../scripts/ui/mini_map/round_button.gd)
- [`scripts/ui/popup/location_cover.gd`](../scripts/ui/popup/location_cover.gd)
- [`scripts/ui/popup/location_hit.gd`](../scripts/ui/popup/location_hit.gd)
- [`scripts/ui/popup/location_label.gd`](../scripts/ui/popup/location_label.gd)
- [`scripts/ui/popup/map_modal.gd`](../scripts/ui/popup/map_modal.gd)
- [`scripts/ui/popup/notice.gd`](../scripts/ui/popup/notice.gd)
- [`scripts/ui/portrait_panel/portrait_panel.gd`](../scripts/ui/portrait_panel/portrait_panel.gd)
- [`scripts/ui/story_modal.gd`](../scripts/ui/story_modal.gd)
- [`scripts/ui/top_bar/action_button.gd`](../scripts/ui/top_bar/action_button.gd)
- [`scripts/ui/top_bar/day_badge.gd`](../scripts/ui/top_bar/day_badge.gd)
- [`scripts/ui/top_bar/stat_readout.gd`](../scripts/ui/top_bar/stat_readout.gd)
- [`scripts/ui/top_bar/top_bar.gd`](../scripts/ui/top_bar/top_bar.gd)

## 剧情数据（1 个）

- [`data/story/ya_bo.json`](../data/story/ya_bo.json)

## 图片与纹理资源（17 个）

- [`assets/Icons.png`](../assets/Icons.png)
- [`assets/backgrounds/ruins-v1.png`](../assets/backgrounds/ruins-v1.png)
- [`assets/icons_4panel.jpg`](../assets/icons_4panel.jpg)
- [`assets/items/ancient_song.tres`](../assets/items/ancient_song.tres)
- [`assets/items/old_plank.tres`](../assets/items/old_plank.tres)
- [`assets/items/ship_blueprint.tres`](../assets/items/ship_blueprint.tres)
- [`assets/portraits/charaterwholebody.png`](../assets/portraits/charaterwholebody.png)
- [`assets/portraits/default_characters.png`](../assets/portraits/default_characters.png)
- [`assets/ui/character_card/card_frame.png`](../assets/ui/character_card/card_frame.png)
- [`assets/ui/map_modal/map_background.png`](../assets/ui/map_modal/map_background.png)
- [`assets/ui/map_modal/map_with_ocean.png`](../assets/ui/map_modal/map_with_ocean.png)
- [`assets/ui/map_modal/map_without_ocean.png`](../assets/ui/map_modal/map_without_ocean.png)
- [`assets/ui/popup/notice_background.png`](../assets/ui/popup/notice_background.png)
- [`assets/ui/top_bar/button_states.png`](../assets/ui/top_bar/button_states.png)
- [`assets/ui/top_bar/day_badge.png`](../assets/ui/top_bar/day_badge.png)
- [`assets/ui/top_bar/rows_texture.png`](../assets/ui/top_bar/rows_texture.png)
- [`assets/ui/top_bar/stat_bar_texture.png`](../assets/ui/top_bar/stat_bar_texture.png)

## 配套文件

- `project.godot`：项目配置与启动入口。
- 对应 `.uid`、`.import`：资源标识和导入配置。
- `tests/ruins_story_tests.gd`：当前剧情回归测试。
- `docs/`、`README.md`：当前入口的结构、操作和剧情说明。
- `previews/ruins-*`、`previews/dialogue-layout-*`：当前剧情与对话布局截图。
- 人物设定、当前开发日志与遗迹背景提示词：相关设计资料，不参与运行。
- `.git/`、`.gitignore`、`.claude/`：版本管理与本地工具配置。
- `.godot/`：Godot 自动生成的本机缓存，不属于运行源码。
