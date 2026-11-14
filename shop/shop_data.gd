class_name ShopData
extends Resource
## What merchants sell and for how much (stage 24: the wandering merchant of a secret
## room; stage 25: the merchant of the glade). Prices are set for the first depth and
## grow with depth; a wandering merchant sells cheaper.

## Offers per merchant, fewest and most.
@export var min_offers: int = 3
@export var max_offers: int = 4
## Relative chance of each kind of offer (a spell offer is a new spell, or the next
## level of a spell the player has).
@export var heal_weight: float = 1.0
@export var weapon_weight: float = 1.0
@export var spell_weight: float = 1.0
## Health restored by a healing offer.
@export var heal_amount: int = 40
## Prices at the first depth, in coins.
@export var heal_price: int = 8
@export var weapon_price: int = 14
@export var spell_price: int = 18
@export var spell_level_price: int = 14
## Weapon prices by rarity id (common, rare, legendary).
@export var rarity_price: Dictionary = {&"common": 1.0, &"rare": 1.8, &"legendary": 3.0}
## Every depth after the first adds this share of the price (0.2 = +20% per depth).
@export var price_growth_per_depth: float = 0.2
## A wandering merchant's prices are multiplied by this.
@export var wandering_discount: float = 0.7


## Final price of something that costs `base` at the first depth.
func price_for(base: float, depth: int, wandering: bool) -> int:
	var price: float = base * (1.0 + price_growth_per_depth * depth)
	if wandering:
		price *= wandering_discount
	return maxi(1, roundi(price))
