extends Node2D

## Кампания + минимальный эндгейм (карты / моды / хаб).

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const CampaignData := preload("res://scripts/world/campaign.gd")
const MapsData := preload("res://scripts/world/endgame_maps.gd")

const SaveData := preload("res://scripts/meta/save_game.gd")

const MAP_W := 2800.0
const MAP_H := 1700.0
const MAP_ORIGIN := Vector2(80, 60)
const HUB_W := 1400.0
const HUB_H := 900.0
const ENEMY_COUNT_MIN := 42
const ENEMY_COUNT_MAX := 50

@onready var _world: Node2D = $World
@onready var _hud_root: Control = $HUD/Root
@onready var _hp_label: Label = $HUD/Root/HpLabel
@onready var _hint_label: Label = $HUD/Root/HintLabel
@onready var _wave_label: Label = $HUD/Root/WaveLabel
@onready var _stats_label: Label = $HUD/Root/StatsLabel
@onready var _inv_label: Label = $HUD/Root/InvLabel
@onready var _passive_label: Label = $HUD/Root/PassiveLabel
@onready var _floor: Polygon2D = $Floor
@onready var _background: Polygon2D = $Background

var _zones: Array = []
var player: CharacterBody2D
var inventory_ui: InventoryUI
var _zone_index: int = 0
var _alive_enemies: int = 0
var _loot_nodes: Array[Node2D] = []
var _zone_clear: bool = false
var _portal: Area2D
var _exit_marker: Node2D
var _flavor_label: Label
var _gold_label: Label
var _act_label: Label
var _merchant: Node2D
var _map_device: Node2D
var _map_panel: Control
var _map_list: VBoxContainer
var _map_rect: Rect2
var _entry_pos: Vector2
var _exit_pos: Vector2
var _transitioning: bool = false

var _run_mode: StringName = &"campaign" ## campaign | hub | map
var _endgame_unlocked: bool = false
var _active_map: Dictionary = {}
var _active_mods: Array = []
var _reward_gold_mult: float = 1.0
var _reward_xp_mult: float = 1.0
var _atlas: Dictionary = {} ## map_id -> true
var _exit_arrow: Label
var _fade: ColorRect
var _side_portal: Area2D
var _merchant_stock: Array = []


func _ready() -> void:
	_zones = CampaignData.zones()
	_hint_label.text = "WASD | колёсико зум | I инв | M карты | F5 сейв | F6 загруз | F9/F10 | R"
	_ensure_extra_labels()
	_build_map_panel()
	_build_fade_and_arrow()
	_spawn_player()
	if SaveData.exists():
		var meta: Dictionary = SaveData.load_into(player)
		_endgame_unlocked = bool(meta.get("endgame_unlocked", false))
		_atlas = meta.get("atlas", {})
		if typeof(_atlas) != TYPE_DICTIONARY:
			_atlas = {}
	_enter_zone(0)


func _ensure_extra_labels() -> void:
	_gold_label = Label.new()
	_gold_label.position = Vector2(16, 140)
	_gold_label.size = Vector2(280, 24)
	_gold_label.add_theme_font_size_override("font_size", 16)
	_hud_root.add_child(_gold_label)

	_act_label = Label.new()
	_act_label.position = Vector2(400, 12)
	_act_label.size = Vector2(560, 28)
	_act_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_act_label.add_theme_font_size_override("font_size", 16)
	_act_label.modulate = Color(0.85, 0.75, 0.55)
	_hud_root.add_child(_act_label)

	_flavor_label = Label.new()
	_flavor_label.position = Vector2(16, 620)
	_flavor_label.size = Vector2(900, 40)
	_flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flavor_label.add_theme_font_size_override("font_size", 13)
	_flavor_label.modulate = Color(0.75, 0.7, 0.65)
	_hud_root.add_child(_flavor_label)


func _build_fade_and_arrow() -> void:
	_exit_arrow = Label.new()
	_exit_arrow.position = Vector2(560, 48)
	_exit_arrow.size = Vector2(200, 28)
	_exit_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exit_arrow.add_theme_font_size_override("font_size", 18)
	_exit_arrow.modulate = Color(0.55, 0.85, 1.0)
	_exit_arrow.text = "→ ВЫХОД"
	_hud_root.add_child(_exit_arrow)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.z_index = 80
	_hud_root.add_child(_fade)


func _build_map_panel() -> void:
	_map_panel = Control.new()
	_map_panel.visible = false
	_map_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud_root.add_child(_map_panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_panel.add_child(dim)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_close_map_panel()
	)

	var panel := PanelContainer.new()
	panel.position = Vector2(360, 120)
	panel.custom_minimum_size = Vector2(520, 420)
	_map_panel.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	var title := Label.new()
	title.text = "Устройство карт — эндгейм"
	title.add_theme_font_size_override("font_size", 18)
	col.add_child(title)

	var hint := Label.new()
	hint.text = "Выбери карту из сумки. На заходе накатятся 1–3 мода."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 280)
	col.add_child(scroll)
	_map_list = VBoxContainer.new()
	_map_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_map_list)

	var close_btn := Button.new()
	close_btn.text = "Закрыть"
	close_btn.pressed.connect(_close_map_panel)
	col.add_child(close_btn)


