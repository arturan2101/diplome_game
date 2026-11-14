class_name ShopOffer
extends RefCounted
## One thing a merchant sells: healing, a weapon (with its rarity), a new spell or the
## next level of a spell the player has, and its price in coins.

enum Kind { HEAL, WEAPON, SPELL, SPELL_LEVEL }

const HEAL_ICON: Texture2D = preload("res://assets/sprites/health_potion.tres")

var kind: Kind = Kind.HEAL
var price: int = 0
var heal_amount: int = 0
var weapon: WeaponData = null
var spell: SpellData = null
## Level the spell reaches with this offer (spell offers).
var spell_level: int = 1
var sold: bool = false


## Short id for the log: heal, the weapon id, the spell id (with its level).
func get_id() -> String:
	match kind:
		Kind.WEAPON:
			return String(weapon.id)
		Kind.SPELL, Kind.SPELL_LEVEL:
			return "%s_%d" % [spell.id, spell_level]
	return "heal"


func get_title() -> String:
	match kind:
		Kind.WEAPON:
			return weapon.get_full_name()
		Kind.SPELL:
			return spell.display_name
		Kind.SPELL_LEVEL:
			return "%s, level %d" % [spell.display_name, spell_level]
	return "Healing (+%d HP)" % heal_amount


func get_icon() -> Texture2D:
	match kind:
		Kind.WEAPON:
			return weapon.icon
		Kind.SPELL, Kind.SPELL_LEVEL:
			return spell.icon
	return HEAL_ICON
