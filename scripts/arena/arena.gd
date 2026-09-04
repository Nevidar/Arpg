extends Node2D

## Кампания: большие зоны в стиле PoE-черновика.
## Вход слева → бой по пути → выход/портал справа.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const CampaignData := preload("res://scripts/world/campaign.gd")

## Размер «карты» (позже можно варьировать по зонам).
const MAP_W := 2800.0
const MAP_H := 1700.0
const MAP_ORIGIN := Vector2(80, 60)
const ENEMY_COUNT_MIN := 42
const ENEMY_COUNT_MAX := 50

@onready var _world: Node2D = $World
@onready var _spawn_points: Node2D = $SpawnPoints
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
var _map_rect: Rect2
var _entry_pos: Vector2
var _exit_pos: Vector2
var _transitioning: bool = false


func _ready() -> void:
	_zones = CampaignData.zones()
	_hint_label.text = "WASD вперёд по карте | выход справа | I инвентарь | Q/E | Пробел | F9 skip | R рестарт"
	_ensure_extra_labels()
	_spawn_player()
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


func _process(_delta: float) -> void:
	if player and player.stats.is_alive():
		_clamp_player()
		if not player.inventory_open:
			_try_pickup_loot()
			_try_portal()
			_update_merchant_hint()
			_try_edge_exit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and (player == null or not player.inventory_open):
			get_tree().reload_current_scene()
		elif event.keycode == KEY_I or event.keycode == KEY_TAB:
			if inventory_ui:
				inventory_ui.toggle()
				player.inventory_open = inventory_ui.visible
				get_viewport().set_input_as_handled()
		elif (event.keycode == KEY_G or event.keycode == KEY_N) and _zone_clear:
			_go_next_zone()
		elif event.keycode == KEY_F9:
			_go_next_zone()
		elif event.keycode == KEY_E:
			_try_merchant_buy()


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


func _setup_map_geometry() -> void:
	_map_rect = Rect2(MAP_ORIGIN, Vector2(MAP_W, MAP_H))
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
	_zone_index = clampi(index, 0, _zones.size() - 1)
	_zone_clear = false
	_transitioning = false
	_clear_world_props()
	_setup_map_geometry()
	var z: Dictionary = _current_zone()
	_act_label.text = CampaignData.act_title(int(z["act"]))
	_flavor_label.text = z["flavor"]
	_background.color = z["bg"]
	_floor.color = z["floor"]
	if player:
		player.global_position = _entry_pos
		player.velocity = Vector2.ZERO
	_spawn_zone_decor(z)
	_spawn_exit_beacon()
	_spawn_zone_enemies(z)
	_refresh_enemy_hud()
	FloatingText.spawn(self, _entry_pos + Vector2(80, -60), CampaignData.act_title(int(z["act"])), Color(0.9, 0.8, 0.5), true)
	_hint_label.text = "Иди вправо по карте. Выход откроется после зачистки."


func _clear_world_props() -> void:
	for n in _world.get_children():
		if n == player:
			continue
		if n.is_in_group("enemies") or n.has_meta("portal") or n.has_meta("merchant") or n.has_meta("item") or n.has_meta("gold") or n.has_meta("decor") or n.has_meta("exit"):
			n.queue_free()
	_loot_nodes.clear()
	_alive_enemies = 0
	_portal = null
	_merchant = null
	_exit_marker = null


func _spawn_zone_decor(z: Dictionary) -> void:
	var act: int = int(z["act"])
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
	for i in 28:
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
		# Разброс по карте, чуть ближе к краям (не блокирует тропу по центру).
		var x := _map_rect.position.x + 180.0 + randf() * (MAP_W - 360.0)
		var y_bias := -1.0 if i % 2 == 0 else 1.0
		var y := _map_rect.get_center().y + y_bias * (180.0 + randf() * (MAP_H * 0.28))
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


