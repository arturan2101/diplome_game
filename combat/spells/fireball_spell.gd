class_name FireballSpell
extends Spell
## Casts a Fireball in the aim direction; the ball reports its blast damage back here.


func _cast(direction: Vector2) -> void:
	var stats: FireballData = data as FireballData
	if stats == null or stats.projectile_scene == null:
		push_error("FireballSpell needs FireballData with a projectile_scene: %s" % data)
		return
	var ball: Fireball = stats.projectile_scene.instantiate() as Fireball
	var info: DamageInfo = DamageInfo.new(SpellData.int_at(stats.damage, level), caster, stats.id)
	ball.setup(info, direction, stats.speed, stats.max_range, SpellData.float_at(stats.radius, level),
			stats.knockback, target_mask, wall_mask)
	ball.color = stats.color
	# If this spell is forgotten while the ball flies, Godot drops the connection.
	ball.exploded.connect(_report_damage)
	_effect_parent().add_child(ball)
	ball.global_position = caster.global_position