func _process(_delta: float) -> void:
	if player and player.stats.is_alive():
		_clamp_player()
		_update_exit_arrow()
		if not player.inventory_open and (_map_panel == null or not _map_panel.visible):
			_try_pickup_loot()
			_try_portal()
			_try_side_portal()
			_update_merchant_hint()
			_update_device_hint()
			_try_edge_exit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and _map_panel and _map_panel.visible:
			_close_map_panel()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_R and (player == null or not player.inventory_open):
			get_tree().reload_current_scene()
		elif event.keycode == KEY_I or event.keycode == KEY_TAB:
			if inventory_ui:
				inventory_ui.toggle()
				player.inventory_open = inventory_ui.visible
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_M:
			_try_open_map_device()
		elif (event.keycode == KEY_G or event.keycode == KEY_N) and _zone_clear:
			_go_next_zone()
		elif event.keycode == KEY_F9:
			if _run_mode == &"campaign":
				_go_next_zone()
			elif _run_mode == &"map":
				_enter_hub()
		elif event.keycode == KEY_F10:
			_force_unlock_endgame()
		elif event.keycode == KEY_F5:
			_save_now()
		elif event.keycode == KEY_F6:
			_load_now()
		elif event.keycode == KEY_E:
			if not _try_merchant_buy():
				_try_open_map_device(true)


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	_world.add_child(player)
	player.hp_changed.connect(_on_player_hp)
	player.died.connect(_on_player_died)
	player.progress_changed.connect(_refresh_stats)
	player.inventory_changed.connect(_refresh_inv)
	player.passives.changed.connect(_refresh_passives)
	player.gold_changed.connect(_on_gold)

	inventory_ui = InventoryUI.new()
	_hud_root.add_child(inventory_ui)
	inventory_ui.setup(player)
	inventory_ui.closed.connect(func() -> void: player.inventory_open = false)

	player.inventory.add(ItemData.make_scroll(&"transmute", "Свиток заговора", ""))
	player.inventory.add(ItemData.make_scroll(&"augment", "Свиток уз", ""))
	player.add_gold(25)

	_on_player_hp(player.stats.hp, player.stats.max_hp)
	_refresh_stats()
	_refresh_inv()
	_refresh_passives()
	_on_gold(player.gold)


func _current_zone() -> Dictionary:
	return _zones[_zone_index]


func _setup_map_geometry(w: float = MAP_W, h: float = MAP_H) -> void:
	_map_rect = Rect2(MAP_ORIGIN, Vector2(w, h))
	_entry_pos = Vector2(_map_rect.position.x + 120.0, _map_rect.get_center().y)
	_exit_pos = Vector2(_map_rect.end.x - 140.0, _map_rect.get_center().y)
	var pad := 500.0
	_background.polygon = [
		Vector2(_map_rect.position.x - pad, _map_rect.position.y - pad),
		Vector2(_map_rect.end.x + pad, _map_rect.position.y - pad),
		Vector2(_map_rect.end.x + pad, _map_rect.end.y + pad),
		Vector2(_map_rect.position.x - pad, _map_rect.end.y + pad),
	]
	_floor.polygon = [
		_map_rect.position,
		Vector2(_map_rect.end.x, _map_rect.position.y),
		_map_rect.end,
		Vector2(_map_rect.position.x, _map_rect.end.y),
	]


func _enter_zone(index: int) -> void:
	_run_mode = &"campaign"
	_active_mods.clear()
	_active_map.clear()
	_reward_gold_mult = 1.0
	_reward_xp_mult = 1.0
	_zone_index = clampi(index, 0, _zones.size() - 1)
	_zone_clear = false
	_transitioning = false
	_clear_world_props()
	var z: Dictionary = _current_zone()
	_setup_map_geometry(float(z.get("map_w", MAP_W)), float(z.get("map_h", MAP_H)))
	_act_label.text = CampaignData.act_title(int(z["act"]))
	_flavor_label.text = z["flavor"]
	_background.color = z["bg"]
	_floor.color = z["floor"]
	if player:
		player.global_position = _entry_pos
		player.velocity = Vector2.ZERO
	_spawn_zone_decor(int(z["act"]))
	_spawn_exit_beacon()
	_spawn_zone_enemies(z, false)
	_refresh_enemy_hud()
	FloatingText.spawn(self, _entry_pos + Vector2(80, -60), CampaignData.act_title(int(z["act"])), Color(0.9, 0.8, 0.5), true)
	_hint_label.text = "Иди вправо. Колёсико — зум. F5 — сейв."
	_play_fade_in()


