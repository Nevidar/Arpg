class_name Damage
extends RefCounted

## Формула урона Nevidar (черновик из дизайн-дока).
## (base + added) * (1 + increased) * product(more) * crit_multi * (1 - resist + pen)

enum HitResult { HIT, CRIT, EVADED, BLOCKED }

var amount: float = 0.0
var damage_type: StringName = &"physical"
var is_crit: bool = false
var result: HitResult = HitResult.HIT
var knockback: Vector2 = Vector2.ZERO


static func roll_attack(
	attacker: CombatStats,
	defender: CombatStats,
	skill_base: float = 0.0,
	skill_more: float = 0.0,
	penetration: float = 0.0,
	aim_dir: Vector2 = Vector2.ZERO
) -> Damage:
	var d := Damage.new()

	# Уклонение (упрощённо)
	if defender.evasion > 0.0:
		var evade_roll := randf()
		var evade_chance := clampf(defender.evasion / (defender.evasion + 200.0), 0.0, 0.75)
		if evade_roll < evade_chance:
			d.result = HitResult.EVADED
			d.amount = 0.0
			return d

	# Блок
	if defender.block_chance > 0.0 and randf() < defender.block_chance:
		d.result = HitResult.BLOCKED
		d.amount = 0.0
		return d

	var base := attacker.base_damage + attacker.added_damage + skill_base
	var increased := 1.0 + attacker.increased_damage
	var more := 1.0
	for m in attacker.more_multipliers:
		more *= (1.0 + m)
	if skill_more != 0.0:
		more *= (1.0 + skill_more)

	var pre_crit := base * increased * more

	# Крит
	var crit_chance := clampf(attacker.crit_chance, 0.0, 0.95)
	if randf() < crit_chance:
		d.is_crit = true
		d.result = HitResult.CRIT
		pre_crit *= attacker.crit_multi
	else:
		d.result = HitResult.HIT

	# Броня как плоский DR (очень упрощённо)
	var after_armor := maxf(0.0, pre_crit - defender.armor * 0.15)

	var resist := clampf(defender.get_resist(d.damage_type) - penetration, 0.0, 0.9)
	d.amount = after_armor * (1.0 - resist)

	if aim_dir != Vector2.ZERO:
		d.knockback = aim_dir.normalized() * (80.0 if d.is_crit else 40.0)

	return d
