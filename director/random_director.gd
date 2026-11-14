class_name RandomDirector
extends Director
## Control group of the experiment: sections are built from the same rooms, enemies
## and items as in the other modes, but nothing depends on how the player is doing.
## Every number is drawn at random; only the depth raises the budget a little, so
## that long runs do not stay trivially easy. Like every mode it starts calmly: the
## first sections of a run get at most the medium budget.

const MAX_TWIST: float = 0.6
const MAX_HEALTH_PACKS: int = 2


func choose_next(state: PlayerState) -> SectionPlan:
	var rng: RandomNumberGenerator = state.rng
	var plan: SectionPlan = new_plan(state)
	if not plan.is_arena:
		plan.phase = SectionPlan.PHASE_RANDOM
	# Calm start: the first sections draw from the lower half only, up to the medium budget.
	var budget_max: int = settings.random_budget_max
	if is_calm_start(state):
		budget_max = clampi(settings.calm_start_max_budget, settings.random_budget_min, budget_max)
	plan.budget = rng.randi_range(settings.random_budget_min, budget_max) + roundi(settings.budget_depth_factor * state.depth)
	plan.enemy_mix = buy_enemies(buy_traps(plan, rng), rng, {}, state.depth)
	plan.corridor_width = rng.randi_range(MIN_CORRIDOR_WIDTH, MAX_CORRIDOR_WIDTH)
	plan.corridor_twist = rng.randf_range(0.0, MAX_TWIST)
	plan.health_packs = rng.randi_range(0, MAX_HEALTH_PACKS)
	plan.coins = rng.randi_range(settings.coins_min, settings.coins_max)
	plan.cover_density = rng.randf()
	plan_combat_rooms(plan, rng)
	finish_arena(plan, rng)
	return plan
