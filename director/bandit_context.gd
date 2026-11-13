class_name BanditContext
extends RefCounted
## What the learned director knows about the player when it plans a section: a short
## vector of numbers (the "context" of the contextual bandit), all between 0 and 1.
## Computed here once and written to the log, so the Python trainer learns from exactly
## the numbers the game will use. The order is fixed: training/train_bandit.py and the
## parameter file list the same names.

const FEATURE_NAMES: Array[String] = [
	"bias",
	"skill",
	"hp",
	"depth",
	"last_result",
	"hurt_by_skeleton",
	"hurt_by_archer",
	"hurt_by_beetle",
]
## Depths deeper than this all count as 1.
const DEPTH_SCALE: float = 6.0
## Enemy types whose share of the recent damage the director looks at.
const ENEMY_IDS: Array[StringName] = [&"skeleton", &"archer", &"beetle"]


## bias (always 1, so a model can have an intercept), skill S, HP share now, depth
## scaled to 0-1, the result p of the last section (S before the first one), and which
## share of the damage of the last sections each enemy type dealt.
static func features(state: PlayerState) -> PackedFloat32Array:
	var x: PackedFloat32Array = PackedFloat32Array()
	x.append(1.0)
	x.append(clampf(state.skill, 0.0, 1.0))
	x.append(clampf(state.hp_fraction, 0.0, 1.0))
	x.append(minf(float(state.depth) / DEPTH_SCALE, 1.0))
	x.append(clampf(state.results[state.results.size() - 1] if not state.results.is_empty() else state.skill, 0.0, 1.0))
	var total: float = 0.0
	for source: StringName in state.recent_damage:
		total += float(state.recent_damage[source])
	for id: StringName in ENEMY_IDS:
		x.append(float(state.recent_damage.get(id, 0)) / total if total > 0.0 else 0.0)
	return x
