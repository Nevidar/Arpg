class_name AffixDef
extends RefCounted

enum Kind { PREFIX, SUFFIX }
enum Stat {
	FLAT_DAMAGE,
	INCREASED_DAMAGE,
	FLAT_HP,
	FLAT_ARMOR,
	CRIT_CHANCE,
	CRIT_MULTI,
	MOVE_SPEED,
	ATTACK_SPEED,
	MANA,
	LIFE_LEECH,
	BLOCK_CHANCE,
	RESIST_PHYS,
	RESIST_FIRE,
	RESIST_COLD,
	RESIST_LIGHTNING,
	RESIST_CHAOS,
}

var id: StringName
var kind: Kind
var display_name: String
var stat: Stat
## tier 1 = strongest (~100%), tier 9 = weakest (~1% of max band conceptually)
var tier_min: int = 1
var tier_max: int = 9
var value_at_t1: float = 10.0
var value_at_t9: float = 1.0


func roll_value(tier: int) -> float:
	var t := clampi(tier, 1, 9)
	var t01 := float(t - 1) / 8.0
	return lerpf(value_at_t1, value_at_t9, t01)


func label_for(tier: int, value: float) -> String:
	match stat:
		Stat.INCREASED_DAMAGE, Stat.CRIT_CHANCE, Stat.CRIT_MULTI, Stat.ATTACK_SPEED, Stat.MOVE_SPEED, Stat.LIFE_LEECH, Stat.BLOCK_CHANCE, Stat.RESIST_PHYS, Stat.RESIST_FIRE, Stat.RESIST_COLD, Stat.RESIST_LIGHTNING, Stat.RESIST_CHAOS:
			return "%s T%d (+%.0f%%)" % [display_name, tier, value * 100.0]
		_:
			return "%s T%d (+%.0f)" % [display_name, tier, value]
