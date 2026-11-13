class_name BanditActions
extends RefCounted
## The choices of the learned director ("arms" of the bandit): section type x danger
## budget level x dominant enemy. 3 x 3 x 3 = 27 actions, numbered
## index = (type * levels + level) * enemies + enemy.
## Type: build (ordinary), peak (long and narrow), rest (short, wide, cover, a health
## pack) - the same layouts as the rules director's phases (Director.fill_contents).
## Budget level: DirectorSettings.bandit_budget_levels (low / mid / high), plus the usual
## growth with depth. Dominant enemy: that type is bandit_dominant_weight times likelier
## when the budget is spent. An arena keeps its own layout; budget and enemies apply.

const TYPES: Array[StringName] = [SectionPlan.PHASE_BUILD, SectionPlan.PHASE_PEAK, SectionPlan.PHASE_REST]
const LEVEL_NAMES: Array[String] = ["low", "mid", "high"]
const ENEMIES: Array[StringName] = [&"skeleton", &"archer", &"beetle"]


static func count(settings: DirectorSettings) -> int:
	return TYPES.size() * settings.bandit_budget_levels.size() * ENEMIES.size()


## {"type": StringName, "level": int, "enemy": StringName} of an action index.
static func decode(index: int, settings: DirectorSettings) -> Dictionary:
	var levels: int = settings.bandit_budget_levels.size()
	return {
		"type": TYPES[index / (levels * ENEMIES.size())],
		"level": (index / ENEMIES.size()) % levels,
		"enemy": ENEMIES[index % ENEMIES.size()],
	}


static func encode(type: StringName, level: int, enemy: StringName, settings: DirectorSettings) -> int:
	return (TYPES.find(type) * settings.bandit_budget_levels.size() + level) * ENEMIES.size() + ENEMIES.find(enemy)


## True if the action fits the calm start of a run: not a peak, and a budget level no
## higher than DirectorSettings.calm_start_max_budget (low and mid with the usual settings).
static func is_calm(index: int, settings: DirectorSettings) -> bool:
	var action: Dictionary = decode(index, settings)
	return action["type"] != SectionPlan.PHASE_PEAK \
			and settings.bandit_budget_levels[action["level"]] <= settings.calm_start_max_budget


## Every action allowed at the calm start: 2 types x 2 levels x 3 enemies = 12 of the 27.
static func calm_actions(settings: DirectorSettings) -> PackedInt32Array:
	var allowed: PackedInt32Array = PackedInt32Array()
	for index in count(settings):
		if is_calm(index, settings):
			allowed.append(index)
	return allowed


## Readable name, e.g. "peak/high/archer".
static func label(index: int, settings: DirectorSettings) -> String:
	var action: Dictionary = decode(index, settings)
	var level: int = action["level"]
	var level_name: String = LEVEL_NAMES[level] if level < LEVEL_NAMES.size() else str(level)
	return "%s/%s/%s" % [action["type"], level_name, action["enemy"]]


## Fills a plan made by director.new_plan() according to the action.
static func apply(director: Director, plan: SectionPlan, state: PlayerState, index: int) -> void:
	var action: Dictionary = decode(index, director.settings)
	var settings: DirectorSettings = director.settings
	plan.action = index
	if not plan.is_arena:
		plan.phase = action["type"]
	plan.budget = settings.bandit_budget_levels[action["level"]] + roundi(settings.budget_depth_factor * state.depth)
	plan.enemy_mix = director.buy_enemies(plan.budget, state.rng, {action["enemy"]: settings.bandit_dominant_weight})
	director.fill_contents(plan, state)
	director.finish_arena(plan, state.rng)
