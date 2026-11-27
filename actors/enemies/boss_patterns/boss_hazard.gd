class_name BossHazard
extends Node2D
## Base of the pieces a BossPattern puts on the floor (stage 50): a line, sweeping arms,
## a field of cells. Each knows its own timing: hidden for start_delay, a warning for
## the pattern's warn_time, then the strike. It hurts the player's hurtbox only where it
## warned, each target at most once per rehit_time, and frees itself when done (or when
## its boss dies).
## threatens() answers for the bots whether a point will be hurt within a time window;
## the bots only "see" what the player sees, as they read it after their reaction time.

## Every live hazard is in this group, for the bots.
const GROUP: StringName = &"boss_hazards"
## Seconds a target is safe after being hit by the same hazard.
const REHIT_TIME: float = 0.8

var pattern: BossPattern = null
var damage: int = 0
var caster: Node = null
var source_id: StringName = &""
var target_mask: int = 0
## Seconds before the warning shows.
var start_delay: float = 0.0
## Seconds since the hazard was placed.
var age: float = 0.0
## Hurtbox instance id -> age when it was last hit.
var _hit_at: Dictionary = {}
var _strike_played: bool = false


## Adds the hazard to the level's floor-effects layer (over the floor, under the actors)
## or to host, at a world position. Cleared between sections like arrows.
static func place(hazard: BossHazard, host: Node, at: Vector2) -> BossHazard:
	hazard.add_to_group(GROUP)
	hazard.add_to_group(Arrow.GROUP)
	var parent: Node = host
	var level: Level = host.get_tree().get_first_node_in_group(Level.GROUP) as Level if host.is_inside_tree() else null
	if level != null and level.floor_effects != null:
		parent = level.floor_effects
	parent.add_child(hazard)
	hazard.global_position = at
	return hazard


## True if any live hazard (of only, when given) will hurt a body of radius margin at
## point at some moment between from_time and to_time seconds from now.
static func threat_at(tree: SceneTree, point: Vector2, margin: float, from_time: float, to_time: float,
		only: Array = []) -> bool:
	for node: Variant in (only if not only.is_empty() else tree.get_nodes_in_group(GROUP)):
		if not is_instance_valid(node):
			continue
		var hazard: BossHazard = node as BossHazard
		if hazard == null or hazard.is_queued_for_deletion():
			continue
		if hazard.threatens(point, margin, from_time, to_time):
			return true
	return false


func setup(from_pattern: BossPattern, hit: int, by: Node, id: StringName, mask: int, delay: float = 0.0) -> BossHazard:
	pattern = from_pattern
	damage = hit
	caster = by
	source_id = id
	target_mask = mask
	start_delay = delay
	return self


## Seconds from now until the (first) strike; negative once it has struck.
func time_to_strike() -> float:
	return start_delay + pattern.warn_time - age


func is_warning() -> bool:
	return age >= start_delay and time_to_strike() > 0.0


## True if a body of radius margin at point gets hurt by this hazard between from_time
## and to_time seconds from now. Each kind of hazard answers for its shape.
func threatens(_point: Vector2, _margin: float, _from_time: float, _to_time: float) -> bool:
	return false


## True when nothing of it is left to happen or to show.
func is_finished() -> bool:
	return false


func _physics_process(delta: float) -> void:
	age += delta
	if _caster_gone() or is_finished():
		queue_free()
		set_physics_process(false)
		return
	if not _strike_played and time_to_strike() <= 0.0:
		_strike_played = true
		Sound.play_at(pattern.strike_sound, global_position)
	_update(delta)
	queue_redraw()


func _update(_delta: float) -> void:
	pass


## The boss is dead or gone: its attacks vanish with it.
func _caster_gone() -> bool:
	if caster == null:
		return false
	if not is_instance_valid(caster):
		return true
	var enemy: Enemy = caster as Enemy
	return enemy != null and enemy.health != null and enemy.health.is_dead()


