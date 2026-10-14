# 当前界面组件

入口为 `scenes/ui/component_gallery.tscn`。`scripts/ui/component_gallery.gd` 负责连接组件信号、推进剧情、加载存档、刷新任务和行动按钮。设计尺寸为 1920×1032，随窗口等比缩放居中。

| 组件 | 场景 | 作用 |
| --- | --- | --- |
| 顶栏 | `scenes/ui/top_bar/top_bar.tscn` | 日期、AP，任务、物品、状态与设置入口 |
| 人物栏 | `scenes/ui/character_card/character_rail.tscn` | 人物卡选择；卡片来自 `character_card.tscn` |
| 立绘 | `scenes/ui/portrait_panel/portrait_panel.tscn` | 显示当前人物 |
| 对话框 | `scenes/ui/dialogue_box/dialogue_box.tscn` | 逐段显示台词，发出对话完成信号 |
| 小地图按钮 | `scenes/ui/mini_map/mini_map.tscn` | 打开地图、物品与结束今日行动 |
| 地图弹窗 | `scenes/ui/popup/map_modal.tscn` | 展示地图与地点，选择后交由入口处理移动 |
| 地点标签 | `scenes/ui/popup/location_label.tscn` | 地图地点文字，与点击区域和遮盖脚本配合 |
| 通知 | `scenes/ui/popup/notice.tscn` | 场景内保留的可配置通知组件 |

`story_modal.gd` 在运行时创建通用弹窗，用于移动确认、物品、任务、状态和剧情选项。`ruins_state.gd` 管理行动点、进度、背包与保存恢复。`data/story/ya_bo.json` 提供台词及物品图像路径。

完整文件列表见 [依赖清单](component_gallery_files.md)，操作与测试见 [运行说明](ruins_runtime.md)。