func _enter_hub() -> void:
	_run_mode = &"hub"
	_zone_clear = true
	_transitioning = false
	_active_mods.clear()
	_active_map.clear()
	_reward_gold_mult = 1.0
	_reward_xp_mult = 1.0
	_clear_world_props()
	_setup_map_geometry(HUB_W, HUB_H)
	_background.color = Color(0.12, 0.11, 0.14)
	_floor.color = Color(0.28, 0.24, 0.2)
	_act_label.text = "Хаб — эндгейм"
	_flavor_label.text = "Алтарь карт ждёт. Клади карту — и снова в круг."
	_wave_label.text = "Хаб | без врагов"
	if player:
		player.global_position = _map_rect.get_center()
		player.velocity = Vector2.ZERO
		player.stats.heal_full()
		player.hp_changed.emit(player.stats.hp, player.stats.max_hp)
	_spawn_zone_decor(0)
	_spawn_merchant(_map_rect.get_center() + Vector2(-160, 40))
	_spawn_map_device(_map_rect.get_center() + Vector2(160, 20))
	_hint_label.text = "E / M у алтаря — выбрать карту. Купец слева. F5 сейв."
	_play_fade_in()


func _enter_endgame_map(map_item: ItemData) -> void:
	var base: Dictionary = MapsData.base_by_id(map_item.map_id)
	if String(map_item.map_id) == "uber_morena" or int(map_item.map_tier) >= 10:
		base = MapsData.uber_map()
	_active_map = base
	_active_mods = MapsData.roll_map_mods(int(base["tier"]))
	_reward_gold_mult = MapsData.gold_mult(_active_mods)
	_reward_xp_mult = MapsData.xp_mult(_active_mods)
	# Убер может не лежать в сумке.
	player.inventory.remove_item(map_item)
	_refresh_inv()

	_run_mode = &"map"
	_zone_clear = false
	_transitioning = false
	_clear_world_props()
	var tw := 2400.0 + float(int(base["tier"])) * 80.0
	var th := 1500.0 + float(int(base["tier"])) * 40.0
	_setup_map_geometry(tw, th)
	_background.color = base["bg"]
	_floor.color = base["floor"]
	_act_label.text = "Карта T%d — %s" % [int(base["tier"]), base["name"]]
	_flavor_label.text = "%s | Моды: %s" % [base["flavor"], MapsData.mods_label(_active_mods)]
	if player:
		player.global_position = _entry_pos
		player.velocity = Vector2.ZERO
	_spawn_zone_decor(int(base["tier"]) + 2)
	_spawn_exit_beacon()
	_spawn_zone_enemies(base, true)
	_refresh_enemy_hud()
	FloatingText.spawn(self, _entry_pos + Vector2(40, -50), base["name"], Color(0.5, 0.95, 0.7), true)
	_hint_label.text = "Карта: зачисти и выйди справа / портал в хаб."
	_play_fade_in()


func _force_unlock_endgame() -> void:
	if not _endgame_unlocked:
		_endgame_unlocked = true
		_grant_starter_maps()
		FloatingText.spawn(self, player.global_position, "Эндгейм открыт", Color(0.5, 1.0, 0.7), true)
	_enter_hub()


func _grant_starter_maps() -> void:
	for b in MapsData.bases():
		player.try_pickup(ItemData.make_map(b["id"], b["name"], int(b["tier"])))
	_refresh_inv()


func _clear_world_props() -> void:
	for n in _world.get_children():
		if n == player:
			continue
		if n.is_in_group("enemies") or n.has_meta("portal") or n.has_meta("merchant") or n.has_meta("item") or n.has_meta("gold") or n.has_meta("decor") or n.has_meta("exit") or n.has_meta("device") or n.has_meta("side"):
			n.queue_free()
	_loot_nodes.clear()
	_alive_enemies = 0
	_portal = null
	_side_portal = null
	_merchant = null
	_exit_marker = null
	_map_device = null
	_merchant_stock.clear()


func _spawn_zone_decor(act: int) -> void:
	var accent := Color(0.45, 0.55, 0.3)
	match act:
		2:
			accent = Color(0.25, 0.55, 0.55)
		3:
			accent = Color(0.65, 0.35, 0.25)
		4:
			accent = Color(0.7, 0.55, 0.2)
		5:
			accent = Color(0.45, 0.55, 0.85)
		0:
			accent = Color(0.55, 0.45, 0.35)
	var count := 12 if _run_mode == &"hub" else 28
	for i in count:
		var p := Polygon2D.new()
		p.set_meta("decor", true)
		p.z_index = -5
		p.color = accent.darkened(0.1 + 0.04 * float(i % 4))
		var s := 16.0 + float(i % 5) * 7.0
		if act == 1 or act == 4:
			p.polygon = [Vector2(0, -s), Vector2(s * 0.55, s * 0.4), Vector2(-s * 0.55, s * 0.4)]
		elif act == 2 or act == 5:
			p.polygon = [Vector2(-s, 0), Vector2(-s * 0.3, -s * 0.45), Vector2(s * 0.7, -s * 0.2), Vector2(s, s * 0.2), Vector2(-s * 0.4, s * 0.35)]
		else:
			p.polygon = [Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s)]
		var x := _map_rect.position.x + 180.0 + randf() * (_map_rect.size.x - 360.0)
		var y_bias := -1.0 if i % 2 == 0 else 1.0
		var y := _map_rect.get_center().y + y_bias * (120.0 + randf() * (_map_rect.size.y * 0.25))
		p.global_position = Vector2(x, clampf(y, _map_rect.position.y + 40.0, _map_rect.end.y - 40.0))
		_world.add_child(p)


