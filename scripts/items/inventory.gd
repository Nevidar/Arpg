class_name Inventory
extends RefCounted

signal changed

var items: Array[ItemData] = []
var equipped: Dictionary = {} ## Slot int -> ItemData
const MAX_SIZE := 16


func add(item: ItemData) -> bool:
	if items.size() >= MAX_SIZE:
		return false
	items.append(item)
	changed.emit()
	return true


func get_equipped(slot: ItemData.Slot) -> ItemData:
	return equipped.get(int(slot), null)


func equip(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	var item: ItemData = items[index]
	var slot_key := int(item.slot)
	if equipped.has(slot_key) and equipped[slot_key] != null:
		items.append(equipped[slot_key])
	equipped[slot_key] = item
	items.remove_at(index)
	changed.emit()


func identify_first() -> bool:
	for item in items:
		if item.identify():
			changed.emit()
			return true
	for slot_key in equipped.keys():
		var eq: ItemData = equipped[slot_key]
		if eq and eq.identify():
			changed.emit()
			return true
	return false


func all_equipped() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for slot_key in equipped.keys():
		var eq: ItemData = equipped[slot_key]
		if eq:
			out.append(eq)
	return out


func summary_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	var order := [
		ItemData.Slot.WEAPON, ItemData.Slot.SHIELD, ItemData.Slot.HELMET,
		ItemData.Slot.BODY, ItemData.Slot.GLOVES, ItemData.Slot.BOOTS
	]
	for slot in order:
		var eq := get_equipped(slot)
		var label := _slot_name(slot)
		if eq:
			lines.append("%s: %s (%s)" % [label, eq.display_name, eq.rarity_label()])
		else:
			lines.append("%s: —" % label)
	lines.append("--- сумка (1-9 экип, I опознать) ---")
	for i in mini(items.size(), 9):
		var it: ItemData = items[i]
		var mark := "?" if not it.identified else it.rarity_label()
		lines.append("%d) %s [%s]" % [i + 1, it.display_name, mark])
	if items.is_empty():
		lines.append("(пусто)")
	return lines


func _slot_name(slot: ItemData.Slot) -> String:
	match slot:
		ItemData.Slot.WEAPON:
			return "Оружие"
		ItemData.Slot.SHIELD:
			return "Щит"
		ItemData.Slot.HELMET:
			return "Шлем"
		ItemData.Slot.BODY:
			return "Тело"
		ItemData.Slot.GLOVES:
			return "Перчатки"
		ItemData.Slot.BOOTS:
			return "Сапоги"
		_:
			return "Слот"
