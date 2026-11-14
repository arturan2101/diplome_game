class_name Director
extends RefCounted
## Base class of every director mode (random, rules, learned). A director never
## touches the scene tree: it reads a PlayerState and returns a SectionPlan.
## This base class is also the simplest director: no adaptation at all, the danger
## budget just grows with the section index. Subclasses override choose_next().

const CATALOG_PATH: String = "res://actors/enemies/enemy_catalog.tres"
const SETTINGS_PATH: String = "res://director/director_settings.tres"
## Budget of the very first section and its growth per section for this baseline.
const BASELINE_BUDGET: int = 3
const MIN_ROOMS: int = 3
const MAX_ROOMS: int = 5
const MIN_CORRIDOR_WIDTH: int = 2
const MAX_CORRIDOR_WIDTH: int = 4
## Layout and contents of the adaptive directors (rules and learned), see fill_contents().
const COVER_TAG: StringName = &"cover"
const NORMAL_WIDTH: int = 3
const REST_ROOMS: int = 3
const NORMAL_TWIST: float = 0.3

var catalog: EnemyCatalog = null
var settings: DirectorSettings = null


func _init(enemy_catalog: EnemyCatalog = null, director_settings: DirectorSettings = null) -> void:
	catalog = enemy_catalog if enemy_catalog != null else load(CATALOG_PATH) as EnemyCatalog
	settings = director_settings if director_settings != null else load(SETTINGS_PATH) as DirectorSettings


## Plans the next section for the given state.
func choose_next(state: PlayerState) -> SectionPlan:
	var plan: SectionPlan = new_plan(state)
	plan.budget = BASELINE_BUDGET + state.section_index
	plan.enemy_mix = buy_enemies(plan.budget, state.rng)
	finish_arena(plan, state.rng)
	return plan


## A plan with the parts every mode fills the same way: indexes, layout size,
## chests and side branches, a shrine now and then, and the arena that ends every depth.
func new_plan(state: PlayerState) -> SectionPlan:
	var plan: SectionPlan = SectionPlan.new()
	plan.section_index = state.section_index
	plan.depth = state.depth
	plan.room_count = state.rng.randi_range(MIN_ROOMS, MAX_ROOMS)
	plan.chests = pick_weighted(settings.chest_count_weights, state.rng)
	for _i in plan.chests:
		if state.rng.randf() < settings.chest_branch_chance:
			plan.side_branches += 1
	# What the learned director sees; logged for every mode.
	plan.context = BanditContext.features(state)
	if state.is_depth_end:
		plan.is_arena = true
		plan.phase = SectionPlan.PHASE_ARENA
		plan.room_count = settings.arena_rooms
		plan.is_boss = settings.boss_every_depths > 0 and (state.depth + 1) % settings.boss_every_depths == 0
	elif state.rng.randf() < settings.shrine_chance:
		plan.shrines = 1
	return plan


## Calm start of a run (DirectorSettings.calm_start_sections): the first sections are
## never a peak and get no more than the medium budget, whatever the mode.
func is_calm_start(state: PlayerState) -> bool:
	return state.section_index < settings.calm_start_sections


## The most a calm-start section may get: the medium budget plus the growth with depth.
func calm_start_budget_cap(state: PlayerState) -> int:
	return settings.calm_start_max_budget + roundi(settings.budget_depth_factor * state.depth)


## Contents and layout the adaptive directors (rules and learned) fill the same way,
## after the phase, the budget and the enemies: coins, health packs (one more for a hurt
## player), cover, corridors; then the phase's layout: a rest section is short and wide
## with cover and one more health pack, a peak is long and narrow.
func fill_contents(plan: SectionPlan, state: PlayerState) -> void:
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


## Arenas, after the budget and the enemies are chosen: two waves from a large budget.
## A boss arena instead holds the boss plus an escort bought with what is left of the
## budget, all in one wave (the boss calls more help itself).
func finish_arena(plan: SectionPlan, rng: RandomNumberGenerator) -> void:
	if not plan.is_arena:
		return
	var boss: EnemyData = catalog.get_by_id(settings.boss_id) if plan.is_boss else null
	if boss != null:
		plan.enemy_mix = buy_enemies(maxi(0, plan.budget - boss.danger_cost), rng, {}, plan.depth)
		plan.enemy_mix[boss.id] = 1
		plan.waves = 1
		return
	plan.is_boss = false
	plan.waves = 2 if plan.budget >= settings.arena_two_waves_budget else 1


## Index picked with the given weights (they need not add up to 1).
func pick_weighted(weights: Array[float], rng: RandomNumberGenerator) -> int:
	var total: float = 0.0
	for weight: float in weights:
		total += weight
	var roll: float = rng.randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll < 0.0:
			return i
	return weights.size() - 1