func _spawn_exit_beacon() -> void:
	_exit_marker = Node2D.new()
	_exit_marker.set_meta("exit", true)
	_exit_marker.global_position = _exit_pos
	var arrow := Polygon2D.new()
	arrow.polygon = [Vector2(-18, -28), Vector2(28, 0), Vector2(-18, 28)]
	arrow.color = Color(0.55, 0.75, 0.9, 0.55)
	_exit_marker.add_child(arrow)
	var lab := Label.new()
	lab.text = "ВЫХОД →"
	lab.position = Vector2(-34, -52)
	lab.add_theme_font_size_override("font_size", 14)
	lab.modulate = Color(0.7, 0.85, 1.0, 0.7)
	_exit_marker.add_child(lab)
	_world.add_child(_exit_marker)


func _spawn_zone_enemies(z: Dictionary, is_map: bool) -> void:
	var act_or_tier: int = int(z["tier"]) if is_map else int(z["act"])
	var ilvl: int = int(z["ilvl"])
	var is_boss_zone := true if is_map else bool(z["boss"])
	var count := randi_range(ENEMY_COUNT_MIN, ENEMY_COUNT_MAX)
	if is_map:
		count += int(z.get("enemy_bonus", 0)) + MapsData.sum_extra_enemies(_active_mods)
	elif is_boss_zone:
		count = randi_range(38, 45)

	var kinds: Array = [
		Enemy.EnemyKind.NORMAL, Enemy.EnemyKind.NORMAL, Enemy.EnemyKind.NORMAL,
		Enemy.EnemyKind.FAST, Enemy.EnemyKind.FAST,
		Enemy.EnemyKind.TANK, Enemy.EnemyKind.RANGED, Enemy.EnemyKind.RANGED,
	]
	if MapsData.has_ranged_bias(_active_mods):
		kinds = [
			Enemy.EnemyKind.RANGED, Enemy.EnemyKind.RANGED, Enemy.EnemyKind.RANGED,
			Enemy.EnemyKind.NORMAL, Enemy.EnemyKind.FAST, Enemy.EnemyKind.TANK,
		]

	var clusters := 8
	var per_cluster := int(ceil(float(count) / float(clusters)))
	var spawned := 0
	for c in clusters:
		var cx := _map_rect.position.x + 280.0 + (_map_rect.size.x - 520.0) * (float(c) + 0.5) / float(clusters)
		var cy := _map_rect.get_center().y + randf_range(-_map_rect.size.y * 0.22, _map_rect.size.y * 0.22)
		for j in per_cluster:
			if spawned >= count:
				break
			var enemy: CharacterBody2D = ENEMY_SCENE.instantiate()
			_world.add_child(enemy)
			enemy.global_position = Vector2(cx, cy) + Vector2(randf_range(-90, 90), randf_range(-70, 70))
			enemy.global_position.x = clampf(enemy.global_position.x, _map_rect.position.x + 160.0, _map_rect.end.x - 220.0)
			enemy.global_position.y = clampf(enemy.global_position.y, _map_rect.position.y + 50.0, _map_rect.end.y - 50.0)
			var kind: int = kinds[spawned % kinds.size()]
			if j == 0 and c % 3 == 2:
				kind = Enemy.EnemyKind.TANK
			enemy.setup(player, kind)
			_scale_enemy(enemy, ilvl, act_or_tier, false)
			if is_map:
				MapsData.apply_to_enemy(enemy, _active_mods)
			# Чемпионы / редкие — мини-цели с лучшим лутом.
			if kind != Enemy.EnemyKind.BOSS:
				if spawned == 3:
					enemy.promote_rare()
				elif randf() < 0.09:
					enemy.promote_champion()
			enemy.died.connect(_on_enemy_died)
			_alive_enemies += 1
			spawned += 1

	if is_boss_zone:
		var bname: String = str(z["boss_name"])
		_wave_label.text = "%s | БОСС: %s" % [z["name"], bname]
		var boss: CharacterBody2D = ENEMY_SCENE.instantiate()
		_world.add_child(boss)
		boss.global_position = _exit_pos + Vector2(-160, 0)
		boss.setup(player, Enemy.EnemyKind.BOSS)
		_scale_enemy(boss, ilvl, act_or_tier, true)
		if is_map:
			MapsData.apply_to_enemy(boss, _active_mods)
		boss.died.connect(_on_enemy_died)
		_alive_enemies += 1
	else:
		_wave_label.text = "%s | Враги: %d" % [z["name"], _alive_enemies]


