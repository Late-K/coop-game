class_name CrackedGlass
extends Control
## The Visitor's handheld, cracked (Chapter 1's opening): a split across the screen from
## one impact, two dead columns of the display, a stuck line, and a corner below the impact
## that flickers in and out. Drawn over the interface and under the CRT glass, so it curves
## and scanlines with everything else. Same cracks every time (fixed seed).

const SEED := 4113
const RAYS := 7
## Where it was hit, as a fraction of the screen.
const IMPACT := Vector2(0.77, 0.7)
const FLICKER_RATE := 12.0

var _cracks: Array[PackedVector2Array] = []
var _rings: Array[PackedVector2Array] = []
var _corner := PackedVector2Array()
var _rng := RandomNumberGenerator.new()
var _flicker_time := 0.0
var _corner_on := true


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(_shape)
	_shape()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_flicker_time -= delta
	if _flicker_time <= 0.0:
		_flicker_time = 1.0 / FLICKER_RATE
		# Mostly dead, now and then it catches.
		_corner_on = _rng.randf() < 0.25
		queue_redraw()


## Lays out the cracks for this size: jagged rays from the impact to the edges (some
## branching), short rings between them near the impact, and the dead corner.
func _shape() -> void:
	var shape_rng := RandomNumberGenerator.new()
	shape_rng.seed = SEED
	_cracks.clear()
	_rings.clear()
	var impact := IMPACT * size
	var reach := size.length()
	var angles: Array[float] = []
	for i in RAYS:
		angles.append(TAU * i / RAYS + shape_rng.randf_range(-0.3, 0.3))
	for angle in angles:
		var length := reach * shape_rng.randf_range(0.35, 0.9)
		var ray := _jagged(impact, angle, length, shape_rng)
		_cracks.append(ray)
		if shape_rng.randf() < 0.6:
			var from := ray[shape_rng.randi_range(2, ray.size() - 2)]
			_cracks.append(_jagged(from, angle + shape_rng.randf_range(-0.9, 0.9), length * 0.35, shape_rng))
	for ring_radius in [26.0, 58.0]:
		for i in angles.size():
			if shape_rng.randf() < 0.65:
				var a0: float = angles[i]
				var a1: float = angles[(i + 1) % angles.size()] + (TAU if i == angles.size() - 1 else 0.0)
				var r: float = ring_radius * shape_rng.randf_range(0.8, 1.3)
				_rings.append(PackedVector2Array([impact + Vector2.from_angle(a0) * r,
						impact + Vector2.from_angle((a0 + a1) / 2.0) * r * 1.1, impact + Vector2.from_angle(a1) * r]))
	# The corner below and right of the impact, cut off along a crack.
	_corner = PackedVector2Array([Vector2(size.x * 0.86, size.y), Vector2(size.x, size.y * 0.79), size])
	queue_redraw()


func _jagged(from: Vector2, angle: float, length: float, shape_rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array([from])
	var at := from
	var steps := maxi(4, int(length / 40.0))
	for i in steps:
		var heading := angle + shape_rng.randf_range(-0.35, 0.35)
		at += Vector2.from_angle(heading) * length / steps
		points.append(at)
	return points


func _draw() -> void:
	var light := UiStyle.accent.lerp(Color.WHITE, 0.55)
	light.a = 0.55
	var shadow := Color(0, 0, 0, 0.7)
	# Dead columns and a stuck line: the display behind the glass is damaged too.
	for column in [0.312, 0.318]:
		draw_rect(Rect2(size.x * column, 0, 3, size.y), Color(0, 0, 0, 0.85))
	var stuck := UiStyle.dim
	stuck.a = 0.8
	draw_rect(Rect2(0, size.y * 0.573, size.x, 2), stuck)
	# The corner: mostly black, catching now and then as a smear of the accent colour.
	draw_colored_polygon(_corner, Color(UiStyle.accent, 0.35) if _corner_on else Color(0, 0, 0, 0.92))
	for crack in _cracks:
		draw_polyline(_offset(crack, Vector2(1, 1)), shadow, 2.0)
		draw_polyline(crack, light, 1.0)
	for ring in _rings:
		draw_polyline(ring, light, 1.0)
	draw_circle(IMPACT * size, 5.0, light)


func _offset(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var moved := PackedVector2Array()
	for p in points:
		moved.append(p + by)
	return moved
