class_name GladeData
extends Resource
## The merchant's glade between depths (stage 25): a short open place in the nature
## theme, without enemies, where the ruins open to the sky. The generator lays it out
## from its own random stream (GameManager.make_glade_rng), the game puts the merchant,
## the props and the gate on it.

## Inner size of the clearing (cells).
@export var size: Vector2i = Vector2i(26, 11)
## Size of the sunlit patch in its middle.
@export var sunlit_size: Vector2i = Vector2i(4, 3)
## Width of the ring of old slabs around the sunlit patch (cells).
@export var paved_ring: int = 1
## Where the merchant stands, from the middle of the clearing.
@export var merchant_offset: Vector2i = Vector2i(0, -3)
## Bumps of rock along the top and bottom edges, so the clearing is not a box.
@export var bumps: int = 6
## Props (no collision) along the edges, and how many of them.
@export var props: Array[Texture2D] = []
@export var prop_count: int = 6
## Tile theme of the glade, a key of Level.region_themes.
@export var theme: StringName = &"glade"