## Hits a target once per REHIT_TIME, pushing it along push (a unit vector).
func _hit(hurtbox: Hurtbox, push: Vector2) -> void:
	var id: int = hurtbox.get_instance_id()
	if _hit_at.has(id) and age - float(_hit_at[id]) < REHIT_TIME:
		return
	var source: Node = caster if is_instance_valid(caster) else null
	var info: DamageInfo = DamageInfo.new(damage, source, source_id, push * pattern.knockback)
	info.direction = push
	if hurtbox.receive_hit(info):
		_hit_at[id] = age


## The target hurtboxes overlapping a band: from a point along an angle, length long,
## half_width to each side (world coordinates).
func _hurtboxes_in_band(from: Vector2, angle: float, length: float, half_width: float) -> Array[Hurtbox]:
	var found: Array[Hurtbox] = []
	if length <= 0.0:
		return found
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(length, half_width * 2.0)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = rect
	query.transform = Transform2D(angle, from + Vector2.from_angle(angle) * length * 0.5)
	query.collision_mask = target_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for result: Dictionary in get_world_2d().direct_space_state.intersect_shape(query):
		var hurtbox: Hurtbox = result["collider"] as Hurtbox
		if hurtbox != null and not hurtbox in found:
			found.append(hurtbox)
	return found


## How far a line from a world point along an angle runs over the level before a wall
## stops it, at most max_length (without a level: max_length). Lines lash over pits and
## pillars (cover): a pillar in the middle of an arena must not break a sweep.
func _reach(from: Vector2, angle: float, max_length: float) -> float:
	var level: Level = get_tree().get_first_node_in_group(Level.GROUP) as Level if is_inside_tree() else null
	return BossHazard.reach_on(level, from, angle, max_length)


static func reach_on(level: Level, from: Vector2, angle: float, max_length: float) -> float:
	if level == null or level.grid == null:
		return max_length
	const STEP: float = 4.0
	var direction: Vector2 = Vector2.from_angle(angle)
	var travelled: float = 0.0
	while travelled < max_length:
		var next: float = minf(travelled + STEP, max_length)
		if level.cell_type_at(from + direction * next) == LevelGrid.Cell.WALL:
			return travelled
		travelled = next
	return max_length


# --- drawing -------------------------------------------------------------

## Draws a strip's frame tiled along +x (local) from start to end, centred on the x
## axis, height high; the last piece is cut to fit. Without a texture, a band in color.
func _draw_band(texture: Texture2D, frames: int, frame: int, start: float, end: float, height: float,
		color: Color, alpha: float) -> void:
	if end <= start:
		return
	if texture == null:
		draw_rect(Rect2(start, -height * 0.5, end - start, height), Color(color, color.a * alpha))
		return
	var size: float = float(texture.get_height())
	var source_x: float = float(posmod(frame, maxi(frames, 1))) * size
	var x: float = start
	while x < end:
		var piece: float = minf(size, end - x)
		draw_texture_rect_region(texture, Rect2(x, -height * 0.5, piece, height),
				Rect2(source_x, 0.0, piece, size), Color(1.0, 1.0, 1.0, alpha))
		x += piece


## The striking body (a vine) along +x from 0 to reach, its tip at the end.
func _draw_strike(reach: float, frame: int) -> void:
	if reach <= 0.0:
		return
	var tip: float = minf(16.0, reach) if pattern.tip_texture != null else 0.0
	_draw_band(pattern.strike_texture, pattern.strike_frames, frame, 0.0, reach - tip, 16.0, pattern.strike_color, 1.0)
	if tip > 0.0:
		# The end of the tip's frame (its point), as much as fits.
		var size: float = float(pattern.tip_texture.get_height())
		draw_texture_rect_region(pattern.tip_texture, Rect2(reach - tip, -8.0, tip, 16.0),
				Rect2(posmod(frame, maxi(pattern.strike_frames, 1)) * size + size - tip, 0.0, tip, size))


## A strip's frame at a time, looping at fps.
static func frame_at(time: float, fps: float, frames: int) -> int:
	return int(maxf(time, 0.0) * fps) % maxi(frames, 1)
