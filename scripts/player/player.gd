extends CharacterBody2D

signal hp_changed(current: float, maximum: float)
signal died

@export var body_color: Color = Color(0.75, 0.55, 0.35)

var stats: CombatStats = CombatStats.new()

var _dash_time: float = 0.0
var _dash_cooldown: float = 0.0
var _attack_cooldown: float = 0.0
var _skill_cooldown: float = 0.0
var _invuln: float = 0.0
var _facing: Vector2 = Vector2.RIGHT
var _hit_flash: float = 0.0

@onready var _visual: ColorRect = $Visual
@onready var _attack_area: Area2D = $AttackArc
@onready var _attack_shape: CollisionShape2D = $AttackArc/CollisionShape2D
@onready var _splash_area: Area2D = $SplashArea
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	stats.max_hp = 120.0
	stats.hp = 120.0
	stats.max_mana = 40.0
	stats.mana = 40.0
	stats.base_damage = 12.0
	stats.increased_damage = 0.2
	stats.crit_chance = 0.12
	stats.crit_multi = 1.5
	stats.move_speed = 200.0
	stats.resist_physical = 0.05
	_visual.color = body_color
	_attack_area.monitoring = false
	_splash_area.monitoring = false
	hp_changed.emit(stats.hp, stats.max_hp)


func _physics_process(delta: float) -> void:
	if not stats.is_alive():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_skill_cooldown = maxf(0.0, _skill_cooldown - delta)
	_invuln = maxf(0.0, _invuln - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	var prev_mana := stats.mana
	stats.mana = minf(stats.max_mana, stats.mana + 6.0 * delta)
	_visual.color = Color(1, 0.4, 0.4) if _hit_flash > 0.0 else body_color
	if absf(stats.mana - prev_mana) > 0.01:
		hp_changed.emit(stats.hp, stats.max_hp)

	if _dash_time > 0.0:
		_dash_time -= delta
		move_and_slide()
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir != Vector2.ZERO:
		_facing = input_dir.normalized()
		velocity = input_dir * stats.move_speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, stats.move_speed * 8.0 * delta)

	if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0.0:
		_start_dash()

	if Input.is_action_just_pressed("attack") and _attack_cooldown <= 0.0:
		_do_basic_attack()

	if Input.is_action_just_pressed("skill_splash") and _skill_cooldown <= 0.0:
		_do_splash()

	_update_attack_facing()
	move_and_slide()


func _start_dash() -> void:
	var dir := _facing
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir != Vector2.ZERO:
		dir = input_dir.normalized()
	velocity = dir * 520.0
	_dash_time = 0.14
	_dash_cooldown = 0.7
	_invuln = 0.14


func _update_attack_facing() -> void:
	var mouse := get_global_mouse_position()
	var to_mouse := (mouse - global_position)
	if to_mouse.length() > 4.0:
		_facing = to_mouse.normalized()
	_attack_area.rotation = _facing.angle()
	_splash_area.position = _facing * 28.0


func _do_basic_attack() -> void:
	_attack_cooldown = 0.35 / maxf(0.2, stats.attack_speed)
	_attack_area.monitoring = true
	_attack_shape.disabled = false
	_flash_attack_visual()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_resolve_hits(_attack_area, 0.0, 0.0)
	_attack_area.monitoring = false


func _do_splash() -> void:
	if stats.mana < 8.0:
		return
	stats.mana -= 8.0
	_skill_cooldown = 1.1
	_splash_area.monitoring = true
	_flash_splash_visual()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_resolve_hits(_splash_area, 6.0, 0.25) # +skill base, +25% more
	_splash_area.monitoring = false


func _resolve_hits(area: Area2D, skill_base: float, skill_more: float) -> void:
	for body in area.get_overlapping_bodies():
		if body.has_method("apply_damage"):
			var hit := Damage.roll_attack(stats, body.stats, skill_base, skill_more, 0.0, _facing)
			body.apply_damage(hit)


func apply_damage(hit: Damage) -> void:
	if not stats.is_alive():
		return
	if _invuln > 0.0 or _dash_time > 0.0:
		return
	if hit.result == Damage.HitResult.EVADED or hit.result == Damage.HitResult.BLOCKED:
		_spawn_float_text("блок" if hit.result == Damage.HitResult.BLOCKED else "мисс", Color(0.7, 0.7, 0.9))
		return
	stats.take_raw_hp(hit.amount)
	_hit_flash = 0.12
	if hit.knockback != Vector2.ZERO:
		velocity += hit.knockback
	hp_changed.emit(stats.hp, stats.max_hp)
	_spawn_float_text(str(int(round(hit.amount))), Color(1.0, 0.35, 0.35), hit.is_crit)
	if not stats.is_alive():
		died.emit()
		_visual.color = Color(0.2, 0.2, 0.2)


func _flash_attack_visual() -> void:
	var arc := ColorRect.new()
	arc.size = Vector2(42, 28)
	arc.position = Vector2(18, -14)
	arc.color = Color(1.0, 0.85, 0.4, 0.7)
	_attack_area.add_child(arc)
	get_tree().create_timer(0.1).timeout.connect(arc.queue_free)


func _flash_splash_visual() -> void:
	var blob := ColorRect.new()
	blob.size = Vector2(70, 70)
	blob.position = Vector2(-35, -35)
	blob.color = Color(0.9, 0.45, 0.2, 0.55)
	_splash_area.add_child(blob)
	get_tree().create_timer(0.12).timeout.connect(blob.queue_free)


func _spawn_float_text(text: String, color: Color, crit: bool = false) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	if crit:
		label.scale = Vector2(1.4, 1.4)
		label.text = text + "!"
	label.global_position = global_position + Vector2(-10, -40)
	get_tree().current_scene.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "global_position", label.global_position + Vector2(0, -36), 0.55)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.55)
	tween.tween_callback(label.queue_free)


func revive_at(pos: Vector2) -> void:
	global_position = pos
	stats.heal_full()
	_visual.color = body_color
	hp_changed.emit(stats.hp, stats.max_hp)
