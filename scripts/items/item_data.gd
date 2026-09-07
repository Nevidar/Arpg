class_name ItemData
extends RefCounted

const MapsData := preload("res://scripts/world/endgame_maps.gd")

enum Slot { WEAPON, HELMET, BODY, GLOVES, BOOTS, SHIELD, RING, AMULET, BACK, CURRENCY }
enum Rarity { NORMAL, MAGIC, RARE, UNIQUE }

var id: StringName = &""
var base_name: String = "Предмет"
var display_name: String = "Предмет"
var slot: Slot = Slot.WEAPON
var rarity: Rarity = Rarity.NORMAL
var base_damage: float = 0.0
var base_armor: float = 0.0
var color: Color = Color(0.8, 0.8, 0.8)
var identified: bool = true
var prefixes: Array[ItemAffix] = []
var suffixes: Array[ItemAffix] = []
var grid_w: int = 1
var grid_h: int = 1
## Для свитков: transmute / augment / alchemy / regal / scour
var craft_id: StringName = &""
## Для карт эндгейма
var map_id: StringName = &""
var map_tier: int = 0


static func create_base(slot: Slot, base_name: String, base_damage: float = 0.0, base_armor: float = 0.0) -> ItemData:
	var item := ItemData.new()
	item.slot = slot
	item.base_name = base_name
	item.display_name = base_name
	item.id = StringName("%s_%d" % [base_name, randi()])
	item.base_damage = base_damage
	item.base_armor = base_armor
	item.rarity = Rarity.NORMAL
	item.identified = true
	item.color = Color(0.75, 0.75, 0.75)
	item._set_grid_size()
	return item


static func roll_loot(ilvl: int = 1) -> ItemData:
	# Джекпот: уникал (~2%)
	if randf() < 0.02:
		return make_unique_weapon()
	# Иногда свиток крафта
	if randf() < 0.18:
		return roll_scroll()

	var slot_roll := randf()
	var item: ItemData
	if slot_roll < 0.32:
		var names := ["Меч", "Топор", "Двуручный топор", "Молот"]
		item = create_base(Slot.WEAPON, names[randi() % names.size()], 10.0 + ilvl * 0.8 + randf_range(0, 3))
	elif slot_roll < 0.46:
		item = create_base(Slot.BODY, "Нагрудник", 0.0, 6.0 + ilvl * 0.5)
	elif slot_roll < 0.56:
		item = create_base(Slot.HELMET, "Шлем", 0.0, 3.0 + ilvl * 0.3)
	elif slot_roll < 0.66:
		item = create_base(Slot.GLOVES, "Перчатки", 0.0, 2.0 + ilvl * 0.25)
	elif slot_roll < 0.76:
		item = create_base(Slot.BOOTS, "Сапоги", 0.0, 2.0 + ilvl * 0.25)
	elif slot_roll < 0.86:
		item = create_base(Slot.SHIELD, "Щит", 0.0, 8.0 + ilvl * 0.6)
	elif slot_roll < 0.93:
		item = create_base(Slot.RING, "Кольцо", 0.0, 0.0)
	else:
		item = create_base(Slot.AMULET, "Амулет", 0.0, 0.0)

	var r := randf()
	if r > 0.93:
		item.rarity = Rarity.RARE
	elif r > 0.62:
		item.rarity = Rarity.MAGIC
	else:
		item.rarity = Rarity.NORMAL

	item._apply_rarity_affixes()
	return item


static func roll_scroll() -> ItemData:
	var roll := randf()
	if roll < 0.35:
		return make_scroll(&"transmute", "Свиток заговора", "Обычный → магический")
	if roll < 0.60:
		return make_scroll(&"augment", "Свиток уз", "Добавляет аффикс магическому")
	if roll < 0.80:
		return make_scroll(&"alchemy", "Свиток алхимии", "Обычный/маг. → редкий")
	if roll < 0.90:
		return make_scroll(&"regal", "Свиток регала", "Магический → редкий (+1 аффикс)")
	return make_scroll(&"scour", "Свиток очищения", "Маг./редкий → обычный")


static func make_scroll(craft: StringName, name: String, _hint: String) -> ItemData:
	var item := create_base(Slot.CURRENCY, name, 0.0, 0.0)
	item.craft_id = craft
	item.identified = true
	item.color = Color(0.55, 0.35, 0.85)
	item.display_name = name
	return item


static func make_unique_weapon() -> ItemData:
	var item := create_base(Slot.WEAPON, "Секира Велеса", 52.0, 0.0)
	item.rarity = Rarity.UNIQUE
	item.identified = true
	item.color = Color(1.0, 0.55, 0.12) # оранжевый уник
	item.display_name = "Секира Велеса"
	item.prefixes.clear()
	item.suffixes.clear()
	item.grid_w = 2
	item.grid_h = 3
	return item


