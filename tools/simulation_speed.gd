class_name SimulationSpeed
extends RefCounted
## Fast-forward for bot runs and tests without changing the physics.
## Engine.time_scale alone makes every physics tick longer (delta grows), which
## changes how the game plays. Here the tick rate grows together with the time scale,
## so each tick still simulates 1/60 s and only more ticks fit into a real second.

const NORMAL_TICKS_PER_SECOND: int = 60
const NORMAL_MAX_STEPS_PER_FRAME: int = 8
## Physics ticks allowed per rendered frame, per unit of speed.
const STEPS_PER_FRAME_FACTOR: int = 4


## factor 1 = normal speed, 8 = eight times faster (if the CPU keeps up).
static func set_factor(factor: int) -> void:
	factor = maxi(factor, 1)
	Engine.time_scale = float(factor)
	Engine.physics_ticks_per_second = NORMAL_TICKS_PER_SECOND * factor
	Engine.max_physics_steps_per_frame = maxi(NORMAL_MAX_STEPS_PER_FRAME, factor * STEPS_PER_FRAME_FACTOR)


static func reset() -> void:
	set_factor(1)
