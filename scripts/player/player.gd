extends CharacterBody2D

signal hp_changed(current: float, maximum: float)
signal died
signal progress_changed
signal inventory_changed

@export var body_color: Color = Color(0.75, 0.55, 0.35)

var stats: CombatStats = CombatStats.new()
var progress: PlayerProgress = PlayerProgress.new()
var inventory: Inventory = Inventory.new()
var passives: PassiveTree = PassiveTree.new()
var life_leech: float = 0.0

var _dash_time: float = 0.0
var _dash_cooldown: float = 0.0
var _attack_cooldown: float = 0.0
var _skill_cooldown: float = 0.0
var _slam_cooldown: float = 0.0
var _invuln: float = 0.0
var _facing: Vector2 = Vector2.RIGHT
var _hit_flash: float = 0.0
var _shake_time: float = 0.0
var _shake_power: float = 0.0
var _unarmed_damage: float = 8.0

@onready var _visual: ColorRect = $Visual
@onready var _attack_area: Area2D = $AttackArc
@onready var _attack_shape: CollisionShape2D = $AttackArc/CollisionShape2D
@onready var _splash_area: Area2D = $SplashArea
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	inventory.changed.connect(func() -> void:
		_recompute_from_gear()
		inventory_changed.emit()
	)
	passives.changed.connect(func() -> void:
		_recompute_from_gear()
		progress_changed.emit()
	)
	progress.leveled_up.connect(_on_leveled_up)
	progress.xp_changed.connect(func(_a, _b, _c) -> void: progress_changed.emit())
	passives.add_point(1) # стартовое очко
	_recompute_from_gear()
	stats.heal_full()
	_visual.color = body_color
	_attack_area.monitoring = false
	_splash_area.monitoring = false
	hp_changed.emit(stats.hp, stats.max_hp)
	progress_changed.emit()
	inventory_changed.emit()


