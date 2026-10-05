# 十天回合界面

## 版本管理

当前项目已建立独立的本地 Git 仓库，基线标签为 `v0.1`，日常分支为 `codex/main`。该标签保存本次游戏源码、场景、项目设置、测试、预览和当前人物设定文档；引擎缓存与生成的压缩包不纳入 Git。

后续修改前先保存当前工作，每个完成且可运行的版本单独提交。保留 `v0.1` 标签，不移动或覆盖。需要回到旧版时，可以直接要求“恢复到 v0.1，并保留当前新版”；恢复前先保存新版，再从旧版创建分支，避免丢失后续工作。

独立压缩备份为 `taptap-v0.1.zip`。如需立即查看旧版，可解压到另一个文件夹，在 Godot 中导入其中的 `project.godot`。本地 Git 和同盘压缩包可防止改动难以撤销；防范磁盘损坏还需将备份复制到其他磁盘或云盘。

完整 Godot 4 / GDScript 项目。采用 Godot 默认控件风格与系统中文字体，没有外部美术素材、插件或第三方代码依赖。初始窗口与设计分辨率为 1920×1080，最小窗口为 960×540，使用 `canvas_items` 随窗口缩放。

## 打开和运行

1. 启动 Godot 4（本项目在本机 Godot 4.7.2 标准版验证）。
2. 在项目管理器中选择“导入”，选中本目录的 `project.godot`。
3. 打开项目后按 **F5**，或点击右上角“运行项目”。主场景已配置。
4. 初始显示第 1 天上午、时间进度 1 / 30。无需安装 .NET，也无需下载素材。

命令行运行（将 `godot` 换成自己的 Godot 可执行文件路径）：

```sh
godot --path /path/to/taptap
```

本机也可以使用：

```sh
"/Users/maxlou/Downloads/Godot.app/Contents/MacOS/Godot" --path "/Users/maxlou/Documents/ChatGPT/taptap"
```

## 文件

```text
project.godot             项目设置及主场景入口
scenes/main.tscn          可在编辑器中直接查看、编辑的完整 UI 场景
scripts/game_state.gd    统一状态与所有回合规则
scripts/main.gd          按钮事件、弹窗与显示同步
tests/run_tests.gd       状态与场景集成测试
tests/validation.txt     本次实际运行的验证日志
previews/               引擎实际渲染的四张 1920×1080 截图
README.md               本说明
```

`.godot` 是本机导入缓存，不需要分发；解压项目后引擎会自动重新生成。

## 场景结构

```text
Main (Control) → scripts/main.gd
├── GameScreen (MarginContainer)
│   └── Layout (VBoxContainer)
│       ├── Title (Label)
│       ├── Separator (HSeparator)
│       ├── Content (CenterContainer，纵向扩展)
│       │   └── Status (VBoxContainer)
│       │       ├── DayLabel (Label)
│       │       ├── TimeLabel (Label)
│       │       ├── Sequence (Label)
│       │       ├── Spacer (Control)
│       │       ├── ProgressLabel (Label)
│       │       └── TimeProgress (ProgressBar)
│       └── Footer (VBoxContainer)
│           ├── LastDayHint (Label)
│           └── Buttons (HBoxContainer)
│               ├── SkipButton (Button：后一天)
│               └── NextButton (Button：下个时间节点)
├── SettlementScreen (CenterContainer，初始隐藏)
│   └── Layout (VBoxContainer)
│       ├── Title (Label：游戏结束)
│       ├── Description (Label：已完成全部 10 天)
│       └── RestartButton (Button：重新开始)
└── SkipDialog (ConfirmationDialog，原生模态弹窗)
```

结算通过切换同一场景内的两个界面实现。确认和取消按钮由 `ConfirmationDialog` 自带，无需另外创建节点。

## 统一状态与更新方式

`game_state.gd` 只保存 `_position`（0～29）与 `_finished`。天数、节点、进度由同一位置派生：

- 天数：`floor(_position / 3) + 1`
- 节点：`_position % 3`，依次对应上午、下午、晚上
- 进度：`_position + 1`，进度条最大值为 30

两个主按钮调用同一个状态对象的 `advance()` 或 `skip_day()`，没有各自的天数变量。每次状态改变发出 `changed` 信号，由 `_refresh()` 同步更新天数、时间、进度、界面及按钮。弹窗可见性变化也会更新按钮。

进入位置 29 时仍是第 10 天晚上，显示 30 / 30；只有在该位置再次调用 `advance()` 才设置结束标志，位置永远不会增加到第 11 天。`restart()` 重置位置和结束标志。

弹窗仅在确认时调用 `skip_day()`。取消、关闭与 Esc 使用原生取消路径，不修改游戏状态。弹窗为 `exclusive`，打开时两个主按钮都会禁用，按钮处理函数也检查弹窗是否可见。第 10 天另外显示“已是最后一天”，并禁用跳天。

## 验证

运行自动测试：

```sh
godot --headless --path /path/to/taptap --script res://tests/run_tests.gd
```

同时验证图形渲染并生成预览（需要图形桌面，不要加 `--headless`）：

```sh
godot --path /path/to/taptap --script res://tests/run_tests.gd -- --capture
```

2026-10-05 本机验证结果：Godot 4.7.2，macOS / Apple M3 Max，Compatibility 渲染器。无图形测试 **192 项检查，0 失败**；图形测试（含四次截图保存检查）**196 项检查，0 失败**。已查看四张渲染截图，中文、按钮、弹窗和结算均正常显示。

| 行为 | 验证内容 | 结果 |
| --- | --- | --- |
| 正常推进 | 全部 30 个节点的天数、时间、进度 | 通过 |
| 确认跳天 | 第 1～9 天每个时间节点跳至次日上午；UI 原生确认按钮路径 | 通过 |
| 取消跳天 | 原生取消按钮、窗口关闭通知及从宿主视口派发 Esc | 通过 |
| 模态限制 | 弹窗打开时按钮禁用、处理函数拒绝推进 | 通过 |
| 跨天 | 第 1～9 天晚上推进到第二天上午 | 通过 |
| 第 10 天 | 跳天禁用、提示可见、状态层拒绝跳天 | 通过 |
| 结算边界 | 第 10 天晚上保留游戏界面，再推进才结算，永不产生第 11 天 | 通过 |
| 重新开始 | 恢复第 1 天上午、1 / 30、按钮和主界面 | 通过 |

测试使用实际场景、按钮信号及原生弹窗输入路径；不是对游戏逻辑的另一份模拟实现。未在其他操作系统或其他 Godot 4 版本逐一执行测试。中文使用系统字体（苹方、微软雅黑或 Noto CJK），系统需具有中文字体。

环境记录：本机 Godot 4.7.2 在一次 `--headless --editor --import --quit` 导入完成后的编辑器退出阶段报告了引擎内部线程退出崩溃。后续独立运行游戏、无图形测试和图形测试均正常完成，测试退出码均为 0；这份项目不需要使用上述编辑器批处理命令来运行。

原生弹窗行为参考：[Godot AcceptDialog 文档](https://docs.godotengine.org/en/4.5/classes/class_acceptdialog.html)。
