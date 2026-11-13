class_name TileTheme
extends Resource
## Which pictures a level is drawn with. The generator and the game logic know only
## cell types (LevelGrid.Cell); this resource maps them to tiles of two atlases.
## A new ruin style is a new .tres of this class.

## Size of one tile in pixels.
@export var tile_size: int = 16
## Main atlas (Kenney Tiny Dungeon).
@export var texture: Texture2D
## Atlas with hazard tiles the main pack lacks.
@export var hazard_texture: Texture2D
## Floor tiles in the main atlas (column, row). The first is the common one.
@export var floor_tiles: Array[Vector2i] = []
## Share of floor cells drawn with one of the other floor tiles.
@export_range(0.0, 1.0) var floor_variant_chance: float = 0.12
## Wall tiles in the main atlas (column, row), picked per cell.
@export var wall_tiles: Array[Vector2i] = []
## Wall-top tiles (top face only) for walls with no open cell directly south.
## Empty: every wall uses wall_tiles.
@export var wall_top_tiles: Array[Vector2i] = []
## Cover object in the main atlas, drawn over a floor tile.
@export var cover_tile: Vector2i = Vector2i.ZERO
## Pit and spikes tiles in the hazard atlas. pit_tile has a rim and is used at the
## top edge of a pit; pit_inner_tile is used below another pit cell.
@export var pit_tile: Vector2i = Vector2i.ZERO
@export var pit_inner_tile: Vector2i = Vector2i.ZERO
@export var spikes_tile: Vector2i = Vector2i.ZERO
## Physics layers of walls and cover (world).
@export_flags_2d_physics var solid_collision_layer: int = 1
