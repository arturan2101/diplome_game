class_name Spell
extends Node2D
## Base class of a learned spell: one node per spell slot, a child of the player's
## SpellBook (so effects drawn around the player move with it). try_cast() checks the
## cooldown and calls _cast(); subclasses do the effect. Damage is reported up with
## damage_dealt, so telemetry logs spell damage apart from weapon damage.

## Emitted on every cast. Telemetry counts it as a spell use.
signal cast_performed(spell_id: StringName)
## Emitted when the spell's effect hurts enemies (the sum of one blast or one tick).
signal damage_dealt(spell_id: StringName, amount: int)

## Physics layers of the hurtboxes spells damage (enemy_hurtbox) and of walls.
@export_flags_2d_physics var target_mask: int = 16
@export_flags_2d_physics var wall_mask: int = 1

var data: SpellData = null
var caster: Player = null
## 1 to SpellData.MAX_LEVEL; read at every cast, so a level-up works at once.
var level: int = 1

var _cooldown_left: float = 0.0
## Patches of this spell with their damage times the caster's spell power, by power.
var _scaled_zones: Dictionary = {}


## Called by the spell book right after creating the spell, before adding it to the tree.
func setup(spell_data: SpellData, spell_caster: Player, spell_level: int = 1) -> void:
	data = spell_data
	caster = spell_caster
	level = clampi(spell_level, 1, SpellData.MAX_LEVEL)


## Casts towards direction if the cooldown is over. Returns true if it was cast.
func try_cast(direction: Vector2) -> bool:
	if data == null or not is_ready() or direction.is_zero_approx():
		return false
	_cast(direction.normalized())
	Sound.play(data.cast_sound)
	_cooldown_left = data.cooldown_at(level)
	cast_performed.emit(data.id)
	return true


func is_ready() -> bool:
	return _cooldown_left <= 0.0


## 0 = ready, 1 = cooldown just started. For the HUD.
func get_cooldown_fraction() -> float:
	var total: float = data.cooldown_at(level) if data != null else 0.0
	if total <= 0.0:
		return 0.0
	return clampf(_cooldown_left / total, 0.0, 1.0)


## Stops a lasting effect at once (the caster died, fell, or left the section).
func cancel() -> void:
	pass


## Subclasses that override this must call super(delta), or the cooldown stops.
func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)


## The effect itself. direction is normalized.
func _cast(_direction: Vector2) -> void:
	pass


## The caster's spell power (after stage 49: the elements grow with the depth like
## the enemies' health), 1 without a caster.
func get_power() -> float:
	return caster.spell_power if caster != null else 1.0


## Damage of this level from a per-level table, times the spell power.
func spell_damage(values: PackedInt32Array) -> int:
	return roundi(SpellData.int_at(values, level) * get_power())


## A patch's data with its damage times the spell power (the same copy while the power
## stays the same).
func scaled_zone(stats: ZoneData) -> ZoneData:
	var power: float = get_power()
	if stats == null or is_equal_approx(power, 1.0):
		return stats
	var key: Array = [stats, power]
	if not _scaled_zones.has(key):
		_scaled_zones[key] = stats.scaled(power)
	return _scaled_zones[key]


func _report_damage(amount: int) -> void:
	if amount > 0 and data != null:
		damage_dealt.emit(data.id, amount)


## Where effects that stay in the world (fireballs, ice) are added: the level.
func _effect_parent() -> Node:
	var level_node: Node = get_tree().get_first_node_in_group(Level.GROUP)
	return level_node if level_node != null else get_tree().current_scene
