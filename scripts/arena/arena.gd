extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

@onready var _world: Node2D = $World
@onready var _spawn_points: Node2D = $SpawnPoints
@onready var _hud: CanvasLayer = $HUD
@onready var _hp_label: Label = $HUD/Root/HpLabel
@onready var _hint_label: Label = $HUD/Root/HintLabel
@onready var _wave_label: Label = $HUD/Root/WaveLabel

var player: CharacterBody2D
var _wave: int = 1
var _alive_enemies: int = 0


func _ready() -> void:
	_hint_label.text = "WASD — ход | ЛКМ — удар | Q — сплеш | Пробел — рывок | R — рестарт"
	_spawn_player()
	_spawn_wave()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.global_position = Vector2(640, 360)
	_world.add_child(player)
	player.hp_changed.connect(_on_player_hp)
	player.died.connect(_on_player_died)
	_on_player_hp(player.stats.hp, player.stats.max_hp)


func _on_player_hp(current: float, maximum: float) -> void:
	_hp_label.text = "HP %d / %d   Mana %d" % [int(current), int(maximum), int(player.stats.mana)]


func _on_player_died() -> void:
	_hint_label.text = "Ты пал. Нажми R чтобы встать снова."


func _spawn_wave() -> void:
	_wave_label.text = "Волна %d" % _wave
	var kinds: Array = [
		Enemy.EnemyKind.NORMAL,
		Enemy.EnemyKind.NORMAL,
		Enemy.EnemyKind.FAST,
		Enemy.EnemyKind.TANK,
		Enemy.EnemyKind.RANGED,
	]
	# Больше врагов с волнами
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


func _on_enemy_died(_enemy: Node) -> void:
	_alive_enemies = maxi(0, _alive_enemies - 1)
	if _alive_enemies <= 0 and player.stats.is_alive():
		_wave += 1
		await get_tree().create_timer(1.0).timeout
		_spawn_wave()
