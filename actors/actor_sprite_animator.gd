class_name ActorSpriteAnimator
extends AnimatedSprite2D
## Visual only: picks "<idle|walk>_<down|up|left|right>" from the parent body's
## velocity and plays one-shot actions over them: "attack_<dir>" (an enemy's attack,
## or a player's attack), "hurt_<dir>" when the parent's
## Health takes damage, and "death" when it dies. An enemy is freed when it dies, so its
## death plays on a copy left on the ground (a heap of bones for the skeleton).
## A player's attack plays the weapon's own animation (WeaponData.attack_animation).
## The player also shows lasting actions: "dash_<dir>" during a dash, "block_<dir>"
## while the shield is up (it rises and holds), and "bow_<dir>" while drawing the bow
## (frames 0-3 follow the draw, 4-5 play on release).
## An enemy's attack (stage 41): with EnemyData.attack_strike_frame the frames before it
## are the wind-up, spread over the windup and held on the last, and the blow plays when
## the enemy reports `struck`; a cut-short windup drops it. The boss names its attack
## animation (slam, throw, wave) and also roars ("roar") going into its second phase and
## raises a fist ("summon") when it calls servants.
## Never changes movement or combat. Animations missing from sprite_frames are skipped.

## Frames of the bow strip: drawing (0 .. BOW_DRAW_FRAMES - 1), then the release.
const BOW_DRAW_FRAMES: int = 4

## Below this speed (pixels per second) the actor counts as standing.
@export var walk_threshold: float = 5.0
## Length of the player's attack and of any hurt animation, in seconds.
@export var attack_time: float = 0.25
@export var hurt_time: float = 0.18
## Seconds a corpse stays on the ground after its death animation, then fades.
@export var corpse_time: float = 4.0
@export var corpse_fade_time: float = 1.0
## Spark over the actor when it takes damage (a strip played once), or null.
@export var hit_effect: Texture2D = preload("res://assets/art/fx/hit_spark.png")
@export var hit_effect_frames: int = 3
## The damage of each hit floats up as a number: white over enemies, red over the player.
@export var show_damage_numbers: bool = true
@export var enemy_damage_color: Color = Color("#f4f0e0")
@export var player_damage_color: Color = Color("#e85a3a")
## A critical hit's number: golden and bigger.
@export var crit_damage_color: Color = Color("#ffd24a")
@export var crit_number_scale: float = 1.4
## Height of the number above the actor's centre.
@export var damage_number_height: float = 14.0
## Seconds the boss's summon gesture lasts.
@export var summon_time: float = 0.75
## Burst of bits when an enemy dies (bone chips for the skeleton).
@export var death_particle_color: Color = Color("#d8d4c4")
@export var death_particles: int = 10

var _direction: String = "down"
var _body: CharacterBody2D
var _action_left: float = 0.0
var _was_winding_up: bool = false
var _weapon: Weapon = null
## The bow was drawn last frame (its release plays when the drawing stops).
var _bow_drawn: bool = false
## The enemy's wind-up being shown (held before its strike frame), &"" when none.
var _windup_animation: StringName = &""
var _strike_frame: int = -1


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
	var enemy: Enemy = _body as Enemy
	if enemy != null:
		enemy.struck.connect(_on_struck)
	var boss: Guardian = _body as Guardian
	if boss != null:
		boss.phase_changed.connect(_on_phase_changed)
		boss.summon_requested.connect(_on_summon_requested.unbind(2))


func _process(delta: float) -> void:
	if _body == null or sprite_frames == null:
		return
	var enemy: Enemy = _body as Enemy
	if enemy != null:
		var winding: bool = enemy.state == Enemy.State.WINDUP
		if winding and not _was_winding_up:
			_face(enemy.velocity if enemy.velocity.length() > walk_threshold else _to_player())
			_start_windup(enemy)
		_was_winding_up = winding
		if not winding:
			_windup_animation = &""
		elif _windup_animation != &"":
			# Hold the wind-up: its frames follow the windup, the last one waits for the blow.
			frame = mini(int(enemy.get_windup_progress() * _strike_frame), _strike_frame - 1)
			_action_left = 0.0
			return
	var player: Player = _body as Player
	if player != null and _show_player_pose(player):
		return
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


