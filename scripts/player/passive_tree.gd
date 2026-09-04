class_name PassiveTree
extends RefCounted

## Простое дерево: очки за уровень, покупка узлов без связей (MVP).

signal changed

class NodeDef:
	var id: StringName
	var title: String
	var desc: String
	var max_rank: int = 1
	var cost: int = 1
	var stat: StringName
	var value_per_rank: float = 0.0

var points: int = 0
var ranks: Dictionary = {} ## id -> int
var _defs: Array[NodeDef] = []


func _init() -> void:
	_defs = [
		_n(&"vitality", "Живучесть", "+20 HP / ранг", 3, &"hp", 20.0),
		_n(&"might", "Мощь", "+8% урона / ранг", 3, &"inc_damage", 0.08),
		_n(&"precision", "Меткость", "+3% крита / ранг", 3, &"crit", 0.03),
		_n(&"iron", "Железо", "+6 брони / ранг", 3, &"armor", 6.0),
		_n(&"swift", "Быстрота", "+8 скорости / ранг", 3, &"move", 8.0),
		_n(&"focus", "Фокус", "+10 маны / ранг", 3, &"mana", 10.0),
		_n(&"ferocity", "Свирепость", "+15% crit multi / ранг", 2, &"crit_multi", 0.15),
		_n(&"blood", "Кровь", "+2% leech / ранг", 2, &"leech", 0.02),
	]


func _n(id: StringName, title: String, desc: String, max_rank: int, stat: StringName, value: float) -> NodeDef:
	var d := NodeDef.new()
	d.id = id
	d.title = title
	d.desc = desc
	d.max_rank = max_rank
	d.stat = stat
	d.value_per_rank = value
	return d


func add_point(amount: int = 1) -> void:
	points += amount
	changed.emit()


func try_buy(index: int) -> bool:
	if index < 0 or index >= _defs.size():
		return false
	var d: NodeDef = _defs[index]
	var cur: int = int(ranks.get(d.id, 0))
	if points < d.cost or cur >= d.max_rank:
		return false
	points -= d.cost
	ranks[d.id] = cur + 1
	changed.emit()
	return true


func get_bonus(stat: StringName) -> float:
	var total := 0.0
	for d in _defs:
		if d.stat == stat:
			total += float(ranks.get(d.id, 0)) * d.value_per_rank
	return total


func summary_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	lines.append("Пассивки — очки: %d (F1-F8 взять)" % points)
	for i in _defs.size():
		var d: NodeDef = _defs[i]
		var cur: int = int(ranks.get(d.id, 0))
		lines.append("F%d %s %d/%d — %s" % [i + 1, d.title, cur, d.max_rank, d.desc])
	return lines
