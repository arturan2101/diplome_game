class_name WeaponRarity
extends Resource
## How rare, and how strong, a found weapon is: common, rare or legendary.
## A weapon keeps its base stats in its own resource; the rarity multiplies them when
## the weapon is created. One .tres per rarity in combat/weapons/rarity/.

## Stable id for logs and the director: &"common", &"rare", &"legendary".
@export var id: StringName = &"common"
## Shown before the weapon name in the pickup hint, e.g. "Rare".
@export var display_name: String = "Common"
## Outline of the weapon on the floor, its name in the hint, the bar under its HUD slot.
@export var color: Color = Color(0.75, 0.75, 0.75)
## Multiplies the damage of every hit.
@export var damage_multiplier: float = 1.0
## Attacks are this many times faster: sword swings with their recovery, bow draw
## and bow cooldown take this many times less time.
@export var attack_speed_multiplier: float = 1.0
