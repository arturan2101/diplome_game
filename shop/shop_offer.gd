class_name ShopOffer
extends RefCounted
## One thing a merchant sells: healing, a weapon (with its rarity), a new spell, the
## next level of a spell the player has, or the merging of two spells (stage 26), and
## its price in coins.

enum Kind { HEAL, WEAPON, SPELL, SPELL_LEVEL, FUSION }

const HEAL_ICON: Texture2D = preload("res://assets/sprites/shop_heal_icon.tres")

var kind: Kind = Kind.HEAL
var price: int = 0
var heal_amount: int = 0
var weapon: WeaponData = null
var spell: SpellData = null
## Level the spell reaches with this offer (spell offers).
var spell_level: int = 1
## The two spells that merge and what they become (fusion offers).
var recipe: FusionRecipe = null
## A new spell while both slots are full: buying it asks which spell to forget.
var replaces: bool = false
var sold: bool = false


## Short id for the log: heal, the weapon id, the spell id (with its level).
func get_id() -> String:
	match kind:
		Kind.WEAPON:
			return String(weapon.id)
		Kind.SPELL, Kind.SPELL_LEVEL:
			return "%s_%d" % [spell.id, spell_level]
		Kind.FUSION:
			return recipe.get_id()
	return "heal"


func get_title() -> String:
	match kind:
		Kind.WEAPON:
			return weapon.get_full_name()
		Kind.SPELL:
			return "%s (swap)" % spell.display_name if replaces else spell.display_name
		Kind.SPELL_LEVEL:
			return "%s, level %d" % [spell.display_name, spell_level]
		Kind.FUSION:
			return "Merge into %s" % recipe.result.display_name
	return "Healing (+%d HP)" % heal_amount


func get_icon() -> Texture2D:
	match kind:
		Kind.WEAPON:
			return weapon.icon
		Kind.SPELL, Kind.SPELL_LEVEL:
			return spell.icon
		Kind.FUSION:
			return recipe.result.icon
	return HEAL_ICON


## False while the player cannot take it (a new spell the player already has, the spell
## not at the level below any more, the two spells of a merge no longer at the top). A
## new spell with both slots full can be taken: it replaces one (the game asks which).
## book = null: no spells known, both slots free (as in ShopStock).
func is_available(book: SpellBook) -> bool:
	match kind:
		Kind.SPELL:
			if book == null:
				return true
			var result: SpellBook.LearnResult = book.check_learn(spell)
			return result == SpellBook.LearnResult.LEARNED or result == SpellBook.LearnResult.SLOTS_FULL
		Kind.SPELL_LEVEL:
			return book != null and book.level_of(spell.id) == spell_level - 1
		Kind.FUSION:
			return book != null and book.can_fuse(recipe)
	return true
