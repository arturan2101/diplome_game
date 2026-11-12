class_name RuleDirector
extends Director
## The main director: rules and formulas from docs/design.md.
## 1. Tension wave: build-up (x0.8, x1.0), peak (x1.3), rest (x0.3), then again.
## 2. Frustration guard: low HP or several bad sections in a row force a rest.
## 3. Danger budget: B = round((base + k_s * S + k_d * depth) * phase multiplier),
##    where S is the estimated skill.
## 4. Contents follow the phase and the player's trouble: more health and cover when
##    resting or hurt, fewer of the enemy type that hurts a weak player most (more of
##    it for a strong player).
## All numbers live in DirectorSettings.

const COVER_TAG: StringName = &"cover"
const OPEN_TAG: StringName = &"open"
const HAZARD_TAG: StringName = &"hazard"
const HAZARD_SOURCES: Array[StringName] = [&"pit", &"spikes"]
const NORMAL_WIDTH: int = 3
const REST_ROOMS: int = 3
const NORMAL_TWIST: float = 0.3


func choose_next(state: PlayerState) -> SectionPlan:
	var plan: SectionPlan = new_plan(state)
	if not plan.is_arena:
		plan.phase = next_phase(state)
	plan.budget = budget_for(state, plan.phase)
	var problem: StringName = _problem_source(state)
	plan.enemy_mix = buy_enemies(plan.budget, state.rng, _enemy_weights(state, problem))
	plan.corridor_twist = NORMAL_TWIST
	plan.coins = state.rng.randi_range(settings.coins_min, settings.coins_max)
	plan.health_packs = settings.base_health_packs
	plan.cover_density = settings.cover_density
	plan.corridor_width = NORMAL_WIDTH
	if state.hp_fraction < settings.extra_pack_below_hp:
		plan.health_packs += 1
	match plan.phase:
		SectionPlan.PHASE_REST:
			# A breather: short, wide, with cover and an extra health pack.
			plan.room_count = REST_ROOMS
			plan.corridor_width = MAX_CORRIDOR_WIDTH
			plan.health_packs += 1
			plan.cover_density = settings.rest_cover_density
			plan.preferred_tags.append(COVER_TAG)
		SectionPlan.PHASE_PEAK:
			# The tense one: long and narrow.
			plan.room_count = MAX_ROOMS
			plan.corridor_width = MIN_CORRIDOR_WIDTH
	_help_with_problem(plan, state, problem)
	finish_arena(plan)
	return plan


## Phase of the next section: the forced rest of the frustration guard, or the next
## step of the wave after the phases already played.
func next_phase(state: PlayerState) -> StringName:
	if _needs_rest(state):
		return SectionPlan.PHASE_REST
	if state.phases.is_empty():
		return SectionPlan.PHASE_BUILD
	var last: StringName = state.phases[state.phases.size() - 1]
	# The arena that ends a depth counts as a peak: a rest follows it.
	if last == SectionPlan.PHASE_PEAK or last == SectionPlan.PHASE_ARENA:
		return SectionPlan.PHASE_REST
	if last != SectionPlan.PHASE_BUILD:
		return SectionPlan.PHASE_BUILD
	return SectionPlan.PHASE_BUILD if _build_steps_done(state) < settings.build_multipliers.size() \
			else SectionPlan.PHASE_PEAK


## B = round((base + k_s * S + k_d * depth) * m_phase).
func budget_for(state: PlayerState, phase: StringName) -> int:
	var raw: float = settings.budget_base + settings.budget_skill_factor * state.skill \
			+ settings.budget_depth_factor * state.depth
	var budget: int = roundi(raw * _phase_multiplier(state, phase))
	if phase != SectionPlan.PHASE_REST:
		budget = maxi(budget, settings.min_budget)
	return budget


func _phase_multiplier(state: PlayerState, phase: StringName) -> float:
	match phase:
		SectionPlan.PHASE_PEAK, SectionPlan.PHASE_ARENA:
			# The frustration guard softens an arena to an ordinary build-up section.
			if phase == SectionPlan.PHASE_ARENA and _needs_rest(state):
				return settings.build_multipliers[settings.build_multipliers.size() - 1]
			return settings.peak_multiplier
		SectionPlan.PHASE_REST:
			return settings.rest_multiplier
	var step: int = mini(_build_steps_done(state), settings.build_multipliers.size() - 1)
	return settings.build_multipliers[step]


## How many build-up sections in a row were just played.
func _build_steps_done(state: PlayerState) -> int:
	var steps: int = 0
	for i in range(state.phases.size() - 1, -1, -1):
		if state.phases[i] != SectionPlan.PHASE_BUILD:
			break
		steps += 1
	return steps


## Frustration guard: low HP, or the last sections all went badly.
func _needs_rest(state: PlayerState) -> bool:
	if state.hp_fraction < settings.low_hp_fraction:
		return true
	if state.results.size() < settings.low_result_streak:
		return false
	# A rest was just given for that streak: do not repeat it forever.
	if not state.phases.is_empty() and state.phases[state.phases.size() - 1] == SectionPlan.PHASE_REST:
		return false
	for i in range(state.results.size() - settings.low_result_streak, state.results.size()):
		if state.results[i] >= settings.low_result:
			return false
	return true


## The source (enemy type or hazard) behind most of the recent damage, or &"".
func _problem_source(state: PlayerState) -> StringName:
	var total: int = 0
	for source: StringName in state.recent_damage:
		total += int(state.recent_damage[source])
	if total <= 0:
		return &""
	for source: StringName in state.recent_damage:
		if float(state.recent_damage[source]) / float(total) >= settings.problem_enemy_share:
			return source
	return &""


## A weak player meets the enemy that hurts them less often, a strong one more often.
func _enemy_weights(state: PlayerState, problem: StringName) -> Dictionary:
	if problem == &"" or catalog.get_by_id(problem) == null:
		return {}
	if state.skill < settings.weak_player_below:
		return {problem: settings.problem_enemy_weight_weak}
	if state.skill > settings.strong_player_above:
		return {problem: settings.problem_enemy_weight_strong}
	return {}


## Rooms and cover that help a weak player against what hurts them:
## cover against archers, no hazard rooms if the hazards are the trouble.
func _help_with_problem(plan: SectionPlan, state: PlayerState, problem: StringName) -> void:
	if problem == &"" or state.skill >= settings.weak_player_below:
		return
	if problem in HAZARD_SOURCES:
		plan.avoided_tags.append(HAZARD_TAG)
	elif problem == &"archer":
		plan.cover_density = settings.rest_cover_density
		if not COVER_TAG in plan.preferred_tags:
			plan.preferred_tags.append(COVER_TAG)
		plan.avoided_tags.append(OPEN_TAG)
