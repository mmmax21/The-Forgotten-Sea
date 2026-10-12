# 数据格式

这里维护组件之间传递的嵌套数据。外观和信号见 [ui_components.md](ui_components.md)，操作顺序见 [ux_interactions.md](ux_interactions.md)。字段有增减时改这里，并换掉对应的测试 JSON。

顶栏虽然单项很短，整份入参要交给数据引擎，所以也收在这里。

测试 JSON 里的 `portrait` 是资源路径或 `null`。交给控件之前，调用方把它载成 `Texture2D`。控件不读路径。

## 顶栏

入口是 `top_bar.apply_engine(data)`。数据引擎只组这份字典，不读节点，也不在顶栏里打开界面。按下按钮时顶栏发出 `action_pressed(id)`，`id` 来自 `buttons`。

缺字段时用脚本里的 `_preview_payload()` 补上。那份只给单独预览，不代替存档。`configure(...)` 负责拆到数值行、按钮行和天数角标，数据引擎不要直接调用。

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `stats` | 数组 | 左侧第一行。一项是 `{label, value}`，`value` 原样转成文字。正式运行是「支持度」和「警戒值」，算法见下一节 |
| `buttons` | 数组 | 左侧第二行。一项是 `{id, text}`。非对象的项会被跳过 |
| `day` | 整数 | 角标上的「第N天」 |
| `total` | 整数 | 总天数。角标目前不显示，字段先留给引擎 |
| `ap` | 整数 | 剩余行动点 |
| `ap_max` | 整数 | 行动点上限。角标显示成「ap/ap_max」，缺省 3 |

```json
{
  "stats": [
    { "label": "支持度", "value": "1" },
    { "label": "警戒值", "value": "2" }
  ],
  "buttons": [
    { "id": "story", "text": "剧情" },
    { "id": "items", "text": "物品" },
    { "id": "status", "text": "状态" },
    { "id": "settings", "text": "设置" }
  ],
  "day": 1,
  "total": 10,
  "ap": 2,
  "ap_max": 3
}
```

这条测试数据显示「支持度 1」「警戒值 2」「第1天」和「2/3」。四个按钮按下后分别交回 `story`、`items`、`status`、`settings`。单独预览顶栏时，脚本里的两项都是 0。

## 地区态势

支持度是地区变量，等于该地区居民个体支持度的平均值，四舍五入到整数。没有居民时为 0。警戒值是全局变量，表示对王国敌对势力的暴露程度，换地区不清零。

数值策划未定。增减量和玩家看到的说明写在 [data/region_stance.json](../data/region_stance.json)。[scripts/story/region_stance.gd](../scripts/story/region_stance.gd) 读这张表。表缺失或读失败时，用脚本里的同一份默认值。界面不写死增量。

顶栏只接收算好的两个整数，不读这张表，也不读存档。剧情入口在玩家确认之后调用方法，再把结果交回顶栏。

哑伯剧情里的「哑伯支持度」是另一个数，存在剧情存档的 `support`。演奏加的 10 只记在那里，不进入地区平均值。

### 设计表

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `alert` | 整数 | 新局的警戒值。存档里已有警戒值时不用这里的 |
| `alert_min` | 整数 | 警戒值下限。默认 0。暂不设上限 |
| `support_min` | 整数 | 单个居民支持度下限。默认 0。暂不设上限 |
| `ap_cost` | 整数 | 集会、隐藏各自消耗的行动点。默认 1 |
| `actions` | 对象 | 键是行动 id。`gather` 是集会，`hide` 是隐藏 |
| `actions.*.title` | 字符串 | 确认弹窗标题 |
| `actions.*.lead` | 字符串 | 弹窗第一句。`{region}` 换成当前地区名 |
| `actions.*.summary` | 字符串 | 结果说明 |
| `actions.*.empty_summary` | 字符串 | 仅集会：该地区没有居民时改用这句 |
| `actions.*.floor_summary` | 字符串 | 仅隐藏：警戒值已经到下限、数值不再变化时用这句。这种情况下不扣行动点 |
| `actions.*.support` | 整数 | 加到该地区每一个居民的支持度。隐藏默认 0 |
| `actions.*.alert` | 整数 | 加到全局警戒值。集会默认 1，隐藏默认 -1 |
| `regions` | 对象 | 键是地区 id，与大地图相同 |
| `regions.*.name` | 字符串 | 地区名 |
| `regions.*.npcs` | 数组 | `{id, name, support}`。`support` 是新局的个体支持度 |
| `location_region` | 对象 | 剧情所在地到地区 id。`home`（哑伯住处）属于 `fishing_village` |

