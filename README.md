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


## 十五天 MVP（Trail2）

打开 `scenes/trail2.tscn`，按 **F6**。已贯通渔村、集市、旧学城、四类主结局、人物后日谈与自动存档。原有默认启动场景未变。

[玩法与验证路线](docs/trail2_mvp.md) · [开发步骤记录](docs/trail2_progress.md)

## trial1 六回合渔村

打开 `scenes/trial1.tscn`，按 **F6**。保留原人物卡、立绘、地图与对白操作，改为六天自由调查；支持公开传播、人物风险、材料交接、离村结算与独立存档。离村可继续四天集市与五天旧学城。

[操作说明与验证路线](docs/trial1_mvp.md) · [六回合规则](docs/design/渔村六回合设定_v0.3.md)

## 当前渔村到集市流程

`scenes/trial1.tscn` 的六天渔村已衔接四天集市。离村后选择“前往 / 继续集市”；玩法、代表路线和已实现范围见 [集市试玩说明](docs/market_chapter_mvp.md)。`scenes/market_chapter.tscn` 可独立试玩，默认不携带渔村成果。已有 Trail2 原型仍然独立。

## 当前五回合旧学城

集市结束后选择“前往 / 继续旧学城”，进入五天《海港篇》调查。已实现档案核对、三位人物、旧稿清理、分散讲读、公开质证、正式异议及前章成果承接。也可打开 `scenes/academy_chapter.tscn` 按 **F6** 独立试玩。详见 [学城玩法与验证路线](docs/academy_chapter_mvp.md)。羽之森与王城终局均已接入，Trail2 保持独立。

## 当前五回合羽之森

学城离城后选择“前往 / 继续羽之森”，或从地图进入。已实现观测台调查、高塔双入口、翅骨与修建记录取证、限时保全、安翼礼传播、可选飞行迹象、人物预警与前章帮助。新版使用独立v2存档，旧版进度保留。可打开 `scenes/forest_chapter.tscn` 按 **F6** 独立试玩。详见 [羽之森玩法与验证路线](docs/forest_chapter_mvp.md)。


## 王城六回合终章

羽之森结束后，通过“前往 / 继续王城”或地图进入。王城承接各地认知、证据、渠道与联系人风险，提供海回归、王国解放、新的王和遗忘重临四种结局。独立试玩打开 `scenes/royal_chapter.tscn` 按 **F6**。当前使用地图作为王城背景占位、姓名职业卡作为人物占位。

详见 [王城玩法、数值与验证路线](docs/royal_chapter_mvp.md)。

王城前区成果规则已更新：海回归需要渔村实证、羽之森证据核实及传播与前区海洋读者；学城责任链和集市组织分别开放两条解除执行路线。见 [最新完整流程验证](docs/campaign_routes_verification.md)。独立运行王城不带前区成果时，不能从零达成这些终局。
