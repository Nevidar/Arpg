extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

@onready var _world: Node2D = $World
@onready var _spawn_points: Node2D = $SpawnPoints
@onready var _hp_label: Label = $HUD/Root/HpLabel
@onready var _hint_label: Label = $HUD/Root/HintLabel
@onready var _wave_label: Label = $HUD/Root/WaveLabel
@onready var _stats_label: Label = $HUD/Root/StatsLabel
@onready var _inv_label: Label = $HUD/Root/InvLabel

var player: CharacterBody2D
var _wave: int = 1
var _alive_enemies: int = 0
var _loot_nodes: Array[Node2D] = []


func _ready() -> void:
	_hint_label.text = "WASD ход | ЛКМ удар | Q сплеш | E удар по земле (ур.4) | Пробел рывок | 1-9 экип | R рестарт"
	_spawn_player()
	_spawn_wave()


func _process(_delta: float) -> void:
	_try_pickup_loot()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.global_position = Vector2(640, 360)
	_world.add_child(player)
	player.hp_changed.connect(_on_player_hp)
	player.died.connect(_on_player_died)
	player.progress_changed.connect(_refresh_stats)
	player.inventory_changed.connect(_refresh_inv)
	_on_player_hp(player.stats.hp, player.stats.max_hp)
	_refresh_stats()
	_refresh_inv()


func _on_player_hp(current: float, maximum: float) -> void:
	_hp_label.text = "HP %d/%d  Mana %d" % [int(current), int(maximum), int(player.stats.mana)]


func _on_player_died() -> void:
	_hint_label.text = "Ты пал. Нажми R чтобы начать волну заново."


func _refresh_stats() -> void:
	var p: PlayerProgress = player.progress
	_stats_label.text = "Ур.%d  XP %d/%d\nСИЛ %.0f  ЛОВ %.1f  ИНТ %.1f  Урон %.0f" % [
		p.level, p.xp, p.xp_to_next(),
		p.strength, p.dexterity, p.intelligence,
		player.stats.base_damage + player.stats.added_damage
	]


func _refresh_inv() -> void:
	_inv_label.text = "\n".join(player.inventory.summary_lines())


func _spawn_wave() -> void:
	_wave_label.text = "Волна %d" % _wave
	var kinds: Array = [
		Enemy.EnemyKind.NORMAL,
		Enemy.EnemyKind.NORMAL,
		Enemy.EnemyKind.FAST,
		Enemy.EnemyKind.TANK,
		Enemy.EnemyKind.RANGED,
	]
	var count := mini(4 + _wave, kinds.size() + _wave)
	for i in count:
		var pt: Marker2D = _spawn_points.get_child(i % _spawn_points.get_child_count())
		var enemy: CharacterBody2D = ENEMY_SCENE.instantiate()
		_world.add_child(enemy)
		enemy.global_position = pt.global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		var kind: int = kinds[i % kinds.size()]
		if _wave >= 3 and i == 0:
			kind = Enemy.EnemyKind.TANK
		enemy.setup(player, kind)
		enemy.died.connect(_on_enemy_died)
		_alive_enemies += 1


func _on_enemy_died(enemy: Node) -> void:
	_alive_enemies = maxi(0, _alive_enemies - 1)
	if is_instance_valid(enemy):
		if player and player.stats.is_alive():
			player.gain_xp(enemy.xp_reward())
		var drop: ItemData = enemy.roll_drop()
		if drop:
			_spawn_loot(enemy.global_position, drop)
	_refresh_stats()
	if _alive_enemies <= 0 and player.stats.is_alive():
		_wave += 1
		await get_tree().create_timer(1.0).timeout
		_spawn_wave()


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


func _try_pickup_loot() -> void:
	if player == null or not player.stats.is_alive():
		return
	var remain: Array[Node2D] = []
	for node in _loot_nodes:
		if not is_instance_valid(node):
			continue
		if player.global_position.distance_to(node.global_position) <= 28.0:
			var item: ItemData = node.get_meta("item")
			if player.try_pickup(item):
				node.queue_free()
				continue
		remain.append(node)
	_loot_nodes = remain
