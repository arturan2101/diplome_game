class_name SandSerpent
extends Enemy
## Sand serpent of the sand temple (stage 49, numbers in SandSerpentData). It lies under
## the sand (the hidden strip over a ring of rippling sand), out of reach of weapons and
## spells (Enemy.set_buried()), and creeps towards the player it noticed. When the
## player is within emerge_range it bursts out: the emerge strip is its attack, the
## head rearing back is the wind-up and the bite lands on its strike frame. It then
## stands upright for its recovery (the moment to hit it), sinks again (the sink strip)
## and creeps to its next ambush. Nothing pushes it.

var _stats: SandSerpentData = null
var _sink_left: float = 0.0
var _resurface_left: float = 0.0
var _ripple: StripSprite = null


func _ready() -> void:
	super()
	_stats = data as SandSerpentData
	if _stats == null:
		push_error("SandSerpent needs SandSerpentData: %s" % data)
		set_physics_process(false)
		return
	if _stats.ripple != null:
		_ripple = StripSprite.new()
		_ripple.name = "Ripple"
		_ripple.texture = _stats.ripple
		_ripple.hframes = maxi(_stats.ripple_frames, 1)
		_ripple.fps = _stats.ripple_fps
		_ripple.z_index = -1
		_ripple.position = Vector2(0.0, feet_below_centre * data.body_radius / 6.0)
		add_child(_ripple)
	_hide_in_sand()


## True while it lies under the sand (not while sinking).
func is_hidden() -> bool:
	return is_buried()


func get_pose() -> StringName:
	if _sink_left > 0.0:
		return &"sink"
	return &"hidden" if is_buried() else &""


## Bursting out is its attack.
func get_attack_animation() -> String:
	return "emerge"


func _update_chase(delta: float) -> void:
	if _stats == null or not is_instance_valid(_target):
		super(delta)
		return
	velocity = Vector2.ZERO
	if _sink_left > 0.0:
		_sink_left -= delta
		if _sink_left <= 0.0:
			_hide_in_sand()
		return
	if not is_buried():
		# Its bite is over: back under the sand.
		_sink_left = _stats.sink_time
		return
	_resurface_left = maxf(_resurface_left - delta, 0.0)
	var distance: float = global_position.distance_to(_target.global_position)
	if distance <= _stats.emerge_range and _resurface_left <= 0.0 and _can_see_target():
		set_buried(false)
		_show_ripple(false)
		_enter(State.WINDUP)
		return
	if distance > _stats.hold_distance:
		var speed: float = _stats.hidden_speed * (_slow_multiplier if is_slowed() else 1.0)
		velocity = _direction_to_target(delta) * speed


## Rooted in the sand: no blow pushes it or breaks its bite.
func apply_knockback(_knockback_velocity: Vector2) -> void:
	pass


func _hide_in_sand() -> void:
	_sink_left = 0.0
	_resurface_left = _stats.resurface_delay
	set_buried(true)
	_show_ripple(true)


func _show_ripple(shown: bool) -> void:
	if _ripple != null:
		_ripple.visible = shown
