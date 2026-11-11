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
	return plan


## A plan with the parts every mode fills the same way: indexes, layout size,
## and a chest (in a side branch) while the player has a free weapon slot.
func new_plan(state: PlayerState) -> SectionPlan:
	var plan: SectionPlan = SectionPlan.new()
	plan.section_index = state.section_index
	plan.depth = state.depth
	plan.room_count = state.rng.randi_range(MIN_ROOMS, MAX_ROOMS)
	plan.has_chest = state.weapon_count < Player.WEAPON_SLOT_COUNT and state.section_index > 0
	plan.has_side_branch = plan.has_chest
	return plan


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
			if enemy_data.danger_cost <= left and weight > 0.0:
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
