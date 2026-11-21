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
## Merging two spells at the top level into a new one (stage 26).
@export var fusion_price: int = 30
## Goods (stage 42, ExperimentConfig.shop_goods): how often a random offer is one of
## them, which ones (ids: &"whetstone", &"elixir", &"charm", &"rune_key"), and their
## prices at the first depth. The dice (new goods) come as one more offer at the end.
@export var goods_weight: float = 0.8
@export var goods: Array[StringName] = [&"whetstone", &"elixir", &"charm", &"rune_key"]
@export var goods_prices: Dictionary = {&"whetstone": 20, &"elixir": 16, &"charm": 14, &"rune_key": 12, &"dice": 6}
## Max HP a heart elixir adds (and heals).
@export var elixir_max_hp: int = 10
## Pictures of the goods: a strip of 16x16 icons in goods_icon_order.
@export var goods_icons: Texture2D = preload("res://assets/art/ui/shop_icons2.png")
@export var goods_icon_order: Array[StringName] = [&"whetstone", &"dice", &"elixir", &"charm", &"rune_key"]
## Weapon prices by rarity id (common, rare, legendary).
@export var rarity_price: Dictionary = {&"common": 1.0, &"rare": 1.8, &"legendary": 3.0}
## Every depth after the first adds this share of the price (0.2 = +20% per depth).
@export var price_growth_per_depth: float = 0.2
## A wandering merchant's prices are multiplied by this.
@export var wandering_discount: float = 0.7


## Every price times this (the full game's tuning makes the shop dearer).
@export var price_multiplier: float = 1.0


## The icon of a good, cut from goods_icons (null if it has none).
func goods_icon(good: StringName) -> Texture2D:
	var index: int = goods_icon_order.find(good)
	if goods_icons == null or index < 0:
		return null
	var icon: AtlasTexture = AtlasTexture.new()
	icon.atlas = goods_icons
	icon.region = Rect2(index * 16.0, 0.0, 16.0, 16.0)
	return icon


## Final price of something that costs `base` at the first depth.
func price_for(base: float, depth: int, wandering: bool) -> int:
	var price: float = base * price_multiplier * (1.0 + price_growth_per_depth * depth)
	if wandering:
		price *= wandering_discount
	return maxi(1, roundi(price))