static func make_map(map_id: StringName, map_name: String, tier: int) -> ItemData:
	var item := create_base(Slot.CURRENCY, map_name, 0.0, 0.0)
	item.map_id = map_id
	item.map_tier = tier
	item.identified = true
	item.color = Color(0.35, 0.75, 0.55)
	item.display_name = "Карта: %s (T%d)" % [map_name, tier]
	item.grid_w = 1
	item.grid_h = 1
	return item


static func roll_map(tier_prefer: int = 1) -> ItemData:
	var bases: Array = MapsData.bases()
	var idx := clampi(tier_prefer - 1 + randi_range(0, 1), 0, bases.size() - 1)
	var b: Dictionary = bases[idx]
	return make_map(b["id"], b["name"], int(b["tier"]))


func _apply_rarity_affixes() -> void:
	prefixes.clear()
	suffixes.clear()
	match rarity:
		Rarity.NORMAL:
			identified = true
			color = Color(0.75, 0.75, 0.75)
			display_name = base_name
		Rarity.MAGIC:
			identified = false
			color = Color(0.35, 0.55, 1.0)
			_add_one_affix(true if randf() < 0.5 else false)
			display_name = "Неопознанный %s" % base_name
		Rarity.RARE:
			identified = false
			color = Color(1.0, 0.85, 0.2)
			var pref_count := randi_range(1, 3)
			var suf_count := randi_range(1, 3)
			for i in pref_count:
				_add_one_affix(true)
			for i in suf_count:
				_add_one_affix(false)
			display_name = "Неопознанный %s" % base_name
		Rarity.UNIQUE:
			identified = true
			color = Color(0.85, 0.45, 0.15)
			_add_one_affix(true)
			_add_one_affix(false)
			_rebuild_name()


func _add_one_affix(as_prefix: bool) -> void:
	var pool: Array[AffixDef] = AffixTable.prefixes() if as_prefix else AffixTable.suffixes()
	var used: Dictionary = {}
	for a in prefixes:
		used[a.def_id] = true
	for a in suffixes:
		used[a.def_id] = true
	var candidates: Array[AffixDef] = []
	for def in pool:
		if not used.has(def.id):
			candidates.append(def)
	if candidates.is_empty():
		return
	var def: AffixDef = candidates[randi() % candidates.size()]
	var rolled := ItemAffix.from_def(def, AffixTable.roll_tier())
	if as_prefix:
		prefixes.append(rolled)
	else:
		suffixes.append(rolled)


func identify() -> bool:
	if identified:
		return false
	identified = true
	_rebuild_name()
	return true


func _rebuild_name() -> void:
	if rarity == Rarity.UNIQUE:
		display_name = base_name
		return
	var pref := ""
	var suf := ""
	if not prefixes.is_empty():
		pref = prefixes[0].display_name + " "
	if not suffixes.is_empty():
		suf = " " + suffixes[0].display_name
	if rarity == Rarity.RARE and (prefixes.size() + suffixes.size()) > 1:
		display_name = "%s%s" % [pref, base_name] if pref != "" else base_name
		if suf != "":
			display_name += suf
	else:
		display_name = "%s%s%s" % [pref, base_name, suf]


func rarity_label() -> String:
	match rarity:
		Rarity.MAGIC:
			return "маг."
		Rarity.RARE:
			return "редк."
		Rarity.UNIQUE:
			return "уник."
		_:
			return "обыч."


func slot_label() -> String:
	match slot:
		Slot.WEAPON:
			return "оружие"
		Slot.HELMET:
			return "шлем"
		Slot.BODY:
			return "нагрудник"
		Slot.GLOVES:
			return "перчатки"
		Slot.BOOTS:
			return "сапоги"
		Slot.SHIELD:
			return "щит"
		_:
			return "предмет"


func tooltip_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	if is_currency():
		lines.append("%s [свиток]" % display_name)
		lines.append(craft_hint())
		lines.append("Выбери шмот, ПКМ по свитку")
		return lines
	lines.append("%s [%s/%s]" % [display_name, rarity_label(), slot_label()])
	if not identified:
		lines.append("Не опознан — ПКМ")
		return lines
	if base_damage > 0.0:
		lines.append("Баз. урон: %.0f" % base_damage)
	if base_armor > 0.0:
		lines.append("Броня: %.0f" % base_armor)
	for a in prefixes:
		lines.append("П: " + a.label())
	for a in suffixes:
		lines.append("С: " + a.label())
	return lines


func accumulate_into(bag: Dictionary) -> void:
	## bag keys = AffixDef.Stat int -> float sum
	if not identified:
		return
	for a in prefixes:
		_acc(bag, a)
	for a in suffixes:
		_acc(bag, a)


func _acc(bag: Dictionary, a: ItemAffix) -> void:
	var key := int(a.stat)
	bag[key] = float(bag.get(key, 0.0)) + a.value


