class_name SporeBat
extends Enemy
## Spore bat of the fungal catacombs (stage 48, numbers in SporeBatData): flies, so pits
## and spikes never stop it (walls and cover do); with a clear line to the player it
## flies straight at it, otherwise along the grid path. Its attack: it rises during the
## wind-up, then dives along the wind-up direction and bites once if it passes close
## enough. Comes in small packs.

var _stats: SporeBatData = null
var _dive_left: float = 0.0
var _bitten: bool = false


func _ready() -> void:
	super()
	_stats = data as SporeBatData
	if _stats == null:
		push_error("SporeBat needs SporeBatData: %s" % data)
		set_physics_process(false)
		return
	# It flies: no falling into pits, no spikes.
	if hazards != null:
		hazards.process_mode = Node.PROCESS_MODE_DISABLED


## True while it dives after its wind-up.
func is_diving() -> bool:
	return _dive_left > 0.0


func _update_windup(delta: float) -> void:
	_state_time_left -= delta
	if _state_time_left > 0.0:
		return
	# The dive frame and the screech; the bite comes when it reaches the player.
	struck.emit()
	_enter(State.RECOVER)
	_dive_left = _stats.dive_time
	_bitten = false
	velocity = _attack_direction * _stats.dive_speed


func _update_recover(delta: float) -> void:
	if _dive_left > 0.0:
		_dive_left -= delta
		if not _bitten and is_instance_valid(_target) and weapon != null \
				and global_position.distance_to(_target.global_position) <= _stats.bite_reach:
			_bitten = true
			var toward: Vector2 = global_position.direction_to(_target.global_position)
			weapon.try_attack(toward)
			weapon.release_attack(toward)
		if _dive_left <= 0.0:
			velocity = Vector2.ZERO
		return
	super(delta)


func _enter(new_state: State) -> void:
	# Anything else (a blow, a stun, a freeze) ends the dive.
	if new_state != State.RECOVER:
		_dive_left = 0.0
	super(new_state)


## Straight at the target when nothing solid is between (it flies over pits); else the
## grid path around the walls.
func _direction_to_target(delta: float) -> Vector2:
	if _can_see_target():
		return global_position.direction_to(_target.global_position)
	return super(delta)
