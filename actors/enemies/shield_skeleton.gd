class_name ShieldSkeleton
extends Enemy
## Elite skeleton with a shield (numbers in ShieldSkeletonData). Hits that come from
## the shield's arc are blocked, unless they knock back: the last hit of a sword combo
## breaks the guard and staggers it. The shield turns towards the player slowly and
## stays still while the skeleton swings and recovers, so the way in is from the side
## or from behind. The sprite shows the shield; a faint arc drawn in code shows the side
## it really blocks, and lights up when it stops a hit.

@export var shield_color: Color = Color(0.62, 0.64, 0.72, 0.45)
@export var shield_block_color: Color = Color(1.0, 0.95, 0.7, 0.9)
## Seconds the shield lights up after blocking a hit.
@export var block_flash_time: float = 0.15
@export var shield_distance: float = 10.0
@export var shield_width: float = 1.5

## Where the shield faces (unit vector).
var shield_direction: Vector2 = Vector2.DOWN

var _stats: ShieldSkeletonData = null
var _flash_left: float = 0.0


func _ready() -> void:
	super()
	_stats = data as ShieldSkeletonData
	if _stats == null:
		push_error("ShieldSkeleton needs ShieldSkeletonData: %s" % data)
	if hurtbox != null:
		hurtbox.add_guard(_guard)


func _physics_process(delta: float) -> void:
	super(delta)
	if is_dormant or _stats == null:
		return
	_flash_left = maxf(_flash_left - delta, 0.0)
	var holding: bool = state == State.WINDUP or state == State.RECOVER or state == State.STAGGER
	if not holding and is_instance_valid(_target):
		var wanted: Vector2 = global_position.direction_to(_target.global_position)
		if not wanted.is_zero_approx():
			var step: float = _stats.shield_turn_speed * delta
			shield_direction = shield_direction.rotated(clampf(shield_direction.angle_to(wanted), -step, step))
	queue_redraw()


## True if the shield stops this hit: it comes from the shield's arc and does not
## knock back, and the skeleton is not staggered.
func blocks(info: DamageInfo) -> bool:
	if _stats == null or state == State.STAGGER or not info.knockback.is_zero_approx():
		return false
	var incoming: Vector2 = -info.direction
	var attacker: Node2D = info.source as Node2D
	if incoming.is_zero_approx() and attacker != null:
		incoming = global_position.direction_to(attacker.global_position)
	if incoming.is_zero_approx():
		return false
	return absf(shield_direction.angle_to(incoming)) <= deg_to_rad(_stats.shield_arc_degrees) * 0.5


func _guard(info: DamageInfo) -> bool:
	var stopped: bool = blocks(info)
	if stopped:
		_flash_left = block_flash_time
	return stopped


func _draw() -> void:
	if _stats == null or is_dormant:
		return
	var half: float = deg_to_rad(_stats.shield_arc_degrees) * 0.5
	var color: Color = shield_block_color if _flash_left > 0.0 else shield_color
	draw_arc(Vector2.ZERO, shield_distance, shield_direction.angle() - half, shield_direction.angle() + half, 12, color, shield_width)
