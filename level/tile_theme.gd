class_name TileTheme
extends Resource
## Which pictures a level is drawn with. The generator and the game logic know only
## cell types (LevelGrid.Cell); this resource maps them to tiles of two atlases.
## A new ruin style is a new .tres of this class.

## Name of the style, shown in a banner when a run reaches it (stage 42); "" = none.
@export var display_name: String = ""
## Id of the style for the enemies of its floors (EnemyData.floor_style): &"ruins",
## &"flooded", &"fire".
@export var style_id: StringName = &""
## Plate behind the style's name in the banner: index in the HUD's floor_plates strip
## (0 ruins, 1 flooded, 2 fire); -1 = the name without a plate.
@export var plate_index: int = -1
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
## Top of a wall that runs vertically (after stage 49, batch 17): drawn instead of the
## wall top where the floor is on one side only (left or right, not below). The art has
## the edge towards the floor on its right; for a floor on the left it is mirrored.
## (-1, -1) = side walls use wall_top_tiles.
@export var wall_side_tile: Vector2i = Vector2i(-1, -1)
## Wall with a faint crack (the way into a secret room): front and top, like wall_tiles
## and wall_top_tiles. (-1, -1) = the crack wall looks like any wall.
@export var cracked_wall_tile: Vector2i = Vector2i(-1, -1)
@export var cracked_wall_top_tile: Vector2i = Vector2i(-1, -1)
## Old slabs laid on purpose (around the glade's sunlit patch), picked per cell; empty =
## ordinary floor there.
@export var paved_floor_tiles: Array[Vector2i] = []
## Floor in a patch of light from above (placed on purpose, never a random variant).
## (-1, -1) = none.
@export var sunlit_floor_tile: Vector2i = Vector2i(-1, -1)
## Cover object in the main atlas, drawn over a floor tile.
@export var cover_tile: Vector2i = Vector2i.ZERO
## Pit and spikes tiles in the hazard atlas. pit_tile has a rim and is used at the
## top edge of a pit; pit_inner_tile is used below another pit cell.
@export var pit_tile: Vector2i = Vector2i.ZERO
@export var pit_inner_tile: Vector2i = Vector2i.ZERO
@export var spikes_tile: Vector2i = Vector2i.ZERO
## Pits drawn as an animation (the fire ruins' lava): a strip with the edge on row 0
## and the inside on row 1, lava_frames frames each at lava_fps. Null = still pit tiles.
## Only for the main theme of a level, not for region themes.
@export var lava_texture: Texture2D
@export var lava_frames: int = 4
@export var lava_fps: float = 6.0
## Free-standing obstacles drawn on cover cells instead of cover_tile (stage 42: column,
## broken column, rocks, sarcophagus), on cover_piece_chance of them. The bottom-left of
## a picture sits on the bottom-left of its cell; a picture taller than a tile is only
## used where the cell above is not floor (nothing walks behind it), one two tiles wide
## only at the start of a run of two cover cells. Only the look: the cell stays solid.
@export var cover_pieces: Array[Texture2D] = []
@export_range(0.0, 1.0) var cover_piece_chance: float = 0.0
## Health of an obstacle when they break (ExperimentConfig.breakable_cover, stage 47):
## 20 = two sword blows (10 each for the first two). Plain cover tiles (gravestones)
## never break.
@export var cover_piece_hp: int = 20
## Details over the brick fronts of walls (crack, chain, niche with a skull, banner,
## ivy): a strip of 16x16 overlays, on wall_detail_chance of the fronts. Null = none.
@export var wall_details: Texture2D
@export_range(0.0, 1.0) var wall_detail_chance: float = 0.0
## Floor decals of this style (a strip of 16x16 pieces); null = the decor's own.
@export var floor_decals: Texture2D
## The style's wall light instead of the decor's torch (stage 48: glowing mushrooms, a
## lantern, a brazier): a strip of wall_light_frames 16x16 frames and the colour of its
## glow. Null = the torch.
@export var wall_light: Texture2D
@export var wall_light_frames: int = 4
@export var wall_light_color: Color = Color(1.0, 0.62, 0.3, 0.22)
## Rubble on doors walled up while the level runs; null = the decor's own.
@export var door_seal: Texture2D
## A floor trap the style adds after a section is built (stage 48: the fungal
## puffballs, SporePuff); null = none.
@export var floor_trap: SporeTrapData
## Quicksand patches the style lays after a section is built (stage 49: the sand
## temple, Quicksand); null = none.
@export var quicksand: QuicksandData
## The rock behind the walls (stage 48, batch 16): a seamless texture repeated under the
## whole level, seen where no tile is drawn; tint multiplies it. Null = the plain
## clear colour.
@export var backdrop: Texture2D
@export var backdrop_tint: Color = Color.WHITE
## Physics layers of walls and cover (world).
@export_flags_2d_physics var solid_collision_layer: int = 1
