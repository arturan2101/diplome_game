class_name Ghost
extends Enemy
## Ghost (stage 31): drifts straight at the player through walls and over pits and
## spikes, half see-through. It can only strike from open ground: inside a wall it
## never starts a windup (and walls keep the player's blows and arrows from it). To
## strike it fades in fully with a flash of light, touches with cold, then fades back.

## Art (visual only): the flash when it fades in to strike and when it fades out.
@export var fade_in_effect: Texture2D = preload("res://assets/art/fx/ghost_fade_in.png")
@export var fade_out_effect: Texture2D = preload("res://assets/art/fx/ghost_fade_out.png")
@export var fade_effect_frames: int = 5

var _stats: GhostData = null
var _shown: bool = false


func _ready() -> void:
	super()
	_stats = data as GhostData
	if _stats == null:
		push_error("Ghost needs GhostData: %s" % data)
		set_physics_process(false)
		return
	# It floats: no pits or spikes, and nothing but other enemies stops its body.
	if hazards != null:
		hazards.process_mode = Node.PROCESS_MODE_DISABLED
	collision_mask = collision_layer
	# The see-through look is on the ghost itself: the sprite's own tints (windup, hit
	# flash) stay untouched.
	modulate.a = _stats.drift_alpha


func _physics_process(delta: float) -> void:
	super(delta)
	if _stats == null:
		return
	var showing: bool = state == State.WINDUP or state == State.RECOVER
	if showing != _shown:
		_shown = showing
		_fade(showing)


## True if the ghost floats inside a wall (or over anything but open ground).
func is_in_wall() -> bool:
	if not is_instance_valid(_level):
		return false
	return _level.cell_type_at(global_position) == LevelGrid.Cell.WALL


func _update_chase(delta: float) -> void:
	if not is_instance_valid(_target):
		_enter(State.IDLE)
		return
	var distance: float = global_position.distance_to(_target.global_position)
	if distance <= data.attack_range and not is_in_wall() and _can_see_target():
		_enter(State.WINDUP)
		return
	velocity = _direction_to_target(delta) * data.move_speed


## Straight at the target, through anything.
func _direction_to_target(_delta: float) -> Vector2:
	return global_position.direction_to(_target.global_position)


func _fade(showing: bool) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0 if showing else _stats.drift_alpha, _stats.fade_time)
	StripSprite.spawn(get_parent(), global_position + (visual as Node2D).position, fade_in_effect if showing else fade_out_effect,
			fade_effect_frames, fade_effect_frames / maxf(_stats.fade_time * 2.0, 0.01))
