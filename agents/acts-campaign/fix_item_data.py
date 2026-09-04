from pathlib import Path
p = Path(r"C:\Users\eilukhin\Documents\Ai_agent\arpg_Nevidar\scripts\items\item_data.gd")
t = p.read_text(encoding="utf-8")
t = t.replace(
    "static func roll_map(tier_ Prefer: int = 1) -> ItemData:",
    "static func roll_map(tier_prefer: int = 1) -> ItemData:",
)
needle = "func is_currency() -> bool:\n\treturn slot == Slot.CURRENCY\n"
insert = needle + "\n\nfunc is_map() -> bool:\n\treturn map_id != &\"\"\n"
if "func is_map()" not in t:
    t = t.replace(needle, insert)
# short label for maps
t = t.replace(
    "\t\tSlot.CURRENCY:\n\t\t\treturn \"※\"",
    "\t\tSlot.CURRENCY:\n\t\t\treturn \"M\" if map_id != &\"\" else \"※\"",
)
p.write_text(t, encoding="utf-8")
print("fixed")