func _scale_enemy(enemy: CharacterBody2D, ilvl: int, act: int, is_boss: bool) -> void:
	var mult_hp := 1.0 + 0.18 * float(ilvl - 1) + 0.1 * float(act - 1)
	var mult_dmg := 1.0 + 0.12 * float(ilvl - 1) + 0.08 * float(act - 1)
	if is_boss:
		mult_hp *= 1.15
		mult_dmg *= 1.1
	enemy.stats.max_hp *= mult_hp
	enemy.stats.hp = enemy.stats.max_hp
	enemy.stats.base_damage *= mult_dmg


func _refresh_enemy_hud() -> void:
	if _run_mode == &"hub":
		_wave_label.text = "Хаб | без врагов"
		return
	var title := str(_active_map.get("name", _current_zone()["name"]))
	if _zone_clear:
		_wave_label.text = "%s | ЗАЧИЩЕНО — выход →" % title
	elif _alive_enemies > 0:
		_wave_label.text = "%s | осталось: %d" % [title, _alive_enemies]


func _clamp_player() -> void:
	if player == null:
		return
	var m := 28.0
	player.global_position.x = clampf(player.global_position.x, _map_rect.position.x + m, _map_rect.end.x - m)
	player.global_position.y = clampf(player.global_position.y, _map_rect.position.y + m, _map_rect.end.y - m)


func _on_player_hp(current: float, maximum: float) -> void:
	_hp_label.text = "HP %d/%d  Mana %d" % [int(current), int(maximum), int(player.stats.mana)]


func _on_gold(amount: int) -> void:
	_gold_label.text = "Золото: %d" % amount


func _on_player_died() -> void:
	_hint_label.text = "Ты пал. R — рестарт. F10 — хаб эндгейма."


func _refresh_stats() -> void:
	var p: PlayerProgress = player.progress
	_stats_label.text = "Ур.%d  XP %d/%d\nСИЛ %.0f  ЛОВ %.1f  ИНТ %.1f  Урон %.0f" % [
		p.level, p.xp, p.xp_to_next(),
		p.strength, p.dexterity, p.intelligence,
		player.stats.base_damage + player.stats.added_damage
	]


func _refresh_inv() -> void:
	_inv_label.text = "\n".join(player.inventory.summary_lines())
	if inventory_ui and inventory_ui.visible:
		inventory_ui.refresh()


func _refresh_passives() -> void:
	_passive_label.text = "\n".join(player.passives.summary_lines())


func _on_enemy_died(enemy: Node) -> void:
	_alive_enemies = maxi(0, _alive_enemies - 1)
	if is_instance_valid(enemy):
		if player and player.stats.is_alive():
			var xp := int(round(float(enemy.xp_reward()) * _reward_xp_mult))
			var gold := int(round(float(enemy.gold_reward()) * _reward_gold_mult))
			player.gain_xp(xp)
			player.add_gold(gold)
		var drop: ItemData = enemy.roll_drop()
		if drop:
			_spawn_loot(enemy.global_position, drop)
		_spawn_gold_pile(enemy.global_position, maxi(1, int(enemy.gold_reward() / 2)))
		if enemy.kind == Enemy.EnemyKind.BOSS:
			_maybe_drop_map(enemy.global_position)
	_refresh_stats()
	_refresh_enemy_hud()
	if _alive_enemies <= 0 and player and player.stats.is_alive():
		_on_zone_cleared()


func _maybe_drop_map(pos: Vector2) -> void:
	var chance := 0.35
	if _run_mode == &"map":
		chance = 0.7
	elif _run_mode == &"campaign" and bool(_current_zone().get("boss", false)):
		chance = 0.45
	else:
		return
	if randf() > chance:
		return
	var tier := 1
	if _run_mode == &"map":
		tier = int(_active_map.get("tier", 1))
	elif int(_current_zone().get("act", 1)) >= 4:
		tier = 2
	_spawn_loot(pos + Vector2(0, 24), ItemData.roll_map(tier))


