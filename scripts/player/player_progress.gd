class_name PlayerProgress
extends RefCounted

## Воин: основная сила, потом ловкость, интеллект самый низкий.
## Прирост за уровень: 1.0 / 0.6 / 0.3

signal leveled_up(new_level: int)
signal xp_changed(xp: int, need: int, level: int)

var level: int = 1
var xp: int = 0
var strength: float = 10.0
var dexterity: float = 6.0
var intelligence: float = 3.0
var passive_points_on_level: int = 1


func xp_to_next() -> int:
	return 40 + (level - 1) * 25


func add_xp(amount: int) -> void:
	xp += amount
	xp_changed.emit(xp, xp_to_next(), level)
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		strength += 1.0
		dexterity += 0.6
		intelligence += 0.3
		leveled_up.emit(level)
		xp_changed.emit(xp, xp_to_next(), level)


func skill_unlocked(skill_id: StringName) -> bool:
	## Черновая сетка уровней из дизайна: 1/4/8/12/...
	match String(skill_id):
		"basic", "splash":
			return level >= 1
		"ground_slam":
			return level >= 4
		"lunge":
			return level >= 8
		_:
			return false
