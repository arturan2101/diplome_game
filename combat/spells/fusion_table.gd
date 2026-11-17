class_name FusionTable
extends Resource
## Which pairs of spells merge into which new spell (stage 26). One FusionRecipe per
## pair in combat/spells/fusions.tres; a new pair is one more recipe there (plus the
## .tres of its result), no code. The merchant offers every recipe the player can do.

@export var recipes: Array[FusionRecipe] = []


## The recipe of these two spells (either order), or null.
func find(a: StringName, b: StringName) -> FusionRecipe:
	for recipe: FusionRecipe in recipes:
		if recipe != null and recipe.matches(a, b):
			return recipe
	return null


## Recipes the book can do now (both spells at the top level, the result not known).
func available(book: SpellBook) -> Array[FusionRecipe]:
	var found: Array[FusionRecipe] = []
	if book == null:
		return found
	for recipe: FusionRecipe in recipes:
		if recipe != null and book.can_fuse(recipe):
			found.append(recipe)
	return found


## Every spell a recipe makes, in table order without repeats.
func results() -> Array[SpellData]:
	var found: Array[SpellData] = []
	for recipe: FusionRecipe in recipes:
		if recipe != null and recipe.result != null and not found.has(recipe.result):
			found.append(recipe.result)
	return found
