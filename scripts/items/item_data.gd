class_name ItemData
extends RefCounted

enum Slot { WEAPON, HELMET, BODY, GLOVES, BOOTS, SHIELD, RING, AMULET, BACK }
enum Rarity { NORMAL, MAGIC, RARE, UNIQUE }

var id: StringName = &""
var display_name: String = "Предмет"
var slot: Slot = Slot.WEAPON
var rarity: Rarity = Rarity.NORMAL
var base_damage: float = 0.0
var added_armor: float = 0.0
var added_hp: float = 0.0
var increased_damage: float = 0.0
var color: Color = Color(0.8, 0.8, 0.8)


static func make_weapon(weapon_name: String, dmg: float, rarity: Rarity = Rarity.NORMAL) -> ItemData:
	var item := ItemData.new()
	item.id = StringName(weapon_name.to_snake_case())
	item.display_name = weapon_name
	item.slot = Slot.WEAPON
	item.rarity = rarity
	item.base_damage = dmg
	match rarity:
		Rarity.MAGIC:
			item.increased_damage = 0.1
			item.color = Color(0.35, 0.55, 1.0)
		Rarity.RARE:
			item.increased_damage = 0.25
			item.added_hp = 15.0
			item.color = Color(1.0, 0.85, 0.2)
		Rarity.UNIQUE:
			item.increased_damage = 0.4
			item.added_hp = 30.0
			item.color = Color(0.85, 0.45, 0.15)
		_:
			item.color = Color(0.75, 0.75, 0.75)
	return item


static func make_armor(armor_name: String, armor: float, hp: float, rarity: Rarity = Rarity.NORMAL) -> ItemData:
	var item := ItemData.new()
	item.id = StringName(armor_name.to_snake_case())
	item.display_name = armor_name
	item.slot = Slot.BODY
	item.rarity = rarity
	item.added_armor = armor
	item.added_hp = hp
	item.color = Color(0.45, 0.7, 0.45) if rarity == Rarity.MAGIC else Color(0.6, 0.6, 0.65)
	return item


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
