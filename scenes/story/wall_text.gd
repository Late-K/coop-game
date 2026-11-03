@tool
class_name WallText
extends Label3D
## Text on a surface. "paint" is crude red writing someone left; both players see it, but
## for the Subject it is censored (see RoleVisibility): the letters glitch and won't settle,
## so only the Visitor can read it out. "code" is the facility's own cyan marking: only the
## Subject sees it, clearly; to the Visitor it isn't there at all. It's a machine reading a
## machine's labels. (visible_to and censored_for apply to paint; code is always that.)
##
## Place it flat against a wall face, facing into the room (+Z), or lying on the floor. The
## top-down camera reads north walls and floors; east and west walls are seen edge-on.
## MetaSave placeholders work ({iteration}).

## How often the censored letters change (seconds).
const GLITCH_STEP := 0.09

@export_enum("paint", "code") var style := "paint":
	set(value):
		style = value
		_restyle()
## Paint: who has it at all (the other player doesn't see it).
@export_enum("both", "subject", "visitor") var visible_to := "both"
## Paint: who sees it scrambled.
@export_enum("nobody", "subject", "visitor") var censored_for := "subject"
@export_multiline var message := "":
	set(value):
		message = value
		_restyle()
## Height of a letter, in metres. Floor writing needs about 0.4 to read from the camera.
@export var letter_size := 0.18:
	set(value):
		letter_size = value
		_restyle()

var _glitch_time := 0.0
var _glitch_seed := 0
var _rest := Vector3.ZERO


func _ready() -> void:
	font = preload("res://ui/theme.tres").default_font
	font_size = 32
	outline_size = 0
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	double_sided = false
	_rest = position
	_restyle()
	if not Engine.is_editor_hint():
		var visibility := RoleVisibility.new()
		visibility.visible_to = "subject" if style == "code" else visible_to
		add_child(visibility)
		Session.roles_changed.connect(_restyle)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _censored():
		return
	_glitch_time -= delta
	if _glitch_time > 0.0:
		return
	_glitch_time = GLITCH_STEP * randf_range(0.6, 1.6)
	_glitch_seed += 1
	text = RoleVisibility.censor(MetaSave.format(message), _glitch_seed)
	# It jitters, and now and then tears sideways.
	position = _rest + Vector3(randf_range(-0.02, 0.02), randf_range(-0.01, 0.01), 0)
	if randf() < 0.08:
		position.x += randf_range(-0.12, 0.12)
	modulate.a = 1.0 if randf() > 0.1 else 0.35


func _censored() -> bool:
	return style == "paint" and RoleVisibility.censored_locally(censored_for)


func _restyle() -> void:
	if not is_inside_tree():
		return
	if Engine.is_editor_hint():
		text = message
	elif _censored():
		text = RoleVisibility.censor(MetaSave.format(message), _glitch_seed)
	else:
		text = MetaSave.format(message)
		position = _rest
		modulate.a = 1.0
	pixel_size = letter_size / font_size
	if style == "code":
		modulate = Color(0.45, 0.95, 0.82)
		shaded = false
		rotation.z = 0.0
	else:
		modulate = Color(0.55, 0.06, 0.05)
		shaded = true
		rotation.z = -0.04 # by hand, not quite level