## The player's lasting actions. True if one is shown this frame.
func _show_player_pose(player: Player) -> bool:
	var skill: Skill = player.skill
	if skill != null and skill.is_active():
		if skill is DashSkill:
			_face(player.velocity)
			return _hold_pose("dash")
		if skill is ParrySkill:
			# Its own pose (batch 14), else the weapon held up like the shield.
			_face(player.get_look_direction())
			return _hold_pose("parry") or _hold_pose("block")
		if skill is BlockSkill:
			_face(player.get_look_direction())
			return _hold_pose("block")
	var bow: BowWeapon = player.weapon as BowWeapon
	var progress: float = bow.get_draw_progress() if bow != null else 0.0
	if progress > 0.0:
		_face(player.get_look_direction())
		var anim: StringName = StringName("bow_" + _direction)
		if not sprite_frames.has_animation(anim):
			return false
		if animation != anim:
			animation = anim
		pause()
		frame = mini(int(progress * BOW_DRAW_FRAMES), BOW_DRAW_FRAMES - 1)
		_bow_drawn = true
		_action_left = 0.0
		return true
	if _bow_drawn:
		_bow_drawn = false
		var release: StringName = StringName("bow_" + _direction)
		if sprite_frames.has_animation(release) and sprite_frames.get_frame_count(release) > BOW_DRAW_FRAMES:
			animation = release
			frame = BOW_DRAW_FRAMES
			play()
			_action_left = float(sprite_frames.get_frame_count(release) - BOW_DRAW_FRAMES) / sprite_frames.get_animation_speed(release)
	return false


## An enemy's attack: held wind-up frames with a strike frame, or the whole animation
## stretched over the windup without one.
func _start_windup(enemy: Enemy) -> void:
	var action: String = enemy.get_attack_animation()
	var anim: StringName = StringName(action + "_" + _direction)
	var strike: int = enemy.data.attack_strike_frame
	if strike <= 0 or not sprite_frames.has_animation(anim) or strike >= sprite_frames.get_frame_count(anim):
		play_action(action, enemy.data.windup)
		return
	_windup_animation = anim
	_strike_frame = strike
	animation = anim
	pause()
	frame = 0


## The blow: the rest of the attack animation from its strike frame, at its own speed.
func _on_struck() -> void:
	if _windup_animation == &"" or not sprite_frames.has_animation(_windup_animation):
		return
	var anim: StringName = _windup_animation
	_windup_animation = &""
	animation = anim
	frame = _strike_frame
	play()
	_action_left = float(sprite_frames.get_frame_count(anim) - _strike_frame) / maxf(sprite_frames.get_animation_speed(anim), 1.0)


## The boss roars going into its second phase, for as long as it stands still for it.
func _on_phase_changed(_phase: int) -> void:
	_face(_to_player())
	play_action("roar", (_body as Guardian).get_roar_time())


## The boss raises a fist when it calls servants (not over its roar or an attack).
func _on_summon_requested() -> void:
	var enemy: Enemy = _body as Enemy
	if _action_left > 0.0 or (enemy != null and enemy.state == Enemy.State.WINDUP):
		return
	play_action("summon", summon_time)


## Plays "<action>_<dir>" once and stays on its last frame while the action lasts.
func _hold_pose(action: String) -> bool:
	var anim: StringName = StringName(action + "_" + _direction)
	if not sprite_frames.has_animation(anim):
		return false
	if animation != anim:
		play(anim)
	_action_left = 0.0
	return true


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
		# The bow has its own draw and release.
		if _weapon is BowWeapon and sprite_frames.has_animation(StringName("bow_" + _direction)):
			return
		_face(player.get_look_direction())
		# Each weapon names its own attack (the spear thrusts, the daggers stab).
		if _weapon != null and _weapon.data != null:
			play_action(String(_weapon.data.attack_animation), attack_time)
			return
	play_action("attack", attack_time)


func _on_damaged(info: DamageInfo) -> void:
	StripSprite.spawn(_body.get_parent(), _body.global_position + offset * 0.5, hit_effect, hit_effect_frames)
	if show_damage_numbers:
		var color: Color = player_damage_color if _body is Player else enemy_damage_color
		if info.is_critical:
			color = crit_damage_color
		var number: DamageNumber = DamageNumber.spawn(_body.get_parent(),
				_body.global_position + Vector2(0.0, -damage_number_height), info.amount, color)
		if number != null and info.is_critical:
			number.scale = Vector2.ONE * crit_number_scale
	if _body is Enemy and (_body as Enemy).state == Enemy.State.WINDUP:
		return
	# The boss's roar is not cut by a hit.
	if _body is Guardian and (_body as Guardian).is_roaring():
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
	var bits: CPUParticles2D = CPUParticles2D.new()
	bits.position = _body.position + offset
	bits.one_shot = true
	bits.explosiveness = 1.0
	bits.amount = death_particles
	bits.lifetime = 0.6
	bits.spread = 180.0
	bits.initial_velocity_min = 30.0
	bits.initial_velocity_max = 70.0
	bits.gravity = Vector2(0, 160)
	bits.damping_min = 40.0
	bits.damping_max = 60.0
	bits.color = death_particle_color
	bits.emitting = true
	holder.add_child.call_deferred(bits)
	bits.finished.connect(bits.queue_free)
	corpse.ready.connect(func() -> void:
		corpse.play(&"death")
		var fade: Tween = corpse.create_tween()
		fade.tween_interval(corpse_time)
		fade.tween_property(corpse, "modulate:a", 0.0, corpse_fade_time)
		fade.tween_callback(corpse.queue_free))
