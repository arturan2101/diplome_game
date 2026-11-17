class_name SpellBook
extends Node2D
## The player's spells: SLOT_COUNT slots, each holding a Spell node (a child of this
## node). Learning a spell the player already has raises its level, up to
## SpellData.MAX_LEVEL; a new spell goes into a free slot; with both slots full the
## caller has to choose a slot for replace(). Two spells at the top level can merge by a
## FusionRecipe (fuse(), at the merchant): the new spell comes at level 1 into the first
## one's slot and the other slot is freed. Created by the player in code.

## Slots or levels changed (for the HUD).
signal spells_changed
## A spell was learned (level 1) or levelled up.
signal spell_learned(spell_data: SpellData, level: int)
## Two spells merged into recipe.result (sent after its spell_learned).
signal spell_fused(recipe: FusionRecipe)
## Re-sent from the spells, for telemetry.
signal spell_cast(spell_id: StringName)
signal spell_damage_dealt(spell_id: StringName, amount: int)

enum LearnResult { LEARNED, LEVELED_UP, MAX_LEVEL, SLOTS_FULL }

const SLOT_COUNT: int = 2
## Input actions of the slots, in slot order.
const SLOT_ACTIONS: Array[StringName] = [&"spell_1", &"spell_2"]

var caster: Player = null

## One entry per slot; null = empty slot.
var _slots: Array[Spell] = []


func _init() -> void:
	_slots.resize(SLOT_COUNT)


func setup(spell_caster: Player) -> void:
	caster = spell_caster


## The spell in this slot, or null.
func get_spell(slot: int) -> Spell:
	if slot < 0 or slot >= SLOT_COUNT:
		return null
	return _slots[slot]


## Level of a known spell, 0 if the player does not have it.
func level_of(spell_id: StringName) -> int:
	var spell: Spell = _find(spell_id)
	return spell.level if spell != null else 0


func has_free_slot() -> bool:
	return _slots.has(null)


## What learning this spell would do now, without doing it.
func check_learn(spell_data: SpellData) -> LearnResult:
	var known: Spell = _find(spell_data.id)
	if known != null:
		return LearnResult.MAX_LEVEL if known.level >= SpellData.MAX_LEVEL else LearnResult.LEVELED_UP
	return LearnResult.LEARNED if has_free_slot() else LearnResult.SLOTS_FULL


## Learns the spell or raises its level. With SLOTS_FULL or MAX_LEVEL nothing changes.
func learn(spell_data: SpellData) -> LearnResult:
	var result: LearnResult = check_learn(spell_data)
	match result:
		LearnResult.LEVELED_UP:
			var known: Spell = _find(spell_data.id)
			known.level += 1
			spells_changed.emit()
			spell_learned.emit(spell_data, known.level)
		LearnResult.LEARNED:
			_put(_slots.find(null), spell_data)
	return result


## Puts a new spell (level 1) into a slot, forgetting the spell that was there.
func replace(slot: int, spell_data: SpellData) -> void:
	if slot >= 0 and slot < SLOT_COUNT:
		_put(slot, spell_data)


## True if the recipe can be done now: both spells are known at the top level and its
## result is not known yet.
func can_fuse(recipe: FusionRecipe) -> bool:
	if recipe == null or recipe.first == null or recipe.second == null or recipe.result == null:
		return false
	return (level_of(recipe.first.id) >= SpellData.MAX_LEVEL and level_of(recipe.second.id) >= SpellData.MAX_LEVEL
			and level_of(recipe.result.id) == 0)


## Merges the two spells of the recipe: the result (level 1) takes the first one's slot,
## the second one's slot becomes free. Returns false (and changes nothing) if
## can_fuse() is false.
func fuse(recipe: FusionRecipe) -> bool:
	if not can_fuse(recipe):
		return false
	var first_slot: int = _slots.find(_find(recipe.first.id))
	var second_slot: int = _slots.find(_find(recipe.second.id))
	_slots[second_slot].queue_free()
	_slots[second_slot] = null
	_put(first_slot, recipe.result)
	spell_fused.emit(recipe)
	return true


## The spells in the slots, in slot order, without empty slots.
func get_known() -> Array[SpellData]:
	var known: Array[SpellData] = []
	for spell: Spell in _slots:
		if spell != null:
			known.append(spell.data)
	return known


## Casts the spell of a slot towards the player's aim. Returns true if it was cast.
func cast(slot: int) -> bool:
	var spell: Spell = get_spell(slot)
	if spell == null or caster == null:
		return false
	return spell.try_cast(caster.aim_direction(spell.data.auto_aim_radius))


## Stops lasting effects (death, falling, a new section).
func cancel_all() -> void:
	for spell: Spell in _slots:
		if spell != null:
			spell.cancel()


## Known spells and their levels: {id: level}. For the director.
func to_dictionary() -> Dictionary:
	var known: Dictionary = {}
	for spell: Spell in _slots:
		if spell != null:
			known[spell.data.id] = spell.level
	return known


func _find(spell_id: StringName) -> Spell:
	for spell: Spell in _slots:
		if spell != null and spell.data.id == spell_id:
			return spell
	return null


func _put(slot: int, spell_data: SpellData) -> void:
	if spell_data == null or spell_data.spell_scene == null:
		push_error("Spell %s has no spell_scene" % spell_data)
		return
	if _slots[slot] != null:
		_slots[slot].queue_free()
	var spell: Spell = spell_data.spell_scene.instantiate() as Spell
	spell.setup(spell_data, caster, 1)
	spell.cast_performed.connect(spell_cast.emit)
	spell.damage_dealt.connect(spell_damage_dealt.emit)
	add_child(spell)
	_slots[slot] = spell
	spells_changed.emit()
	spell_learned.emit(spell_data, 1)
