class_name ShopStock
extends RefCounted
## Picks what a merchant sells (stage 24). All choices come from the given generator,
## so the same seed and section give the same stock for the same player.
## Spell offers raise a spell the player has (below the top level) or bring a new one
## (with both slots full it replaces one of them: stage 27); without spells in the
## series, or with nothing to offer, the slot becomes healing. With a fusion table (stage 26) every merge the player can do
## now comes first, outside the random offers (it draws nothing from the generator), and
## spells made by merging can be raised like the others (they are never sold new).


## min_offers..max_offers offers (merges and the dice besides), at most
## ShopData.max_shown_offers in all. spells = null: the series has no spells.
## book: the player's spells (null = none known, both slots free).
## fusions = null: no merging in the series.
static func make_offers(data: ShopData, depth: int, rng: RandomNumberGenerator, weapons: WeaponPool,
		rarity_table: RarityTable, spells: SpellPool, book: SpellBook, wandering: bool,
		fusions: FusionTable = null, goods: Array[StringName] = []) -> Array[ShopOffer]:
	var offers: Array[ShopOffer] = []
	var offered_spells: Dictionary = {}
	if fusions != null:
		for recipe: FusionRecipe in fusions.available(book):
			var fusion: ShopOffer = ShopOffer.new()
			fusion.kind = ShopOffer.Kind.FUSION
			fusion.recipe = recipe
			fusion.price = data.price_for(data.fusion_price, depth, wandering)
			offers.append(fusion)
	var kinds: Array[ShopOffer.Kind] = [ShopOffer.Kind.HEAL, ShopOffer.Kind.WEAPON]
	var weights: Array[float] = [data.heal_weight, data.weapon_weight]
	if spells != null and not spells.spells.is_empty():
		kinds.append(ShopOffer.Kind.SPELL)
		weights.append(data.spell_weight)
	# Goods (stage 42): only when the game passes some; otherwise nothing changes.
	var goods_left: Array[StringName] = goods.duplicate()
	if not goods_left.is_empty():
		kinds.append(ShopOffer.Kind.GOODS)
		weights.append(data.goods_weight)
	for _i in rng.randi_range(data.min_offers, data.max_offers):
		var offer: ShopOffer = ShopOffer.new()
		offer.kind = kinds[_pick(weights, rng)]
		var base: float = data.heal_price
		if offer.kind == ShopOffer.Kind.WEAPON and weapons != null and not weapons.weapons.is_empty():
			var rarity: WeaponRarity = rarity_table.pick(depth, rng) if rarity_table != null else null
			var weapon: WeaponData = weapons.pick(rng)
			offer.weapon = weapon.with_rarity(rarity) if rarity != null else weapon
			base = data.weapon_price * float(data.rarity_price.get(offer.weapon.get_rarity().id, 1.0))
		elif offer.kind == ShopOffer.Kind.SPELL and _choose_spell(offer, spells, book, offered_spells, rng, fusions):
			base = data.spell_level_price * (offer.spell_level - 1) if offer.kind == ShopOffer.Kind.SPELL_LEVEL else data.spell_price
			offered_spells[offer.spell.id] = true
		elif offer.kind == ShopOffer.Kind.GOODS and not goods_left.is_empty():
			_make_goods(offer, goods_left.pop_at(rng.randi_range(0, goods_left.size() - 1)), data)
			base = float(data.goods_prices.get(offer.goods, data.heal_price))
		else:
			offer.kind = ShopOffer.Kind.HEAL
		if offer.kind == ShopOffer.Kind.HEAL:
			offer.heal_amount = data.heal_amount
			base = data.heal_price
		offer.price = data.price_for(base, depth, wandering)
		offers.append(offer)
	var fusion_count: int = 0
	for offer: ShopOffer in offers:
		if offer.kind == ShopOffer.Kind.FUSION:
			fusion_count += 1
	if data.max_shown_offers > 0:
		# What fits on the screen: the first merges, then the other offers in order
		# (drawn as before, only cut), and room for the dice.
		var kept_fusions: int = mini(fusion_count, data.max_fusion_offers)
		var room: int = maxi(data.max_shown_offers - kept_fusions - (0 if goods.is_empty() else 1), 0)
		var others: Array[ShopOffer] = offers.slice(fusion_count, fusion_count + room)
		offers = offers.slice(0, kept_fusions)
		offers.append_array(others)
	if not goods.is_empty():
		# The dice: always the last offer, buying it brings new goods.
		var dice: ShopOffer = ShopOffer.new()
		_make_goods(dice, &"dice", data)
		dice.price = data.price_for(float(data.goods_prices.get(&"dice", 1)), depth, wandering)
		offers.append(dice)
	return offers


static func _make_goods(offer: ShopOffer, good: StringName, data: ShopData) -> void:
	offer.kind = ShopOffer.Kind.GOODS
	offer.goods = good
	offer.goods_icon = data.goods_icon(good)
	if good == &"elixir":
		offer.goods_amount = data.elixir_max_hp


## A level for a spell the player has (below the top), else a new spell (for a free slot,
## or to replace one). Merged spells (results of the fusion table) can only be raised.
static func _choose_spell(offer: ShopOffer, spells: SpellPool, book: SpellBook, offered: Dictionary,
		rng: RandomNumberGenerator, fusions: FusionTable = null) -> bool:
	var raise: Array[SpellData] = []
	var fresh: Array[SpellData] = []
	var candidates: Array[SpellData] = spells.spells.duplicate()
	if fusions != null:
		for result: SpellData in fusions.results():
			if not candidates.has(result):
				candidates.append(result)
	for spell_data: SpellData in candidates:
		if offered.has(spell_data.id):
			continue
		var level: int = book.level_of(spell_data.id) if book != null else 0
		if level > 0 and level < SpellData.MAX_LEVEL:
			raise.append(spell_data)
		elif level == 0 and spells.spells.has(spell_data):
			fresh.append(spell_data)
	var pool: Array[SpellData] = raise if not raise.is_empty() else fresh
	if pool.is_empty():
		return false
	offer.spell = pool[rng.randi_range(0, pool.size() - 1)]
	var known: int = book.level_of(offer.spell.id) if book != null else 0
	offer.spell_level = known + 1
	offer.kind = ShopOffer.Kind.SPELL_LEVEL if known > 0 else ShopOffer.Kind.SPELL
	offer.replaces = known == 0 and book != null and not book.has_free_slot()
	return true


static func _pick(weights: Array[float], rng: RandomNumberGenerator) -> int:
	var total: float = 0.0
	for weight: float in weights:
		total += weight
	var roll: float = rng.randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll < 0.0:
			return i
	return weights.size() - 1
