class_name HazardReceiver
extends Node
## Makes its owner react to floor hazards of the Level it stands on:
## spikes hurt on entering and then at intervals (timed spikes only while they are up;
## the damage source is the kind of spikes); a pit makes the owner fall, lose a share of
## max HP and reappear on the last safe tile. Works the same for the player and
## enemies. Without a Level in the scene it does nothing.

## Emitted when the owner starts falling into a pit: the owner must stop acting.
signal fall_started
## Emitted when the owner is back on a safe tile and may act again.
signal fall_ended

const PIT_SOURCE: StringName = &"pit"

## Body whose position is checked and moved back after a fall.
@export var body: CharacterBody2D
@export var health: Health
## Visual shrunk while falling.
@export var visual: Node2D
@export var data: HazardData

## True while the owner is carried over the ground (dash): hazards are ignored.
var suspended: bool = false

var _level: Level = null
var _last_safe_position: Vector2 = Vector2.ZERO
var _has_safe_position: bool = false
var _spikes_time_left: float = 0.0
var _fall_time_left: float = 0.0
var _is_falling: bool = false
var _visual_scale: Vector2 = Vector2.ONE


func is_falling() -> bool:
	return _is_falling


## Forgets the last safe tile (the owner was moved to another place or section).
func reset() -> void:
	_has_safe_position = false
	_spikes_time_left = 0.0


func _physics_process(delta: float) -> void:
	if body == null or health == null or data == null:
		return
	if _is_falling:
		_update_fall(delta)
		return
	if health.is_dead() or suspended:
		return
	if not is_instance_valid(_level):
		_level = get_tree().get_first_node_in_group(Level.GROUP) as Level
		if _level == null:
			return
	match _level.cell_type_at(body.global_position):
		LevelGrid.Cell.FLOOR:
			_last_safe_position = _level.cell_center(_level.cell_at(body.global_position))
			_has_safe_position = true
			_spikes_time_left = 0.0
		LevelGrid.Cell.SPIKES:
			_on_spikes(data.static_spikes, delta)
		LevelGrid.Cell.SPIKES_TIMED:
			if _level.are_timed_spikes_up(_level.cell_at(body.global_position)):
				_on_spikes(data.timed_spikes, delta)
			else:
				# Down: the next rise hits at once.
				_spikes_time_left = 0.0
		LevelGrid.Cell.PIT:
			_start_fall()


## Standing on raised spikes: a hit on entering, then one every hit_interval.
func _on_spikes(trap: SpikeTrapData, delta: float) -> void:
	_spikes_time_left -= delta
	if _spikes_time_left <= 0.0:
		_spikes_time_left = trap.hit_interval
		health.take_damage(DamageInfo.new(trap.damage, null, trap.id))


func _start_fall() -> void:
	_is_falling = true
	_fall_time_left = data.fall_delay
	_spikes_time_left = 0.0
	body.velocity = Vector2.ZERO
	fall_started.emit()
	# Falling hurts even through invulnerability frames.
	var info: DamageInfo = DamageInfo.new(ceili(health.max_hp * data.pit_damage_fraction), null, PIT_SOURCE)
	info.ignores_invulnerability = true
	health.take_damage(info)
	if visual != null:
		_visual_scale = visual.scale


func _update_fall(delta: float) -> void:
	_fall_time_left -= delta
	if visual != null:
		visual.scale = _visual_scale * clampf(_fall_time_left / data.fall_delay, 0.0, 1.0)
	if _fall_time_left > 0.0:
		return
	_is_falling = false
	if visual != null:
		visual.scale = _visual_scale
	if health.is_dead():
		return
	if is_instance_valid(_level):
		body.global_position = _last_safe_position if _has_safe_position \
				else _level.nearest_safe_position(body.global_position)
	body.velocity = Vector2.ZERO
	# The usual invulnerability after damage, counted from the moment of return.
	health.make_invulnerable(health.invulnerability_time)
	fall_ended.emit()
