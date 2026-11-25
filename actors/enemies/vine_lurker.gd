class_name VineLurker
extends Enemy
## Vine lurker of the fungal catacombs (stage 48, numbers in VineLurkerData): a bud on a
## stem rooted to its cell. It waits closed in the floor (it can already be hit there,
## so it never hides an arena's last enemy) and comes out when the player comes within
## emerge_range or hits it; then it lashes with its vine at whoever is within reach
## (a long, narrow melee blow) and never moves or gets pushed.

var _stats: VineLurkerData = null
var _hidden: bool = true
var _emerge_left: float = 0.0


func _ready() -> void:
	super()
	_stats = data as VineLurkerData
	if _stats == null:
		push_error("VineLurker needs VineLurkerData: %s" % data)
		set_physics_process(false)
		return
	struck.connect(_show_lash)


## True while it waits closed in the floor (not yet coming out).
func is_hidden() -> bool:
	return _hidden and _emerge_left <= 0.0


func get_pose() -> StringName:
	if _emerge_left > 0.0:
		return &"emerge"
	return &"hidden" if _hidden else &""


func _physics_process(delta: float) -> void:
	if is_dormant or _stats == null:
		return
	if _emerge_left > 0.0:
		_emerge_left -= delta
		if _emerge_left <= 0.0:
			_hidden = false
			_enter(State.CHASE)
		return
	if _hidden:
		_target = get_tree().get_first_node_in_group(Player.GROUP) as Node2D
		if _target != null and global_position.distance_to(_target.global_position) <= _stats.emerge_range:
			emerge()
		return
	super(delta)


## Comes out of the floor (once).
func emerge() -> void:
	if not _hidden or _emerge_left > 0.0:
		return
	_emerge_left = _stats.emerge_time
	Sound.play_at(_stats.emerge_sound, global_position)


## Rooted: it strikes whoever is within reach and in sight, and never walks.
func _update_chase(_delta: float) -> void:
	if not is_instance_valid(_target):
		_enter(State.IDLE)
		return
	velocity = Vector2.ZERO
	if global_position.distance_to(_target.global_position) <= data.attack_range and _can_see_target():
		_enter(State.WINDUP)


## Rooted: a heavy blow still breaks its lash (and a parry stuns it), but nothing
## pushes it off its cell.
func apply_knockback(_knockback_velocity: Vector2) -> void:
	if not _hidden:
		super(Vector2.ZERO)


## A hit wakes it up (an arrow from afar too).
func _on_hit_received(info: DamageInfo) -> void:
	if _hidden:
		emerge()
	else:
		super(info)


## The vine shoots from the bud towards the blow.
func _show_lash() -> void:
	var lash: StripSprite = StripSprite.spawn(get_parent(), global_position + Vector2(0.0, -_stats.lash_height),
			_stats.lash_effect, _stats.lash_frames, _stats.lash_fps)
	if lash == null:
		return
	lash.centered = false
	lash.offset = Vector2(0.0, -float(_stats.lash_effect.get_height()) * 0.5)
	lash.rotation = _attack_direction.angle()
