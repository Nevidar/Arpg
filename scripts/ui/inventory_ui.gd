class_name InventoryUI
extends Control

## Инвентарь: paper doll как в PoE + сетка сумки + тултип.
## ПКМ по предмету = опознать.

signal closed

const CELL := 36
const SLOT_W := 68
const SLOT_H := 68

var player: CharacterBody2D
var _selected_bag: Dictionary = {}
var _drag_entry: Dictionary = {}
var _panel: PanelContainer
var _grid_host: Control
var _tooltip: RichTextLabel
var _equip_buttons: Dictionary = {}
var _hint: Label
var _last_lmb_ms: int = 0
var _last_lmb_item: ItemData = null
var _craft_target: ItemData = null


func setup(p: CharacterBody2D) -> void:
	player = p
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	player.inventory_changed.connect(refresh)
	refresh()
	visible = false


func toggle() -> void:
	visible = not visible
	if player:
		player.inventory_open = visible
	if visible:
		refresh()
	else:
		closed.emit()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			toggle()
	)

	_panel = PanelContainer.new()
	_panel.position = Vector2(140, 50)
	_panel.custom_minimum_size = Vector2(980, 580)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)

	# --- PoE-like paper doll ---
	var doll_col := VBoxContainer.new()
	doll_col.custom_minimum_size = Vector2(280, 0)
	root.add_child(doll_col)

	var title := Label.new()
	title.text = "Персонаж"
	title.add_theme_font_size_override("font_size", 18)
	doll_col.add_child(title)

	var doll := Control.new()
	doll.custom_minimum_size = Vector2(270, 340)
	doll_col.add_child(doll)

	# Силуэт по центру (подсказка формы тела)
	var silhouette := ColorRect.new()
	silhouette.position = Vector2(102, 90)
	silhouette.size = Vector2(66, 150)
	silhouette.color = Color(0.18, 0.17, 0.22, 0.9)
	silhouette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	doll.add_child(silhouette)

	# Раскладка как в PoE:
	#        [Шлем]
	# [Оружие][Тело][Щит]
	# [Кольцо]      [Амулет]
	# [Перчатки]    [Сапоги]
	_place_slot(doll, ItemData.Slot.HELMET, "Шлем", Vector2(101, 8), Vector2(68, 56))
	_place_slot(doll, ItemData.Slot.WEAPON, "Оружие", Vector2(12, 72), Vector2(72, 110))
	_place_slot(doll, ItemData.Slot.BODY, "Броня", Vector2(101, 72), Vector2(68, 110))
	_place_slot(doll, ItemData.Slot.SHIELD, "Щит", Vector2(186, 72), Vector2(72, 110))
	_place_slot(doll, ItemData.Slot.RING, "Кольцо", Vector2(22, 196), Vector2(52, 52))
	_place_slot(doll, ItemData.Slot.AMULET, "Амулет", Vector2(196, 196), Vector2(52, 52))
	_place_slot(doll, ItemData.Slot.GLOVES, "Перчатки", Vector2(12, 260), Vector2(72, 64))
	_place_slot(doll, ItemData.Slot.BOOTS, "Сапоги", Vector2(186, 260), Vector2(72, 64))

	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(270, 100)
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.text = "ЛКМ — выбрать / перенос\nДвойной ЛКМ — надеть\nПКМ по шмоту — опознать\nПКМ по свитку — крафт на выбранный\nПКМ по слоту — снять\nI / Tab / Esc — закрыть"
	doll_col.add_child(_hint)

	# --- Bag ---
	var bag_col := VBoxContainer.new()
	root.add_child(bag_col)
	var bag_title := Label.new()
	bag_title.text = "Сумка %d×%d" % [Inventory.COLS, Inventory.ROWS]
	bag_title.add_theme_font_size_override("font_size", 18)
	bag_col.add_child(bag_title)

	_grid_host = Control.new()
	_grid_host.custom_minimum_size = Vector2(Inventory.COLS * CELL + 4, Inventory.ROWS * CELL + 4)
	bag_col.add_child(_grid_host)

	# --- Tooltip ---
	var tip_col := VBoxContainer.new()
	tip_col.custom_minimum_size = Vector2(260, 0)
	root.add_child(tip_col)
	var tip_title := Label.new()
	tip_title.text = "Свойства"
	tip_title.add_theme_font_size_override("font_size", 18)
	tip_col.add_child(tip_title)
	_tooltip = RichTextLabel.new()
	_tooltip.bbcode_enabled = true
	_tooltip.fit_content = true
	_tooltip.custom_minimum_size = Vector2(250, 420)
	_tooltip.scroll_active = true
	tip_col.add_child(_tooltip)


