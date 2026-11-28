class_name FieldPattern
extends BossPattern
## A field of floor cells around the boss (stage 50): half of them light up (stripes, a
## chequerboard or rings round the boss), then burst; the dark ones are safe. With
## several waves the next one lights the other half as the first bursts, so the player
## steps into the cells that have just burst.

enum Layout { STRIPES, CHECKER, RINGS }

@export var layout: Layout = Layout.CHECKER
## STRIPES and CHECKER: the width of a stripe or a square, in tiles.
@export var block_tiles: int = 2
## RINGS: the width of a ring, in pixels.
@export var ring_width: float = 32.0
## Cells farther from the boss than this (pixels) stay dark.
@export var area_radius: float = 170.0
@export var waves: int = 2
## Under the warning art, each lit cell is also filled with warn_color (art that is
## faint on its floor, like the sand ripple on sand).
@export var fill_warning: bool = false
@export_group("Burst")
## Seconds a burst hurts after the strike, and how long its art plays.
@export var active_time: float = 0.15
@export var burst_time: float = 0.4


func cast(host: Node, origin: Vector2, _target: Vector2, caster: Node, source_id: StringName,
		damage_scale: float, target_mask: int, rng: RandomNumberGenerator) -> Array[BossHazard]:
	var level: Level = host.get_tree().get_first_node_in_group(Level.GROUP) as Level if host.is_inside_tree() else null
	if level == null or level.grid == null:
		return []
	var parity: int = rng.randi() % 2
	var along_x: bool = rng.randf() < 0.5
	var field: FieldHazard = FieldHazard.new()
	field.setup(self, scaled_damage(damage_scale), caster, source_id, target_mask)
	field.active_time = active_time
	field.burst_time = burst_time
	var center: Vector2i = level.cell_at(origin)
	var tile: float = float(level.theme.tile_size)
	var span: int = ceili(area_radius / tile)
	for wave in maxi(waves, 1):
		var lit: Array[Vector2i] = []
		for y in range(center.y - span, center.y + span + 1):
			for x in range(center.x - span, center.x + span + 1):
				var cell: Vector2i = Vector2i(x, y)
				if not level.grid.is_walkable(cell) or level.cell_center(cell).distance_to(origin) > area_radius:
					continue
				if is_lit(cell, center, level.cell_center(cell).distance_to(origin), (parity + wave) % 2, along_x):
					lit.append(cell)
		field.add_wave(lit)
	Sound.play_at(warn_sound, origin)
	BossHazard.place(field, host, origin)
	field.set_cells_from(level)
	return [field]


## True if a floor cell lights up with this parity (0 or 1).
func is_lit(cell: Vector2i, center: Vector2i, distance: float, parity: int, along_x: bool) -> bool:
	var block: int = maxi(block_tiles, 1)
	var bx: int = floori(float(cell.x - center.x) / block)
	var by: int = floori(float(cell.y - center.y) / block)
	match layout:
		Layout.STRIPES:
			return posmod((bx if along_x else by) + parity, 2) == 0
		Layout.RINGS:
			return posmod(floori(distance / maxf(ring_width, 1.0)) + parity, 2) == 0
	return posmod(bx + by + parity, 2) == 0


func get_duration() -> float:
	return warn_time * maxi(waves, 1) + active_time
