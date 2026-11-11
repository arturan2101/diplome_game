class_name TestFactory
extends RefCounted
## Builders of small actors for headless tests, so tests do not depend on .tscn files.
## Every function returns a node that is not in the tree yet.

## Physics layer bits, same as the project layer names.
const WORLD_LAYER: int = 1
const PLAYER_LAYER: int = 2
const ENEMY_LAYER: int = 4
const PLAYER_HURTBOX_LAYER: int = 8
const ENEMY_HURTBOX_LAYER: int = 16


static func pack(node: Node) -> PackedScene:
	var scene: PackedScene = PackedScene.new()
	scene.pack(node)
	node.free()
	return scene


static func circle_shape(radius: float) -> CollisionShape2D:
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	return shape


static func hazard_data() -> HazardData:
	return HazardData.new()


## Data of a melee enemy that hits the player hurtbox layer.
static func melee_enemy_data(id: StringName, damage: int = 10) -> EnemyData:
	var step: MeleeAttackStep = MeleeAttackStep.new()
	step.damage = damage
	step.reach = 24.0
	step.arc_degrees = 120.0
	step.duration = 0.1
	step.recovery = 0.0
	var weapon_data: MeleeWeaponData = MeleeWeaponData.new()
	weapon_data.id = &"test_blade"
	weapon_data.combo = [step] as Array[MeleeAttackStep]
	var weapon_template: MeleeWeapon = MeleeWeapon.new()
	weapon_template.target_mask = PLAYER_HURTBOX_LAYER
	weapon_data.weapon_scene = pack(weapon_template)
	var data: EnemyData = EnemyData.new()
	data.id = id
	data.max_hp = 30
	data.move_speed = 120.0
	data.detection_range = 400.0
	data.attack_range = 18.0
	data.windup = 0.4
	data.recovery = 0.5
	data.weapon = weapon_data
	return data


## An enemy with health, hurtbox, a visual and (optionally) a hazard receiver.
static func enemy(data: EnemyData, with_hazards: bool = false) -> Enemy:
	var new_enemy: Enemy = Enemy.new()
	new_enemy.data = data
	new_enemy.collision_layer = ENEMY_LAYER
	new_enemy.collision_mask = WORLD_LAYER
	new_enemy.add_child(circle_shape(6.0))
	var health: Health = Health.new()
	new_enemy.add_child(health)
	new_enemy.health = health
	var hurtbox: Hurtbox = Hurtbox.new()
	hurtbox.collision_layer = ENEMY_HURTBOX_LAYER
	hurtbox.collision_mask = 0
	hurtbox.add_child(circle_shape(7.0))
	hurtbox.health = health
	new_enemy.add_child(hurtbox)
	new_enemy.hurtbox = hurtbox
	var visual: Node2D = Node2D.new()
	new_enemy.add_child(visual)
	new_enemy.visual = visual
	if with_hazards:
		var hazards: HazardReceiver = HazardReceiver.new()
		hazards.body = new_enemy
		hazards.health = health
		hazards.visual = visual
		hazards.data = hazard_data()
		new_enemy.add_child(hazards)
		new_enemy.hazards = hazards
	return new_enemy


## A stand-in for the player: a node in the player group with Health and a Hurtbox
## (children named "Health" and "Hurtbox").
static func player_target(max_hp: int = 100, invulnerability_time: float = 0.0) -> Node2D:
	var target: Node2D = Node2D.new()
	target.add_to_group(Player.GROUP)
	var health: Health = Health.new()
	health.name = "Health"
	health.max_hp = max_hp
	health.invulnerability_time = invulnerability_time
	target.add_child(health)
	var hurtbox: Hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = PLAYER_HURTBOX_LAYER
	hurtbox.collision_mask = 0
	hurtbox.add_child(circle_shape(6.0))
	hurtbox.health = health
	target.add_child(hurtbox)
	return target


## A body with Health and a HazardReceiver (children "Health" and "HazardReceiver").
static func hazard_body(max_hp: int = 100, invulnerability_time: float = 0.0) -> CharacterBody2D:
	var body: CharacterBody2D = CharacterBody2D.new()
	body.collision_layer = 0
	body.collision_mask = 0
	var health: Health = Health.new()
	health.name = "Health"
	health.max_hp = max_hp
	health.invulnerability_time = invulnerability_time
	body.add_child(health)
	var hazards: HazardReceiver = HazardReceiver.new()
	hazards.name = "HazardReceiver"
	hazards.body = body
	hazards.health = health
	hazards.data = hazard_data()
	body.add_child(hazards)
	return body