func _place_slot(parent: Control, slot: ItemData.Slot, label: String, pos: Vector2, size: Vector2) -> void:
	var box := Control.new()
	box.position = pos
	box.size = size + Vector2(0, 16)
	parent.add_child(box)

	var name_l := Label.new()
	name_l.text = label
	name_l.position = Vector2(0, 0)
	name_l.size = Vector2(size.x, 14)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 10)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_l)

	var btn := Button.new()
	btn.position = Vector2(0, 14)
	btn.size = size
	btn.clip_text = true
	btn.add_theme_font_size_override("font_size", 11)
	btn.pressed.connect(func() -> void: _on_equip_slot_clicked(slot, false))
	btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			_on_equip_slot_clicked(slot, true)
	)
	box.add_child(btn)
	_equip_buttons[int(slot)] = btn


func refresh() -> void:
	if player == null:
		return
	_rebuild_grid()
	_refresh_equip_slots()
	_refresh_tooltip()


func _refresh_equip_slots() -> void:
	for slot_key in _equip_buttons.keys():
		var btn: Button = _equip_buttons[slot_key]
		var eq: ItemData = player.inventory.get_equipped(slot_key)
		if eq:
			var shown: String = eq.display_name
			if shown.length() > 10:
				shown = shown.substr(0, 9) + "…"
			btn.text = "%s\n%s" % [eq.short_label(), shown]
			btn.modulate = eq.color
			btn.tooltip_text = "\n".join(eq.tooltip_lines())
		else:
			btn.text = "—"
			btn.modulate = Color(0.85, 0.85, 0.9)
			btn.tooltip_text = ""


func _rebuild_grid() -> void:
	for c in _grid_host.get_children():
		c.queue_free()

	for y in Inventory.ROWS:
		for x in Inventory.COLS:
			var cell := ColorRect.new()
			cell.position = Vector2(x * CELL, y * CELL)
			cell.size = Vector2(CELL - 2, CELL - 2)
			cell.color = Color(0.12, 0.13, 0.16, 0.95)
			cell.mouse_filter = Control.MOUSE_FILTER_STOP
			var cx := x
			var cy := y
			cell.gui_input.connect(func(ev: InputEvent) -> void: _on_cell_input(ev, cx, cy))
			_grid_host.add_child(cell)

	for e in player.inventory.bag:
		var item: ItemData = e["item"]
		var x: int = e["x"]
		var y: int = e["y"]
		var rect := ColorRect.new()
		rect.position = Vector2(x * CELL, y * CELL)
		rect.size = Vector2(item.grid_w * CELL - 2, item.grid_h * CELL - 2)
		var selected: bool = _selected_bag.get("item", null) == item
		rect.color = Color(item.color.lightened(0.2), 1.0) if selected else Color(item.color, 0.88)
		rect.mouse_filter = Control.MOUSE_FILTER_STOP
		var lab := Label.new()
		lab.text = "?" if not item.identified else item.short_label()
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.set_anchors_preset(Control.PRESET_FULL_RECT)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.add_child(lab)
		var entry: Dictionary = e
		rect.gui_input.connect(func(ev: InputEvent) -> void: _on_item_input(ev, entry))
		_grid_host.add_child(rect)


