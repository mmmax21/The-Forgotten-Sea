"""渔村六回合交互式模拟器 (village_v03)。

基于 docs/design/渔村六回合设定_v0.3.md 实现的状态机与 validate_village_v03.py
完全一致；本文件在此之上提供命令行交互，让用户能像玩游戏一样走完六天。

运行：python3 tools/design/village_sim.py
退出：Ctrl-C，或在主提示符输入 quit / exit。
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

# 复用已有 Village 状态机，避免规则分叉。
_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE))
from validate_village_v03 import Village  # noqa: E402

# --- 行动的中文标签与简短描述（用于菜单展示） ---

NPC = {"salt": "盐嫂", "elder": "哑伯", "child": "螺螺"}

ACTIONS: list[tuple[str, str, str]] = [
    # (action_key, arg_or_None, label, cost, extra_ap, extra_food, condition_str, flavor)
    ("feed", None, "送粮（1 AP + 1 粮）", 1, 0, 1, "未完成", "向盐嫂送粮"),
    ("listen", None, "倾听丈夫经历（1 AP）", 1, 0, 0, "已送粮", "听盐嫂讲述丈夫的事"),
    ("heirloom", None, "查看遗物（1 AP）", 1, 0, 0, "已倾听，盐嫂 T≥60 且 A<60", "取得 H"),
    ("family", None, "安置家人（2 AP + 1 粮）", 2, 0, 1, "已倾听，第 1—3 天", "盐嫂 A−20"),
    ("repair", None, "修整旧物（1 AP）", 1, 0, 0, "未完成", "哑伯 T+15"),
    ("identify", None, "辨认碎片（1 AP）", 1, 0, 0, "持有 fragment，哑伯 T≥60 且 A<60", "碎片→F"),
    ("tidy", None, "收好危险旧物（1 AP，仅一次）", 1, 0, 0, "哑伯知情", "哑伯 A−10"),
    ("hear", None, "听螺螺见闻（1 AP）", 1, 0, 0, "未完成", "螺螺 T+10，知隐蔽入口"),
    ("retrieve", None, "取回遗落物品（1 AP）", 1, 0, 0, "已听见闻", "螺螺 T+15，获准确入口"),
    ("survey", None, "自行勘察遗迹（1 AP）", 1, 0, 0, "尚无准确入口，遗迹开放", "获得准确入口"),
    ("clear", None, "清理入口（1 AP）", 1, 0, 0, "已知入口，遗迹开放", "开放内部"),
    ("search", None, "搜查遗迹（1 AP）", 1, 0, 0, "已清理，遗迹开放", "获得未确认碎片"),
    ("caution", None, "梳理不能公开说的内容（1 AP，仅一次）", 1, 0, 0, "螺螺知情", "螺螺 A−10"),
    ("show", "salt", "私下展示给盐嫂（1 AP）", 1, 0, 0, "持有 H/F 或其记录", "盐嫂 T+10/A+15/知情"),
    ("show", "elder", "私下展示给哑伯（1 AP）", 1, 0, 0, "持有 H/F 或其记录", "哑伯 T+10/A+15/知情"),
    ("show", "child", "私下展示给螺螺（1 AP）", 1, 0, 0, "持有 H/F 或其记录", "螺螺 T+10/A+15/知情"),
    ("record", "H", "自行制作 H 记录（2 AP）", 2, 0, 0, "持有 H 原物，未制作过 H 记录", ""),
    ("record", "F", "自行制作 F 记录（2 AP）", 2, 0, 0, "持有 F 原物，未制作过 F 记录", ""),
    ("scribe", "H", "请人抄写 H 记录（1 AP + 1 粮）", 1, 0, 1, "持有 H 原物，未制作过 H 记录", ""),
    ("scribe", "F", "请人抄写 F 记录（1 AP + 1 粮）", 1, 0, 1, "持有 F 原物，未制作过 F 记录", ""),
    ("public", "material", "公开：匿名物证说明（2 AP）", 2, 0, 0, "第 4—5 天，持有 H/F 原物或记录", ""),
    ("public", "anonymous", "公开：匿名丈夫经历（1 AP）", 1, 0, 0, "第 4—5 天，持有 H 或 H_r，已倾听", ""),
    ("public", "named_salt", "公开：实名丈夫证词（1 AP）", 1, 0, 0, "第 4—5 天，持有 H 或 H_r，已倾听", ""),
    ("public", "named_elder", "公开：实名船匠辨认（1 AP）", 1, 0, 0, "第 4—5 天，持有 F 或 F_r", ""),
    ("neighbor", "H", "安排邻里传播：交 H 原物（1 AP）", 1, 0, 0, "盐嫂知情且 T≥60/A<60 且具资格，持有 H", ""),
    ("neighbor", "F", "安排邻里传播：交 F 原物（1 AP）", 1, 0, 0, "盐嫂知情且 T≥60/A<60 且具资格，持有 F", ""),
    ("neighbor", "H_r", "安排邻里传播：交 H_r 记录（1 AP）", 1, 0, 0, "盐嫂知情且 T≥60/A<60 且具资格，持有 H_r", ""),
    ("neighbor", "F_r", "安排邻里传播：交 F_r 记录（1 AP）", 1, 0, 0, "盐嫂知情且 T≥60/A<60 且具资格，持有 F_r", ""),
    ("apology", "salt", "承认越界并停止引用（盐嫂）（1 AP）", 1, 0, 0, "盐嫂已被实名曝光", ""),
    ("apology", "elder", "承认越界并停止引用（哑伯）（1 AP）", 1, 0, 0, "哑伯已被实名曝光", ""),
    ("waterline", None, "观察并核对水线（2 AP）", 2, 0, 0, "已确认 F，持有 F 或 F_r，第 2—4 天", "获得 W"),
]


def _is_once(action: str, arg) -> bool:
    return action in ("feed", "listen", "repair", "hear", "retrieve", "survey", "clear",
                      "search", "identify", "tidy", "caution", "waterline", "family",
                      "heirloom", "public", "withdraw") or (
        action in ("record", "scribe") and arg in ("H", "F")) or (
        action in ("apology",))


# --- 显示辅助 ---

def _npc_row(name_zh: str, t: int, a: int, known: bool) -> str:
    star = "知情" if known else "—"
    return f"  · {name_zh:<4} T={t:>3}  A={a:>3}  {star}"


def show_status(v: Village) -> None:
    print()
    print("=" * 60)
    print(f"第 {v.day} 天 | AP {v.ap}/3 | 粮 {v.food} | 海洋认知度 B = {v.b}")
    print("-" * 60)
    print("人物：")
    for who, zh in NPC.items():
        t, a, known = v.npc[who]
        flags = []
        if who in v.exposed:
            flags.append("已曝光")
        if who in v.reported:
            flags.append("已告密")
        if "withdraw_" + who in v.flags:
            flags.append("已撤回")
        suffix = (" [" + ", ".join(flags) + "]") if flags else ""
        print(_npc_row(zh, t, a, known) + suffix)
    print("-" * 60)
    items = sorted(v.items)
    print(f"持有：{', '.join(items) if items else '（无）'}")
    if v.neighbor:
        print(f"邻里传播：盐嫂持有 {v.neighbor}（离场时结算）")
    if v.warn:
        print("预警（截止回合）：")
        for who, due in sorted(v.warn.items(), key=lambda x: (x[1], x[0])):
            print(f"  · {NPC[who]} 截止 第 {due} 天 结束")
    if v.exposed:
        print(f"已实名曝光：{', '.join(NPC[w] for w in v.exposed)}")
    if v.penalty_pending:
        print("⚠  今日已结算告密，下一天起少 1 AP（一次性）")
    if v.departed:
        print("—— 已离场 ——")
    print("=" * 60)


def show_menu(v: Village) -> None:
    if v.departed:
        return
    print()
    print("可用行动：")
    idx = 0
    entries: list[tuple[int, str, object | None]] = []
    for action, arg, label, _cost, _eap, _efood, _cond, _flavor in ACTIONS:
        key = action + (":" + str(arg) if arg is not None else "")
        once = _is_once(action, arg) or key in v.flags
        if once and key in v.flags:
            continue
        try:
            v.act(action, arg)  # dry-run: Village.act 捕获 AssertionError 并回滚
            v.act(action, arg)  # 第二次还是会回滚，但 Village 没有 dry-run 接口
        except AssertionError:
            continue
        # Village.act 是真改；回滚要自己处理。改用探测：act 内部 copy+回滚。
        idx += 1
        entries.append((idx, label, (action, arg)))
        print(f"  {idx:>2}. {label}")
    if not entries:
        print("  （当前没有可执行行动，结束当天或检查条件）")
    # 额外命令
    print("  --------")
    print("  e. 结束当天 (end)")
    print("  s. 保存进度 (save)")
    print("  h. 帮助 (help)")
    print("  q. 退出 (quit)")
    return entries


def probe(v: Village, action: str, arg) -> bool:
    """试一次 action；不真正改变 v（依赖 Village.act 的事务回滚）。"""
    from copy import deepcopy
    before = deepcopy(v.__dict__)
    try:
        v.act(action, arg)
    except AssertionError:
        return False
    finally:
        v.__dict__ = before
    return True


def show_menu_v2(v: Village) -> list[tuple[int, str, tuple]]:
    """用 probe 列举当前可执行行动，避免 Village.act 实际扣费。"""
    if v.departed:
        return []
    entries: list[tuple[int, str, tuple]] = []
    idx = 0
    print()
    print("可用行动：")
    for action, arg, label, _c, _eap, _efood, _cond, _flavor in ACTIONS:
        if not probe(v, action, arg):
            continue
        idx += 1
        entries.append((idx, label, (action, arg)))
        print(f"  {idx:>2}. {label}")
    if not entries:
        print("  （当前没有可执行行动，结束当天或检查条件）")
    print("  --------")
    print("  e. 结束当天 (end)")
    print("  h. 帮助 (help)")
    print("  q. 退出 (quit)")
    return entries


# 替换 v1 实现
show_menu = show_menu_v2  # type: ignore


HELP_TEXT = """\
命令：
  数字            选择菜单中的行动
  e / end         结束当天（end-of-day）
  h / help        显示此帮助
  s / save        保存当前进度到 village_save.json（演示用，写在脚本同目录）
  q / quit        退出模拟（不保存）

