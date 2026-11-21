class_name StripSprite
extends Sprite2D
## Visual only: a Sprite2D whose texture is a horizontal strip of frames (hframes) and
## plays them by itself: in a loop (a spinning coin, a flickering torch, the open
## portal) or once (a chest opening). Used for art that comes as one PNG strip.

## Frames per second.
@export var fps: float = 8.0
@export var looping: bool = true
## Plays from the start; off = stands on `frame` until play_range() is called.
@export var autoplay: bool = true
## Frames of the loop or the one-off run; -1 = the last frame.
@export var first_frame: int = 0
@export var last_frame: int = -1
## A one-off effect (a burst): freed after its last frame.
@export var free_when_done: bool = false

## Emitted when a run that does not loop reaches its last frame.
signal finished

var _playing: bool = false
var _time: float = 0.0


## A one-off effect: plays the strip once at a global position under parent, then frees
## itself (a hit spark, a puff of dust). Returns it, or null without a parent or picture.
static func spawn(parent: Node, at: Vector2, strip: Texture2D, frames: int, frames_per_second: float = 16.0) -> StripSprite:
	if parent == null or strip == null:
		return null
	var effect: StripSprite = StripSprite.new()
	effect.texture = strip
	effect.hframes = maxi(frames, 1)
	effect.fps = frames_per_second
	effect.looping = false
	effect.free_when_done = true
	parent.add_child(effect)
	effect.global_position = at
	return effect


func _ready() -> void:
	if autoplay:
		play_range(first_frame, last_frame, looping)


## Plays frames from..to (to = -1: the last one); looping or stopping on the last.
func play_range(from: int, to: int = -1, loop: bool = false) -> void:
	first_frame = clampi(from, 0, hframes - 1)
	last_frame = to
	looping = loop
	frame = first_frame
	_time = 0.0
	_playing = true


## Shows another picture as a still (one frame), e.g. a used shrine.
func show_still(still: Texture2D) -> void:
	_playing = false
	texture = still
	hframes = 1
	frame = 0


func is_playing() -> bool:
	return _playing


func _process(delta: float) -> void:
	if not _playing or fps <= 0.0:
		return
	_time += delta
	var last: int = hframes - 1 if last_frame < 0 else mini(last_frame, hframes - 1)
	var count: int = last - first_frame + 1
	var step: int = int(_time * fps)
	if looping:
		frame = first_frame + step % maxi(count, 1)
	else:
		frame = mini(first_frame + step, last)
		if first_frame + step > last:
			_playing = false
			finished.emit()
			if free_when_done:
				queue_free()
