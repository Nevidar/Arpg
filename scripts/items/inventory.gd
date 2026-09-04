class_name Inventory
extends RefCounted

## Сетка сумки как PoE/D2 + слоты экипа как Diablo/Hero Siege.

signal changed

const COLS := 10
const ROWS := 6

var equipped: Dictionary = {} ## Slot int -> ItemData
## { "item": ItemData, "x": int, "y": int }
var bag: Array[Dictionary] = []


func add(item: ItemData) -> bool:
	item._set_grid_size()
	var spot := _find_free(item.grid_w, item.grid_h)
	if spot.x < 0:
		return false
	bag.append({"item": item, "x": spot.x, "y": spot.y})
	changed.emit()
	return true


func get_equipped(slot) -> ItemData:
	return equipped.get(int(slot), null)


func all_equipped() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for slot_key in equipped.keys():
		var eq: ItemData = equipped[slot_key]
		if eq:
			out.append(eq)
	return out


func get_bag_entry_at(cell_x: int, cell_y: int) -> Dictionary:
	for e in bag:
		var item: ItemData = e["item"]
		var x: int = e["x"]
		var y: int = e["y"]
		if cell_x >= x and cell_x < x + item.grid_w and cell_y >= y and cell_y < y + item.grid_h:
			return e
	return {}


func equip_from_bag(entry: Dictionary) -> bool:
	if entry.is_empty():
		return false
	var item: ItemData = entry["item"]
	var ox: int = entry["x"]
	var oy: int = entry["y"]
	var slot_key := int(item.slot)
	var old: ItemData = equipped.get(slot_key, null)
	_remove_by_item(item)
	if old != null:
		old._set_grid_size()
		var placed := false
		if _can_place(old.grid_w, old.grid_h, ox, oy, item):
			bag.append({"item": old, "x": ox, "y": oy})
			placed = true
		else:
			var spot := _find_free(old.grid_w, old.grid_h, item)
			if spot.x >= 0:
				bag.append({"item": old, "x": spot.x, "y": spot.y})
				placed = true
		if not placed:
			bag.append({"item": item, "x": ox, "y": oy})
			changed.emit()
			return false
	equipped[slot_key] = item
	changed.emit()
	return true


func unequip_slot(slot) -> bool:
	var slot_key := int(slot)
	var eq: ItemData = equipped.get(slot_key, null)
	if eq == null:
		return false
	eq._set_grid_size()
	var spot := _find_free(eq.grid_w, eq.grid_h)
	if spot.x < 0:
		return false
	bag.append({"item": eq, "x": spot.x, "y": spot.y})
	equipped.erase(slot_key)
	changed.emit()
	return true


func move_bag_item(entry: Dictionary, new_x: int, new_y: int) -> bool:
	if entry.is_empty():
		return false
	var item: ItemData = entry["item"]
	var ox: int = entry["x"]
	var oy: int = entry["y"]
	_remove_by_item(item)
	if _can_place(item.grid_w, item.grid_h, new_x, new_y):
		bag.append({"item": item, "x": new_x, "y": new_y})
		changed.emit()
		return true
	bag.append({"item": item, "x": ox, "y": oy})
	changed.emit()
	return false


func identify_item(item: ItemData) -> bool:
	if item and item.identify():
		changed.emit()
		return true
	return false


func identify_first() -> bool:
	for e in bag:
		var item: ItemData = e["item"]
		if item.identify():
			changed.emit()
			return true
	for eq in all_equipped():
		if eq.identify():
			changed.emit()
			return true
	return false


func occupied_map(ignore: ItemData = null) -> Dictionary:
	var map := {}
	for e in bag:
		var item: ItemData = e["item"]
		if item == ignore:
			continue
		for dx in item.grid_w:
			for dy in item.grid_h:
				map["%d,%d" % [e["x"] + dx, e["y"] + dy]] = item
	return map


func summary_lines() -> PackedStringArray:
	return PackedStringArray([
		"Сумка %dx%d | вещей: %d" % [COLS, ROWS, bag.size()],
		"I / Tab — инвентарь"
	])


func _remove_by_item(item: ItemData) -> void:
	for i in range(bag.size() - 1, -1, -1):
		if bag[i]["item"] == item:
			bag.remove_at(i)
			return


func _find_free(w: int, h: int, ignore: ItemData = null) -> Vector2i:
	for y in ROWS:
		for x in COLS:
			if _can_place(w, h, x, y, ignore):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _can_place(w: int, h: int, x: int, y: int, ignore: ItemData = null) -> bool:
	if x < 0 or y < 0 or x + w > COLS or y + h > ROWS:
		return false
	var occ := occupied_map(ignore)
	for dx in w:
		for dy in h:
			if occ.has("%d,%d" % [x + dx, y + dy]):
				return false
	return true
