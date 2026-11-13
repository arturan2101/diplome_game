class_name IceWallData
extends SpellData
## Ice wall: a row of ice blocks across the aim direction, a little ahead of the
## caster. Blocks stop enemies and arrows (they are on the world layer) and melt after
## a while. Only free floor gets a block, so nobody is shut inside one.

## Number of blocks (tiles) at levels 1, 2, 3.
@export var blocks: PackedInt32Array = PackedInt32Array([3, 4, 5])
## Seconds the wall stands at levels 1, 2, 3.
@export var duration: PackedFloat32Array = PackedFloat32Array([4.0, 5.0, 6.0])
## Distance from the caster to the middle of the wall, in pixels.
@export var distance: float = 32.0
## One block (root node is an IceBlock).
@export var block_scene: PackedScene
