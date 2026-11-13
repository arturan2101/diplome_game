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
		plan.enemy_mix = buy_enemies(maxi(0, plan.budget - boss.danger_cost), rng)
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
## without a weight counts as 1. Returns type id -> number of spawns.
func buy_enemies(budget: int, rng: RandomNumberGenerator, weights: Dictionary = {}) -> Dictionary:
	var mix: Dictionary = {}
	var left: int = budget
	while true:
		var affordable: Array[EnemyData] = []
		var total_weight: float = 0.0
		for enemy_data: EnemyData in catalog.enemies:
			var weight: float = float(weights.get(enemy_data.id, 1.0))
			if not enemy_data.is_boss and enemy_data.danger_cost <= left and weight > 0.0:
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


## Danger cost of an enemy mix (type id -> number of spawns).
func mix_cost(mix: Dictionary) -> int:
	var cost: int = 0
	for id: StringName in mix:
		var enemy_data: EnemyData = catalog.get_by_id(id)
		if enemy_data != null:
			cost += enemy_data.danger_cost * int(mix[id])
	return cost
