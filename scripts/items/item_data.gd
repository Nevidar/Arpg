class_name ItemData
extends RefCounted

enum Slot { WEAPON, HELMET, BODY, GLOVES, BOOTS, SHIELD, RING, AMULET, BACK }
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
	return item


static func roll_loot(ilvl: int = 1) -> ItemData:
	var slot_roll := randf()
	var item: ItemData
	if slot_roll < 0.35:
		var names := ["Меч", "Топор", "Двуручный топор", "Молот"]
		item = create_base(Slot.WEAPON, names[randi() % names.size()], 10.0 + ilvl * 0.8 + randf_range(0, 3))
	elif slot_roll < 0.5:
		item = create_base(Slot.BODY, "Нагрудник", 0.0, 6.0 + ilvl * 0.5)
	elif slot_roll < 0.62:
		item = create_base(Slot.HELMET, "Шлем", 0.0, 3.0 + ilvl * 0.3)
	elif slot_roll < 0.74:
		item = create_base(Slot.GLOVES, "Перчатки", 0.0, 2.0 + ilvl * 0.25)
	elif slot_roll < 0.86:
		item = create_base(Slot.BOOTS, "Сапоги", 0.0, 2.0 + ilvl * 0.25)
	else:
		item = create_base(Slot.SHIELD, "Щит", 0.0, 8.0 + ilvl * 0.6)

	var r := randf()
	if r > 0.93:
		item.rarity = Rarity.RARE
	elif r > 0.62:
		item.rarity = Rarity.MAGIC
	else:
		item.rarity = Rarity.NORMAL

	item._apply_rarity_affixes()
	return item


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
	lines.append("%s [%s/%s]" % [display_name, rarity_label(), slot_label()])
	if not identified:
		lines.append("Не опознан (I)")
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
