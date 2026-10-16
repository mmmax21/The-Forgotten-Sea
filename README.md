# 被遗忘的海

使用 Godot 4 打开 `project.godot`，按 F5 启动 `scenes/ui/component_gallery.tscn`。点击哑伯开始渔村—遗迹剧情。

## 文件入口

- 场景：`scenes/ui/component_gallery.tscn`
- 界面与剧情调度：`scripts/ui/component_gallery.gd`
- 剧情状态、行动点与存档：`scripts/story/ruins_state.gd`
- 剧情对白与物品图像配置：`data/story/ya_bo.json`
- 回归测试：`tests/ruins_story_tests.gd`

[完整依赖清单](docs/component_gallery_files.md)列出当前入口使用的全部场景、脚本和资源。修改玩法与对白时，先从上面的文件入手。

## 说明

- [运行与测试](docs/ruins_runtime.md)
- [界面组件](docs/ui_components.md)
- [哑伯剧情配置](docs/ya_bo_story.md)
- [遗迹剧情设计](docs/ruins_story_design.md)

当前项目仅保留此入口使用的运行文件，以及相关测试、截图、设计资料和开发日志。Godot 的 `.import`、`.uid` 用于资源导入与标识；`.godot/` 是自动生成的本机缓存。
