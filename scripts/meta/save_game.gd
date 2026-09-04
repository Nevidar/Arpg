class_name SaveGame
extends RefCounted

## Простое сохранение персонажа (user://nevidar_save.cfg).
## Анти-дюп заглушка: у предметов есть instance_id, дубликаты в сейве отбрасываются.


const PATH := "user://nevidar_save.cfg"


static func save_player(player: CharacterBody2D, meta: Dictionary = {}) -> bool:
	if player == null:
		return false
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 1)
	cfg.set_value("meta", "saved_at", Time.get_unix_time_from_system())
	cfg.set_value("meta", "endgame_unlocked", bool(meta.get("endgame_unlocked", false)))
	cfg.set_value("meta", "atlas", meta.get("atlas", {}))
	cfg.set_value("meta", "zone_index", int(meta.get("zone_index", 0)))
	cfg.set_value("player", "gold", player.gold)
	cfg.set_value("player", "level", player.progress.level)
	cfg.set_value("player", "xp", player.progress.xp)
	cfg.set_value("player", "strength", player.progress.strength)
	cfg.set_value("player", "dexterity", player.progress.dexterity)
	cfg.set_value("player", "intelligence", player.progress.intelligence)
	cfg.set_value("player", "passive_points", player.passives.points)
	cfg.set_value("player", "passive_ranks", player.passives.ranks.duplicate())
	# Инвентарь — только id/имена для MVP (без полной сериализации аффиксов)
	var bag_simple: Array = []
	var seen: Dictionary = {}
	for e in player.inventory.bag:
		var it: ItemData = e["item"]
		var iid := str(it.id)
		if seen.has(iid):
			continue # анти-дюп: один instance id
		seen[iid] = true
		bag_simple.append({
			"id": iid,
			"name": it.display_name,
			"slot": int(it.slot),
			"map_id": String(it.map_id),
			"map_tier": it.map_tier,
			"craft_id": String(it.craft_id),
			"base_damage": it.base_damage,
			"rarity": int(it.rarity),
			"unique": it.is_unique() if it.has_method("is_unique") else false,
		})
	cfg.set_value("player", "bag", bag_simple)
	return cfg.save(PATH) == OK


static func load_into(player: CharacterBody2D) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return {}
	player.gold = int(cfg.get_value("player", "gold", player.gold))
	player.progress.level = int(cfg.get_value("player", "level", 1))
	player.progress.xp = int(cfg.get_value("player", "xp", 0))
	player.progress.strength = float(cfg.get_value("player", "strength", player.progress.strength))
	player.progress.dexterity = float(cfg.get_value("player", "dexterity", player.progress.dexterity))
	player.progress.intelligence = float(cfg.get_value("player", "intelligence", player.progress.intelligence))
	player.passives.points = int(cfg.get_value("player", "passive_points", player.passives.points))
	var ranks = cfg.get_value("player", "passive_ranks", {})
	if ranks is Dictionary:
		player.passives.ranks = ranks.duplicate()
	player.passives.changed.emit()
	player.progress_changed.emit()
	player.gold_changed.emit(player.gold)
	# Карты/свитки из сейва — упрощённо восстанавливаем
	var bag = cfg.get_value("player", "bag", [])
	if bag is Array:
		for entry in bag:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var mid := StringName(str(entry.get("map_id", "")))
			var cid := StringName(str(entry.get("craft_id", "")))
			if mid != &"":
				player.try_pickup(ItemData.make_map(mid, str(entry.get("name", "Карта")).replace("Карта: ", "").split(" (")[0], int(entry.get("map_tier", 1))))
			elif cid != &"":
				player.try_pickup(ItemData.make_scroll(cid, str(entry.get("name", "Свиток")), ""))
			elif bool(entry.get("unique", false)):
				player.try_pickup(ItemData.make_unique_weapon())
	return {
		"endgame_unlocked": bool(cfg.get_value("meta", "endgame_unlocked", false)),
		"atlas": cfg.get_value("meta", "atlas", {}),
		"zone_index": int(cfg.get_value("meta", "zone_index", 0)),
	}


static func exists() -> bool:
	return FileAccess.file_exists(PATH)
