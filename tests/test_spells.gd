extends TestCase
## Headless test for spells: numbers by level, the spell pool, the spell book (learn,
## level up, full slots, replace, cooldown), the three effects (fireball blast,
## whirlwind ticks, ice wall blocks), the scroll and the shrine, the choice screen,
## shrines in plans and sections, and spell uses and damage in the log.

const FIREBALL: String = "res://combat/spells/fireball.tres"
const ICE_WALL: String = "res://combat/spells/ice_wall.tres"
const WHIRLWIND: String = "res://combat/spells/whirlwind.tres"
const POOL: String = "res://combat/spells/spell_pool.tres"
const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const SHRINE_SCENE: String = "res://actors/pickups/shrine.tscn"
const SCROLL_SCENE: String = "res://actors/pickups/spell_pickup.tscn"
const CHOICE_SCENE: String = "res://ui/spell_choice.tscn"
const ENEMY_HURTBOX_LAYER: int = 16
const WORLD_LAYER: int = 1
const ENEMY_BODY_LAYER: int = 4
const TARGET_HP: int = 1000
const TARGET_RADIUS: float = 8.0
const PLANS: int = 1000
const RUN_SEED: int = 31
## Open floor with one pit ('~' at cell 5,5) for the ice wall.
const FLOOR_MAP: String = """###########
#.........#
#.........#
#.........#
#.........#
#....~....#
#.........#
#.........#
###########"""

var _fireball: SpellData = null
var _ice_wall: SpellData = null
var _whirlwind: SpellData = null


func run() -> void:
	_fireball = load(FIREBALL) as SpellData
	_ice_wall = load(ICE_WALL) as SpellData
	_whirlwind = load(WHIRLWIND) as SpellData
	_test_data()
	await _test_book()
	await _test_fireball()
	await _test_whirlwind()
	await _test_ice_wall()
	await _test_scroll_and_shrine()
	await _test_choice_screen()
	_test_plans_and_sections()
	await _test_log()


func _test_data() -> void:
	var fireball: FireballData = _fireball as FireballData
	var damage: Array[int] = []
	for level in range(1, SpellData.MAX_LEVEL + 1):
		damage.append(SpellData.int_at(fireball.damage, level))
	check(damage[0] < damage[1] and damage[1] < damage[2] and fireball.cooldown_at(3) < fireball.cooldown_at(1),
			"a higher level hits harder (%s) and cools down faster" % [damage])
	check(SpellData.int_at(fireball.damage, 7) == damage[2], "levels past the table use the top level")
	var pool: SpellPool = load(POOL) as SpellPool
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var offer: Array[SpellData] = pool.offer(3, rng)
	var ids: Dictionary = {}
	for spell_data: SpellData in offer:
		ids[spell_data.id] = true
	check(offer.size() == 3 and ids.size() == 3 and pool.offer(5, rng).size() == 3,
			"a shrine offers three different spells, never more than the pool has")


func _test_book() -> void:
	var player: Player = _add_player(Vector2(100.0, 400.0))
	await physics_frames(2)
	var book: SpellBook = player.spell_book
	var learned: Array[int] = []
	book.spell_learned.connect(func(_data: SpellData, level: int) -> void: learned.append(level))
	check(book != null and book.get_spell(0) == null and book.has_free_slot(), "the player starts with two empty spell slots")
	check(book.learn(_fireball) == SpellBook.LearnResult.LEARNED and book.level_of(&"fireball") == 1,
			"a new spell goes into a free slot at level 1")
	check(book.learn(_fireball) == SpellBook.LearnResult.LEVELED_UP and book.learn(_fireball) == SpellBook.LearnResult.LEVELED_UP
			and book.level_of(&"fireball") == 3, "learning it again raises the level up to 3")
	check(book.learn(_fireball) == SpellBook.LearnResult.MAX_LEVEL and book.level_of(&"fireball") == 3,
			"past level 3 nothing changes")
	check(book.learn(_ice_wall) == SpellBook.LearnResult.LEARNED and book.get_spell(1).data == _ice_wall,
			"a second spell takes the second slot")
	check(book.learn(_whirlwind) == SpellBook.LearnResult.SLOTS_FULL and book.level_of(&"whirlwind") == 0,
			"a third spell does not fit while both slots are full")
	book.replace(0, _whirlwind)
	await physics_frames(1)
	check(book.level_of(&"fireball") == 0 and book.get_spell(0).data == _whirlwind and book.get_spell(0).level == 1
			and book.to_dictionary() == {&"whirlwind": 1, &"ice_wall": 1}, "replace forgets the old spell for a new one")
	check(learned == ([1, 2, 3, 1, 1] as Array[int]), "spell_learned reports every new spell and level-up")
	check(book.cast(0) and not book.cast(0) and is_equal_approx(book.get_spell(0).get_cooldown_fraction(), 1.0),
			"after a cast the spell cools down")
	player.queue_free()
	await physics_frames(2)