func _on_item_input(ev: InputEvent, entry: Dictionary) -> void:
	if not (ev is InputEventMouseButton and ev.pressed):
		return
	var item: ItemData = entry["item"]
	if ev.button_index == MOUSE_BUTTON_RIGHT:
		_selected_bag = entry
		# Свиток крафта: ПКМ применяет к выбранному ранее шмоту
		if item.is_currency():
			if item.is_map():
				_spawn_float("Карта: открой устройство карт (M / E у алтаря)")
				return
			var target: ItemData = null
			# если ранее выбран другой предмет — он цель; иначе ищем другой selected через drag
			# цель: любой другой выбранный gear — храним _craft_target
			if _craft_target != null and _craft_target != item:
				target = _craft_target
			elif _drag_entry.get("item", null) != null and _drag_entry["item"] != item and not (_drag_entry["item"] as ItemData).is_currency():
				target = _drag_entry["item"]
			if target == null:
				_spawn_float("Сначала ЛКМ по шмоту, потом ПКМ по свитку")
				_refresh_tooltip()
				refresh()
				return
			var msg := Crafting.apply_scroll(item, target)
			if msg in ["Заговор наложен", "Узы добавлены", "Алхимия свершилась"]:
				player.inventory.remove_item(item)
				Sfx.play_level_up()
			_spawn_float(msg)
			_selected_bag = {}
			_craft_target = target
			refresh()
			_refresh_tooltip_item(target)
			return
		# Обычный предмет: ПКМ = опознать
		if not item.identified:
			if player.inventory.identify_item(item):
				Sfx.play_pickup()
				_spawn_float("Опознано")
		else:
			_spawn_float("Уже опознан")
		_refresh_tooltip()
		refresh()
		return

	if ev.button_index == MOUSE_BUTTON_LEFT:
		var now := Time.get_ticks_msec()
		var is_double := _last_lmb_item == item and (now - _last_lmb_ms) < 350
		_last_lmb_ms = now
		_last_lmb_item = item
		_selected_bag = entry
		_drag_entry = entry
		if not item.is_currency():
			_craft_target = item
		_refresh_tooltip()
		if is_double and item.identified and not item.is_currency():
			player.inventory.equip_from_bag(entry)
			_selected_bag = {}
			_drag_entry = {}
			Sfx.play_pickup()
			_spawn_float("Надето")
		_rebuild_grid()


func _on_cell_input(ev: InputEvent, x: int, y: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var under: Dictionary = player.inventory.get_bag_entry_at(x, y)
		if not under.is_empty():
			_on_item_input(ev, under)
			return
		if not _drag_entry.is_empty():
			if player.inventory.move_bag_item(_drag_entry, x, y):
				_selected_bag = player.inventory.get_bag_entry_at(x, y)
				_drag_entry = _selected_bag
				Sfx.play_swing()
			refresh()


func _on_equip_slot_clicked(slot: ItemData.Slot, right: bool) -> void:
	var eq: ItemData = player.inventory.get_equipped(slot)
	if right:
		# ПКМ по слоту: опознать надетое, иначе снять
		if eq and not eq.identified:
			if player.inventory.identify_item(eq):
				Sfx.play_pickup()
				_spawn_float("Опознано")
				refresh()
			return
		if eq:
			if player.inventory.unequip_slot(slot):
				Sfx.play_pickup()
				refresh()
		return

	if eq:
		_refresh_tooltip_item(eq)
		return
	if not _selected_bag.is_empty():
		var item: ItemData = _selected_bag["item"]
		if item.slot == slot:
			if not item.identified:
				_spawn_float("Сначала опознай (ПКМ)")
				return
			player.inventory.equip_from_bag(_selected_bag)
			_selected_bag = {}
			Sfx.play_pickup()
			refresh()


func _spawn_float(text: String) -> void:
	_hint.text = text + "\n\nЛКМ — выбрать / перенос\nДвойной ЛКМ — надеть\nПКМ по шмоту — опознать\nЛКМ шмот → ПКМ свиток — крафт\nПКМ по слоту — снять\nI / Tab / Esc — закрыть"


func _refresh_tooltip() -> void:
	if not _selected_bag.is_empty():
		_refresh_tooltip_item(_selected_bag["item"])
	else:
		_tooltip.text = "[i]Выбери предмет в сумке или слоте[/i]"


func _refresh_tooltip_item(item: ItemData) -> void:
	var color := item.color.to_html(false)
	var lines := item.tooltip_lines()
	var bb := "[color=#%s][b]%s[/b][/color]\n" % [color, lines[0]]
	for i in range(1, lines.size()):
		bb += lines[i] + "\n"
	if item.identified:
		bb += "\n[i]%dx%d клеток[/i]" % [item.grid_w, item.grid_h]
	else:
		bb += "\n[color=#88aaff]ПКМ — опознать[/color]"
	_tooltip.text = bb


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I or event.keycode == KEY_TAB or event.keycode == KEY_ESCAPE:
			toggle()
			get_viewport().set_input_as_handled()
