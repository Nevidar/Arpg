class_name Inventory
extends RefCounted

signal changed

var items: Array[ItemData] = []
var equipped_weapon: ItemData
var equipped_body: ItemData
const MAX_SIZE := 12


func add(item: ItemData) -> bool:
	if items.size() >= MAX_SIZE:
		return false
	items.append(item)
	changed.emit()
	return true


func equip(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	var item: ItemData = items[index]
	match item.slot:
		ItemData.Slot.WEAPON:
			if equipped_weapon != null:
				items.append(equipped_weapon)
			equipped_weapon = item
			items.remove_at(index)
		ItemData.Slot.BODY, ItemData.Slot.HELMET, ItemData.Slot.GLOVES, ItemData.Slot.BOOTS, ItemData.Slot.SHIELD:
			if equipped_body != null:
				items.append(equipped_body)
			equipped_body = item
			items.remove_at(index)
		_:
			pass
	changed.emit()


func summary_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	if equipped_weapon:
		lines.append("Оружие: %s (%s)" % [equipped_weapon.display_name, equipped_weapon.rarity_label()])
	else:
		lines.append("Оружие: кулаки")
	if equipped_body:
		lines.append("Броня: %s (%s)" % [equipped_body.display_name, equipped_body.rarity_label()])
	else:
		lines.append("Броня: нет")
	lines.append("--- инвентарь (1-9 экип) ---")
	for i in mini(items.size(), 9):
		var it: ItemData = items[i]
		lines.append("%d) %s [%s]" % [i + 1, it.display_name, it.rarity_label()])
	if items.is_empty():
		lines.append("(пусто)")
	return lines
