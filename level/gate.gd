class_name Gate
extends Area2D
## The exit of a section (stage 42): a rectangular stone portal, two cells wide. It stands
## dark until open() is called (when every enemy of the section is dead); then its runes
## light up and its light loops, and it reports the player stepping in. close() makes
## it dark again while a combat room around it is sealed.
## After a boss (rises = true) it is not there at first: only purple cracks in the floor.
## When it opens it rises smoothly out of the floor with dust, then lights up.
## All frames come from one strip (portal_rise.png): 0 cracks, 1 the slot glows, 5 the
## frame standing dark, 6-7 the runes lighting up; then the loop (portal_loop.png).

## Emitted when the player enters the open gate.
signal entered(player: Player)

@export var sprite: Sprite2D
## The strip of the portal's states and the size of one frame.
@export var frames_texture: Texture2D = preload("res://assets/art/level/portal_rise.png")
@export var frame_size: Vector2 = Vector2(32.0, 48.0)
@export var crack_frame: int = 0
@export var slot_frame: int = 1
@export var dark_frame: int = 5
@export var light_frames: Array[int] = [6, 7]
@export var light_fps: float = 10.0
## The open loop.
@export var loop_texture: Texture2D = preload("res://assets/art/level/portal_loop.png")
@export var loop_frames: int = 4
@export var loop_fps: float = 8.0
## Rows of the picture below the ground line (its shadow), so the frame stands on the floor.
@export var ground_rows: float = 2.0
## Rising out of the floor: seconds, how far it shakes sideways, dust while it rises.
@export var rise_time: float = 1.6
@export var rise_shake: float = 1.0
@export var dust: Texture2D = preload("res://assets/art/fx/dust_puff.png")
@export var dust_frames: int = 4
@export var dust_every: float = 0.3
## Burst of light when the portal opens (a strip played once over it), or null.
@export var open_burst: Texture2D = preload("res://assets/art/fx/portal_open.png")
@export var open_burst_frames: int = 5
@export var open_burst_fps: float = 12.0
## Physics layers of the bodies that can use the gate (player).
@export_flags_2d_physics var traveller_mask: int = 2

## Set by the game before the gate enters the tree: the boss portal that rises.
var rises: bool = false
var is_open: bool = false
## Cracks left under the rising portal.
var _slot: Sprite2D = null
var _rise_left: float = -1.0
var _dust_left: float = 0.0
var _light_step: int = -1
var _light_time: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = traveller_mask
	body_entered.connect(_on_body_entered)
	_show_frame(crack_frame if rises else dark_frame)


func is_rising() -> bool:
	return _rise_left >= 0.0


func open() -> void:
	if is_open:
		return
	is_open = true
	if rises:
		_start_rise()
	else:
		_start_light()
	# The player may already be standing in the gate when the last enemy dies.
	for body: Node2D in get_overlapping_bodies():
		_on_body_entered(body)


## Goes dark again (an open gate inside a combat room that has just sealed): no light,
## no travel until open() is called again, which lights it up at once (no rising).
func close() -> void:
	if not is_open:
		return
	is_open = false
	rises = false
	_rise_left = -1.0
	_light_step = -1
	if _slot != null:
		_slot.queue_free()
		_slot = null
	var loop: Node = get_node_or_null(^"Loop")
	if loop != null:
		remove_child(loop)
		loop.queue_free()
	sprite.visible = true
	_show_frame(dark_frame)


func _process(delta: float) -> void:
	if is_rising():
		_update_rise(delta)
	elif _light_step >= 0:
		_light_time += delta
		var step: int = int(_light_time * light_fps)
		if step >= light_frames.size():
			_light_step = -1
			_show_loop()
		elif step != _light_step:
			_light_step = step
			_show_frame(light_frames[step])


## The portal grows out of the floor: the visible part of the dark frame is its top,
## standing on the ground line, taller every frame (eased), over the glowing slot.
func _start_rise() -> void:
	_slot = Sprite2D.new()
	_slot.name = "Slot"
	_slot.texture = frames_texture
	_slot.region_enabled = true
	_slot.region_rect = Rect2(Vector2(slot_frame * frame_size.x, 0.0), frame_size)
	_slot.offset = sprite.offset
	_slot.show_behind_parent = true
	add_child(_slot)
	_rise_left = rise_time
	_dust_left = 0.0
	_update_rise(0.0)


func _update_rise(delta: float) -> void:
	_rise_left -= delta
	var t: float = clampf(1.0 - _rise_left / maxf(rise_time, 0.001), 0.0, 1.0)
	var shown: float = roundf(frame_size.y * ease(t, -2.0))
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2(dark_frame * frame_size.x, 0.0), Vector2(frame_size.x, maxf(shown, 1.0)))
	# The bottom of the visible part stays on the ground line.
	sprite.offset = Vector2(roundf(sin(t * 40.0) * rise_shake * (1.0 - t)), _ground_y() - shown * 0.5)
	_dust_left -= delta
	if _dust_left <= 0.0 and t < 1.0:
		_dust_left = dust_every
		StripSprite.spawn(get_parent(), global_position + Vector2(0.0, 6.0), dust, dust_frames)
	if _rise_left <= 0.0:
		_rise_left = -1.0
		if _slot != null:
			_slot.queue_free()
			_slot = null
		_start_light()


func _start_light() -> void:
	_light_step = 0
	_light_time = 0.0
	_show_frame(light_frames[0] if not light_frames.is_empty() else dark_frame)
	_play_burst()


## One frame of the strip, standing on the floor.
func _show_frame(index: int) -> void:
	if sprite == null:
		return
	sprite.texture = frames_texture
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2(index * frame_size.x, 0.0), frame_size)
	sprite.offset = Vector2(0.0, _ground_y() - frame_size.y * 0.5)


func _show_loop() -> void:
	var strip: StripSprite = StripSprite.new()
	strip.name = "Loop"
	strip.texture = loop_texture
	strip.hframes = maxi(loop_frames, 1)
	strip.fps = loop_fps
	strip.offset = Vector2(0.0, _ground_y() - frame_size.y * 0.5)
	add_child(strip)
	sprite.visible = false


## The ground line, from the node's centre (the middle of its cell): the cell's bottom,
## minus the shadow rows under the frame.
func _ground_y() -> float:
	return 8.0 + ground_rows


## The burst of light over the gate as it opens (visual only, frees itself).
func _play_burst() -> void:
	if open_burst == null:
		return
	var burst: StripSprite = StripSprite.new()
	burst.texture = open_burst
	burst.hframes = maxi(open_burst_frames, 1)
	burst.fps = open_burst_fps
	burst.looping = false
	burst.free_when_done = true
	burst.offset = Vector2(0.0, _ground_y() - frame_size.y * 0.5)
	add_child(burst)


func _on_body_entered(body: Node2D) -> void:
	var player: Player = body as Player
	if is_open and player != null:
		entered.emit(player)