## A fireball flies right, hits the first target and explodes: the target next to it
## is hurt too, the one behind a wall is not.
func _test_fireball() -> void:
	var player: Player = _add_player(Vector2(100.0, 100.0))
	var near: Hurtbox = _add_target(Vector2(160.0, 100.0))
	var beside: Hurtbox = _add_target(Vector2(150.0, 118.0))
	var walled: Hurtbox = _add_target(Vector2(130.0, 85.0))
	var wall: StaticBody2D = _add_wall(Vector2(139.0, 90.0), Vector2(4.0, 12.0))
	var knockbacks: Array[Vector2] = []
	beside.hit_received.connect(func(info: DamageInfo) -> void: knockbacks.append(info.knockback))
	await physics_frames(2)
	player.spell_book.learn(_fireball)
	var reported: Array[int] = [0]
	player.spell_book.spell_damage_dealt.connect(func(_id: StringName, amount: int) -> void: reported[0] += amount)
	var damage: int = SpellData.int_at((_fireball as FireballData).damage, 1)
	check(player.spell_book.get_spell(0).try_cast(Vector2.RIGHT), "the fireball is cast")
	await physics_frames(30)
	check(_damage_taken(near) == damage and _damage_taken(beside) == damage,
			"the blast hurts the target it hit and the one beside it (%d each)" % damage)
	check(_damage_taken(walled) == 0, "a target behind a wall is safe from the blast")
	check(knockbacks.size() == 1 and knockbacks[0].y > 0.0, "the blast pushes targets away from its centre")
	check(reported[0] == damage * 2, "the spell reports the blast damage (%d)" % reported[0])
	for node: Node in [player, near, beside, walled, wall]:
		node.queue_free()
	await physics_frames(2)


func _test_whirlwind() -> void:
	var player: Player = _add_player(Vector2(300.0, 300.0))
	var target: Hurtbox = _add_target(Vector2(320.0, 300.0))
	var far: Hurtbox = _add_target(Vector2(380.0, 300.0))
	await physics_frames(2)
	player.spell_book.learn(_whirlwind)
	var spell: WhirlwindSpell = player.spell_book.get_spell(0) as WhirlwindSpell
	spell.try_cast(Vector2.RIGHT)
	await physics_frames(30)
	var tick: int = SpellData.int_at((_whirlwind as WhirlwindData).damage, 1)
	check(spell.is_active() and _damage_taken(target) >= 2 * tick, "the wind hurts a target inside it every tick")
	await physics_frames(150)
	var total: int = _damage_taken(target)
	check(not spell.is_active() and total >= 7 * tick and total <= 9 * tick,
			"it lasts its duration: %d damage, about 8 ticks of %d" % [total, tick])
	check(_damage_taken(far) == 0, "a target outside the radius is not touched")
	await physics_frames(30)
	check(_damage_taken(target) == total, "after the wind is gone nothing more happens")
	for node: Node in [player, target, far]:
		node.queue_free()
	await physics_frames(2)


## Level 3 ice wall: five tiles across the aim; the pit tile and the tile where an enemy
## stands are skipped; the blocks stop rays on the world layer and melt later.
func _test_ice_wall() -> void:
	var level: Level = Level.new()
	level.debug_map = FLOOR_MAP
	add_child(level)
	var player: Player = _add_player(level.cell_center(Vector2i(3, 4)))
	var standing: CharacterBody2D = CharacterBody2D.new()
	standing.collision_layer = ENEMY_BODY_LAYER
	standing.collision_mask = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	standing.add_child(shape)
	add_child(standing)
	standing.global_position = level.cell_center(Vector2i(5, 3))
	await physics_frames(2)
	for _i in SpellData.MAX_LEVEL:
		player.spell_book.learn(_ice_wall)
	check(player.spell_book.get_spell(0).try_cast(Vector2.RIGHT), "the ice wall is cast")
	await physics_frames(2)
	var cells: Array[Vector2i] = []
	for child: Node in level.get_children():
		if child is IceBlock:
			cells.append(level.cell_at((child as IceBlock).global_position))
	cells.sort()
	check(cells == ([Vector2i(5, 2), Vector2i(5, 4), Vector2i(5, 6)] as Array[Vector2i]),
			"blocks stand on free floor across the aim; the pit and the enemy's tile are skipped: %s" % [cells])
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			level.cell_center(Vector2i(8, 4)), level.cell_center(Vector2i(3, 4)), WORLD_LAYER)
	var hit: Dictionary = player.get_world_2d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and hit["collider"] is IceBlock, "the ice stops anything that walls stop (arrows, enemies)")
	var duration: float = SpellData.float_at((_ice_wall as IceWallData).duration, 3)
	await physics_frames(ceili(duration * Engine.physics_ticks_per_second) + 10)
	var left: int = 0
	for child: Node in level.get_children():
		if child is IceBlock:
			left += 1
	check(left == 0, "the ice melts after %.0f s" % duration)
	for node: Node in [player, standing, level]:
		node.queue_free()
	await physics_frames(2)


