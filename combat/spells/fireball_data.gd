class_name FireballData
extends SpellData
## Fireball: flies straight and explodes on the first enemy or wall, or at the end of
## its range, hurting every enemy in the blast that is not behind a wall.

## Damage of the blast at levels 1, 2, 3.
@export var damage: PackedInt32Array = PackedInt32Array([20, 28, 36])
## Blast radius in pixels at levels 1, 2, 3.
@export var radius: PackedFloat32Array = PackedFloat32Array([24.0, 30.0, 36.0])
## Flight speed in pixels per second and range in pixels.
@export var speed: float = 220.0
@export var max_range: float = 200.0
## Push away from the centre of the blast, pixels per second.
@export var knockback: float = 150.0
## The flying ball (root node is a Fireball).
@export var projectile_scene: PackedScene
