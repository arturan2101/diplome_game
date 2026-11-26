class_name Scarab
extends Enemy
## Scarab of the sand temple (stage 49, numbers in ScarabData): a small beetle that comes
## in packs. When the player is far it burrows (the burrow strip), crawls under the sand
## along the grid path, out of reach of weapons and spells (Enemy.set_buried()), and
## comes up beside the player (the emerge strip, the mound and the sound warn of it; it
## is still untouchable while coming up) to bite like a beetle. A burrow takes a moment
## and a blow during it stops it.

enum Dig { NONE, BURROWING, UNDER, EMERGING }

var _stats: ScarabData = null
var _dig: Dig = Dig.NONE
var _dig_left: float = 0.0
var _burrow_cooldown_left: float = 0.0


func _ready() -> void:
	super()
	_stats = data as ScarabData
	if _stats == null:
		push_error("Scarab needs ScarabData: %s" % data)
		set_physics_process(false)


func is_burrowing() -> bool:
	return _dig != Dig.NONE


func get_pose() -> StringName:
	match _dig:
		Dig.BURROWING, Dig.UNDER:
			return &"burrow"
		Dig.EMERGING:
			return &"emerge"
	return &""


func _physics_process(delta: float) -> void:
	_burrow_cooldown_left = maxf(_burrow_cooldown_left - delta, 0.0)
	super(delta)


func _update_chase(delta: float) -> void:
	if _stats == null or not is_instance_valid(_target):
		super(delta)
		return
	var distance: float = global_position.distance_to(_target.global_position)
	match _dig:
		Dig.NONE:
			if distance >= _stats.burrow_distance and _burrow_cooldown_left <= 0.0:
				_dig = Dig.BURROWING
				_dig_left = _stats.burrow_time
				velocity = Vector2.ZERO
				Sound.play_at(_stats.burrow_sound, global_position)
				return
			super(delta)
		Dig.BURROWING:
			velocity = Vector2.ZERO
			_dig_left -= delta
			if _dig_left <= 0.0:
				_dig = Dig.UNDER
				_dig_left = _stats.max_underground_time
				set_buried(true)
		Dig.UNDER:
			_dig_left -= delta
			if distance <= _stats.emerge_distance or _dig_left <= 0.0:
				_dig = Dig.EMERGING
				_dig_left = _stats.emerge_time
				velocity = Vector2.ZERO
				Sound.play_at(_stats.burrow_sound, global_position)
				return
			var speed: float = _stats.underground_speed * (_slow_multiplier if is_slowed() else 1.0)
			velocity = _direction_to_target(delta) * speed
		Dig.EMERGING:
			velocity = Vector2.ZERO
			_dig_left -= delta
			if _dig_left <= 0.0:
				# Out of the sand: it can be hit again and bites at once if in reach.
				_dig = Dig.NONE
				_burrow_cooldown_left = _stats.burrow_cooldown
				set_buried(false)


## Anything but walking on (a blow, a freeze, a fall) ends the burrow, back on the
## surface; it may try again after the cooldown.
func _enter(new_state: State) -> void:
	if new_state != State.CHASE and _dig != Dig.NONE:
		_dig = Dig.NONE
		set_buried(false)
		_burrow_cooldown_left = _stats.burrow_cooldown
	super(new_state)
