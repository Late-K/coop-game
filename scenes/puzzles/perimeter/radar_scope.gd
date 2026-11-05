class_name RadarScope
extends ConsoleScreen
## The radar control room's scope (Chapter 1's opening), used in first person. A sweep turns
## over the snowfield south of the facility; what it passes lights up and fades like old
## phosphor: the marker posts with their symbols, the lit lamps, the entrance to the north,
## and one moving contact: the Visitor, wherever they really are. Under it, the emergency
## contact channel (the ContactBeacon's frequency): a place on the band to meet.
##
## Each machine draws its own from the synced player positions. The contact is only there
## while the Visitor is alive and out on the field; when the entrance doors come down
## (`crush`), it simply goes out, and a while later a new heat signature reads inside.

const SWEEP_PERIOD := 3.2
## Seconds a return takes to fade after the sweep passes it.
const PERSISTENCE := 2.6
const PHOSPHOR := Color(0.45, 1.0, 0.6)
const LIT_COLOR := Color(1.0, 0.75, 0.35)
const SYMBOL_PIXELS := 18.0
## Seconds after the doors come down before the new signature reads inside.
const SIGNATURE_DELAY := 8.0

@export var network: BeaconNetwork
@export var beacon: ContactBeacon
@export var crush: EntranceCrush
## The snowfield on the floor, as (x, z, width, depth): where a contact can be.
@export var field := Rect2(-10, 30, 40, 46)
## The facility entrance (x, z): the top of the scope, where the sweep turns.
@export var entrance := Vector2(10.5, 29)
## Metres from the entrance to the scope's edge.
@export var scope_range := 50.0

var _angle := 0.0
## Where the contact was when the sweep last crossed it (x, z), and when.
var _contact_seen := Vector2.INF
var _contact_time := -100.0
var _time := 0.0
var _had_contact := false


func _ready() -> void:
	prompt = "Use the radar"
	super()


func _process(delta: float) -> void:
	_time += delta
	var before := _angle
	_angle = fmod(_angle + TAU * delta / SWEEP_PERIOD, TAU)
	var contact := _contact()
	if contact != Vector2.INF and _swept(before, _angle, _bearing(contact)):
		_contact_seen = contact
		_contact_time = _time
		if has_local_focus or _near_local_player():
			Sound.play_at("radar_ping", global_position + Vector3.UP * 1.3, -6.0, 8.0, 0.0)
	if contact == Vector2.INF and _had_contact and _time - _contact_time > PERSISTENCE:
		_contact_seen = Vector2.INF
	_had_contact = contact != Vector2.INF
	canvas.queue_redraw()


## The Visitor's position on the field (x, z), or INF when there's nothing out there.
func _contact() -> Vector2:
	for player: Player in get_tree().get_nodes_in_group("players"):
		if player.role == Session.Role.VISITOR and player.health > 0 and not player.is_dead:
			var at := Vector2(player.global_position.x, player.global_position.z)
			if field.has_point(at):
				return at
	return Vector2.INF


func _near_local_player() -> bool:
	for player: Player in get_tree().get_nodes_in_group("players"):
		if player.is_multiplayer_authority():
			return player.global_position.distance_to(global_position) < 6.0
	return false


## Bearing of a floor point from the entrance, as the sweep measures it (0 = south, turning
## clockwise as seen on the scope).
func _bearing(point: Vector2) -> float:
	var offset := point - entrance
	return fposmod(atan2(-offset.x, offset.y), TAU)


func _swept(from: float, to: float, bearing: float) -> bool:
	if to >= from:
		return bearing > from and bearing <= to
	return bearing > from or bearing <= to


## 1 just after the sweep passed `bearing`, fading to 0.
func _glow(bearing: float) -> float:
	var since := fposmod(_angle - bearing, TAU) / TAU * SWEEP_PERIOD
	return exp(-since / PERSISTENCE * 2.0)


func _to_scope(point: Vector2) -> Vector2:
	return _centre() + (point - entrance) * _radius() / scope_range


func _centre() -> Vector2:
	return Vector2(PIXELS.x / 2.0, PIXELS.y * 0.16)


## The half-disc fills the screen down to the readouts; its sides run off the edges.
func _radius() -> float:
	return PIXELS.y * 0.7


