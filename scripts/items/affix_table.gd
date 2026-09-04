class_name AffixTable
extends RefCounted

## Пул аффиксов (~40). T1 сильнее, T9 слабее.


static func all() -> Array[AffixDef]:
	var list: Array[AffixDef] = []
	list.append(_p("ярый", "Ярый", AffixDef.Stat.FLAT_DAMAGE, 8, 1))
	list.append(_p("тяжёлый", "Тяжёлый", AffixDef.Stat.FLAT_DAMAGE, 12, 2))
	list.append(_p("кровожадный", "Кровожадный", AffixDef.Stat.INCREASED_DAMAGE, 0.35, 0.04))
	list.append(_p("свирепый", "Свирепый", AffixDef.Stat.INCREASED_DAMAGE, 0.25, 0.03))
	list.append(_p("живучий", "Живучий", AffixDef.Stat.FLAT_HP, 40, 6))
	list.append(_p("крепкий", "Крепкий", AffixDef.Stat.FLAT_HP, 28, 4))
	list.append(_p("железный", "Железный", AffixDef.Stat.FLAT_ARMOR, 20, 3))
	list.append(_p("кованый", "Кованый", AffixDef.Stat.FLAT_ARMOR, 14, 2))
	list.append(_p("быстрый", "Быстрый", AffixDef.Stat.ATTACK_SPEED, 0.25, 0.03))
	list.append(_p("стремительный", "Стремительный", AffixDef.Stat.MOVE_SPEED, 0.18, 0.03))
	list.append(_p("меткий", "Меткий", AffixDef.Stat.CRIT_CHANCE, 0.12, 0.02))
	list.append(_p("острый", "Острый", AffixDef.Stat.CRIT_MULTI, 0.5, 0.08))
	list.append(_p("пылающий", "Пылающий", AffixDef.Stat.RESIST_FIRE, 0.3, 0.05))
	list.append(_p("морозный", "Морозный", AffixDef.Stat.RESIST_COLD, 0.3, 0.05))
	list.append(_p("искрящийся", "Искрящийся", AffixDef.Stat.RESIST_LIGHTNING, 0.3, 0.05))
	list.append(_p("тёмный", "Тёмный", AffixDef.Stat.RESIST_CHAOS, 0.25, 0.04))
	list.append(_p("плотный", "Плотный", AffixDef.Stat.RESIST_PHYS, 0.2, 0.03))
	list.append(_p("жадный", "Жадный", AffixDef.Stat.LIFE_LEECH, 0.08, 0.01))
	list.append(_p("велесов", "Велесов", AffixDef.Stat.FLAT_DAMAGE, 10, 1.5))
	list.append(_p("перунов", "Перунов", AffixDef.Stat.CRIT_CHANCE, 0.15, 0.025))
	list.append(_p("бережный", "Бережный", AffixDef.Stat.FLAT_HP, 48, 7))

	list.append(_s("силы", "силы", AffixDef.Stat.FLAT_DAMAGE, 6, 1))
	list.append(_s("мощи", "мощи", AffixDef.Stat.INCREASED_DAMAGE, 0.2, 0.03))
	list.append(_s("жизни", "жизни", AffixDef.Stat.FLAT_HP, 35, 5))
	list.append(_s("плоти", "плоти", AffixDef.Stat.FLAT_HP, 22, 4))
	list.append(_s("защиты", "защиты", AffixDef.Stat.FLAT_ARMOR, 16, 2))
	list.append(_s("стены", "стены", AffixDef.Stat.FLAT_ARMOR, 22, 3))
	list.append(_s("ловкости", "ловкости", AffixDef.Stat.MOVE_SPEED, 0.15, 0.02))
	list.append(_s("скорости", "скорости", AffixDef.Stat.ATTACK_SPEED, 0.2, 0.03))
	list.append(_s("точности", "точности", AffixDef.Stat.CRIT_CHANCE, 0.1, 0.015))
	list.append(_s("казни", "казни", AffixDef.Stat.CRIT_MULTI, 0.4, 0.06))
	list.append(_s("маны", "маны", AffixDef.Stat.MANA, 25, 4))
	list.append(_s("духа", "духа", AffixDef.Stat.MANA, 18, 3))
	list.append(_s("блока", "блока", AffixDef.Stat.BLOCK_CHANCE, 0.2, 0.03))
	list.append(_s("огня", "огня", AffixDef.Stat.RESIST_FIRE, 0.25, 0.04))
	list.append(_s("льда", "льда", AffixDef.Stat.RESIST_COLD, 0.25, 0.04))
	list.append(_s("грома", "грома", AffixDef.Stat.RESIST_LIGHTNING, 0.25, 0.04))
	list.append(_s("нави", "нави", AffixDef.Stat.RESIST_CHAOS, 0.22, 0.03))
	list.append(_s("камня", "камня", AffixDef.Stat.RESIST_PHYS, 0.18, 0.03))
	list.append(_s("крови", "крови", AffixDef.Stat.LIFE_LEECH, 0.06, 0.01))
	list.append(_s("яровита", "яровита", AffixDef.Stat.ATTACK_SPEED, 0.22, 0.035))
	list.append(_s("щита", "щита", AffixDef.Stat.BLOCK_CHANCE, 0.24, 0.04))
	return list


static func prefixes() -> Array[AffixDef]:
	var out: Array[AffixDef] = []
	for a in all():
		if a.kind == AffixDef.Kind.PREFIX:
			out.append(a)
	return out


static func suffixes() -> Array[AffixDef]:
	var out: Array[AffixDef] = []
	for a in all():
		if a.kind == AffixDef.Kind.SUFFIX:
			out.append(a)
	return out


static func _p(id: String, name: String, stat: AffixDef.Stat, t1: float, t9: float) -> AffixDef:
	var a := AffixDef.new()
	a.id = StringName(id)
	a.kind = AffixDef.Kind.PREFIX
	a.display_name = name
	a.stat = stat
	a.value_at_t1 = t1
	a.value_at_t9 = t9
	return a


static func _s(id: String, name: String, stat: AffixDef.Stat, t1: float, t9: float) -> AffixDef:
	var a := AffixDef.new()
	a.id = StringName(id)
	a.kind = AffixDef.Kind.SUFFIX
	a.display_name = name
	a.stat = stat
	a.value_at_t1 = t1
	a.value_at_t9 = t9
	return a


static func roll_tier() -> int:
	## Чаще плохие тиры, редко T1
	var r := randf()
	if r < 0.03:
		return 1
	if r < 0.08:
		return 2
	if r < 0.15:
		return 3
	if r < 0.28:
		return 4
	if r < 0.45:
		return 5
	if r < 0.65:
		return 6
	if r < 0.8:
		return 7
	if r < 0.92:
		return 8
	return 9