每个人加上同一个 `support` 时，平均值也加上这个数。渔村开局四个居民都是 0，所以第一次集会后支持度从 0 变为 1。遗迹目前没有居民，在那里集会只升警戒值。

要改数值，改这张表即可。方法名不用改。

### 存档

剧情存档里的 `stance` 只记当前数值，不记增减量。没有这个字段的旧存档按新局处理。

```json
{
  "alert": 1,
  "supports": {
    "fisher": 1,
    "salt": 1,
    "luoluo": 1,
    "yabo": 1
  }
}
```

`supports` 按居民 id 盖过设计表里的初始支持度。表里后来删掉的居民不再计入平均值。

### 方法

都在 `region_stance.gd`。`apply` 不检查行动点，也不扣点。调用方先打开确认弹窗；玩家按下确认，并且 `preview.ok` 为真，再 `apply`，然后自己扣 `ap_cost`。

| 方法 | 作用 |
| --- | --- |
| `normalize(saved)` | 按表补齐居民。存档里的警戒值和个体支持度优先 |
| `region_of(location)` | 所在地换成地区 id |
| `regional_support(stance, region_id)` | 当前地区支持度 |
| `alert_of(stance)` | 全局警戒值 |
| `preview(stance, action, region_id, ap)` | 不改数值。给出变化前后，以及这次能不能结算 |
| `apply(stance, action, region_id)` | 按表写进 `stance` |
| `confirm_copy(preview)` | 确认弹窗用的 `title` 和 `text` |

`preview.ok` 为假有三种情况：行动不在表里，剩余行动点不够，或结算后两个数都不变。确认弹窗写明原因。这种情况下确认也不会改数值、不扣行动点。

取消不调用 `apply`。

默认：集会给当前地区每个居民支持度 +1，警戒值 +1。隐藏只把警戒值 -1，不低于 0。两次都是 1 AP。

### 小地图

上侧小钮 id 是 `gather`，纸心写「集」。下侧小钮 id 是 `hide`，纸心写「隐」。按下只把 id 交给调用方。剧情入口用确认弹窗写出这次的支持度、警戒值和行动点，玩家确认后才结算。

## 人物栏

已有。`character_rail.configure(people)` 接收一个数组，每人一项。非对象的项会被跳过。缺省：`disabled` 为假，`visible` 为真，`portrait` 为空。

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `name` | 字符串 | 卡上的名字，也是单击信号要带的名字 |
| `portrait` | 纹理或空 | 卡内人像。测试 JSON 里写路径 |
| `summary` | 字符串 | 悬停介绍。置灰时不显示 |
| `disabled` | 布尔 | 为真时整张置灰，不弹出介绍，单击无效 |
| `visible` | 布尔 | 为假时不占位 |

```json
[
  {
    "name": "老渔夫",
    "portrait": "res://assets/portraits/default_characters.png",
    "summary": "镇上的老渔夫。想把潮汐歌留下来，却害怕连累孙子。",
    "disabled": false,
    "visible": true
  },
  {
    "name": "盐嫂",
    "portrait": "res://assets/portraits/default_characters.png",
    "summary": "置灰示例。悬停不弹出介绍，单击不打开对话。",
    "disabled": true,
    "visible": true
  },
  {
    "name": "未出场",
    "portrait": null,
    "summary": "",
    "disabled": false,
    "visible": false
  }
]
```

四人像是同一张横图。调用方切好再传入。切点和显示尺寸见组件文档的人物栏。

## 日记书页

已有。`journal_book.refresh(pages)` 接收按天排好的数组。控件不读 `data/journal_test.json`。那份文件是平铺的 `journal_log`，只有 F6 单独运行日记场景时，场景自己按 `day` 收成下面这种书页。

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `day` | 整数 | 这一页的天数 |
| `entries` | 数组 | 这一天的记录，可以是空数组 |
| `entries[].id` | 字符串 | 未读判断用。同一条换了 `text` 会再次算未读 |
| `entries[].title` | 字符串 | 条目标题 |
| `entries[].text` | 字符串 | 正文。换行写在字符串里 |

