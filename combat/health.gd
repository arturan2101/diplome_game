class_name Health
extends Node
## Hit points of any actor: player, enemies, training dummy.
## Reports changes with signals, so it does not need to know who owns it.
## Also the single place for invulnerability: after a hit (invulnerability_time) and
## during a dash (make_invulnerable). Hits while invulnerable are absorbed:
## they are not damage taken and emit nothing.

## Emitted after damage is applied; hp is already reduced.
signal damaged(info: DamageInfo)
## Emitted once when hp reaches zero; info describes the killing blow.
signal died(info: DamageInfo)
## Emitted after healing; amount is what was actually restored.
signal healed(amount: int)
## Emitted whenever hp changes (damage, healing, reset). For the HUD.
signal hp_changed(hp: int, max_hp: int)
## Emitted when invulnerability starts (true) and ends (false), e.g. for blinking.
signal invulnerability_changed(is_invulnerable: bool)

@export var max_hp: int = 100
## Seconds of invulnerability after taking damage. Keep 0 for enemies,
## otherwise the hits of a sword combo would be absorbed.
@export var invulnerability_time: float = 0.0

var hp: int = 0
var _invulnerable_left: float = 0.0


func _ready() -> void:
	hp = max_hp


func _physics_process(delta: float) -> void:
	if _invulnerable_left <= 0.0:
		return
	_invulnerable_left -= delta
	if _invulnerable_left <= 0.0:
		_invulnerable_left = 0.0
		invulnerability_changed.emit(false)


## True if take_damage(info) would apply the damage right now.
func can_take_damage(info: DamageInfo) -> bool:
	if is_dead() or info.amount <= 0:
		return false
	return info.ignores_invulnerability or not is_invulnerable()


## Applies damage. Returns false if the hit was absorbed (dead, invulnerable or no damage).
func take_damage(info: DamageInfo) -> bool:
	if not can_take_damage(info):
		return false
	hp = maxi(hp - info.amount, 0)
	damaged.emit(info)
	hp_changed.emit(hp, max_hp)
	if hp == 0:
		died.emit(info)
	else:
		make_invulnerable(invulnerability_time)
	return true


## Restores up to amount hit points. Returns how many were actually restored.
func heal(amount: int) -> int:
	if is_dead() or amount <= 0:
		return 0
	var restored: int = mini(amount, max_hp - hp)
	if restored > 0:
		hp += restored
		healed.emit(restored)
		hp_changed.emit(hp, max_hp)
	return restored


func is_dead() -> bool:
	return hp <= 0


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


## Ignores damage for the given seconds (after a hit, during a dash).
## Overlapping calls keep the longer time.
func make_invulnerable(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var was_invulnerable: bool = is_invulnerable()
	_invulnerable_left = maxf(_invulnerable_left, seconds)
	if not was_invulnerable:
		invulnerability_changed.emit(true)


## Restores full health and ends invulnerability (restored dummy, new run).
func reset() -> void:
	hp = max_hp
	hp_changed.emit(hp, max_hp)
	if is_invulnerable():
		_invulnerable_left = 0.0
		invulnerability_changed.emit(false)
