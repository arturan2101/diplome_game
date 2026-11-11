class_name Skill
extends Node2D
## Base class of the player's basic skill (dash, shield block): one per run, with a cooldown.
## The player calls press() / release() and asks how the skill affects movement and
## attacks; the skill reports back with a signal.

## Emitted each time the skill is activated. Telemetry counts it as skill_uses.
signal used

var data: SkillData = null
var wielder: Player = null

var _cooldown_left: float = 0.0


## Called by the player right after creating the skill, before adding it to the tree.
func setup(skill_data: SkillData, skill_wielder: Player) -> void:
	data = skill_data
	wielder = skill_wielder


## Called when the skill button is pressed. direction is where the player is heading.
func press(direction: Vector2) -> void:
	if not is_ready():
		return
	_activate(direction)
	used.emit()


## Called when the skill button is released.
func release() -> void:
	_on_released()


## Stops the skill at once (the player died).
func cancel() -> void:
	pass


func is_ready() -> bool:
	return _cooldown_left <= 0.0 and not is_active()


## True while the skill is doing its thing (dashing, shield up).
func is_active() -> bool:
	return false


## 0 = ready, 1 = cooldown just started. For the HUD.
func get_cooldown_fraction() -> float:
	if data == null or data.cooldown <= 0.0:
		return 0.0
	return clampf(_cooldown_left / data.cooldown, 0.0, 1.0)


## Multiplier for the wielder's movement speed (the shield slows down).
func get_move_speed_multiplier() -> float:
	return 1.0


## Non-zero while the skill moves the wielder itself (the dash).
func get_forced_velocity() -> Vector2:
	return Vector2.ZERO


## True while the wielder cannot attack.
func blocks_attacks() -> bool:
	return is_active()


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_update(delta)


func _start_cooldown() -> void:
	_cooldown_left = data.cooldown


## Subclasses: start the skill.
func _activate(_direction: Vector2) -> void:
	pass


## Subclasses: react to the button release.
func _on_released() -> void:
	pass


## Subclasses: per-physics-frame logic. Used instead of _physics_process so the
## cooldown above always ticks.
func _update(_delta: float) -> void:
	pass
