class_name SpikeTrapData
extends Resource
## One kind of spikes. Static spikes are always up. Timed spikes go round a cycle:
## hidden -> warn (a short warning) -> rise -> up (they hurt) -> retract -> hidden.
## The cycle runs on the section clock (Level.section_time) with a phase shift per
## cell, so the same seed and the same director decisions replay the same spikes.
## The director buys spikes in groups for danger_cost points of its budget: a static
## group is a small patch in a room, a timed group is a "wave" across a tunnel whose
## rows rise one after another (wave_step apart), so it is crossed in rhythm.

const PHASE_HIDDEN: StringName = &"hidden"
const PHASE_WARN: StringName = &"warn"
const PHASE_RISE: StringName = &"rise"
const PHASE_UP: StringName = &"up"
const PHASE_RETRACT: StringName = &"retract"

## Damage source in the log: &"spikes_static" or &"spikes_timed".
@export var id: StringName = &"spikes_static"
## Danger points one group costs the director.
@export var danger_cost: int = 1
## Damage when stepping on raised spikes, and again every hit_interval on them.
@export var damage: int = 8
@export var hit_interval: float = 0.5
## Static spikes are always up; timed ones follow the phases below.
@export var timed: bool = false

@export_group("Timed cycle")
## Seconds of each phase, in this order.
@export var hidden_time: float = 1.6
@export var warn_time: float = 0.5
@export var rise_time: float = 0.1
@export var up_time: float = 0.8
@export var retract_time: float = 0.2
## Phase shift between neighbouring rows of a wave, seconds.
@export var wave_step: float = 0.3

@export_group("Groups")
## Rows of a timed wave across a tunnel.
@export var group_rows: int = 3
## Cells of a static patch in a room.
@export var group_cells: int = 3

@export_group("Look")
## Timed spikes: animations hidden, warn, rise, up, retract (one cell, 16x16).
@export var frames: SpriteFrames


## Seconds of one whole cycle (0 for static spikes).
func get_period() -> float:
	if not timed:
		return 0.0
	return hidden_time + warn_time + rise_time + up_time + retract_time


## Phase at the given time of the cell's own cycle (section time plus its shift).
func phase_at(time: float) -> StringName:
	if not timed:
		return PHASE_UP
	var t: float = fposmod(time, get_period())
	for step: Array in _phases():
		if t < step[1]:
			return step[0]
		t -= step[1]
	return PHASE_HIDDEN


## How far into its phase the cycle is at that time, 0-1 (for the animation frame).
func phase_progress_at(time: float) -> float:
	if not timed:
		return 0.0
	var t: float = fposmod(time, get_period())
	for step: Array in _phases():
		if t < step[1]:
			return t / step[1] if step[1] > 0.0 else 0.0
		t -= step[1]
	return 0.0


## True if the spikes hurt at that time.
func is_up_at(time: float) -> bool:
	return phase_at(time) == PHASE_UP


## True if the spikes do not hurt at any moment of [from, to] of the cell's own cycle
## (no "up" phase overlaps it). Static spikes always hurt.
func is_down_during(from: float, to: float) -> bool:
	if not timed:
		return false
	var period: float = get_period()
	var up_start: float = hidden_time + warn_time + rise_time
	var first: int = floori(from / period) - 1
	var last: int = floori(to / period) + 1
	for cycle in range(first, last + 1):
		var start: float = cycle * period + up_start
		if start < to and start + up_time > from:
			return false
	return true


func _phases() -> Array:
	return [[PHASE_HIDDEN, hidden_time], [PHASE_WARN, warn_time], [PHASE_RISE, rise_time],
			[PHASE_UP, up_time], [PHASE_RETRACT, retract_time]]
