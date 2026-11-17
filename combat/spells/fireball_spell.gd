class_name FireballSpell
extends Spell
## Casts a Fireball in the aim direction; the ball reports its blast damage back here.
## The steam burst (a fused spell) is the same kind of ball with its own numbers and look.


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
	ball.blast_time = stats.blast_time
	ball.set_look(stats.frames, stats.animation_at(level), stats.rotate_look, stats.look_scale, stats.blast_look)
	if level >= stats.trail_min_level:
		ball.set_trail(stats.frames, stats.trail_animation, stats.trail_spacing, stats.trail_time)
	# If this spell is forgotten while the ball flies, Godot drops the connection.
	ball.exploded.connect(_report_damage)
	_effect_parent().add_child(ball)
	ball.global_position = caster.global_position
