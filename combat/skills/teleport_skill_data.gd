class_name TeleportSkillData
extends SkillData
## Parameters of the short teleport (stage 39): the wielder vanishes and appears a little
## further on, over pits and spikes but never through walls.

## Longest jump, in pixels.
@export var distance: float = 72.0
## Spots are tried from the farthest back towards the wielder in steps of this many pixels.
@export var search_step: float = 4.0
## Radius of the free space the wielder needs at the landing spot, in pixels.
@export var body_radius: float = 6.0
## Seconds of invulnerability from the jump on.
@export var invulnerability: float = 0.25
## Strips played where the wielder leaves and where they appear (once each).
@export var out_effect: Texture2D
@export var in_effect: Texture2D
@export var effect_frames: int = 5
@export var effect_fps: float = 20.0