func _on_zone_cleared() -> void:
	_zone_clear = true
	_refresh_enemy_hud()

	if _run_mode == &"map":
		_flavor_label.text = "Карта пройдена. Портал в хаб справа."
		_hint_label.text = "Выход справа / портал — в хаб. Можешь фармить снова."
		if _active_map.has("id"):
			_atlas[String(_active_map["id"])] = true
		_spawn_portal(_exit_pos, "ХАБ →")
		_mark_exit_open()
		return

	var z: Dictionary = _current_zone()
	var last := _zone_index >= _zones.size() - 1
	var act_end := bool(z["boss"])

	if last:
		_flavor_label.text = "Морена пала. Эндгейм открыт — алтарь карт в хабе."
		_hint_label.text = "Кампания пройдена. Иди к выходу / F10 — хаб."
		if not _endgame_unlocked:
			_endgame_unlocked = true
			_grant_starter_maps()
		_spawn_merchant(_exit_pos + Vector2(-80, 80))
		_spawn_map_device(_exit_pos + Vector2(40, 60))
		_spawn_portal(_exit_pos, "ХАБ →")
		_mark_exit_open()
		return

	if act_end:
		_flavor_label.text = "Акт %d завершён. Купец у выхода." % int(z["act"])
		_hint_label.text = "E — купец. Выход справа → Акт %d." % (int(z["act"]) + 1)
		_spawn_merchant(_exit_pos + Vector2(-100, 90))
		_spawn_portal(_exit_pos, "Акт %d →" % (int(z["act"]) + 1))
	else:
		_flavor_label.text = "Тропа свободна. Основной выход → или развилка вверх."
		_hint_label.text = "Выход справа / развилка вверх (N/G / портал)."
		_spawn_portal(_exit_pos, "ДАЛЬШЕ →")
		_spawn_side_exit(Vector2(_map_rect.get_center().x, _map_rect.position.y + 90.0), "ТРОПА ↑")
	_mark_exit_open()


func _mark_exit_open() -> void:
	if _exit_marker == null or not is_instance_valid(_exit_marker):
		return
	for c in _exit_marker.get_children():
		if c is Polygon2D:
			c.color = Color(0.4, 0.95, 0.7, 0.9)
		elif c is Label:
			c.modulate = Color(0.6, 1.0, 0.75, 1.0)
			c.text = "ОТКРЫТО →"


func _spawn_merchant(pos: Vector2) -> void:
	if _merchant and is_instance_valid(_merchant):
		_merchant.queue_free()
	_merchant = Node2D.new()
	_merchant.global_position = pos
	_merchant.set_meta("merchant", true)
	var body := Polygon2D.new()
	body.polygon = [Vector2(-14, -18), Vector2(14, -18), Vector2(14, 18), Vector2(-14, 18)]
	body.color = Color(0.75, 0.55, 0.3)
	_merchant.add_child(body)
	var lab := Label.new()
	lab.text = "Купец\nE: товар"
	lab.position = Vector2(-36, -52)
	lab.add_theme_font_size_override("font_size", 12)
	_merchant.add_child(lab)
	_world.add_child(_merchant)
	_restock_merchant()


func _restock_merchant() -> void:
	_merchant_stock.clear()
	var act := 1
	if _run_mode == &"campaign":
		act = int(_current_zone().get("act", 1))
	elif _run_mode == &"map":
		act = int(_active_map.get("tier", 3))
	_merchant_stock.append({"kind": "scroll", "price": 25 + act * 5})
	_merchant_stock.append({"kind": "scroll", "price": 30 + act * 5})
	if act >= 2:
		_merchant_stock.append({"kind": "map", "price": 40 + act * 10, "tier": mini(act, 5)})
	if _endgame_unlocked and act >= 4:
		_merchant_stock.append({"kind": "map", "price": 80, "tier": 6})


func _spawn_map_device(pos: Vector2) -> void:
	if _map_device and is_instance_valid(_map_device):
		_map_device.queue_free()
	_map_device = Node2D.new()
	_map_device.global_position = pos
	_map_device.set_meta("device", true)
	var body := Polygon2D.new()
	body.polygon = [Vector2(-22, -10), Vector2(22, -10), Vector2(16, 18), Vector2(-16, 18)]
	body.color = Color(0.3, 0.7, 0.55)
	_map_device.add_child(body)
	var lab := Label.new()
	lab.text = "Алтарь карт\nE / M"
	lab.position = Vector2(-42, -48)
	lab.add_theme_font_size_override("font_size", 12)
	_map_device.add_child(lab)
	_world.add_child(_map_device)


func _update_merchant_hint() -> void:
	if _merchant == null or not is_instance_valid(_merchant) or player == null:
		return
	if player.global_position.distance_to(_merchant.global_position) < 50.0:
		_hint_label.text = "Купец: E — случайный свиток за 30 золота"


func _update_device_hint() -> void:
	if _map_device == null or not is_instance_valid(_map_device) or player == null:
		return
	if player.global_position.distance_to(_map_device.global_position) < 55.0:
		_hint_label.text = "Алтарь карт: E или M — выбрать карту"


