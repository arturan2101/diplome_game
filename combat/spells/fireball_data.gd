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
## Sound of the blast (stage 46).
@export var explode_sound: StringName = &""
## Push away from the centre of the blast, pixels per second.
@export var knockback: float = 150.0
## The flying ball (root node is a Fireball).
@export var projectile_scene: PackedScene
## Seconds the blast stays drawn.
@export var blast_time: float = 0.25
## The plasma (stage 40): the ball flies through enemies, hurting each one it passes
## with the full damage, and bursts only at a wall or at the end of its range (the
## burst spares the enemies it already went through).
@export var pierce: bool = false
@export_group("Look")
## The look turns with the flight (a ball with a tail); off for round looks (steam).
@export var rotate_look: bool = true
## Size of the flying look (1 = the art's own size).
@export var look_scale: float = 1.0
## At the blast the look grows to the blast's size and fades out (a cloud of steam);
## off = the look disappears and the blast is drawn as a flash in the spell's colour.
@export var blast_look: bool = false
## Burning ground the ball leaves behind (an animation in frames) from this level on;
## &"" = none. Only a look: it does not hurt.
@export var trail_animation: StringName = &""
@export var trail_min_level: int = 3
## Pixels between two flames of the trail and seconds one flame burns.
@export var trail_spacing: float = 10.0
@export var trail_time: float = 0.5


func power_at(level: int) -> float:
	return float(int_at(damage, level))
