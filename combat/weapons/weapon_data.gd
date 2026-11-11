class_name WeaponData
extends Resource
## Data shared by every weapon. A concrete weapon is a .tres file of a subclass
## (for example MeleeWeaponData), so a new weapon needs no new code.

## Stable id used in logs and telemetry, e.g. &"sword".
@export var id: StringName = &""
@export var display_name: String = ""
## Small picture for the HUD and the menu.
@export var icon: Texture2D
## The wielder aims at the nearest visible enemy within this distance, in pixels.
## 0 turns auto-aim off.
@export var auto_aim_radius: float = 56.0
## Scene with the weapon behaviour (root node is a Weapon), created when the weapon is equipped.
@export var weapon_scene: PackedScene
