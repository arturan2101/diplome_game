class_name IceWallSpell
extends Spell
## Raises a row of IceBlocks across the aim direction, centred a little ahead of the
## caster, one block per floor tile. Tiles with walls, pits or spikes and tiles where
## someone stands are skipped, so nobody ends up inside the ice.

## Physics layers of bodies that must not end up inside a block (player, enemies).
@export_flags_2d_physics var body_mask: int = 6


func _cast(direction: Vector2) -> void:
	var stats: IceWallData = data as IceWallData
	var level_node: Level = get_tree().get_first_node_in_group(Level.GROUP) as Level
	if stats == null or stats.block_scene == null or level_node == null or level_node.grid == null:
		return
	var tile: float = float(level_node.theme.tile_size)
	var center: Vector2 = caster.global_position + direction * stats.distance
	var across: Vector2 = direction.orthogonal()
	var count: int = SpellData.int_at(stats.blocks, level)
	var duration: float = SpellData.float_at(stats.duration, level)
	var used: Dictionary = {}
	for i in count:
		var cell: Vector2i = level_node.cell_at(center + across * (i - (count - 1) * 0.5) * tile)
		if used.has(cell) or level_node.grid.get_cell(cell) != LevelGrid.Cell.FLOOR:
			continue
		used[cell] = true
		var at: Vector2 = level_node.cell_center(cell)
		if _is_occupied(at, tile):
			continue
		var block: IceBlock = stats.block_scene.instantiate() as IceBlock
		block.lifetime = duration
		block.color = stats.color
		_effect_parent().add_child(block)
		block.global_position = at


## True if a body (the player, an enemy) overlaps the tile at this point.
func _is_occupied(at: Vector2, tile: float) -> bool:
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(tile, tile)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = rect
	query.transform = Transform2D(0.0, at)
	query.collision_mask = body_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
