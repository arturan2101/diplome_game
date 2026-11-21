class_name Golem
extends Enemy
## Stone golem (stage 29): slow and tough, hits do not push it back. Its only attack is a
## slam of the ground around itself after a long windup: both fists rise and hold over
## its head (the art's wind-up), a shadow pulses on the floor over the slam's area, so a
## careful player steps out in time.
## Damage goes out with the golem's id as its source, like any enemy's.

@export_flags_2d_physics var player_hurtbox_mask: int = 8
## Smoothness of the dust ring drawn after the slam.
@export var telegraph_segments: int = 32
@export var dust_color: Color = Color(0.85, 0.83, 0.77)
## Art (visual only): the pulsing shadow on the floor during the windup and the
## shockwave of the slam, both round and centred; the radius each was drawn for, so
## they are scaled to the slam's radius. Null = the circles drawn in code.
@export var warning_texture: Texture2D = preload("res://assets/art/fx/golem_warning.png")
@export var warning_frames: int = 4
@export var warning_drawn_radius: float = 24.0
@export var shockwave_texture: Texture2D = preload("res://assets/art/fx/golem_shockwave.png")
@export var shockwave_frames: int = 6
@export var shockwave_drawn_radius: float = 31.0
@export var shockwave_fps: float = 12.0

var _stats: GolemData = null
var _flash_left: float = 0.0
var _warning: StripSprite = null


func _ready() -> void:
	super()
	_stats = data as GolemData
	if _stats == null:
		push_error("Golem needs GolemData: %s" % data)
		set_physics_process(false)
		return
	if warning_texture != null:
		_warning = StripSprite.new()
		_warning.name = "Warning"
		_warning.texture = warning_texture
		_warning.hframes = maxi(warning_frames, 1)
		_warning.scale = Vector2.ONE * (_stats.slam_radius / warning_drawn_radius)
		_warning.show_behind_parent = true
		_warning.visible = false
		add_child(_warning)


func _physics_process(delta: float) -> void:
	super(delta)
	if _flash_left > 0.0:
		_flash_left -= delta
	if _warning != null:
		_warning.visible = state == State.WINDUP
	if state == State.WINDUP or _flash_left > -delta:
		queue_redraw()


## The bot (and anyone asking) must leave the whole circle.
func get_windup_reach() -> float:
	return _stats.slam_radius if _stats != null else super()


func is_windup_area() -> bool:
	return true


func apply_knockback(knockback_velocity: Vector2) -> void:
	if _stats != null and _stats.stagger_immune:
		return
	super(knockback_velocity)


## No weapon: the slam is the golem's own.
func _create_weapon() -> void:
	pass


func _update_windup(delta: float) -> void:
	_state_time_left -= delta
	if _state_time_left > 0.0:
		return
	AreaDamage.hit(get_world_2d().direct_space_state, global_position, _stats.slam_radius,
			roundi(_stats.slam_damage * damage_multiplier), self, data.id, _stats.slam_knockback,
			player_hurtbox_mask, sight_mask)
	_flash_left = _stats.slam_flash_time
	struck.emit()
	var wave: StripSprite = StripSprite.spawn(get_parent(), global_position, shockwave_texture, shockwave_frames, shockwave_fps)
	if wave != null:
		wave.scale = Vector2.ONE * (_stats.slam_radius / shockwave_drawn_radius)
		# On the floor: drawn just before the golem, so under it (not z -1, which would put
		# it under the floor tiles).
		wave.get_parent().move_child(wave, get_index())
		_flash_left = 0.0
	_enter(State.RECOVER)


func _draw() -> void:
	if _stats == null:
		return
	if _flash_left > 0.0 and state != State.WINDUP:
		var t: float = 1.0 - _flash_left / _stats.slam_flash_time
		draw_arc(Vector2.ZERO, _stats.slam_radius * (0.6 + 0.4 * t), 0.0, TAU, telegraph_segments,
				Color(dust_color, 0.8 * (1.0 - t)), 3.0)
