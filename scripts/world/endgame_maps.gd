class_name EndgameMaps
extends RefCounted

## Минимальный эндгейм: 3 базы карт + пул модов.


static func bases() -> Array:
	return [
		{
			"id": &"kurgan",
			"name": "Курганный круг",
			"tier": 1,
			"ilvl": 16,
			"enemy_bonus": 0,
			"boss_name": "Курганный страж",
			"flavor": "Камни помнят кровь. Карта открывает круг снова и снова.",
			"bg": Color(0.2, 0.16, 0.1),
			"floor": Color(0.42, 0.34, 0.16),
		},
		{
			"id": &"ice_path",
			"name": "Ледяная тропа",
			"tier": 2,
			"ilvl": 18,
			"enemy_bonus": 4,
			"boss_name": "Страж зимы",
			"flavor": "Холод режет быстрее клинка. Не стой на месте.",
			"bg": Color(0.1, 0.14, 0.26),
			"floor": Color(0.2, 0.3, 0.48),
		},
		{
			"id": &"whisper",
			"name": "Низина шёпота",
			"tier": 3,
			"ilvl": 20,
			"enemy_bonus": 8,
			"boss_name": "Шёпот Нави",
			"flavor": "Голоса зовут глубже. Эндгейм только начинается.",
			"bg": Color(0.12, 0.08, 0.18),
			"floor": Color(0.28, 0.16, 0.36),
		},
	]


static func mods() -> Array:
	return [
		{"id": &"cruel", "name": "Жестокость", "desc": "Враги +25% урона", "dmg": 0.25},
		{"id": &"vital", "name": "Живучесть", "desc": "Враги +40% HP", "hp": 0.4},
		{"id": &"swift", "name": "Скорость", "desc": "Враги +20% скорости", "move": 0.2},
		{"id": &"dense", "name": "Плотность", "desc": "+12 врагов", "extra_enemies": 12},
		{"id": &"armour", "name": "Броня", "desc": "Враги +20 брони", "armor": 20.0},
		{"id": &"rage", "name": "Ярость", "desc": "+15% урона и +10% скорости", "dmg": 0.15, "move": 0.1},
		{"id": &"wealth", "name": "Богатство", "desc": "×2 золото", "gold_mult": 2.0},
		{"id": &"wisdom", "name": "Мудрость", "desc": "×1.5 опыт", "xp_mult": 1.5},
		{"id": &"pack", "name": "Стая", "desc": "Больше дальнобойных", "ranged_bias": true},
		{"id": &"titan", "name": "Титан", "desc": "Танки +50% HP", "tank_hp": 0.5},
	]


static func base_by_id(id: StringName) -> Dictionary:
	for b in bases():
		if b["id"] == id:
			return b
	return bases()[0]


static func roll_map_mods(tier: int) -> Array:
	var pool: Array = mods().duplicate()
	pool.shuffle()
	var count := clampi(1 + tier, 1, 3)
	var picked: Array = []
	for i in count:
		picked.append(pool[i])
	return picked


static func sum_extra_enemies(active_mods: Array) -> int:
	var n := 0
	for m in active_mods:
		n += int(m.get("extra_enemies", 0))
	return n


static func gold_mult(active_mods: Array) -> float:
	var mult := 1.0
	for m in active_mods:
		mult *= float(m.get("gold_mult", 1.0))
	return mult


static func xp_mult(active_mods: Array) -> float:
	var mult := 1.0
	for m in active_mods:
		mult *= float(m.get("xp_mult", 1.0))
	return mult


static func apply_to_enemy(enemy: CharacterBody2D, active_mods: Array) -> void:
	for m in active_mods:
		if m.has("hp"):
			enemy.stats.max_hp *= 1.0 + float(m["hp"])
		if m.has("dmg"):
			enemy.stats.base_damage *= 1.0 + float(m["dmg"])
		if m.has("move"):
			enemy.stats.move_speed *= 1.0 + float(m["move"])
		if m.has("armor"):
			enemy.stats.armor += float(m["armor"])
		if m.has("tank_hp") and int(enemy.kind) == 2: # EnemyKind.TANK
			enemy.stats.max_hp *= 1.0 + float(m["tank_hp"])
	enemy.stats.hp = enemy.stats.max_hp


static func has_ranged_bias(active_mods: Array) -> bool:
	for m in active_mods:
		if bool(m.get("ranged_bias", false)):
			return true
	return false


static func mods_label(active_mods: Array) -> String:
	if active_mods.is_empty():
		return "без модов"
	var parts: PackedStringArray = []
	for m in active_mods:
		parts.append(str(m["name"]))
	return ", ".join(parts)
