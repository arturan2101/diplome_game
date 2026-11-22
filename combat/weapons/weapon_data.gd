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
## Pictures of the rarer copies by rarity id (&"rare", &"legendary"); a missing one
## keeps icon.
@export var rarity_icons: Dictionary = {}
## The wielder aims at the nearest visible enemy within this distance, in pixels.
## 0 turns auto-aim off.
@export var auto_aim_radius: float = 56.0

@export_group("Sounds")
## Sound ids (stage 46): assets/audio/sfx/<id>.ogg or its variants <id>_1, _2...; &"" = silent.
## Every attack (a swing, a shot); the last step of a combo plays finisher_sound if set.
@export var attack_sound: StringName = &""
@export var finisher_sound: StringName = &""
## The bow starts drawing; the crossbow is loaded again.
@export var charge_sound: StringName = &""
@export var reload_sound: StringName = &""
@export_group("")
## Scene with the weapon behaviour (root node is a Weapon), created when the weapon is equipped.
@export var weapon_scene: PackedScene
## How rare this copy of the weapon is; empty = common. The base .tres files stay
## common: a found weapon is a copy of its base resource with a rarity (with_rarity()).
@export var rarity: WeaponRarity
## Name of the player's animation for an attack with this weapon: "<name>_<dir>"
## (the spear thrusts, the daggers stab); a missing animation plays nothing.
@export var attack_animation: StringName = &"attack"

@export_group("Level and critical hits")
## Level of this copy: 1 as found, one more after every boss the player kills while
## carrying it, up to max_level (stage 39, only with ExperimentConfig.arsenal).
@export var level: int = 1
@export var max_level: int = 3
## Extra damage for each level above the first: 0.25 = level 2 hits x1.25, level 3 x1.5.
@export var damage_per_level: float = 0.25
## Chance (0-1) that a hit is critical, before the rarity's bonus. 0 = never (enemy
## weapons). The player's weapons only crit with ExperimentConfig.arsenal.
@export_range(0.0, 1.0) var crit_chance: float = 0.0
## A critical hit deals this many times the damage.
@export var crit_multiplier: float = 2.0


## The rarity of this weapon, never null (common when none is set).
func get_rarity() -> WeaponRarity:
	return rarity if rarity != null else COMMON_RARITY


## Rarity and level together.
func get_damage_multiplier() -> float:
	return get_rarity().damage_multiplier * get_level_multiplier()


## 1 at level 1, then damage_per_level more for every level.
func get_level_multiplier() -> float:
	return 1.0 + damage_per_level * float(maxi(level, 1) - 1)


## The chance of a critical hit with the rarity's bonus; 0 for a weapon that never crits.
func get_crit_chance() -> float:
	if crit_chance <= 0.0:
		return 0.0
	return clampf(crit_chance + get_rarity().crit_chance_bonus, 0.0, 1.0)


func is_max_level() -> bool:
	return level >= max_level


func get_attack_speed_multiplier() -> float:
	return get_rarity().attack_speed_multiplier


## The name with the rarity in front and the level after it once it has grown,
## e.g. "Rare Sword" or "Rare Sword Lv2".
func get_full_name() -> String:
	var full_name: String = "%s %s" % [get_rarity().display_name, display_name]
	return full_name if level <= 1 else "%s Lv%d" % [full_name, level]


## A copy of this weapon at the given level (clamped to 1..max_level); this resource
## itself is not changed.
func with_level(new_level: int) -> WeaponData:
	var copy: WeaponData = duplicate() as WeaponData
	copy.level = clampi(new_level, 1, max_level)
	return copy


## Lines of the weapon card (ui/weapon_card.gd): {"name", "value", "text"}; a higher
## value is better, the text is what the card shows. Subclasses add their own lines
## (damage, speed, reach); the base adds the critical hits.
func get_card_stats() -> Array[Dictionary]:
	var stats: Array[Dictionary] = []
	var chance: float = get_crit_chance()
	if chance > 0.0:
		stats.append(card_line("Crit", chance, "%d%% x%s" % [roundi(chance * 100.0), _short(crit_multiplier)]))
	return stats


static func card_line(line_name: String, value: float, text: String) -> Dictionary:
	return {"name": line_name, "value": value, "text": text}


## A number with at most one decimal, without a trailing ".0".
static func _short(value: float) -> String:
	var rounded: float = snappedf(value, 0.1)
	return str(int(rounded)) if is_equal_approx(rounded, roundf(rounded)) else "%.1f" % rounded


## A copy of this weapon with the given rarity; this resource itself is not changed.
func with_rarity(new_rarity: WeaponRarity) -> WeaponData:
	var copy: WeaponData = duplicate() as WeaponData
	copy.rarity = new_rarity
	if new_rarity != null and rarity_icons.has(new_rarity.id):
		copy.icon = rarity_icons[new_rarity.id]
	return copy
