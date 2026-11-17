class_name EffectSprite
extends AnimatedSprite2D
## Visual only: plays one animation where it was put, then frees itself. With a
## lifetime it stays that many seconds and fades out over the last fade_time seconds
## (the burning trail of a level 3 fireball); without one it ends with the last frame of
## its animation (the flash where two spells merge).

## Seconds the effect stays; 0 = one pass of the animation.
@export var lifetime: float = 0.0
@export var fade_time: float = 0.2

var _age: float = 0.0


## Creates the effect under parent at a global position and starts it.
static func spawn(parent: Node, at: Vector2, effect_frames: SpriteFrames, effect_animation: StringName,
		seconds: float = 0.0) -> EffectSprite:
	var effect: EffectSprite = EffectSprite.new()
	effect.sprite_frames = effect_frames
	effect.animation = effect_animation
	effect.lifetime = seconds
	parent.add_child(effect)
	effect.global_position = at
	return effect


func _ready() -> void:
	if sprite_frames == null or not sprite_frames.has_animation(animation):
		queue_free()
		return
	if lifetime <= 0.0:
		# One pass of the animation, also when it loops.
		var speed: float = sprite_frames.get_animation_speed(animation)
		lifetime = float(sprite_frames.get_frame_count(animation)) / maxf(speed, 1.0)
		fade_time = 0.0
	play(animation)


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		set_process(false)
		return
	if fade_time > 0.0:
		modulate.a = clampf((lifetime - _age) / fade_time, 0.0, 1.0)