## Spends a danger budget on enemies: picks random affordable types until nothing
## fits. weights (type id -> number) make some types more or less likely; a type
## without a weight counts as 1. Elite types join only when they are on and the depth
## has reached theirs (no depth = no elites). Returns type id -> number of spawns.
func buy_enemies(budget: int, rng: RandomNumberGenerator, weights: Dictionary = {}, depth: int = -1) -> Dictionary:
	var mix: Dictionary = {}
	var left: int = budget
	while true:
		var affordable: Array[EnemyData] = []
		var total_weight: float = 0.0
		for enemy_data: EnemyData in catalog.enemies:
			var weight: float = float(weights.get(enemy_data.id, 1.0))
			if not enemy_data.is_boss and enemy_data.danger_cost <= left and weight > 0.0 and _can_buy(enemy_data, depth):
				affordable.append(enemy_data)
				total_weight += weight
		if affordable.is_empty():
			break
		var roll: float = rng.randf() * total_weight
		var chosen: EnemyData = affordable[affordable.size() - 1]
		for enemy_data: EnemyData in affordable:
			roll -= float(weights.get(enemy_data.id, 1.0))
			if roll <= 0.0:
				chosen = enemy_data
				break
		mix[chosen.id] = int(mix.get(chosen.id, 0)) + 1
		left -= chosen.danger_cost
	return mix


## Spike traps bought from the danger budget before the enemies, the same rule in
## every mode: with trap_chance an ordinary section (not rest, not arena) gets trap
## groups worth up to trap_budget_share of its budget (at most max_trap_groups), kinds
## picked at random among the affordable ones. Draws nothing from the generator when
## traps are off, so such a series plans exactly as before. Returns what is left for
## the enemies.
func buy_traps(plan: SectionPlan, rng: RandomNumberGenerator) -> int:
	plan.traps = {}
	if settings.trap_chance <= 0.0 or settings.trap_kinds.is_empty() or plan.is_arena \
			or plan.phase == SectionPlan.PHASE_REST:
		return plan.budget
	if rng.randf() >= settings.trap_chance:
		return plan.budget
	var left: int = floori(plan.budget * settings.trap_budget_share)
	var groups: int = 0
	while groups < settings.max_trap_groups:
		var affordable: Array[SpikeTrapData] = []
		for kind: SpikeTrapData in settings.trap_kinds:
			if kind.danger_cost <= left:
				affordable.append(kind)
		if affordable.is_empty():
			break
		var chosen: SpikeTrapData = affordable[rng.randi_range(0, affordable.size() - 1)]
		plan.traps[chosen.id] = int(plan.traps.get(chosen.id, 0)) + 1
		left -= chosen.danger_cost
		groups += 1
	return plan.budget - trap_cost(plan.traps)


func _can_buy(enemy_data: EnemyData, depth: int) -> bool:
	return not enemy_data.is_elite or (settings.elites_enabled and depth >= enemy_data.min_depth)


## Combat rooms, the same rule in every mode: with the phase's chance (DirectorSettings,
## more often at a peak) one room of an ordinary section locks its doors when the
## player walks in, and its enemies come in waves. Never in rest or arena sections, and
## not without at least two spawns. Draws nothing when combat rooms are off.
func plan_combat_rooms(plan: SectionPlan, rng: RandomNumberGenerator) -> void:
	plan.combat_rooms = 0
	plan.combat_waves = 0
	if plan.is_arena or plan.phase == SectionPlan.PHASE_REST or plan.get_spawn_count() < 2:
		return
	var chance: float = settings.combat_room_chance_build
	var waves: Vector2i = settings.combat_waves_build
	if plan.phase == SectionPlan.PHASE_PEAK:
		chance = settings.combat_room_chance_peak
		waves = settings.combat_waves_peak
	elif plan.phase == SectionPlan.PHASE_RANDOM:
		chance = settings.combat_room_chance_random
		waves = settings.combat_waves_random
	if chance <= 0.0 or rng.randf() >= chance:
		return
	plan.combat_rooms = 1
	plan.combat_waves = rng.randi_range(waves.x, waves.y)


## Danger cost of the traps of a plan (trap id -> number of groups).
func trap_cost(traps: Dictionary) -> int:
	var cost: int = 0
	for kind: SpikeTrapData in settings.trap_kinds:
		cost += kind.danger_cost * int(traps.get(kind.id, 0))
	return cost


## Danger cost of an enemy mix (type id -> number of spawns).
func mix_cost(mix: Dictionary) -> int:
	var cost: int = 0
	for id: StringName in mix:
		var enemy_data: EnemyData = catalog.get_by_id(id)
		if enemy_data != null:
			cost += enemy_data.danger_cost * int(mix[id])
	return cost