```json
[
  {
    "day": 1,
    "entries": [
      {
        "id": "day1_opening",
        "title": "抵达遗迹",
        "text": "石壁上的潮气还没干。今天只把看到的东西记下来。"
      }
    ]
  },
  {
    "day": 2,
    "entries": []
  }
]
```

## 对话

尚未制作。这是 `open(dialogue)` 的约定，调用方组好再传入。点数和效果不在这份数据里。界面结束时只交回 `option_id`，由调用方结算。

一次对话一个对象。

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `npc` | 对象 | 左侧肖像。`name`、`portrait` |
| `player` | 对象 | 右侧肖像。`name`、`portrait` |
| `opening` | 数组 | 开场旁白，按顺序一段一段显示 |
| `talk` | 数组 | 交谈的具体选项。空数组表示交谈按钮置灰 |
| `investigate` | 数组 | 调查的具体选项。空数组表示调查按钮置灰 |

旁白一项只有正文。说话人固定是左侧 NPC。

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `text` | 字符串 | 这一段旁白 |

选项一项：

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `id` | 字符串 | 同一次对话里唯一。结束时由 `resolved` 交回 |
| `label` | 字符串 | 按钮文案 |
| `lines` | 数组 | 选中后播放的对白，按顺序 |

对白一项：

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `speaker` | 字符串 | `npc` 或 `player`。决定哪一侧亮起 |
| `text` | 字符串 | 这一段对白 |

`talk` 和 `investigate` 用同一份选项结构。界面一次只列出其中一组。

```json
{
  "npc": {
    "name": "老渔夫",
    "portrait": "res://assets/portraits/default_characters.png"
  },
  "player": {
    "name": "学徒",
    "portrait": null
  },
  "opening": [
    { "text": "海风又从北面来了。你要是来问船，就小点声。" },
    { "text": "白天我只在晒网上。别的事，等这网晾干再说。" }
  ],
  "talk": [
    {
      "id": "talk_grandson",
      "label": "问起他的孙子",
      "lines": [
        { "speaker": "player", "text": "孩子今天没跟你出海？" },
        { "speaker": "npc", "text": "他在镇口看着网。你先别去找他。" },
        { "speaker": "player", "text": "我只想知道潮什么时候回来。" },
        { "speaker": "npc", "text": "潮汐歌我还记得两句。现在不能唱给你听。" }
      ]
    },
    {
      "id": "talk_song",
      "label": "请他哼一句潮汐歌",
      "lines": [
        { "speaker": "npc", "text": "一句也不行。墙上有耳朵。" }
      ]
    }
  ],
  "investigate": []
}
```

这条测试数据里，调查没有选项，调查按钮置灰。交谈有两条，点哪条就按该条的 `lines` 播放。旁白两段都由 NPC 说，所以没有 `speaker`。

## 通知弹窗

入口是 `notice.apply_engine(data)`。数据引擎只组这份字典。`open()` 负责显示；还没传入数据时用脚本里的 `_preview_payload()`。按下关闭后发出 `closed`，不在这里结算。

和人物肖像不同：`image` 是资源路径，由弹窗自己加载。路径为空，或载入失败，图片区隐藏。`title` 和 `text` 为空字符串或未传时，对应区域隐藏，不留空位。

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `title` | 字符串 | 标题。空则不显示 |
| `image` | 字符串 | 图片资源路径，例如 `res://assets/portraits/default_characters.png`。空则不显示 |
| `text` | 字符串 | 正文。空则不显示 |

```json
{
  "title": "潮汐将至",
  "image": "res://assets/portraits/default_characters.png",
  "text": "北面的网已经收起。今天先不要出镇。"
}
```

这条测试数据三项都有。只想显示正文时，把 `title` 和 `image` 写成 `""`。

## 确认弹窗

入口是 `confirm_dialog.configure(data)`，然后 `open()`。控件不读存档。按下确认后先隐藏，再调用 `on_confirm`，发出 `confirmed`。按下取消后先隐藏，再调用 `on_cancel`，发出 `cancelled`。方法没传就什么都不做。

