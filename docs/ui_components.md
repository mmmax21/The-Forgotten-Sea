# 界面组件

场景负责外观。脚本对外只留 `configure`、`refresh`、`open` 和信号。拼条目、读存档仍留在调用方，不放进这些控件。

## 日记

已完成。按天翻页的书本弹窗，一页是一天的记录。

- 场景：[scenes/ui/journal_book.tscn](../scenes/ui/journal_book.tscn)
- 脚本：[scripts/ui/journal_book.gd](../scripts/ui/journal_book.gd)
- 对外：`refresh(pages)`、`open()`、`show_day(day)`、`unread()`。翻页和关闭由场景自己处理。
- 一页的数据是 `{day, entries:[{id, title, text}]}`。控件不读 JSON，也不读游戏状态。

叙事控制器在运行时实例化这个场景。主场景节点树里看不到它。用编辑器打开该场景后按 F6，会用 `data/journal_test.json` 单独预览。

## 顶栏

地图界面上方的横条。尚未替换 [scenes/main.tscn](../scenes/main.tscn) 里的旧顶栏（天数、阶段、地区、警戒、手记、菜单）。说服力、影响力、曝光度也还不在游戏状态里，所以这一版只接收调用方传入的文字和数字。

场景都在 `scenes/ui/top_bar/`，脚本在 `scripts/ui/top_bar/`。

| 控件 | 作用 |
| --- | --- |
| `stat_readout.tscn` | 一项数值。`configure(label, value)`。单独使用时自带底；放进顶栏后关掉自己的底。 |
| `action_button.tscn` | 一个操作按钮。`configure(id, text)`。没有贴图时用浅灰圆角，悬停变暗。 |
| `day_badge.tscn` | 右侧天数。`configure(day, total)`，文案只显示「第N天」。贴图 208×210，锚在顶栏右上角，上边和右边不留空。 |
| `top_bar.tscn` | 把上面三块排好。左侧两行，右侧天数。 |

顶栏的入口是 `configure(stats, buttons, day, total)`。

- 一项数值是 `{label, value}`。默认：说服力、影响力、曝光度。
- 一个按钮是 `{id, text}`。默认：任务、物品、状态、设置。
- 按下按钮只发出 `action_pressed(id)`，不在顶栏里打开界面。
- 数值条是整行一张底，三个数值共用。`stat_bar_texture` 和 `button_texture` 都可以空着。

组件预览在 [scenes/ui/component_gallery.tscn](../scenes/ui/component_gallery.tscn)。窗口与主场景一样是 1920×1080，背景是 `Color(0.12, 0.13, 0.15)`。现在只放了顶栏。用 F6 运行这个场景，不要改项目的主场景。

接到地图场景时，由那个场景调用 `configure`，不要让顶栏自己读存档。

### 美术

四张必做，图里不写中文、不画数字。没有图时用纯色占位。花纹只放在边缘，中间留空，方便九宫格拉伸。

- 两行底板：约 620×150，放在 `assets/ui/top_bar/rows_texture.png`。拖到顶栏的 `rows_texture`。左右各 108px、上下各 64px 不拉伸，避开四角藤蔓。
- 数值条：560×72，约 7.8:1，放在 `assets/ui/top_bar/stat_bar_texture.png`，绑在顶栏的 `stat_bar_texture`。左右卷轴各 64px，上下木边各 16px 不拉伸。
- 按钮底：`assets/ui/top_bar/button_states.png`，560×76，从左到右是常规、悬停、按下。区域分别是 `Rect2(0, 0, 186, 76)`、`Rect2(193, 0, 178, 76)`、`Rect2(378, 0, 182, 76)`。绑在操作按钮的 `state_sheet`。圆角两端各留 40px。
- 时间角标：`assets/ui/top_bar/day_badge.png`，208×210。右上四分之一圆，绑在 `DayBadge` 的 `background`，贴住顶栏上边和右边。

合计 4 张必做，2 张可选。数值旁边先不加各自的小图标。
