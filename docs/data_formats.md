# 数据格式

这里维护组件之间传递的嵌套数据。外观和信号见 [ui_components.md](ui_components.md)，操作顺序见 [ux_interactions.md](ux_interactions.md)。字段有增减时改这里，并换掉对应的测试 JSON。

顶栏虽然单项很短，整份入参要交给数据引擎，所以也收在这里。

测试 JSON 里的 `portrait` 是资源路径或 `null`。交给控件之前，调用方把它载成 `Texture2D`。控件不读路径。

## 顶栏

入口是 `top_bar.apply_engine(data)`。数据引擎只组这份字典，不读节点，也不在顶栏里打开界面。按下按钮时顶栏发出 `action_pressed(id)`，`id` 来自 `buttons`。

缺字段时用脚本里的 `_preview_payload()` 补上。那份只给单独预览，不代替存档。`configure(...)` 负责拆到数值行、按钮行和天数角标，数据引擎不要直接调用。

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `stats` | 数组 | 左侧第一行。一项是 `{label, value}`，`value` 原样转成文字 |
| `buttons` | 数组 | 左侧第二行。一项是 `{id, text}`。非对象的项会被跳过 |
| `day` | 整数 | 角标上的「第N天」 |
| `total` | 整数 | 总天数。角标目前不显示，字段先留给引擎 |
| `ap` | 整数 | 剩余行动点 |
| `ap_max` | 整数 | 行动点上限。角标显示成「ap/ap_max」，缺省 3 |

```json
{
  "stats": [
    { "label": "说服力", "value": "0" },
    { "label": "影响力", "value": "0" },
    { "label": "曝光度", "value": "0" }
  ],
  "buttons": [
    { "id": "tasks", "text": "任务" },
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

这条测试数据显示「第1天」和「2/3」。四个按钮按下后分别交回 `tasks`、`items`、`status`、`settings`。

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
