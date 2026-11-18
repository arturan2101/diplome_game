class_name PerkData
extends Resource
## One permanent skill of the camp's tree (stage 35), bought with ruin shards between
## runs. Each level has a price and a value of its effect; the game applies the values
## at the start of every run (only with the progress between runs on).

enum Effect {
	MAX_HP,          ## + hit points
	DAMAGE,          ## + share of weapon damage (0.1 = +10%)
	MOVE_SPEED,      ## + share of move speed
	SKILL_COOLDOWN,  ## - share of the basic skill's cooldown
	HEALING,         ## + share of what health packs heal
	COIN_MAGNET,     ## radius in pixels inside which coins fly to the player
	ARMOR,           ## - share of damage taken
	CHEST_LUCK,      ## depths added when a chest rolls its weapon's rarity
	SPELL_SLOT,      ## extra spell slots
	START_COINS,     ## coins at the start of a run
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var effect: Effect = Effect.MAX_HP
## Value of the effect at levels 1, 2, 3... (index 0 = level 1); the size is the top level.
@export var values: PackedFloat32Array = PackedFloat32Array([1.0])
## Shards for levels 1, 2, 3...
@export var costs: PackedInt32Array = PackedInt32Array([1])
## Bought at least one level of this one first; null = a root of the tree.
@export var requires: PerkData
## Place in the tree screen: column (branch) and row (tier).
@export var tree_position: Vector2i = Vector2i.ZERO


func max_level() -> int:
	return values.size()


## Value of the effect at this level; 0 at level 0.
func value_at(level: int) -> float:
	if level <= 0 or values.is_empty():
		return 0.0
	return values[mini(level, values.size()) - 1]


## Price of the next level after this one; -1 at the top.
func cost_after(level: int) -> int:
	if level >= max_level() or level < 0 or level >= costs.size():
		return -1
	return costs[level]
