extends Node2D

## Акт 1 — зоны у деревни / лес / опушка. Волны пачек, золото, переход дальше.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

const ZONES := [
	{"id": "a1_edge", "name": "Окрайна деревни", "ilvl": 1, "packs": 3, "flavor": "Туман ползёт от леса. Навь ещё далеко — но уже близко."},
	{"id": "a1_forest", "name": "Тёмный бор", "ilvl": 2, "packs": 4, "flavor": "Стволы как рёбра. Что-то смотрит между ними."},
	{"id": "a1_mire", "name": "Гнилая опушка", "ilvl": 3, "packs": 4, "flavor": "Земля чавкает. Здесь кончается первая тропа Акта 1."},
]

@onready var _world: Node2D = $World
@onready var _spawn_points: Node2D = $SpawnPoints
@onready var _hud_root: Control = $HUD/Root
@onready var _hp_label: Label = $HUD/Root/HpLabel
@onready var _hint_label: Label = $HUD/Root/HintLabel
@onready var _wave_label: Label = $HUD/Root/WaveLabel
@onready var _stats_label: Label = $HUD/Root/StatsLabel
@onready var _inv_label: Label = $HUD/Root/InvLabel
@onready var _passive_label: Label = $HUD/Root/PassiveLabel
@onready var _floor: ColorRect = $Floor
@onready var _background: ColorRect = $Background

var player: CharacterBody2D
var inventory_ui: InventoryUI
var _zone_index: int = 0
var _pack: int = 1
var _alive_enemies: int = 0
var _loot_nodes: Array[Node2D] = []
var _zone_clear: bool = false
var _portal: Area2D
var _flavor_label: Label
var _gold_label: Label
var _merchant: Node2D
var _merchant_open: bool = false


func _ready() -> void:
	_hint_label.text = "WASD бой | I/Tab инвентарь | Q/E навыки | Пробел рывок | F1-F8 пассивки | R рестарт"
	_ensure_extra_labels()
	_spawn_player()
	_enter_zone(0)


func _ensure_extra_labels() -> void:
	_gold_label = Label.new()
	_gold_label.position = Vector2(16, 140)
	_gold_label.size = Vector2(280, 24)
	_gold_label.add_theme_font_size_override("font_size", 16)
	_hud_root.add_child(_gold_label)

	_flavor_label = Label.new()
	_flavor_label.position = Vector2(16, 620)
	_flavor_label.size = Vector2(860, 40)
	_flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flavor_label.add_theme_font_size_override("font_size", 13)
	_flavor_label.modulate = Color(0.75, 0.7, 0.65)
	_hud_root.add_child(_flavor_label)


func _process(_delta: float) -> void:
	if player and not player.inventory_open:
		_try_pickup_loot()
		_try_portal()
		_update_merchant_hint()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and (player == null or not player.inventory_open):
			get_tree().reload_current_scene()
		elif event.keycode == KEY_I or event.keycode == KEY_TAB:
			if inventory_ui:
				inventory_ui.toggle()
				player.inventory_open = inventory_ui.visible
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_G and _zone_clear:
			_go_next_zone()
		elif event.keycode == KEY_E:
			_try_merchant_buy()


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.global_position = Vector2(640, 360)
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

	# Стартовые свитки, чтобы сразу пощупать крафт
	player.inventory.add(ItemData.make_scroll(&"transmute", "Свиток заговора", ""))
	player.inventory.add(ItemData.make_scroll(&"augment", "Свиток уз", ""))
	player.add_gold(25)

	_on_player_hp(player.stats.hp, player.stats.max_hp)
	_refresh_stats()
	_refresh_inv()
	_refresh_passives()
	_on_gold(player.gold)


func _enter_zone(index: int) -> void:
	_zone_index = clampi(index, 0, ZONES.size() - 1)
	_pack = 1
	_zone_clear = false
	_clear_enemies_and_portal()
	var z: Dictionary = ZONES[_zone_index]
	_wave_label.text = "Акт 1 — %s | Пачка %d/%d" % [z["name"], _pack, z["packs"]]
	_flavor_label.text = z["flavor"]
	_apply_zone_visuals(_zone_index)
	_spawn_pack()


func _apply_zone_visuals(index: int) -> void:
	match index:
		0:
			_background.color = Color(0.08, 0.09, 0.1)
			_floor.color = Color(0.16, 0.18, 0.14)
		1:
			_background.color = Color(0.05, 0.07, 0.06)
			_floor.color = Color(0.1, 0.14, 0.11)
		_:
			_background.color = Color(0.07, 0.06, 0.08)
			_floor.color = Color(0.14, 0.12, 0.1)


func _clear_enemies_and_portal() -> void:
	for n in _world.get_children():
		if n.is_in_group("enemies") or n.has_meta("portal"):
			n.queue_free()
	_alive_enemies = 0
	_portal = null


func _on_player_hp(current: float, maximum: float) -> void:
	_hp_label.text = "HP %d/%d  Mana %d" % [int(current), int(maximum), int(player.stats.mana)]


func _on_gold(amount: int) -> void:
	_gold_label.text = "Золото: %d" % amount


func _on_player_died() -> void:
	_hint_label.text = "Ты пал. R — начать зону заново."


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


