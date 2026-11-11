extends SceneTree
## Headless test for Health: damage, invulnerability after a hit and from make_invulnerable
## (the future dash), absorbed hits not counting as damage, death and reset.
## Exit code = number of failed checks.
## Run: godot --headless --path . --script res://tests/test_health.gd

const MAX_HP: int = 50
const HIT: int = 10
## 0.5 s of invulnerability = 30 physics frames at 60 Hz.
const INVULNERABILITY_TIME: float = 0.5

var _failures: int = 0
var _damaged_count: int = 0
var _died_count: int = 0
var _invulnerability_changes: Array[bool] = []


func _initialize() -> void:
	await process_frame
	var health: Health = Health.new()
	health.max_hp = MAX_HP
	health.invulnerability_time = INVULNERABILITY_TIME
	health.damaged.connect(func(_info: DamageInfo) -> void: _damaged_count += 1)
	health.died.connect(func(_info: DamageInfo) -> void: _died_count += 1)
	health.invulnerability_changed.connect(func(value: bool) -> void: _invulnerability_changes.append(value))
	root.add_child(health)

	_check(health.take_damage(_hit(HIT)) and health.hp == MAX_HP - HIT, "damage is applied")
	_check(health.is_invulnerable() and _invulnerability_changes == ([true] as Array[bool]),
			"a hit starts invulnerability")
	_check(not health.take_damage(_hit(HIT)) and health.hp == MAX_HP - HIT and _damaged_count == 1,
			"hit during invulnerability is absorbed and not counted as damage")

	await _physics_frames(35)
	_check(not health.is_invulnerable() and _invulnerability_changes == ([true, false] as Array[bool]),
			"invulnerability ends after invulnerability_time")
	_check(health.take_damage(_hit(HIT)) and health.hp == MAX_HP - 2 * HIT, "damage applies again afterwards")

	# Dash-style invulnerability uses the same mechanism; a shorter call does not cut it.
	await _physics_frames(35)
	health.make_invulnerable(1.0)
	health.make_invulnerable(0.1)
	await _physics_frames(20)
	_check(health.is_invulnerable() and not health.take_damage(_hit(HIT)),
			"make_invulnerable blocks damage and a shorter call keeps the longer time")
	await _physics_frames(60)
	_check(not health.is_invulnerable(), "make_invulnerable ends on time")

	_check(not health.take_damage(_hit(0)), "zero damage is ignored")

	# Death: died is emitted once, a dead owner takes no more damage.
	health.take_damage(_hit(MAX_HP))
	health.take_damage(_hit(HIT))
	_check(health.is_dead() and _died_count == 1, "died is emitted once")
	_check(not health.is_invulnerable(), "the killing blow does not start invulnerability")

	health.make_invulnerable(1.0)
	health.reset()
	_check(health.hp == MAX_HP and not health.is_dead() and not health.is_invulnerable(),
			"reset restores hp and ends invulnerability")

	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	quit(_failures)


func _hit(amount: int) -> DamageInfo:
	return DamageInfo.new(amount, null, &"test")


func _physics_frames(count: int) -> void:
	for _i in count:
		await physics_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		print("FAIL: ", description)
		_failures += 1