func _test_scroll_and_shrine() -> void:
	var player: Player = _add_player(Vector2(500.0, 100.0))
	await physics_frames(2)
	var scroll: SpellPickup = _add_scroll(_fireball, player.position + Vector2(12.0, 0.0))
	await physics_frames(2)
	check(player.interaction_target == scroll and scroll.get_prompt().contains("Fireball"),
			"standing next to a scroll, its hint names the spell")
	check(scroll.interact(player) and player.spell_book.level_of(&"fireball") == 1 and scroll.is_queued_for_deletion(),
			"taking a scroll teaches the spell and uses the scroll up")
	await physics_frames(1)
	player.spell_book.learn(_ice_wall)
	var full: SpellPickup = _add_scroll(_whirlwind, player.position + Vector2(-12.0, 0.0))
	var full_events: Array[SpellPickup] = []
	full.slots_full.connect(func(pickup: SpellPickup) -> void: full_events.append(pickup))
	check(full.interact(player) and full_events == ([full] as Array[SpellPickup]) and not full.is_queued_for_deletion(),
			"with both slots full the scroll asks for a choice and stays")
	full.queue_free()
	player.spell_book.learn(_fireball)
	player.spell_book.learn(_fireball)
	var maxed: SpellPickup = _add_scroll(_fireball, player.position + Vector2(0.0, 12.0))
	check(not maxed.can_interact(player), "a scroll of a spell at the top level cannot be taken")
	maxed.queue_free()

	var shrine: Shrine = (load(SHRINE_SCENE) as PackedScene).instantiate() as Shrine
	add_child(shrine)
	var activations: Array[Shrine] = []
	shrine.activated.connect(func(used: Shrine) -> void: activations.append(used))
	var texture_before: Texture2D = shrine.sprite.texture
	check(shrine.can_interact(player) and shrine.interact(player) and not shrine.interact(player)
			and activations == ([shrine] as Array[Shrine]), "a shrine works once")
	check(not shrine.can_interact(player) and shrine.sprite.texture != texture_before, "a used shrine goes dark")
	for node: Node in [player, shrine]:
		node.queue_free()
	await physics_frames(2)


## The screen pauses the game while open; nothing here awaits frames while paused.
func _test_choice_screen() -> void:
	var player: Player = _add_player(Vector2(600.0, 300.0))
	await physics_frames(2)
	var book: SpellBook = player.spell_book
	var choice: SpellChoice = (load(CHOICE_SCENE) as PackedScene).instantiate() as SpellChoice
	add_child(choice)
	var closed: Array = []
	choice.closed.connect(func(learned: SpellData) -> void: closed.append(learned))
	var offers: Array[SpellData] = [_fireball, _ice_wall, _whirlwind]
	choice.open_offers(offers, book)
	var buttons: Array[Button] = _choice_buttons(choice)
	check(choice.is_open() and get_tree().paused and buttons.size() == 3, "the shrine screen shows three spells and pauses")
	buttons[0].pressed.emit()
	check(not choice.is_open() and not get_tree().paused and book.level_of(&"fireball") == 1 and closed == [_fireball],
			"choosing a spell learns it, closes the screen and resumes")
	book.learn(_ice_wall)
	choice.open_offers(offers, book)
	_choice_buttons(choice)[2].pressed.emit()
	var slots: Array[Button] = _choice_buttons(choice)
	check(choice.is_open() and slots.size() == 2 and choice.title.text.contains("Whirlwind"),
			"a new spell with full slots asks which one to forget")
	slots[1].pressed.emit()
	check(not choice.is_open() and book.level_of(&"ice_wall") == 0 and book.level_of(&"whirlwind") == 1
			and book.level_of(&"fireball") == 1, "the chosen slot gets the new spell")
	choice.open_replace(_ice_wall, book)
	choice.back_button.pressed.emit()
	check(not choice.is_open() and not get_tree().paused and closed.back() == null and book.level_of(&"ice_wall") == 0,
			"Keep my spells closes without changes")
	choice.open_offers(offers, book)
	var escape: InputEventAction = InputEventAction.new()
	escape.action = &"pause"
	escape.pressed = true
	choice._unhandled_input(escape)
	check(not choice.is_open() and not get_tree().paused and closed.back() == null, "Esc skips the choice")
	for node: Node in [player, choice]:
		node.queue_free()
	await physics_frames(2)


