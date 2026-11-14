class_name SecretRoomData
extends Resource
## A small hidden room behind a cracked wall (stage 24). After everything else of a
## section is placed, the generator sometimes cuts one into the solid rock next to a
## room of the path (section RNG), with a chest inside and now and then a wandering
## merchant. The way from the entrance to the gate never needs it. It is drawn with its
## own tile theme (Level.region_themes).

## Chance that a section gets a secret room (if there is room for one).
@export_range(0.0, 1.0) var chance: float = 0.35
## Inner size of the room, smallest and largest (cells).
@export var min_size: Vector2i = Vector2i(4, 3)
@export var max_size: Vector2i = Vector2i(6, 4)
## Chance that a wandering merchant waits inside, besides the chest.
@export_range(0.0, 1.0) var merchant_chance: float = 0.15
## Tile theme of the room, a key of Level.region_themes.
@export var theme: StringName = &"nature"
## Places tried before giving up.
@export var tries: int = 80
