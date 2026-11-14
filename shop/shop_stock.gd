class_name ShopStock
extends RefCounted
## Picks what a merchant sells (stage 24). All choices come from the given generator,
## so the same seed and section give the same stock for the same player.
## Spell offers raise a spell the player has (below the top level) or bring a new one
## while a slot is free; without spells in the series, or with nothing to offer, the
## slot becomes healing.


## min_offers..max_offers offers. spells = null: the series has no spells.
## book: the player's spells (null = none known, both slots free).
static func make_offers(data: ShopData, depth: int, rng: RandomNumberGenerator, weapons: WeaponPool,
		rarity_table: RarityTable, spells: SpellPool, book: SpellBook, wandering: bool) -> Array[ShopOffer]:
	var offers: Array[ShopOffer] = []
	var offered_spells: Dictionary = {}
	var kinds: Array[ShopOffer.Kind] = [ShopOffer.Kind.HEAL, ShopOffer.Kind.WEAPON]
	var weights: Array[float] = [data.heal_weight, data.weapon_weight]
	if spells != null and not spells.spells.is_empty():
		kinds.append(ShopOffer.Kind.SPELL)
		weights.append(data.spell_weight)
	for _i in rng.randi_range(data.min_offers, data.max_offers):
		var offer: ShopOffer = ShopOffer.new()
		offer.kind = kinds[_pick(weights, rng)]
		var base: float = data.heal_price
		if offer.kind == ShopOffer.Kind.WEAPON and weapons != null and not weapons.weapons.is_empty():
			var rarity: WeaponRarity = rarity_table.pick(depth, rng) if rarity_table != null else null
			var weapon: WeaponData = weapons.pick(rng)
			offer.weapon = weapon.with_rarity(rarity) if rarity != null else weapon
			base = data.weapon_price * float(data.rarity_price.get(offer.weapon.get_rarity().id, 1.0))
		elif offer.kind == ShopOffer.Kind.SPELL and _choose_spell(offer, spells, book, offered_spells, rng):
			base = data.spell_level_price * (offer.spell_level - 1) if offer.kind == ShopOffer.Kind.SPELL_LEVEL else data.spell_price
			offered_spells[offer.spell.id] = true
		else:
			offer.kind = ShopOffer.Kind.HEAL
		if offer.kind == ShopOffer.Kind.HEAL:
			offer.heal_amount = data.heal_amount
			base = data.heal_price
		offer.price = data.price_for(base, depth, wandering)
		offers.append(offer)
	return offers


## A level for a spell the player has (below the top), else a new spell for a free slot.
static func _choose_spell(offer: ShopOffer, spells: SpellPool, book: SpellBook, offered: Dictionary,
		rng: RandomNumberGenerator) -> bool:
	var raise: Array[SpellData] = []
	var fresh: Array[SpellData] = []
	for spell_data: SpellData in spells.spells:
		if offered.has(spell_data.id):
			continue
		var level: int = book.level_of(spell_data.id) if book != null else 0
		if level > 0 and level < SpellData.MAX_LEVEL:
			raise.append(spell_data)
		elif level == 0 and (book == null or book.has_free_slot()):
			fresh.append(spell_data)
	var pool: Array[SpellData] = raise if not raise.is_empty() else fresh
	if pool.is_empty():
		return false
	offer.spell = pool[rng.randi_range(0, pool.size() - 1)]
	var known: int = book.level_of(offer.spell.id) if book != null else 0
	offer.spell_level = known + 1
	offer.kind = ShopOffer.Kind.SPELL_LEVEL if known > 0 else ShopOffer.Kind.SPELL
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
