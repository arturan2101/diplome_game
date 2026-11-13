class_name ActorSpriteAnimator
extends AnimatedSprite2D
## Visual only: picks "<idle|walk>_<down|up|left|right>" from the parent body's
## velocity. Never changes movement; when standing still it keeps the last direction.
## Animations missing from sprite_frames are skipped, so any SpriteFrames works.

## Below this speed (pixels per second) the actor counts as standing.
@export var walk_threshold: float = 5.0

var _direction: String = "down"
var _body: CharacterBody2D


func _ready() -> void:
	_body = get_parent() as CharacterBody2D


func _process(_delta: float) -> void:
	if _body == null or sprite_frames == null:
		return
	var v: Vector2 = _body.velocity
	var moving: bool = v.length() > walk_threshold
	if moving:
		if absf(v.x) > absf(v.y):
			_direction = "right" if v.x > 0.0 else "left"
		else:
			_direction = "down" if v.y > 0.0 else "up"
	var anim: StringName = StringName(("walk_" if moving else "idle_") + _direction)
	if (anim != animation or not is_playing()) and sprite_frames.has_animation(anim):
		play(anim)