提示：
  - 普通移动与查看信息免费，不需指令。
  - 一次性行动（送粮、倾听、勘察等）完成后即从菜单中消失。
  - 公开说明四版本互斥，整个渔村只能公开一次，第 4—5 天窗口。
  - 实名公开立即结算：被点名者 T−20/A+20、永久失去本区保管与邻里传播资格。
  - 第 6 天只能补救/记录/保管/交接；不能临时补做公开。
  - 离场后若盐嫂仍有效保管邻里材料，B 再 +10 一次。
  - 主动撤回协助/取消传播/跨区信使撤回已移除；只有保管物品可免费取回，离场前的高危状态会带到下一地区处理。
"""


def cmd_save(v: Village) -> None:
    import json
    data = {
        "day": v.day, "ap": v.ap, "food": v.food, "b": v.b,
        "npc": {k: list(v.npc[k]) for k in v.npc},
        "items": sorted(v.items), "flags": sorted(v.flags),
        "exposed": sorted(v.exposed), "reported": sorted(v.reported),
        "warn": v.warn, "public": v.public, "neighbor": v.neighbor,
        "penalty_used": v.penalty_used, "penalty_pending": v.penalty_pending,
        "departed": v.departed,
    }
    path = _HERE / "village_save.json"
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"已保存到 {path}")


def show_departure_summary(v: Village) -> None:
    if not v.departed:
        return
    print()
    print("# 离场结算")
    print(f"- 海洋认知度 B = {v.b}")
    if v.b < 30:
        zone = "传闻尚弱"
    elif v.b < 60:
        zone = "留下认知火种"
    else:
        zone = "出现局部现实变化"
    print(f"- 地区成果：{zone}")
    if v.items & {"H", "F"}:
        kinds = sorted({"H" if "H" in v.items else "H_r",
                        "F" if "F" in v.items else "F_r"})
        print(f"- 证据成果：带走 {', '.join(kinds)}")
    else:
        print("- 证据成果：未带出独立来源")
    if v.neighbor_valid:
        print("- 协助成果：邻里传播有效")
    elif v.neighbor:
        print("- 协助成果：邻里材料已退回")
    else:
        print("- 协助成果：未安排传播")
    if v.exposed:
        print(f"- 人物成果：{', '.join(NPC[w] for w in v.exposed)} 已实名曝光")
    if v.reported:
        print(f"- 告密：{', '.join(NPC[w] for w in v.reported)}（下一地区首回合少 1 AP）")
    if v.warn:
        print(f"- 待处理预警：{v.warn}")


def main() -> None:
    v = Village()
    print("渔村六回合 v0.3 —— 交互试玩")
    print("输入 h 查看命令，q 退出。\n")
    print("开场：第 1 天，免费揭示全部期限。盐嫂缺粮、哑伯守着破损工具和旧图纸、")
    print("螺螺拿着河边捡来的贝壳。村口告示已经贴出。可以先去任何地点。")
    while True:
        show_status(v)
        if v.departed:
            show_departure_summary(v)
            print("\n游戏结束。再开一局请重新运行脚本。")
            return
        entries = show_menu(v)
        try:
            raw = input("\n> ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\n退出。")
            return
        if not raw:
            continue
        low = raw.lower()
        if low in ("q", "quit", "exit"):
            print("退出。")
            return
        if low in ("h", "help", "?"):
            print(HELP_TEXT)
            continue
        if low in ("s", "save"):
            cmd_save(v)
            continue
        if low in ("e", "end"):
            try:
                v.end()
            except AssertionError as ex:
                print(f"[无法结束] {ex}")
            continue
        # 数字选择
        try:
            n = int(raw)
        except ValueError:
            print("无法识别：", raw)
            continue
        match = next((ent for ent in entries if ent[0] == n), None)
        if not match:
            print("无效选项。")
            continue
        _idx, _label, (action, arg) = match
        try:
            v.act(action, arg)
        except AssertionError as ex:
            print(f"[失败] {ex}")


if __name__ == "__main__":
    main()