`title` 和 `text` 可以写成 JSON。`on_confirm`、`on_cancel` 是 GDScript 的 `Callable`，只放在调用方的字典里，不进 JSON。

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `title` | 字符串 | 标题。没传或空字符串时用「请确认」 |
| `text` | 字符串 | 正文。没传或空字符串时不显示，不留空行 |
| `on_confirm` | Callable | 确认后调用。可选 |
| `on_cancel` | Callable | 取消后调用。可选 |

```json
{
  "title": "请确认",
  "text": "北面的网已经收起。今天先不要出镇。"
}
```

只传正文时，标题仍是「请确认」。方法在脚本里另挂，例如 `data["on_confirm"] = _leave_town`。

## 大地图

入口是 `map_modal.configure(data)`，然后 `open()`。控件不读存档。有海无海、每个地点能否前往，都由这一份字典决定。按下关闭后发出 `closed`。点中能前往的地点先打开地图里的确认弹窗。确认后才发出 `place_chosen(place_id, place_name)`，并关闭地图。控件不扣行动点，也不切换所在地。

不传 `places` 时，六个地点都能前往。传了 `places` 时，一项是一个地点，`id` 只接受下面六个，别的 id 跳过。这次没写到的地点不能前往。

| id | 地名 |
| --- | --- |
| `ruins` | 遗迹 |
| `fishing_village` | 渔村 |
| `market` | 集市 |
| `old_academy` | 旧学城 |
| `feather_forest` | 羽之森 |
| `royal_city` | 王城 |

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `show_ocean` | 布尔 | 为真用有海图，缺省或为假用无海图 |
| `places` | 数组 | 一项是 `{id, reachable}`。`reachable` 为真才能前往 |
| `ap` | 整数 | 当前剩余行动点。缺省沿用上一次，最初是 3 |
| `ap_cost` | 整数 | 前往一地消耗的行动点。缺省 1 |
| `current_place` | 字符串 | 玩家现在所在的地点 id。和点中的 id 相同就视为已在当地 |
| `travel_names` | 对象 | 可选。地点 id 到确认框里的目的地名。没写就用地图上的地名 |

```json
{
  "show_ocean": false,
  "places": [
    { "id": "ruins", "reachable": true },
    { "id": "fishing_village", "reachable": true },
    { "id": "market", "reachable": false },
    { "id": "old_academy", "reachable": false },
    { "id": "feather_forest", "reachable": false },
    { "id": "royal_city", "reachable": true }
  ]
}
```

这条是组件预览用的名单，不是某一天的正式进度。遗迹、渔村、王城能前往。其余三地盖住。不传 `places` 时六地都能前往。

## 物品栏

入口是 `inventory_modal.apply_engine(data)`，然后 `open()`。控件不读存档，也不使用物品。按下关闭后发出 `closed`。

`items` 是数组，顺序保持传入顺序。非对象的项跳过。不设数量，也不合并重复物品。引擎给几项就排几格。书签和页码由控件自己记，`apply_engine` 不接收页码。换书签回到第 1 页。

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `items` | 数组 | 一项是一件物品。非对象跳过 |
| `id` | 字符串 | 同一次打开里唯一 |
| `name` | 字符串 | 格子里的名字，也是介绍标题 |
| `kind` | 字符串 | 只接受 `story`（剧情）或 `normal`（普通）。别的值跳过 |
| `icon` | 字符串或空 | 资源路径，或 `null`。由控件自己加载，失败就当没有图标 |
| `description` | 字符串 | 介绍正文 |

```json
{
  "items": [
    {
      "id": "ancient_song",
      "name": "古老的船歌",
      "kind": "story",
      "icon": "res://assets/items/ancient_song.tres",
      "description": "字迹漫漶，隐约可以识读——「向您致敬，深蓝发的神明！蒙您庇佑，我们在波涛之间……」"
    },
    {
      "id": "rope",
      "name": "麻绳",
      "kind": "normal",
      "icon": null,
      "description": "普通物品占位。"
    }
  ]
}
```

这条里船歌进剧情书签，并加载图标。麻绳进普通书签，没有图标，格子里改写名字。`kind` 写成别的值，或该项不是对象，都不会占格。

单独 F6 时脚本自带预览：剧情侧是古老的船歌、旧木板、造船图纸；普通侧 17 件占位，用来看到第二页。
