class_name StoneSpikesSpell
extends Spell
## Earth's stone spikes (stage 40): the line is measured at the cast (it stops at the
## first wall), every enemy within spike_radius of a spike point is hit once and
## stunned, then the spikes come up one after another as a look. The spikes stay where
## they rose (drawn in world space), even if the caster walks on.

## Placeholder look of one spike: a triangle this wide and tall.
@export var spike_width: float = 6.0
@export var spike_height: float = 10.0

## Spike points of the last cast, in world space, and seconds since it.
var _points: PackedVector2Array = PackedVector2Array()
var _age: float = -1.0
## How many spikes of the last cast have come up as art so far.
var _spawned: int = 0


func _cast(direction: Vector2) -> void:
	var stats: StoneSpikesData = data as StoneSpikesData
	if stats == null:
		return
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var origin: Vector2 = caster.global_position
	var length: float = SpellData.float_at(stats.length, level)
	var wall: Dictionary = space.intersect_ray(PhysicsRayQueryParameters2D.create(origin, origin + direction * length, wall_mask))
	if not wall.is_empty():
		length = origin.distance_to(wall["position"])
	_points.clear()
	var along: float = stats.spacing
	while along <= length:
		_points.append(origin + direction * along)
		along += stats.spacing
	var hit: Array[Hurtbox] = []
	for point: Vector2 in _points:
		for hurtbox: Hurtbox in AreaDamage.targets(space, point, stats.spike_radius, target_mask, wall_mask):
			if not hurtbox in hit:
				hit.append(hurtbox)
	var dealt: int = 0
	var damage: int = SpellData.int_at(stats.damage, level)
	for hurtbox: Hurtbox in hit:
		var info: DamageInfo = DamageInfo.new(damage, caster, stats.id)
		info.direction = direction
		if hurtbox.receive_hit(info):
			dealt += damage
			var enemy: Enemy = Enemy.owner_of(hurtbox)
			if enemy != null and is_instance_valid(enemy):
				enemy.stun(SpellData.float_at(stats.stun_time, level))
	_report_damage(dealt)
	_age = 0.0
	_spawned = 0
	queue_redraw()


func _physics_process(delta: float) -> void:
	super(delta)
	if _age < 0.0:
		return
	_age += delta
	var stats: StoneSpikesData = data as StoneSpikesData
	var animation: StringName = stats.animation_at(level)
	# With art every spike is a one-off animation in the level, one after another.
	while animation != &"" and _spawned < _points.size() and _age >= stats.spike_delay * _spawned:
		var spike: EffectSprite = EffectSprite.spawn(_effect_parent(), _points[_spawned], stats.frames, animation)
		spike.offset = stats.spike_offset
		_spawned += 1
	if _age > stats.spike_delay * _points.size() + stats.spike_time:
		_age = -1.0
	queue_redraw()


func _draw() -> void:
	var stats: StoneSpikesData = data as StoneSpikesData
	if _age < 0.0 or stats.animation_at(level) != &"":
		return
	for i in _points.size():
		var shown: float = _age - stats.spike_delay * i
		if shown < 0.0 or shown > stats.spike_time:
			continue
		var t: float = shown / stats.spike_time
		var base: Vector2 = to_local(_points[i])
		var height: float = spike_height * minf(t * 4.0, 1.0)
		var color: Color = Color(stats.color, 1.0 - maxf(t - 0.6, 0.0) * 2.5)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-spike_width * 0.5, 0.0),
				base + Vector2(spike_width * 0.5, 0.0), base + Vector2(0.0, -height)]), color)