func _draw_screen() -> void:
	var font := ThemeDB.fallback_font
	var centre := _centre()
	var radius := _radius()
	canvas.draw_rect(Rect2(Vector2.ZERO, PIXELS), Color(0.01, 0.04, 0.02))
	# The facility, north of the entrance: a dark band the sweep never shows.
	canvas.draw_rect(Rect2(0, 0, PIXELS.x, centre.y), Color(0.02, 0.08, 0.04))
	canvas.draw_line(Vector2(0, centre.y), Vector2(PIXELS.x, centre.y), PHOSPHOR * Color(1, 1, 1, 0.5), 1.0)
	canvas.draw_string(font, Vector2(8, 14), "PERIMETER RADAR // RANGE %d M" % roundi(scope_range),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, PHOSPHOR)
	canvas.draw_string(font, Vector2(8, 28), "LIGHTS %d/%d" % [network.lit.size(), BeaconNetwork.MAX_LIT] if network else "",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LIT_COLOR)
	# Range rings and the half-disc the sweep covers.
	for ring in [0.25, 0.5, 0.75, 1.0]:
		canvas.draw_arc(centre, radius * ring, 0.0, PI, 32, PHOSPHOR * Color(1, 1, 1, 0.22), 1.0)
	# The entrance at the top.
	canvas.draw_rect(Rect2(centre - Vector2(6, 4), Vector2(12, 8)), PHOSPHOR, false, 1.0)
	canvas.draw_string(font, centre + Vector2(10, -4), "ENTRANCE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, PHOSPHOR)
	# The sweep and its fading trail.
	for i in 12:
		var trail := _angle - i * 0.05
		var direction := Vector2(-sin(trail), cos(trail))
		canvas.draw_line(centre, centre + direction * radius, PHOSPHOR * Color(1, 1, 1, 0.35 * (1.0 - i / 12.0)), 2.0)
	# Returns: the posts (brighter as the sweep passes), lit lamps glowing.
	if network:
		for lamp in network.lamps:
			var floor_at := Vector2(lamp.global_position.x, lamp.global_position.z)
			var at := _to_scope(floor_at)
			var lit := lamp.symbol in network.lit
			var glow := 0.3 + 0.7 * _glow(_bearing(floor_at))
			if lit:
				canvas.draw_circle(at, SYMBOL_PIXELS * 0.7, LIT_COLOR * Color(1, 1, 1, 0.3))
			var cell := Rect2(lamp.symbol * Symbols.CELL, 0, Symbols.CELL, Symbols.CELL)
			var rect := Rect2(at - Vector2.ONE * SYMBOL_PIXELS / 2.0, Vector2.ONE * SYMBOL_PIXELS)
			var tint := (LIT_COLOR if lit else PHOSPHOR) * Color(1, 1, 1, glow)
			canvas.draw_texture_rect_region(Symbols.texture, rect, cell, tint)
	# The contact: a blip where the sweep last found it, fading until the next pass.
	var contacts := 0
	if _contact_seen != Vector2.INF:
		var fade := exp(-(_time - _contact_time) / PERSISTENCE * 1.5)
		var at := _to_scope(_contact_seen)
		canvas.draw_circle(at, 4.0, Color(1, 1, 1, fade))
		canvas.draw_arc(at, 8.0 + (1.0 - fade) * 6.0, 0.0, TAU, 16, PHOSPHOR * Color(1, 1, 1, fade), 1.0)
		canvas.draw_string(font, at + Vector2(9, 4), "CONTACT", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, PHOSPHOR * Color(1, 1, 1, fade))
		contacts = 1
	canvas.draw_rect(Rect2(0, PIXELS.y - 40, PIXELS.x, 40), Color(0.01, 0.04, 0.02))
	canvas.draw_line(Vector2(0, PIXELS.y - 40), Vector2(PIXELS.x, PIXELS.y - 40), PHOSPHOR * Color(1, 1, 1, 0.5), 1.0)
	var status := "CONTACTS: %d" % contacts
	if crush and crush.done and contacts == 0:
		var since := Time.get_ticks_msec() / 1000.0 - crush.done_at
		status = "CONTACT LOST // ENTRANCE" if since < SIGNATURE_DELAY \
				else "CONTACTS: 0   HEAT SIGNATURE // INSIDE: INTAKE"
	canvas.draw_string(font, Vector2(8, PIXELS.y - 26), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, PHOSPHOR)
	if beacon:
		canvas.draw_string(font, Vector2(8, PIXELS.y - 10), "EMERGENCY CONTACT CHANNEL %.1f MHz" % beacon.frequency,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LIT_COLOR)
