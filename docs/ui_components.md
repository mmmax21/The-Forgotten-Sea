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

组件预览在 [scenes/ui/component_gallery.tscn](../scenes/ui/component_gallery.tscn)。窗口与主场景一样是 1920×1080，背景是 `Color(0.12, 0.13, 0.15)`。用 F6 运行这个场景，不要改项目的主场景。预览里现在有顶栏和人物栏。

接到地图场景时，由那个场景调用 `configure`，不要让顶栏自己读存档。

### 美术

四张必做，图里不写中文、不画数字。没有图时用纯色占位。花纹只放在边缘，中间留空，方便九宫格拉伸。

- 两行底板：约 620×150，放在 `assets/ui/top_bar/rows_texture.png`。拖到顶栏的 `rows_texture`。左右各 108px、上下各 64px 不拉伸，避开四角藤蔓。
- 数值条：560×72，约 7.8:1，放在 `assets/ui/top_bar/stat_bar_texture.png`，绑在顶栏的 `stat_bar_texture`。左右卷轴各 64px，上下木边各 16px 不拉伸。
- 按钮底：`assets/ui/top_bar/button_states.png`，560×76，从左到右是常规、悬停、按下。区域分别是 `Rect2(0, 0, 186, 76)`、`Rect2(193, 0, 178, 76)`、`Rect2(378, 0, 182, 76)`。绑在操作按钮的 `state_sheet`。圆角两端各留 40px。
- 时间角标：`assets/ui/top_bar/day_badge.png`，208×210。右上四分之一圆，绑在 `DayBadge` 的 `background`，贴住顶栏上边和右边。

合计 4 张必做，2 张可选。数值旁边先不加各自的小图标。

## 人物栏

顶栏木板下方的左侧竖栏。人数不固定，调用方传几张就排几张。隐藏的卡不留空位。这一版没有卡框和介绍底的贴图，用深色木板和羊皮纸纯色占位。

场景在 `scenes/ui/character_card/`，脚本在 `scripts/ui/character_card/`。

| 控件 | 作用 |
| --- | --- |
| `character_card.tscn` | 一张人物卡，144×160。人像 120×104，只伸进木框约 4px。 |
| `character_rail.tscn` | 竖向排卡，间距 48。放在 (16, 220)。 |

单张的入口是 `configure(name, portrait, summary, disabled, visible)`。栏的入口是 `configure(people)`。

- 一个人是 `{name, portrait, summary, disabled, visible}`。`portrait` 可以空。`disabled` 默认假，为真时整张置灰，悬停不弹出介绍。`visible` 默认真，为假时这张不占位。
- 悬停未禁用的卡时，右侧 8px 外弹出介绍。介绍固定 320×160，不随文字变高。超出的文字在内部滚动，滚动条出现在右侧。鼠标移进介绍条时不关闭。
- 预览数据在 [scripts/ui/component_gallery.gd](../scripts/ui/component_gallery.gd)。四个人都显示，盐嫂是置灰示例。

### 美术

卡框已接上。介绍底还没有图。图内不写字、不写数字。花纹只放在边缘，中间留空。置灰和悬停都由代码处理，不必另做状态图。

界面两张要和顶栏一致：深色旧木、细黄铜边、少量藤蔓，平视，无投影。

- 卡框：144×160，`assets/ui/character_card/card_frame.png`，绑在人物卡的 `frame_texture`。四边各 16px 不拉伸。中心全透明，头像从窗口露出。
- 介绍底：320×160，`assets/ui/character_card/tooltip_plate.png`。四边各 22px 不拉伸。中间是空白羊皮纸。

> 游戏界面卡框，144×160 像素。深色旧木边框，四角细黄铜，外缘只有少量藤蔓。正中心完全透明，不要人物，不要脸，不要文字，不要数字。底边略厚。正面平视，边缘清楚，透明背景，厚涂，暗褐与旧金色，不要投影。

> 游戏界面羊皮纸介绍底，320×160 像素。陈旧米色纸，细的深色木边和黄铜边。纹样只沿外圈，中间是空白纸。不要文字，不要字母，不要数字，不要人物。正面平视，边缘清楚，厚涂，淡褐色，透明背景。

默认头像是一张横图 `assets/portraits/default_characters.png`，1024×242。从左到右是老渔夫、盐嫂、螺螺、哑伯。三人之间各有一条黑线，切点去掉黑线和旁边的暗边：`Rect2(0, 0, 259, 242)`、`Rect2(263, 0, 245, 242)`、`Rect2(511, 0, 244, 242)`、`Rect2(758, 0, 265, 242)`。人像缩到 120×104，比木框内窗口每边大约多 4px，多出来的边被木框盖住。名字条在木框之上，贴着窗口下沿。以后换别人时，调用方另传 `portrait`。

> 一张西幻叙事游戏的角色半身像横图，1024×256 像素，透明背景。四个胸像从左到右等距排成一行，每人独占 256×256 的方格，肩部以上，同样大小，同一正面柔光，灰蓝海岸的厚涂，旧亚麻和皮革，不要文字，不要现代物品，不要水印，不要 Q 版。左一：七十岁渔夫，深皱纹，灰白胡子，手里捏着一顶油布帽，眼神疲惫而戒备，褪色的靛蓝外套。左二：四十岁左右的盐妇，寡妇，头发简单地束起，脸被海风吹得粗糙，打补丁的灰蓝亚麻衣，肩上一条盐筐带子，神情防备。左三：十二岁男孩，短发，神情好奇，打补丁的素色束腰外衣，手里握着一枚小贝壳。左四：年老的哑船匠，闭着嘴，风霜脸，双手有明显伤疤并放在画面偏低处，深色皮围裙上沾着木屑。
