class_name CombatStats
extends RefCounted

## Боевые статы сущности (игрок / враг).

var max_hp: float = 100.0
var hp: float = 100.0
var max_mana: float = 50.0
var mana: float = 50.0

var base_damage: float = 10.0
var added_damage: float = 0.0
var increased_damage: float = 0.0 ## сумма Increased (0.5 = +50%)
var more_multipliers: Array[float] = [] ## каждый more как 0.2 = +20% more

var crit_chance: float = 0.05
var crit_multi: float = 1.5 ## базовые 150%

var armor: float = 0.0
var block_chance: float = 0.0
var evasion: float = 0.0

## resists 0..0.75 softcap later; сейчас 0..1
var resist_physical: float = 0.0
var resist_fire: float = 0.0
var resist_cold: float = 0.0
var resist_lightning: float = 0.0
var resist_chaos: float = 0.0 ## яд/тьма

var move_speed: float = 180.0
var attack_speed: float = 1.0

func is_alive() -> bool:
	return hp > 0.0


func heal_full() -> void:
	hp = max_hp
	mana = max_mana


func take_raw_hp(amount: float) -> void:
	hp = maxf(0.0, hp - amount)


func get_resist(damage_type: StringName) -> float:
	match String(damage_type):
		"physical":
			return resist_physical
		"fire":
			return resist_fire
		"cold":
			return resist_cold
		"lightning":
			return resist_lightning
		"chaos", "poison", "dark":
			return resist_chaos
		_:
			return 0.0