func _try_merchant_buy() -> bool:
	if _merchant == null or not is_instance_valid(_merchant) or player == null:
		return false
	if player.global_position.distance_to(_merchant.global_position) > 50.0:
		return false
	if _merchant_stock.is_empty():
		_restock_merchant()
	var offer: Dictionary = _merchant_stock[0]
	var price: int = int(offer["price"])
	if player.gold < price:
		FloatingText.spawn(self, player.global_position, "Мало золота (%d)" % price, Color(1.0, 0.4, 0.4))
		return true
	player.add_gold(-price)
	var bought: ItemData = null
	if str(offer["kind"]) == "map":
		bought = ItemData.roll_map(int(offer.get("tier", 1)))
	else:
		bought = ItemData.roll_scroll()
	if player.try_pickup(bought):
		FloatingText.spawn(self, player.global_position, "Куплено: " + bought.display_name, Color(0.7, 0.5, 1.0))
		_merchant_stock.remove_at(0)
		if _merchant_stock.is_empty():
			FloatingText.spawn(self, _merchant.global_position, "Товар кончился", Color(0.8, 0.8, 0.6))
	else:
		player.add_gold(price)
		FloatingText.spawn(self, player.global_position, "Сумка полна", Color(1.0, 0.4, 0.4))
	return true


func _try_open_map_device(require_near: bool = false) -> void:
	if not _endgame_unlocked and _run_mode != &"hub":
		FloatingText.spawn(self, player.global_position, "Сначала дойди до конца кампании (или F10)", Color(1.0, 0.7, 0.4))
		return
	if require_near:
		if _map_device == null or not is_instance_valid(_map_device):
			return
		if player.global_position.distance_to(_map_device.global_position) > 55.0:
			return
	_open_map_panel()


func _open_map_panel() -> void:
	if inventory_ui and inventory_ui.visible:
		inventory_ui.toggle()
		player.inventory_open = false
	for c in _map_list.get_children():
		c.queue_free()
	var maps: Array = []
	for e in player.inventory.bag:
		var it: ItemData = e["item"]
		if it.is_map():
			maps.append(it)
	var atlas_l := Label.new()
	atlas_l.text = "Атлас открыто: %d карт" % _atlas.size()
	_map_list.add_child(atlas_l)
	if maps.is_empty():
		var empty := Label.new()
		empty.text = "Нет карт в сумке. Купец / боссы / F10 стартовый набор."
		_map_list.add_child(empty)
	else:
		for it in maps:
			var btn := Button.new()
			btn.text = it.display_name
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var map_ref: ItemData = it
			btn.pressed.connect(func() -> void:
				_close_map_panel()
				_enter_endgame_map(map_ref)
			)
			_map_list.add_child(btn)
	if _endgame_unlocked and int(_atlas.size()) >= 3:
		var uber_btn := Button.new()
		uber_btn.text = "УБЕР: Тень зимы (T10) — бесплатный вход"
		uber_btn.pressed.connect(func() -> void:
			_close_map_panel()
			var u: Dictionary = MapsData.uber_map()
			var fake := ItemData.make_map(u["id"], u["name"], int(u["tier"]))
			_enter_endgame_map(fake)
		)
		_map_list.add_child(uber_btn)
	_map_panel.visible = true


func _close_map_panel() -> void:
	if _map_panel:
		_map_panel.visible = false


func _spawn_portal(pos: Vector2, label_text: String = "ПОРТАЛ") -> void:
	if _portal and is_instance_valid(_portal):
		_portal.queue_free()
	_portal = Area2D.new()
	_portal.set_meta("portal", true)
	_portal.global_position = pos
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 48.0
	shape.shape = circle
	_portal.add_child(shape)
	var vis := Polygon2D.new()
	vis.polygon = [Vector2(-30, -30), Vector2(30, -30), Vector2(30, 30), Vector2(-30, 30)]
	vis.color = Color(0.35, 0.85, 0.95, 0.9)
	_portal.add_child(vis)
	var lab := Label.new()
	lab.text = label_text
	lab.position = Vector2(-40, -54)
	lab.add_theme_font_size_override("font_size", 14)
	_portal.add_child(lab)
	_world.add_child(_portal)


func _try_portal() -> void:
	if not _zone_clear or _portal == null or not is_instance_valid(_portal):
		return
	if player.global_position.distance_to(_portal.global_position) < 52.0:
		_go_next_zone()


func _try_edge_exit() -> void:
	if not _zone_clear or _transitioning or _run_mode == &"hub":
		return
	if player.global_position.x >= _map_rect.end.x - 90.0:
		_go_next_zone()


func _go_next_zone() -> void:
	if _transitioning:
		return
	_transitioning = true
	await _play_fade_out()
	if _run_mode == &"map":
		_enter_hub()
		return
	if _run_mode == &"campaign" and _zone_index >= _zones.size() - 1:
		_enter_hub()
		return
	if _zone_index >= _zones.size() - 1:
		_transitioning = false
		return
	_enter_zone(_zone_index + 1)