func _test_plans_and_sections() -> void:
	var director: RandomDirector = RandomDirector.new()
	var with_shrine: int = 0
	var arena_shrines: int = 0
	for i in PLANS:
		var state: PlayerState = PlayerState.new()
		state.section_index = i
		state.rng.seed = i
		state.is_depth_end = i % 4 == 3
		var plan: SectionPlan = director.choose_next(state)
		if plan.is_arena:
			arena_shrines += plan.shrines
		else:
			with_shrine += plan.shrines
	var share: float = float(with_shrine) / (PLANS * 3 / 4)
	var expected: float = director.settings.shrine_chance
	check(absf(share - expected) < 0.05 and arena_shrines == 0,
			"ordinary sections get a shrine with chance %.2f (%.2f), arenas never" % [expected, share])

	var builder: SectionBuilder = SectionBuilder.new()
	var placed_right: int = 0
	for i in 20:
		var plan: SectionPlan = SectionPlan.new()
		plan.section_index = i
		plan.room_count = 3 + i % 3
		plan.shrines = 1
		plan.enemy_mix = {&"skeleton": 2, &"archer": 1}
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = hash([RUN_SEED, i])
		var layout: SectionLayout = builder.build(plan, rng)
		var shrines: Array[Dictionary] = []
		for entry: Dictionary in layout.items:
			if entry["id"] == SectionLayout.ITEM_SHRINE:
				shrines.append(entry)
		if shrines.size() == 1 and shrines[0]["room"] > 0 and shrines[0]["room"] < layout.path_room_count \
				and SectionBuilder.is_passable(layout):
			placed_right += 1
	check(placed_right == 20, "a planned shrine stands in a room of the path after the first one (%d of 20)" % placed_right)


func _test_log() -> void:
	GameManager.start_run(RUN_SEED)
	var write_was: bool = Telemetry.write_enabled
	Telemetry.write_enabled = false
	var player: Player = _add_player(Vector2(800.0, 300.0))
	var target: Hurtbox = _add_target(Vector2(815.0, 300.0))
	await physics_frames(2)
	var plan: SectionPlan = SectionPlan.new()
	var layout: SectionLayout = SectionLayout.new()
	layout.reference_time = 30.0
	Telemetry.begin_section(plan, layout, player)
	player.spell_book.learn(_whirlwind)
	player.spell_book.cast(0)
	await physics_frames(20)
	var record: Dictionary = Telemetry.end_section(false)
	Telemetry.write_enabled = write_was
	check(record["spell_uses"] == {"whirlwind": 1} and int(record["spell_damage"].get("whirlwind", 0)) == _damage_taken(target)
			and _damage_taken(target) > 0, "the log has spell uses and spell damage: %s, %s" % [record["spell_uses"], record["spell_damage"]])
	check(record["weapon_use"] == {} and record["accuracy"] == 0.0, "spells do not count as weapon attacks")
	for node: Node in [player, target]:
		node.queue_free()
	await physics_frames(2)


func _add_player(at: Vector2) -> Player:
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	add_child(player)
	player.global_position = at
	return player


func _add_scroll(spell_data: SpellData, at: Vector2) -> SpellPickup:
	var scroll: SpellPickup = (load(SCROLL_SCENE) as PackedScene).instantiate() as SpellPickup
	scroll.spell_data = spell_data
	add_child(scroll)
	scroll.global_position = at
	return scroll


func _choice_buttons(choice: SpellChoice) -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in choice.choices.get_children():
		if child is Button and not child.is_queued_for_deletion():
			buttons.append(child)
	return buttons


func _add_target(at: Vector2) -> Hurtbox:
	var hurtbox: Hurtbox = Hurtbox.new()
	hurtbox.position = at
	hurtbox.collision_layer = ENEMY_HURTBOX_LAYER
	hurtbox.collision_mask = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = TARGET_RADIUS
	shape.shape = circle
	hurtbox.add_child(shape)
	var health: Health = Health.new()
	health.max_hp = TARGET_HP
	hurtbox.add_child(health)
	hurtbox.health = health
	add_child(hurtbox)
	return hurtbox


func _add_wall(at: Vector2, size: Vector2) -> StaticBody2D:
	var wall: StaticBody2D = StaticBody2D.new()
	wall.position = at
	wall.collision_layer = WORLD_LAYER
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.add_child(shape)
	add_child(wall)
	return wall


func _damage_taken(hurtbox: Hurtbox) -> int:
	return TARGET_HP - hurtbox.health.hp