func _set_grid_size() -> void:
	## Размеры в духе PoE/D2
	match slot:
		Slot.WEAPON:
			if "Двуручный" in base_name or base_name == "Молот":
				grid_w = 2
				grid_h = 3
			else:
				grid_w = 1
				grid_h = 3
		Slot.BODY:
			grid_w = 2
			grid_h = 3
		Slot.SHIELD:
			grid_w = 2
			grid_h = 3
		Slot.HELMET, Slot.GLOVES, Slot.BOOTS:
			grid_w = 2
			grid_h = 2
		Slot.RING:
			grid_w = 1
			grid_h = 1
		Slot.AMULET:
			grid_w = 1
			grid_h = 1
		Slot.BACK:
			grid_w = 2
			grid_h = 2
		Slot.CURRENCY:
			grid_w = 1
			grid_h = 1
		_:
			grid_w = 1
			grid_h = 1


func short_label() -> String:
	if not identified:
		return "?"
	match slot:
		Slot.WEAPON:
			return "W"
		Slot.HELMET:
			return "H"
		Slot.BODY:
			return "B"
		Slot.GLOVES:
			return "G"
		Slot.BOOTS:
			return "F"
		Slot.SHIELD:
			return "S"
		Slot.RING:
			return "R"
		Slot.AMULET:
			return "A"
		Slot.CURRENCY:
			return "M" if map_id != &"" else "C"
		_:
			return "."


func is_currency() -> bool:
	return slot == Slot.CURRENCY


func is_map() -> bool:
	return map_id != &""


func is_unique() -> bool:
	return rarity == Rarity.UNIQUE


func craft_hint() -> String:
	match String(craft_id):
		"transmute":
			return "Обычный → магический (1 аффикс)"
		"augment":
			return "Магический: добавить преф или суфф"
		"alchemy":
			return "Обычный/маг. → редкий"
		"regal":
			return "Магический → редкий (+1 аффикс)"
		"scour":
			return "Маг./редкий → обычный (смыть аффиксы)"
		_:
			return ""


func to_save_data() -> Dictionary:
	return {
		"id": String(id),
		"base_name": base_name,
		"display_name": display_name,
		"slot": int(slot),
		"rarity": int(rarity),
		"base_damage": base_damage,
		"base_armor": base_armor,
		"color": [color.r, color.g, color.b, color.a],
		"identified": identified,
		"grid_w": grid_w,
		"grid_h": grid_h,
		"craft_id": String(craft_id),
		"map_id": String(map_id),
		"map_tier": map_tier,
		"prefixes": _affixes_to_save(prefixes),
		"suffixes": _affixes_to_save(suffixes),
	}


static func from_save_data(data: Dictionary) -> ItemData:
	var item := ItemData.new()
	item.id = StringName(str(data.get("id", "item_%d" % randi())))
	item.base_name = str(data.get("base_name", "Предмет"))
	item.display_name = str(data.get("display_name", item.base_name))
	item.slot = int(data.get("slot", Slot.WEAPON)) as Slot
	item.rarity = int(data.get("rarity", Rarity.NORMAL)) as Rarity
	item.base_damage = float(data.get("base_damage", 0.0))
	item.base_armor = float(data.get("base_armor", 0.0))
	var saved_color = data.get("color", [])
	if saved_color is Array and saved_color.size() == 4:
		item.color = Color(float(saved_color[0]), float(saved_color[1]), float(saved_color[2]), float(saved_color[3]))
	item.identified = bool(data.get("identified", true))
	item.grid_w = int(data.get("grid_w", 1))
	item.grid_h = int(data.get("grid_h", 1))
	item.craft_id = StringName(str(data.get("craft_id", "")))
	item.map_id = StringName(str(data.get("map_id", "")))
	item.map_tier = int(data.get("map_tier", 0))
	item.prefixes = _affixes_from_save(data.get("prefixes", []))
	item.suffixes = _affixes_from_save(data.get("suffixes", []))
	return item


static func _affixes_to_save(affixes: Array[ItemAffix]) -> Array:
	var saved: Array = []
	for affix in affixes:
		saved.append({
			"def_id": String(affix.def_id),
			"kind": int(affix.kind),
			"display_name": affix.display_name,
			"stat": int(affix.stat),
			"tier": affix.tier,
			"value": affix.value,
		})
	return saved


static func _affixes_from_save(saved: Variant) -> Array[ItemAffix]:
	var affixes: Array[ItemAffix] = []
	if not saved is Array:
		return affixes
	for raw in saved:
		if not raw is Dictionary:
			continue
		var affix := ItemAffix.new()
		affix.def_id = StringName(str(raw.get("def_id", "")))
		affix.kind = int(raw.get("kind", AffixDef.Kind.PREFIX)) as AffixDef.Kind
		affix.display_name = str(raw.get("display_name", "Аффикс"))
		affix.stat = int(raw.get("stat", AffixDef.Stat.FLAT_DAMAGE)) as AffixDef.Stat
		affix.tier = int(raw.get("tier", 5))
		affix.value = float(raw.get("value", 0.0))
		affixes.append(affix)
	return affixes