func _physics_process(delta: float) -> void:
	if not stats.is_alive():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_skill_cooldown = maxf(0.0, _skill_cooldown - delta)
	_slam_cooldown = maxf(0.0, _slam_cooldown - delta)
	_invuln = maxf(0.0, _invuln - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	var prev_mana := stats.mana
	stats.mana = minf(stats.max_mana, stats.mana + 6.0 * delta)
	_visual.color = Color(1, 0.4, 0.4) if _hit_flash > 0.0 else body_color
	if absf(stats.mana - prev_mana) > 0.01:
		hp_changed.emit(stats.hp, stats.max_hp)

	_update_shake(delta)

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
		if progress.skill_unlocked(&"splash"):
			_do_splash()

	if Input.is_action_just_pressed("skill_slam") and _slam_cooldown <= 0.0:
		if progress.skill_unlocked(&"ground_slam"):
			_do_ground_slam()

	_update_attack_facing()
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.keycode
		if code >= KEY_1 and code <= KEY_9:
			inventory.equip(code - KEY_1)
		elif code == KEY_I:
			if inventory.identify_first():
				Sfx.play_pickup()
				_spawn_float_text("Опознано", Color(0.5, 0.8, 1.0))
		elif code >= KEY_F1 and code <= KEY_F8:
			if passives.try_buy(code - KEY_F1):
				Sfx.play_level_up()
				_spawn_float_text("Пассивка!", Color(0.7, 0.9, 0.4))


func _start_dash() -> void:
	var dir := _facing
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir != Vector2.ZERO:
		dir = input_dir.normalized()
	velocity = dir * 520.0
	_dash_time = 0.14
	_dash_cooldown = 0.7
	_invuln = 0.14
	Sfx.play_dash()


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
	Sfx.play_swing()
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
	Sfx.play_swing()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_resolve_hits(_splash_area, 6.0, 0.25)
	_splash_area.monitoring = false
	shake(4.0, 0.1)


func _do_ground_slam() -> void:
	if stats.mana < 12.0:
		return
	stats.mana -= 12.0
	_slam_cooldown = 1.6
	_splash_area.monitoring = true
	_flash_slam_visual()
	Sfx.play_swing()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_resolve_hits(_splash_area, 14.0, 0.4)
	_splash_area.monitoring = false
	shake(8.0, 0.18)


func _resolve_hits(area: Area2D, skill_base: float, skill_more: float) -> void:
	var any := false
	var any_crit := false
	var dealt := 0.0
	for body in area.get_overlapping_bodies():
		if body.has_method("apply_damage"):
			var hit := Damage.roll_attack(stats, body.stats, skill_base, skill_more, 0.0, _facing)
			body.apply_damage(hit)
			if hit.amount > 0.0:
				any = true
				any_crit = any_crit or hit.is_crit
				dealt += hit.amount
				_spawn_hit_spark(body.global_position, hit.is_crit)
	if dealt > 0.0 and life_leech > 0.0 and stats.is_alive():
		stats.hp = minf(stats.max_hp, stats.hp + dealt * life_leech)
		hp_changed.emit(stats.hp, stats.max_hp)
	if any:
		Sfx.play_hit(any_crit)
		shake(6.0 if any_crit else 3.0, 0.12 if any_crit else 0.08)


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
	Sfx.play_hurt()
	shake(5.0, 0.12)
	if not stats.is_alive():
		died.emit()
		_visual.color = Color(0.2, 0.2, 0.2)


func gain_xp(amount: int) -> void:
	progress.add_xp(amount)


func try_pickup(item: ItemData) -> bool:
	if inventory.add(item):
		Sfx.play_pickup()
		_spawn_float_text(item.display_name, item.color)
		return true
	return false


func _recompute_from_gear() -> void:
	var hp_ratio: float = 1.0 if stats.max_hp <= 0.0 else stats.hp / stats.max_hp
	var weapon_dmg: float = _unarmed_damage
	var inc: float = 0.15 + progress.strength * 0.01 + passives.get_bonus(&"inc_damage")
	var armor: float = passives.get_bonus(&"armor")
	var bonus_hp: float = progress.strength * 2.0 + passives.get_bonus(&"hp")
	var more_list: Array[float] = []
	var bag: Dictionary = {}
	life_leech = passives.get_bonus(&"leech")

	var weapon := inventory.get_equipped(ItemData.Slot.WEAPON)
	if weapon:
		weapon_dmg = weapon.base_damage
		weapon.accumulate_into(bag)

	for eq in inventory.all_equipped():
		if eq.slot != ItemData.Slot.WEAPON:
			armor += eq.base_armor
			eq.accumulate_into(bag)

	inc += float(bag.get(int(AffixDef.Stat.INCREASED_DAMAGE), 0.0))
	weapon_dmg += float(bag.get(int(AffixDef.Stat.FLAT_DAMAGE), 0.0))
	bonus_hp += float(bag.get(int(AffixDef.Stat.FLAT_HP), 0.0))
	armor += float(bag.get(int(AffixDef.Stat.FLAT_ARMOR), 0.0))
	life_leech += float(bag.get(int(AffixDef.Stat.LIFE_LEECH), 0.0))

	stats.base_damage = weapon_dmg
	stats.added_damage = progress.strength * 0.4
	stats.increased_damage = inc
	stats.more_multipliers = more_list
	stats.armor = armor
	stats.crit_chance = 0.08 + progress.dexterity * 0.004 + passives.get_bonus(&"crit") + float(bag.get(int(AffixDef.Stat.CRIT_CHANCE), 0.0))
	stats.crit_multi = 1.5 + passives.get_bonus(&"crit_multi") + float(bag.get(int(AffixDef.Stat.CRIT_MULTI), 0.0))
	stats.move_speed = 190.0 + progress.dexterity * 1.5 + passives.get_bonus(&"move") + float(bag.get(int(AffixDef.Stat.MOVE_SPEED), 0.0)) * 100.0
	stats.max_mana = 30.0 + progress.intelligence * 2.0 + passives.get_bonus(&"mana") + float(bag.get(int(AffixDef.Stat.MANA), 0.0))
	stats.max_hp = 100.0 + bonus_hp
	stats.hp = clampf(stats.max_hp * hp_ratio, 1.0, stats.max_hp)
	stats.mana = minf(stats.mana, stats.max_mana)
	stats.block_chance = float(bag.get(int(AffixDef.Stat.BLOCK_CHANCE), 0.0))
	stats.resist_physical = 0.05 + float(bag.get(int(AffixDef.Stat.RESIST_PHYS), 0.0))
	stats.resist_fire = float(bag.get(int(AffixDef.Stat.RESIST_FIRE), 0.0))
	stats.resist_cold = float(bag.get(int(AffixDef.Stat.RESIST_COLD), 0.0))
	stats.resist_lightning = float(bag.get(int(AffixDef.Stat.RESIST_LIGHTNING), 0.0))
	stats.resist_chaos = float(bag.get(int(AffixDef.Stat.RESIST_CHAOS), 0.0))
	stats.attack_speed = 1.0 + progress.dexterity * 0.01 + float(bag.get(int(AffixDef.Stat.ATTACK_SPEED), 0.0))
	hp_changed.emit(stats.hp, stats.max_hp)
	progress_changed.emit()


func _on_leveled_up(new_level: int) -> void:
	passives.add_point(progress.passive_points_on_level)
	_recompute_from_gear()
	stats.hp = stats.max_hp
	Sfx.play_level_up()
	_spawn_float_text("Уровень %d!" % new_level, Color(0.95, 0.85, 0.3), true)
	shake(7.0, 0.2)
	hp_changed.emit(stats.hp, stats.max_hp)


func shake(power: float, time: float) -> void:
	_shake_power = maxf(_shake_power, power)
	_shake_time = maxf(_shake_time, time)


func _update_shake(delta: float) -> void:
	if _shake_time <= 0.0:
		_camera.offset = Vector2.ZERO
		return
	_shake_time -= delta
	_camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_power
	_shake_power = move_toward(_shake_power, 0.0, delta * 30.0)


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


func _flash_slam_visual() -> void:
	var ring := ColorRect.new()
	ring.size = Vector2(90, 90)
	ring.position = Vector2(-45, -45)
	ring.color = Color(0.7, 0.35, 0.15, 0.65)
	_splash_area.add_child(ring)
	get_tree().create_timer(0.15).timeout.connect(ring.queue_free)


func _spawn_hit_spark(pos: Vector2, crit: bool) -> void:
	var spark := ColorRect.new()
	spark.size = Vector2(10, 10) if not crit else Vector2(16, 16)
	spark.color = Color(1.0, 0.95, 0.5, 0.9) if not crit else Color(1.0, 0.6, 0.2, 1.0)
	spark.global_position = pos + Vector2(-5, -5)
	get_tree().current_scene.add_child(spark)
	var tween := create_tween()
	tween.tween_property(spark, "modulate:a", 0.0, 0.18)
	tween.parallel().tween_property(spark, "scale", Vector2(1.8, 1.8), 0.18)
	tween.tween_callback(spark.queue_free)


func _spawn_float_text(text: String, color: Color, crit: bool = false) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	if crit:
		label.scale = Vector2(1.4, 1.4)
		if not text.ends_with("!"):
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