func _spawn_side_exit(pos: Vector2, label_text: String) -> void:
	if _side_portal and is_instance_valid(_side_portal):
		_side_portal.queue_free()
	_side_portal = Area2D.new()
	_side_portal.set_meta("side", true)
	_side_portal.set_meta("portal", true)
	_side_portal.global_position = pos
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 40.0
	shape.shape = circle
	_side_portal.add_child(shape)
	var vis := Polygon2D.new()
	vis.polygon = [Vector2(-22, -22), Vector2(22, -22), Vector2(22, 22), Vector2(-22, 22)]
	vis.color = Color(0.55, 0.9, 0.55, 0.85)
	_side_portal.add_child(vis)
	var lab := Label.new()
	lab.text = label_text
	lab.position = Vector2(-36, -48)
	lab.add_theme_font_size_override("font_size", 13)
	_side_portal.add_child(lab)
	_world.add_child(_side_portal)


func _try_side_portal() -> void:
	if not _zone_clear or _side_portal == null or not is_instance_valid(_side_portal):
		return
	if player.global_position.distance_to(_side_portal.global_position) < 48.0:
		_go_next_zone()


func _update_exit_arrow() -> void:
	if _exit_arrow == null or player == null:
		return
	if _run_mode == &"hub":
		_exit_arrow.text = "ХАБ"
		_exit_arrow.modulate = Color(0.85, 0.75, 0.5)
		return
	var to_exit := _exit_pos - player.global_position
	var ang := rad_to_deg(to_exit.angle())
	var dist := int(to_exit.length())
	var dir := "→"
	if ang > 45.0 and ang <= 135.0:
		dir = "↓"
	elif ang < -45.0 and ang >= -135.0:
		dir = "↑"
	elif absf(ang) > 135.0:
		dir = "←"
	_exit_arrow.text = "%s выход %d" % [dir, dist]
	_exit_arrow.modulate = Color(0.45, 1.0, 0.65) if _zone_clear else Color(0.55, 0.85, 1.0)


func _play_fade_in() -> void:
	if _fade == null:
		return
	_fade.color = Color(0, 0, 0, 1)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.35)


func _play_fade_out() -> void:
	if _fade == null:
		return
	Sfx.play_portal()
	_fade.color = Color(0, 0, 0, 0)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.28)
	await tw.finished


func _save_now() -> void:
	var ok := SaveData.save_player(player, {
		"endgame_unlocked": _endgame_unlocked,
		"atlas": _atlas,
		"zone_index": _zone_index,
	})
	FloatingText.spawn(self, player.global_position, "Сохранено" if ok else "Ошибка сейва", Color(0.6, 1.0, 0.7) if ok else Color(1, 0.4, 0.4))


func _load_now() -> void:
	if not SaveData.exists():
		FloatingText.spawn(self, player.global_position, "Нет сейва", Color(1, 0.6, 0.4))
		return
	var meta: Dictionary = SaveData.load_into(player)
	_endgame_unlocked = bool(meta.get("endgame_unlocked", false))
	_atlas = meta.get("atlas", {})
	if typeof(_atlas) != TYPE_DICTIONARY:
		_atlas = {}
	_refresh_inv()
	_refresh_stats()
	_on_gold(player.gold)
	FloatingText.spawn(self, player.global_position, "Загружено", Color(0.6, 0.85, 1.0))


func _spawn_loot(pos: Vector2, item: ItemData) -> void:
	var node := Node2D.new()
	node.global_position = pos
	node.set_meta("item", item)
	var visual := Polygon2D.new()
	visual.polygon = [Vector2(-7, -7), Vector2(7, -7), Vector2(7, 7), Vector2(-7, 7)]
	visual.color = item.color
	node.add_child(visual)
	var label := Label.new()
	label.text = item.display_name
	label.position = Vector2(-20, -24)
	label.add_theme_font_size_override("font_size", 12)
	label.modulate = item.color
	node.add_child(label)
	_world.add_child(node)
	_loot_nodes.append(node)


func _spawn_gold_pile(pos: Vector2, amount: int) -> void:
	var node := Node2D.new()
	node.global_position = pos + Vector2(randf_range(-12, 12), randf_range(-12, 12))
	node.set_meta("gold", amount)
	var visual := Polygon2D.new()
	visual.polygon = [Vector2(-5, -5), Vector2(5, -5), Vector2(5, 5), Vector2(-5, 5)]
	visual.color = Color(0.95, 0.8, 0.2)
	node.add_child(visual)
	_world.add_child(node)
	_loot_nodes.append(node)


func _try_pickup_loot() -> void:
	if player == null or not player.stats.is_alive():
		return
	var remain: Array[Node2D] = []
	for node in _loot_nodes:
		if not is_instance_valid(node):
			continue
		if player.global_position.distance_to(node.global_position) <= 28.0:
			if node.has_meta("gold"):
				player.add_gold(int(node.get_meta("gold")))
				Sfx.play_pickup()
				node.queue_free()
				continue
			var item: ItemData = node.get_meta("item")
			if player.try_pickup(item):
				node.queue_free()
				continue
		remain.append(node)
	_loot_nodes = remain
