class_name ActorSpriteAnimator
extends AnimatedSprite2D
## Visual only: picks "<idle|walk>_<down|up|left|right>" from the parent body's
## velocity and plays one-shot actions over them: "attack_<dir>" (an enemy's windup,
## stretched to its windup time, or a player's attack), "hurt_<dir>" when the parent's
## Health takes damage, and "death" when it dies. An enemy is freed when it dies, so its
## death plays on a copy left on the ground (a heap of bones for the skeleton).
## Never changes movement or combat. Animations missing from sprite_frames are skipped.

## Below this speed (pixels per second) the actor counts as standing.
@export var walk_threshold: float = 5.0
## Length of the player's attack and of any hurt animation, in seconds.
@export var attack_time: float = 0.25
@export var hurt_time: float = 0.18
## Seconds a corpse stays on the ground after its death animation, then fades.
@export var corpse_time: float = 4.0
@export var corpse_fade_time: float = 1.0

var _direction: String = "down"
var _body: CharacterBody2D
var _action_left: float = 0.0
var _was_winding_up: bool = false
var _weapon: Weapon = null


func _ready() -> void:
	_body = get_parent() as CharacterBody2D
	if _body == null:
		return
	var health: Health = _body.get("health") as Health
	if health != null:
		health.damaged.connect(_on_damaged)
		health.died.connect(_on_died)
	if _body.has_signal("weapon_changed"):
		_body.connect("weapon_changed", _on_weapon_changed.unbind(2))
		_on_weapon_changed.call_deferred()


func _process(delta: float) -> void:
	if _body == null or sprite_frames == null:
		return
	var enemy: Enemy = _body as Enemy
	if enemy != null:
		var winding: bool = enemy.state == Enemy.State.WINDUP
		if winding and not _was_winding_up:
			_face(enemy.velocity if enemy.velocity.length() > walk_threshold else _to_player())
			play_action("attack", enemy.data.windup)
		_was_winding_up = winding
	if _action_left > 0.0:
		_action_left -= delta
		return
	var v: Vector2 = _body.velocity
	var moving: bool = v.length() > walk_threshold
	if moving:
		_face(v)
	var anim: StringName = StringName(("walk_" if moving else "idle_") + _direction)
	if (anim != animation or not is_playing()) and sprite_frames.has_animation(anim):
		play(anim)


## Plays "<action>_<dir>" (or "<action>") once, stretched to last the given seconds.
func play_action(action: String, seconds: float) -> void:
	var anim: StringName = StringName(action + "_" + _direction)
	if not sprite_frames.has_animation(anim):
		anim = StringName(action)
	if not sprite_frames.has_animation(anim):
		return
	var frames: int = sprite_frames.get_frame_count(anim)
	var base_speed: float = sprite_frames.get_animation_speed(anim)
	play(anim, (frames / base_speed) / maxf(seconds, 0.01))
	_action_left = seconds


func _face(v: Vector2) -> void:
	if v.is_zero_approx():
		return
	if absf(v.x) > absf(v.y):
		_direction = "right" if v.x > 0.0 else "left"
	else:
		_direction = "down" if v.y > 0.0 else "up"


func _to_player() -> Vector2:
	var player: Node2D = get_tree().get_first_node_in_group(Player.GROUP) as Node2D
	return _body.global_position.direction_to(player.global_position) if player != null else Vector2.ZERO


func _on_weapon_changed() -> void:
	if _weapon != null and is_instance_valid(_weapon) and _weapon.attack_performed.is_connected(_on_attack):
		_weapon.attack_performed.disconnect(_on_attack)
	_weapon = _body.get("weapon") as Weapon
	if _weapon != null:
		_weapon.attack_performed.connect(_on_attack)


func _on_attack(_step: int, _hits: int) -> void:
	var player: Player = _body as Player
	if player != null:
		_face(player.get_look_direction())
	play_action("attack", attack_time)


func _on_damaged(_info: DamageInfo) -> void:
	if _body is Enemy and (_body as Enemy).state == Enemy.State.WINDUP:
		return
	play_action("hurt", hurt_time)


func _on_died(_info: DamageInfo) -> void:
	if not sprite_frames.has_animation(&"death"):
		return
	if _body is Enemy:
		_leave_corpse()
	else:
		play(&"death")
		_action_left = INF


## A copy of this sprite on the ground plays the death and stays a while.
func _leave_corpse() -> void:
	var holder: Node = _body.get_parent()
	if holder == null:
		return
	var corpse: AnimatedSprite2D = AnimatedSprite2D.new()
	corpse.sprite_frames = sprite_frames
	corpse.offset = offset
	corpse.scale = scale
	corpse.z_index = -1
	corpse.position = _body.position
	holder.add_child.call_deferred(corpse)
	corpse.ready.connect(func() -> void:
		corpse.play(&"death")
		var fade: Tween = corpse.create_tween()
		fade.tween_interval(corpse_time)
		fade.tween_property(corpse, "modulate:a", 0.0, corpse_fade_time)
		fade.tween_callback(corpse.queue_free))
