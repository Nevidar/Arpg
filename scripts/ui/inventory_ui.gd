class_name InventoryUI
extends Control

## UI инвентаря: paper doll (Diablo/HS) + сетка (PoE/D2) + тултип.

signal closed

const CELL := 36

var player: CharacterBody2D
var _selected_bag: Dictionary = {}
var _drag_entry: Dictionary = {}
var _panel: PanelContainer
var _grid_host: Control
var _tooltip: RichTextLabel
var _equip_buttons: Dictionary = {}
var _hint: Label


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
	_panel.position = Vector2(180, 70)
	_panel.custom_minimum_size = Vector2(920, 560)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var doll := VBoxContainer.new()
	doll.custom_minimum_size = Vector2(220, 0)
	root.add_child(doll)
	var title := Label.new()
	title.text = "Экипировка"
	title.add_theme_font_size_override("font_size", 18)
	doll.add_child(title)

	var grid_doll := GridContainer.new()
	grid_doll.columns = 3
	grid_doll.add_theme_constant_override("h_separation", 8)
	grid_doll.add_theme_constant_override("v_separation", 8)
	doll.add_child(grid_doll)

	_add_equip_slot(grid_doll, ItemData.Slot.HELMET, "Шлем")
	_add_equip_slot(grid_doll, ItemData.Slot.WEAPON, "Оружие")
	_add_equip_slot(grid_doll, ItemData.Slot.SHIELD, "Щит")
	_add_equip_slot(grid_doll, ItemData.Slot.BODY, "Тело")
	_add_equip_slot(grid_doll, ItemData.Slot.GLOVES, "Перчатки")
	_add_equip_slot(grid_doll, ItemData.Slot.BOOTS, "Сапоги")

	var id_btn := Button.new()
	id_btn.text = "Опознать (I)"
	id_btn.pressed.connect(_on_identify_pressed)
	doll.add_child(id_btn)

	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(210, 90)
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.text = "ЛКМ выбрать\nПКМ экип/снять\nКлик по клетке = перенос\nTab/I/Esc закрыть"
	doll.add_child(_hint)

	var bag_col := VBoxContainer.new()
	root.add_child(bag_col)
	var bag_title := Label.new()
	bag_title.text = "Сумка %d×%d" % [Inventory.COLS, Inventory.ROWS]
	bag_title.add_theme_font_size_override("font_size", 18)
	bag_col.add_child(bag_title)

	_grid_host = Control.new()
	_grid_host.custom_minimum_size = Vector2(Inventory.COLS * CELL + 4, Inventory.ROWS * CELL + 4)
	bag_col.add_child(_grid_host)

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


func _add_equip_slot(parent: GridContainer, slot: ItemData.Slot, label: String) -> void:
	var box := VBoxContainer.new()
	var name_l := Label.new()
	name_l.text = label
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 11)
	box.add_child(name_l)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(64, 64)
	btn.clip_text = true
	btn.pressed.connect(func() -> void: _on_equip_slot_clicked(slot, false))
	btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			_on_equip_slot_clicked(slot, true)
	)
	box.add_child(btn)
	parent.add_child(box)
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
			btn.text = eq.short_label() + "\n" + eq.display_name.substr(0, 8)
			btn.modulate = eq.color
			btn.tooltip_text = "\n".join(eq.tooltip_lines())
		else:
			btn.text = "—"
			btn.modulate = Color(1, 1, 1)
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
		lab.text = item.short_label()
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.set_anchors_preset(Control.PRESET_FULL_RECT)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.add_child(lab)
		var entry: Dictionary = e
		rect.gui_input.connect(func(ev: InputEvent) -> void: _on_item_input(ev, entry))
		_grid_host.add_child(rect)


func _on_item_input(ev: InputEvent, entry: Dictionary) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			_selected_bag = entry
			_drag_entry = entry
			_refresh_tooltip()
			_rebuild_grid()
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			player.inventory.equip_from_bag(entry)
			_selected_bag = {}
			Sfx.play_pickup()
			refresh()


func _on_cell_input(ev: InputEvent, x: int, y: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var under: Dictionary = player.inventory.get_bag_entry_at(x, y)
		if not under.is_empty():
			_selected_bag = under
			_drag_entry = under
			_refresh_tooltip()
			_rebuild_grid()
			return
		if not _drag_entry.is_empty():
			if player.inventory.move_bag_item(_drag_entry, x, y):
				_selected_bag = player.inventory.get_bag_entry_at(x, y)
				_drag_entry = _selected_bag
				Sfx.play_swing()
			refresh()


func _on_equip_slot_clicked(slot: ItemData.Slot, right: bool) -> void:
	var eq: ItemData = player.inventory.get_equipped(slot)
	if eq:
		_refresh_tooltip_item(eq)
		if right:
			if player.inventory.unequip_slot(slot):
				Sfx.play_pickup()
				refresh()
		return
	if not _selected_bag.is_empty():
		var item: ItemData = _selected_bag["item"]
		if item.slot == slot:
			player.inventory.equip_from_bag(_selected_bag)
			_selected_bag = {}
			Sfx.play_pickup()
			refresh()


func _on_identify_pressed() -> void:
	if not _selected_bag.is_empty():
		var item: ItemData = _selected_bag["item"]
		if player.inventory.identify_item(item):
			Sfx.play_pickup()
			refresh()
			return
	if player.inventory.identify_first():
		Sfx.play_pickup()
		refresh()


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
	_tooltip.text = bb


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I or event.keycode == KEY_TAB or event.keycode == KEY_ESCAPE:
			toggle()
			get_viewport().set_input_as_handled()
