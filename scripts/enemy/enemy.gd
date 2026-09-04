class_name Enemy
extends CharacterBody2D

enum EnemyKind { NORMAL, FAST, TANK, RANGED, BOSS }

signal died(enemy)

@export var kind: EnemyKind = EnemyKind.NORMAL

var stats: CombatStats = CombatStats.new()
var player: Node2D
var _attack_cd: float = 0.0
var _hit_flash: float = 0.0
var _body_color: Color = Color(0.55, 0.2, 0.25)

@onready var _visual: ColorRect = $Visual
@onready var _hp_bar: ColorRect = $HpBar
@onready var _hp_bg: ColorRect = $HpBarBg


func _ready() -> void:
	_apply_kind()
	stats.heal_full()
	_visual.color = _body_color
	add_to_group("enemies")


func setup(p: Node2D, enemy_kind: EnemyKind) -> void:
	player = p
	kind = enemy_kind
	_apply_kind()
	stats.heal_full()
	_visual.color = _body_color


func _apply_kind() -> void:
	match kind:
		EnemyKind.NORMAL:
			stats.max_hp = 40.0
			stats.base_damage = 6.0
			stats.move_speed = 95.0
			stats.resist_physical = 0.0
			_body_color = Color(0.55, 0.2, 0.25)
			scale = Vector2.ONE
		EnemyKind.FAST:
			stats.max_hp = 22.0
			stats.base_damage = 5.0
			stats.move_speed = 160.0
			stats.evasion = 40.0
			_body_color = Color(0.75, 0.45, 0.15)
			scale = Vector2(0.85, 0.85)
		EnemyKind.TANK:
			stats.max_hp = 120.0
			stats.base_damage = 10.0
			stats.move_speed = 55.0
			stats.armor = 25.0
			stats.resist_physical = 0.15
			_body_color = Color(0.35, 0.3, 0.45)
			scale = Vector2(1.35, 1.35)
		EnemyKind.RANGED:
			stats.max_hp = 28.0
			stats.base_damage = 8.0
			stats.move_speed = 80.0
			_body_color = Color(0.25, 0.45, 0.55)
			scale = Vector2(0.95, 0.95)
		EnemyKind.BOSS:
			stats.max_hp = 420.0
			stats.base_damage = 16.0
			stats.move_speed = 70.0
			stats.armor = 35.0
			stats.resist_physical = 0.2
			stats.block_chance = 0.1
			_body_color = Color(0.45, 0.1, 0.15)
			scale = Vector2(1.8, 1.8)


func _physics_process(delta: float) -> void:
	if not stats.is_alive():
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	_visual.color = Color(1, 1, 1) if _hit_flash > 0.0 else _body_color
	_update_hp_bar()

	if player == null or not is_instance_valid(player):
		return
	if not player.stats.is_alive():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_player := player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player.normalized() if dist > 0.001 else Vector2.RIGHT

	match kind:
		EnemyKind.RANGED:
			# Не убегает: подходит, пока цель вне радиуса атаки, иначе стоит и стреляет.
			const RANGED_RANGE := 280.0
			if dist > RANGED_RANGE:
				velocity = dir * stats.move_speed
			else:
				velocity = Vector2.ZERO
				if _attack_cd <= 0.0:
					_ranged_attack(dir)
		_:
			const MELEE_RANGE := 28.0
			if dist > MELEE_RANGE:
				velocity = dir * stats.move_speed
			else:
				velocity = Vector2.ZERO
				if _attack_cd <= 0.0:
					_melee_attack(dir)

	move_and_slide()


func _melee_attack(dir: Vector2) -> void:
	_attack_cd = 0.9
	if player.has_method("apply_damage"):
		var hit := Damage.roll_attack(stats, player.stats, 0.0, 0.0, 0.0, dir)
		player.apply_damage(hit)


func _ranged_attack(dir: Vector2) -> void:
	_attack_cd = 1.2
	# Простой «снаряд»-точка: мгновенный хит с задержкой ощущения
	var marker := ColorRect.new()
	marker.size = Vector2(10, 10)
	marker.color = Color(0.4, 0.8, 1.0, 0.9)
	marker.global_position = global_position
	get_tree().current_scene.add_child(marker)
	var target_pos := player.global_position
	var tween := create_tween()
	tween.tween_property(marker, "global_position", target_pos, 0.28)
	tween.tween_callback(func() -> void:
		if is_instance_valid(player) and player.global_position.distance_to(target_pos) < 36.0:
			var hit := Damage.roll_attack(stats, player.stats, 2.0, 0.0, 0.0, dir)
			player.apply_damage(hit)
		marker.queue_free()
	)


func xp_reward() -> int:
	match kind:
		EnemyKind.FAST:
			return 12
		EnemyKind.TANK:
			return 28
		EnemyKind.RANGED:
			return 16
		EnemyKind.BOSS:
			return 120
		_:
			return 10


func gold_reward() -> int:
	match kind:
		EnemyKind.BOSS:
			return randi_range(40, 70)
		EnemyKind.TANK:
			return randi_range(8, 18)
		EnemyKind.RANGED:
			return randi_range(4, 10)
		EnemyKind.FAST:
			return randi_range(3, 8)
		_:
			return randi_range(2, 6)


func roll_drop() -> ItemData:
	if randf() < 0.42:
		return null
	return ItemData.roll_loot(1 + int(stats.max_hp / 40.0))


func apply_damage(hit: Damage) -> void:
	if not stats.is_alive():
		return
	if hit.result == Damage.HitResult.EVADED:
		FloatingText.spawn(self, global_position, "мисс", Color(0.7, 0.7, 0.9))
		return
	if hit.result == Damage.HitResult.BLOCKED:
		FloatingText.spawn(self, global_position, "блок", Color(0.7, 0.7, 0.9))
		return

	stats.take_raw_hp(hit.amount)
	_hit_flash = 0.1
	if hit.knockback != Vector2.ZERO:
		global_position += hit.knockback * 0.35
	FloatingText.spawn(self, global_position, str(int(round(hit.amount))), Color(1.0, 0.9, 0.3), hit.is_crit)
	_update_hp_bar()
	if not stats.is_alive():
		died.emit(self)
		queue_free()


func _update_hp_bar() -> void:
	var ratio := clampf(stats.hp / stats.max_hp, 0.0, 1.0)
	_hp_bar.size.x = 28.0 * ratio
