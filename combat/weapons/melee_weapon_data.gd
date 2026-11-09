class_name MeleeWeaponData
extends WeaponData
## Parameters of a melee weapon such as the sword: a combo of attack steps.
## The behaviour lives in MeleeWeapon.

## Steps of the combo in order. A single step makes a weapon without a combo.
@export var combo: Array[MeleeAttackStep] = []
## After a step is over, a press within this many seconds continues the combo;
## a later press starts again from the first step.
@export var combo_window: float = 0.4
## Extra pause after the last step of the combo, in seconds.
@export var combo_end_cooldown: float = 0.3
## A press while the weapon is busy is remembered (only one) if it comes within
## this many seconds before the next step can start. Earlier presses are ignored.
@export var buffer_window: float = 0.2
