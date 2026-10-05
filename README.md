# 涌现 · 每日行动工作台

## 当前阶段

阶段 1：在原 Godot 主窗口上改造布局与基础导航。沿用 Godot 4、GDScript、Compatibility 渲染器、原主场景入口及回合状态。

已实现顶部信息栏、三张法则牌、主体三栏、固定底部操作区，以及默认隐藏的 DEBUG 面板。中央大日期和正式界面的 30 节点进度条已移除。人物、地点与线索可选择并联动右侧详情；手记、菜单、法则按钮有弹窗反馈。点击空白不移动、不推进日期。

设计尺寸为 1920×1080，最小窗口为 1280×720。通过 Control 与 Container 自动排布，中央填充剩余宽度；两侧在窄窗口使用 220/320 的参考宽度，宽窗口使用 240/340。左右栏可以局部滚动，底部操作区不参与滚动。没有整页滚动或手工逐点摆放的地图坐标。

## 打开与检查

1. 用 Godot 4 导入本目录的 `project.godot`。
2. 按 **F5** 运行；本机验证版本为 Godot 4.7.2 标准版，无需 .NET。
3. 点击左侧人物、中央地点或标记，确认右侧内容切换。同一个人物在列表和地图上的选中状态同步。
4. 点击法则查看完整名称，悬停也会显示全文。手记和菜单打开占位面板；可点击“返回”、关闭窗口或按 Esc 返回。
5. 缩小窗口至 1280×720，检查顶部导航、三张法则牌与底部操作区仍可见。滚动人物或详情只影响本栏。
6. 按 **F3**（部分 Mac 键盘需要 **fn + F3**）打开/关闭 DEBUG。这里保留旧版“后一天”“下个时间节点”和“时间进度”；DEBUG 推进会改变当前运行状态。F3 本身不改变日期。
7. DEBUG 中跳天仍有确认弹窗；取消、关闭与 Esc 保持状态。第 10 天禁用跳天；第 10 天晚上再推进一次才结算；重新开始恢复第 1 天上午。

命令行运行：

```sh
godot --path /path/to/taptap
```

本机：

```sh
"/Users/maxlou/Downloads/Godot.app/Contents/MacOS/Godot" --path "/Users/maxlou/Documents/ChatGPT/taptap"
```

## 文件与职责

| 文件 | 职责 |
| --- | --- |
| `project.godot` | 原项目入口；初始 1920×1080、最小 1280×720，以容器响应窗口尺寸 |
| `scenes/main.tscn` | 原主场景；工作台五区布局、主题、弹窗和原结算界面 |
| `scripts/main.gd` | 绑定真实日期、旧回合信号；DEBUG 导航；原结算与重新开始 |
| `scripts/ui/workbench.gd` | 纯 UI 选择、详情、弹窗、响应式调整；不修改游戏状态 |
| `scripts/game_state.gd` | 原统一状态与回合规则；本阶段没有改动 |
| `preview_data/workbench.json` | 独立且可替换的导航预览配置，明确标记 `preview_only` |
| `tests/run_tests.gd` | 原回合回归测试及布局、真实鼠标导航、缩放测试 |
| `tests/stage1-validation.txt` | 本阶段两种尺寸的引擎验证日志 |
| `previews/stage1-*.png` | 本阶段实际引擎渲染截图，文件名含尺寸 |

场景结构：

```text
Main (Control，原入口)
├── GameScreen (MarginContainer + workbench.gd)
│   └── Layout (VBoxContainer)
│       ├── TopBar (HBoxContainer)：日期、阶段、地区、警戒、手记、菜单
│       ├── LawBar (HBoxContainer)：三个法则按钮
│       ├── Body (HBoxContainer)
│       │   ├── LeftPanel：目标、人物列表、局部 ScrollContainer
│       │   ├── CenterPanel：场景占位、地点 GridContainer、人物与线索标记
│       │   └── RightPanel：目标详情、行动配置、局部 ScrollContainer
│       └── BottomPanel：思想卡占位、三个行动槽、AP、结束今日行动
├── SettlementScreen：原结算与重新开始
├── InfoDialog (AcceptDialog)：法则、手记、菜单
└── DebugPanel (AcceptDialog，默认隐藏)
    ├── Content：旧时间、进度、跳天与推进按钮
    └── SkipDialog (ConfirmationDialog)：原跳天确认
```

## 数据边界与占位

- **真实状态**：日期与原时间节点仍来自唯一的 `GameState`。上午/下午仅在顶部显示为“白天规划”，晚上显示为“夜间结算”；这是显示映射，并没有启用新阶段流程或夜间演算。
- **无存档修改**：现有工程未实现存档系统。本阶段不新增存档，不写入日期，也不把界面预览数据加入状态或结算。
- **预览配置**：目标、潮叔等人物、古代遗迹/石渠/镇口和刻痕都是 `preview_data/workbench.json` 中的导航示例，界面明确标明预览。它们不代表已经相识、已经发现或每局必然发生的剧情；未设置石渠涨退事件。
- **地区与警戒**：现有状态没有这些数据，因此显示“未载入/未接入”，不伪造正式数值。
- **AP 与思想卡**：显示 `剩余 AP — / 3` 和空卡牌状态。行动系统未接入，四种行为、个人/群体规模、加入行动槽和结束今日行动明确禁用。
- **人物关系**：信任、思想信念、合作意愿分别展示为未接入，不使用单一好感代替三者。
- 没有新增成功率、信念公式、移动费用、按日期解锁群体或 NPC 隐藏条件；没有新增传播/组织/救助基础行为，也没有国王动机的剧透。
- 没有实现完整夜间演算、剧情、复杂动画、经济、背包或额外地区内容。

## 自动验证

无图形测试：

```sh
godot --headless --path /path/to/taptap --script res://tests/run_tests.gd -- --small
```

图形测试与截图（需要图形桌面）：

```sh
godot --path /path/to/taptap --script res://tests/run_tests.gd -- --capture
godot --path /path/to/taptap --script res://tests/run_tests.gd -- --small --capture
```

两组图形测试均覆盖：原 30 节点状态推进、每个节点跳天、模态取消/关闭/Esc、最后一天、最终结算和重开；工作台鼠标选择、禁用按钮、空白点击、手记/菜单/法则、详情滚动、F3；1920×1080 与 1280×720 之间实时缩放时区域仍在窗口内且状态保持。

本次两组图形测试各 **273 项检查、0 失败**，实际查看了两种尺寸的主界面、人物详情与 DEBUG 截图。本机 macOS / Godot 4.7.2 验证，其他操作系统和 Godot 版本尚未实际运行。中文依赖系统已有的中文字体，无外部美术素材。

## 版本与回退

- `v0.1`：原基础回合界面，标签保持不变。
- 本次改造前的提交 `79c6b13` 包含新增 NPC PDF。
- 阶段 1 在 `codex/workbench-layout` 分支完成；后续每阶段保留独立提交。
- 要恢复时可要求“恢复到 v0.1，并保留当前新版”。恢复前先保存新版，再从旧版创建分支。
- `taptap-v0.1.zip` 保留旧版，`taptap-stage1.zip` 为本阶段独立包。`.godot` 为可重新生成的缓存，不纳入 Git 或分发包。
