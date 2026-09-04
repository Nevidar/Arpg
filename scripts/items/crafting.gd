class_name Crafting
extends RefCounted

## Свитки заговоров (упрощённый PoE-крафт).


static func apply_scroll(scroll: ItemData, target: ItemData) -> String:
	if scroll == null or target == null:
		return "Нет цели"
	if scroll.is_map() or String(scroll.craft_id) == "":
		return "Это не свиток"
	if target.is_currency():
		return "Нельзя на свиток"
	if not target.identified and String(scroll.craft_id) != "alchemy":
		# alchemy тоже лучше на опознанном, но разрешим после авто-id
		target.identify()

	match String(scroll.craft_id):
		"transmute":
			if target.rarity != ItemData.Rarity.NORMAL:
				return "Нужен обычный предмет"
			target.rarity = ItemData.Rarity.MAGIC
			target.prefixes.clear()
			target.suffixes.clear()
			target._add_one_affix(randf() < 0.5)
			target.identified = true
			target.color = Color(0.35, 0.55, 1.0)
			target._rebuild_name()
			return "Заговор наложен"
		"augment":
			if target.rarity != ItemData.Rarity.MAGIC:
				return "Нужен магический предмет"
			var has_p := not target.prefixes.is_empty()
			var has_s := not target.suffixes.is_empty()
			if has_p and has_s:
				return "Уже 2 аффикса"
			target._add_one_affix(not has_p) # добавить недостающий тип
			target._rebuild_name()
			return "Узы добавлены"
		"alchemy":
			if target.rarity == ItemData.Rarity.RARE or target.rarity == ItemData.Rarity.UNIQUE:
				return "Уже редкий/уник"
			target.rarity = ItemData.Rarity.RARE
			target.prefixes.clear()
			target.suffixes.clear()
			for i in randi_range(1, 3):
				target._add_one_affix(true)
			for i in randi_range(1, 3):
				target._add_one_affix(false)
			target.identified = true
			target.color = Color(1.0, 0.85, 0.2)
			target._rebuild_name()
			return "Алхимия свершилась"
		_:
			return "Неизвестный свиток"
