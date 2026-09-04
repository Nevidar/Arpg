class_name ItemAffix
extends RefCounted

var def_id: StringName
var kind: AffixDef.Kind
var display_name: String
var stat: AffixDef.Stat
var tier: int = 5
var value: float = 0.0


static func from_def(def: AffixDef, tier: int) -> ItemAffix:
	var a := ItemAffix.new()
	a.def_id = def.id
	a.kind = def.kind
	a.display_name = def.display_name
	a.stat = def.stat
	a.tier = tier
	a.value = def.roll_value(tier)
	return a


func label() -> String:
	match stat:
		AffixDef.Stat.INCREASED_DAMAGE, AffixDef.Stat.CRIT_CHANCE, AffixDef.Stat.CRIT_MULTI, AffixDef.Stat.ATTACK_SPEED, AffixDef.Stat.MOVE_SPEED, AffixDef.Stat.LIFE_LEECH, AffixDef.Stat.BLOCK_CHANCE, AffixDef.Stat.RESIST_PHYS, AffixDef.Stat.RESIST_FIRE, AffixDef.Stat.RESIST_COLD, AffixDef.Stat.RESIST_LIGHTNING, AffixDef.Stat.RESIST_CHAOS:
			return "%s T%d (+%.0f%%)" % [display_name, tier, value * 100.0]
		_:
			return "%s T%d (+%.0f)" % [display_name, tier, value]