func _spawn_pack() -> void:
	var z: Dictionary = ZONES[_zone_index]
	_wave_label.text = "Акт 1 — %s | Пачка %d/%d" % [z["name"], _pack, z["packs"]]
	var kinds: Array = [
		Enemy.EnemyKind.NORMAL,
		Enemy.EnemyKind.NORMAL,
		Enemy.EnemyKind.FAST,
		Enemy.EnemyKind.TANK,
		Enemy.EnemyKind.RANGED,
	]
	# Босс на последней пачке последней зоны Акта 1
	var is_boss_pack := _zone_index >= ZONES.size() - 1 and _pack >= int(z["packs"])
	if is_boss_pack:
		_wave_label.text = "Акт 1 — %s | БОСС: Лихо Одноглазое" % z["name"]
		var boss: CharacterBody2D = ENEMY_SCENE.instantiate()
		_world.add_child(boss)
		boss.global_position = Vector2(640, 200)
		boss.setup(player, Enemy.EnemyKind.BOSS)
		boss.died.connect(_on_enemy_died)
		_alive_enemies += 1
		# пара помощников
		for i in 2:
			var pt: Marker2D = _spawn_points.get_child(i)
			var helper: CharacterBody2D = ENEMY_SCENE.instantiate()
			_world.add_child(helper)
			helper.global_position = pt.global_position
			helper.setup(player, Enemy.EnemyKind.FAST if i == 0 else Enemy.EnemyKind.RANGED)
			helper.died.connect(_on_enemy_died)
			_alive_enemies += 1
		return

	var count := mini(3 + _pack + _zone_index, 8)
	for i in count:
		var pt: Marker2D = _spawn_points.get_child(i % _spawn_points.get_child_count())
		var enemy: CharacterBody2D = ENEMY_SCENE.instantiate()
		_world.add_child(enemy)
		enemy.global_position = pt.global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		var kind: int = kinds[i % kinds.size()]
		if _pack >= 3 and i == 0:
			kind = Enemy.EnemyKind.TANK
		enemy.setup(player, kind)
		enemy.stats.max_hp *= 1.0 + 0.25 * _zone_index
		enemy.stats.hp = enemy.stats.max_hp
		enemy.stats.base_damage *= 1.0 + 0.15 * _zone_index
		enemy.died.connect(_on_enemy_died)
		_alive_enemies += 1


func _on_enemy_died(enemy: Node) -> void:
	_alive_enemies = maxi(0, _alive_enemies - 1)
	if is_instance_valid(enemy):
		if player and player.stats.is_alive():
			player.gain_xp(enemy.xp_reward())
			player.add_gold(enemy.gold_reward())
		var drop: ItemData = enemy.roll_drop()
		if drop:
			_spawn_loot(enemy.global_position, drop)
		# Монетки почти всегда
		_spawn_gold_pile(enemy.global_position, maxi(1, int(enemy.gold_reward() / 2)))
	_refresh_stats()
	if _alive_enemies <= 0 and player.stats.is_alive():
		var z: Dictionary = ZONES[_zone_index]
		if _pack < int(z["packs"]):
			_pack += 1
			await get_tree().create_timer(1.0).timeout
			_spawn_pack()
		else:
			_on_zone_cleared()


func _on_zone_cleared() -> void:
	_zone_clear = true
	var z: Dictionary = ZONES[_zone_index]
	_wave_label.text = "Акт 1 — %s | ЗАЧИЩЕНО" % z["name"]
	if _zone_index >= ZONES.size() - 1:
		_flavor_label.text = "Лихо пало. Купец ждёт у костра. E — купить свиток (30 золота)."
		_hint_label.text = "Акт 1 пройден. Подойди к купцу (E) или R — сначала."
		_spawn_merchant(Vector2(720, 360))
	else:
		_flavor_label.text = "Тропа открылась. Подойди к порталу или нажми G."
		_hint_label.text = "Зона чиста. Портал / G — следующая зона."
		_spawn_portal(Vector2(640, 360))


func _spawn_merchant(pos: Vector2) -> void:
	if _merchant and is_instance_valid(_merchant):
		_merchant.queue_free()
	_merchant = Node2D.new()
	_merchant.global_position = pos
	_merchant.set_meta("merchant", true)
	var body := ColorRect.new()
	body.size = Vector2(28, 36)
	body.position = Vector2(-14, -18)
	body.color = Color(0.55, 0.4, 0.25)
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
		_hint_label.text = "Купец: E — свиток заговора/уз/алхимии за 30 золота (случайно)"


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


func _spawn_portal(pos: Vector2) -> void:
	if _portal and is_instance_valid(_portal):
		_portal.queue_free()
	_portal = Area2D.new()
	_portal.set_meta("portal", true)
	_portal.global_position = pos
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 36.0
	shape.shape = circle
	_portal.add_child(shape)
	var vis := ColorRect.new()
	vis.size = Vector2(48, 48)
	vis.position = Vector2(-24, -24)
	vis.color = Color(0.35, 0.75, 0.9, 0.75)
	_portal.add_child(vis)
	var lab := Label.new()
	lab.text = "ПОРТАЛ"
	lab.position = Vector2(-28, -44)
	_portal.add_child(lab)
	_world.add_child(_portal)


func _try_portal() -> void:
	if not _zone_clear or _portal == null or not is_instance_valid(_portal):
		return
	if player.global_position.distance_to(_portal.global_position) < 40.0:
		_go_next_zone()


func _go_next_zone() -> void:
	if _zone_index >= ZONES.size() - 1:
		return
	_enter_zone(_zone_index + 1)


func _spawn_loot(pos: Vector2, item: ItemData) -> void:
	var node := Node2D.new()
	node.global_position = pos
	node.set_meta("item", item)
	var visual := ColorRect.new()
	visual.size = Vector2(14, 14)
	visual.position = Vector2(-7, -7)
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
	var visual := ColorRect.new()
	visual.size = Vector2(10, 10)
	visual.position = Vector2(-5, -5)
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
