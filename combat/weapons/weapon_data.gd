class_name WeaponData
extends Resource
## Data shared by every weapon. A concrete weapon is a .tres file of a subclass
## (for example MeleeWeaponData), so a new weapon needs no new code.

## Rarity of weapons that have none set (starting weapons, enemy weapons).
const COMMON_RARITY: WeaponRarity = preload("res://combat/weapons/rarity/common.tres")

## Stable id used in logs and telemetry, e.g. &"sword".
@export var id: StringName = &""
@export var display_name: String = ""
## Small picture for the HUD and the menu.
@export var icon: Texture2D
## The wielder aims at the nearest visible enemy within this distance, in pixels.
## 0 turns auto-aim off.
@export var auto_aim_radius: float = 56.0
## Scene with the weapon behaviour (root node is a Weapon), created when the weapon is equipped.
@export var weapon_scene: PackedScene
## How rare this copy of the weapon is; empty = common. The base .tres files stay
## common: a found weapon is a copy of its base resource with a rarity (with_rarity()).
@export var rarity: WeaponRarity


## The rarity of this weapon, never null (common when none is set).
func get_rarity() -> WeaponRarity:
	return rarity if rarity != null else COMMON_RARITY


func get_damage_multiplier() -> float:
	return get_rarity().damage_multiplier


func get_attack_speed_multiplier() -> float:
	return get_rarity().attack_speed_multiplier


## The name with the rarity in front, e.g. "Rare Sword".
func get_full_name() -> String:
	return "%s %s" % [get_rarity().display_name, display_name]


## A copy of this weapon with the given rarity; this resource itself is not changed.
func with_rarity(new_rarity: WeaponRarity) -> WeaponData:
	var copy: WeaponData = duplicate() as WeaponData
	copy.rarity = new_rarity
	return copy
