extends RefCounted
# Derived from saved chapter facts so older saves need no new mandatory fields.
static func investigated(academy: Dictionary, turn: int) -> bool:
 return academy.get("people",{}).get("er",{}).get("closed",false) or (academy.get("warnings",{}).has("er") and int(academy.warnings.er)<=turn)
static func market_help(academy: Dictionary) -> bool:
 var market: Dictionary=academy.get("origin",{})
 return market.get("contacts_available",false) or market.get("print_available",false)
static func dependent_link(academy: Dictionary) -> bool:
 return academy.get("findings",{}).get("er_records",false) and academy.get("channels",{}).get("independent_archive",false) and not academy.get("channels",{}).get("public_record",false)
static func epilogue(academy: Dictionary, forest_flags: Dictionary, turn: int) -> String:
 if investigated(academy,turn):
  if forest_flags.get("er_relieved",false): return "二笔：你事后送出交接凭据并安排接应，师姐的责任得到澄清。她已脱离这次追查，恢复安全联系，但失去抄写工作的损失仍在；她正寻找重新抄书的地方。"
  return "二笔：她因交接记录受到盘问，失去藏书馆的抄写工作，师姐也被要求接受核查。你没有完成接应；截至离开羽之森，她仍被排除在藏书馆之外。这份损失不会随大结局自动消失。"
 if academy.get("findings",{}).get("er_protect",false): return "二笔：你提前保留交接凭据、澄清师姐的责任，并安排暂避与替代联络。她与师姐得以继续保存、整理被删去的历史。"
 return ""