func _spawn_zone_enemies(z: Dictionary) -> void:
	var act: int = int(z["act"])
	var ilvl: int = int(z["ilvl"])
	var is_boss_zone := bool(z["boss"])
	var count := randi_range(ENEMY_COUNT_MIN, ENEMY_COUNT_MAX)
	if is_boss_zone:
		count = randi_range(38, 45)

	var kinds: Array = [
		Enemy.EnemyKind.NORMAL,
		Enemy.EnemyKind.NORMAL,
		Enemy.EnemyKind.NORMAL,
		Enemy.EnemyKind.FAST,
		Enemy.EnemyKind.FAST,
		Enemy.EnemyKind.TANK,
		Enemy.EnemyKind.RANGED,
		Enemy.EnemyKind.RANGED,
	]

	# Кластеры вдоль пути слева → направо (PoE-like density).
	var clusters := 8
	var per_cluster := int(ceil(float(count) / float(clusters)))
	var spawned := 0
	for c in clusters:
		var cx := _map_rect.position.x + 280.0 + (MAP_W - 520.0) * (float(c) + 0.5) / float(clusters)
		var cy := _map_rect.get_center().y + randf_range(-MAP_H * 0.22, MAP_H * 0.22)
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
			_scale_enemy(enemy, ilvl, act, false)
			enemy.died.connect(_on_enemy_died)
			_alive_enemies += 1
			spawned += 1

	if is_boss_zone:
		_wave_label.text = "%s | БОСС: %s" % [z["name"], z["boss_name"]]
		var boss: CharacterBody2D = ENEMY_SCENE.instantiate()
		_world.add_child(boss)
		boss.global_position = _exit_pos + Vector2(-160, 0)
		boss.setup(player, Enemy.EnemyKind.BOSS)
		_scale_enemy(boss, ilvl, act, true)
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
	var z: Dictionary = _current_zone()
	if _zone_clear:
		_wave_label.text = "%s | ЗАЧИЩЕНО — иди к выходу →" % z["name"]
	elif bool(z["boss"]):
		_wave_label.text = "%s | БОСС: %s | осталось %d" % [z["name"], z["boss_name"], _alive_enemies]
	else:
		_wave_label.text = "%s | осталось врагов: %d" % [z["name"], _alive_enemies]


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
	_hint_label.text = "Ты пал. R — начать кампанию заново."


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
			player.gain_xp(enemy.xp_reward())
			player.add_gold(enemy.gold_reward())
		var drop: ItemData = enemy.roll_drop()
		if drop:
			_spawn_loot(enemy.global_position, drop)
		_spawn_gold_pile(enemy.global_position, maxi(1, int(enemy.gold_reward() / 2)))
	_refresh_stats()
	_refresh_enemy_hud()
	if _alive_enemies <= 0 and player and player.stats.is_alive():
		_on_zone_cleared()


func _on_zone_cleared() -> void:
	_zone_clear = true
	var z: Dictionary = _current_zone()
	_refresh_enemy_hud()
	var last := _zone_index >= _zones.size() - 1
	var act_end := bool(z["boss"])

	if last:
		_flavor_label.text = "Морена пала. История (черновик) окончена — дальше будет эндгейм."
		_hint_label.text = "Кампания пройдена. E — купец. R — рестарт."
		_spawn_merchant(_exit_pos + Vector2(-80, 80))
		return

	if act_end:
		_flavor_label.text = "Акт %d завершён. Купец у выхода. Иди вправо / в портал." % int(z["act"])
		_hint_label.text = "E — купец. Выход справа → Акт %d." % (int(z["act"]) + 1)
		_spawn_merchant(_exit_pos + Vector2(-100, 90))
		_spawn_portal(_exit_pos, "Акт %d →" % (int(z["act"]) + 1))
	else:
		_flavor_label.text = "Тропа свободна. Иди к выходу справа."
		_hint_label.text = "Иди к выходу → (или портал / N / G)."
		_spawn_portal(_exit_pos, "ДАЛЬШЕ →")

	if _exit_marker and is_instance_valid(_exit_marker):
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
	lab.text = "Купец\nE: свиток 30з"
	lab.position = Vector2(-40, -52)
	lab.add_theme_font_size_override("font_size", 12)
	_merchant.add_child(lab)
	_world.add_child(_merchant)


func _update_merchant_hint() -> void:
	if _merchant == null or not is_instance_valid(_merchant) or player == null:
		return
	if player.global_position.distance_to(_merchant.global_position) < 50.0:
		_hint_label.text = "Купец: E — случайный свиток за 30 золота"


func _try_merchant_buy() -> void:
	if _merchant == null or not is_instance_valid(_merchant) or player == null:
		return
	if player.global_position.distance_to(_merchant.global_position) > 50.0:
		return
	if player.gold < 30:
		FloatingText.spawn(self, player.global_position, "Мало золота", Color(1.0, 0.4, 0.4))
		return
	player.add_gold(-30)
	var scroll := ItemData.roll_scroll()
	if player.try_pickup(scroll):
		FloatingText.spawn(self, player.global_position, "Куплено: " + scroll.display_name, Color(0.7, 0.5, 1.0))
	else:
		player.add_gold(30)
		FloatingText.spawn(self, player.global_position, "Сумка полна", Color(1.0, 0.4, 0.4))


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
	# PoE-like: после зачистки достаточно дойти до правого края.
	if not _zone_clear or _transitioning:
		return
	if player.global_position.x >= _map_rect.end.x - 90.0:
		_go_next_zone()


func _go_next_zone() -> void:
	if _transitioning:
		return
	if _zone_index >= _zones.size() - 1:
		return
	_transitioning = true
	_enter_zone(_zone_index + 1)


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
