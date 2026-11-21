class_name LightningBolt
extends Node2D
## Visual only (stage 40): a bolt through a list of world points that flashes and
## fades, then frees itself. With art: the bolt animation stretched and turned between
## each two points and a flash where it lands; without: a jagged line drawn in code.

## Pixels between two kinks of the bolt and how far a kink strays sideways.
const KINK_STEP: float = 8.0
const KINK_SPREAD: float = 3.0

var color: Color = Color(0.75, 0.85, 1.0)
var lifetime: float = 0.2
var width: float = 2.0

var _points: PackedVector2Array = PackedVector2Array()
var _age: float = 0.0


## A bolt through world points, added to parent. The kinks of the drawn bolt are fixed
## when it is made (a fixed pattern, so no random stream is touched). With frames and a
## bolt animation the art is used instead; hit_animation flashes at every point but
## the first.
static func spawn(parent: Node, points: PackedVector2Array, bolt_color: Color, seconds: float,
		frames: SpriteFrames = null, bolt_animation: StringName = &"", hit_animation: StringName = &"") -> LightningBolt:
	var bolt: LightningBolt = LightningBolt.new()
	bolt.color = bolt_color
	bolt.lifetime = seconds
	bolt.z_index = 1
	parent.add_child(bolt)
	bolt.global_position = Vector2.ZERO
	if frames != null and bolt_animation != &"" and frames.has_animation(bolt_animation):
		bolt._add_art(points, frames, bolt_animation, hit_animation)
		return bolt
	for i in points.size() - 1:
		var from: Vector2 = bolt.to_local(points[i])
		var to: Vector2 = bolt.to_local(points[i + 1])
		var steps: int = maxi(1, int(from.distance_to(to) / KINK_STEP))
		var side: Vector2 = from.direction_to(to).orthogonal()
		for step in steps:
			var t: float = float(step) / steps
			var sway: float = 0.0 if step == 0 else KINK_SPREAD * (1.0 if step % 2 == 0 else -1.0)
			bolt._points.append(from.lerp(to, t) + side * sway)
		if i == points.size() - 2:
			bolt._points.append(to)
	return bolt


## One stretched bolt per segment (its art goes from the middle of the left edge to the
## middle of the right edge) and a flash at every point it reaches.
func _add_art(points: PackedVector2Array, frames: SpriteFrames, bolt_animation: StringName,
		hit_animation: StringName) -> void:
	var size: Vector2 = SpellData.frame_size(frames, bolt_animation)
	var pass_time: float = float(frames.get_frame_count(bolt_animation)) / maxf(frames.get_animation_speed(bolt_animation), 1.0)
	for i in points.size() - 1:
		var from: Vector2 = to_local(points[i])
		var to: Vector2 = to_local(points[i + 1])
		var segment: AnimatedSprite2D = AnimatedSprite2D.new()
		segment.sprite_frames = frames
		segment.offset = Vector2(size.x * 0.5, 0.0)
		segment.position = from
		segment.rotation = from.angle_to_point(to)
		segment.scale = Vector2(from.distance_to(to) / maxf(size.x, 1.0), 1.0)
		segment.speed_scale = pass_time / maxf(lifetime, 0.01)
		add_child(segment)
		segment.play(bolt_animation)
		if hit_animation != &"" and frames.has_animation(hit_animation):
			EffectSprite.spawn(get_parent(), points[i + 1], frames, hit_animation)


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		set_process(false)
		return
	queue_redraw()


func _draw() -> void:
	if _points.size() < 2 or get_child_count() > 0:
		return
	var fade: float = 1.0 - _age / maxf(lifetime, 0.001)
	draw_polyline(_points, Color(color, fade), width + 2.0)
	draw_polyline(_points, Color(1.0, 1.0, 1.0, fade), width * 0.5)
