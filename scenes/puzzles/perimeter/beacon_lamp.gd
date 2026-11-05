class_name BeaconLamp
extends Node3D
## A marker post in the snow: a painted symbol on top (what the Visitor reads out)
## and a heat lamp the Subject can switch on from inside. When lit it glows, throws
## a soft glow that carries through the whiteout, and warms whoever stands near it.
## Built in code; BeaconNetwork switches it with set_active().

const POST_HEIGHT := 2.2
const SIGN_SIZE := 0.9
const SIGN_COLOR := Color(0.12, 0.12, 0.14)
const EYE_SIGN_SIZE := 0.5
const EYE_SIGN_HEIGHT := 1.55
const LAMP_ON_COLOR := Color(1.0, 0.75, 0.35)
const LAMP_OFF_COLOR := Color(0.15, 0.13, 0.1)
const HEAT_RATE := 5.0
const HEAT_RADIUS := 3.5
## Metres across the glow round a lit bulb.
const HALO_SIZE := 3.0

@export_range(0, 7) var symbol := 0

var _lamp_material := StandardMaterial3D.new()
## The glow round the lit bulb: the one thing that carries through the blizzard.
var _halo: MeshInstance3D
var _lit := false
var _light := OmniLight3D.new()
var _heat := TemperatureZone.new()
var _hum: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group("recovery_points")
	_build_post()

	var painted := Symbols.make_sprite(symbol, SIGN_SIZE)
	painted.axis = Vector3.AXIS_Y
	painted.modulate = SIGN_COLOR
	painted.position.y = POST_HEIGHT + 0.03
	add_child(painted)
	# A board under the symbol so it reads as a painted plate.
	var plate := MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(SIGN_SIZE * 1.1, 0.04, SIGN_SIZE * 1.1)
	plate.mesh = plate_mesh
	plate.position.y = POST_HEIGHT
	add_child(plate)
	# At eye height, a box sign with the symbol on every face: what the Visitor reads on foot,
	# in first person, from whichever side they come.
	var sign_box := MeshInstance3D.new()
	var sign_mesh := BoxMesh.new()
	sign_mesh.size = Vector3.ONE * EYE_SIGN_SIZE
	sign_box.mesh = sign_mesh
	sign_box.position.y = EYE_SIGN_HEIGHT
	add_child(sign_box)
	for side in 4:
		var face := Symbols.make_sprite(symbol, EYE_SIGN_SIZE * 0.85)
		face.modulate = SIGN_COLOR
		face.basis = Basis(Vector3.UP, side * PI / 2.0)
		face.position = Vector3(0, EYE_SIGN_HEIGHT, 0) + face.basis.z * (EYE_SIGN_SIZE / 2.0 + 0.005)
		add_child(face)

	# The bulb skips the PS1 material swap and is fogged like everything else: close up you
	# see the lamp, further off only its glow (the halo, which ignores fog).
	_lamp_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lamp_material.albedo_color = LAMP_OFF_COLOR
	_lamp_material.set_meta("retro_skip", true)
	var lamp := MeshInstance3D.new()
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.22
	lamp_mesh.height = 0.44
	lamp.mesh = lamp_mesh
	lamp.material_override = _lamp_material
	lamp.position = Vector3(0.45, POST_HEIGHT - 0.3, 0)
	add_child(lamp)

	_halo = _make_halo()
	_halo.position = lamp.position
	_halo.visible = false
	add_child(_halo)

	_light.light_color = LAMP_ON_COLOR
	_light.omni_range = 9.0
	_light.light_energy = 0.0
	_light.position = lamp.position
	add_child(_light)

	_heat.warmth_rate = HEAT_RATE
	_heat.active = false
	var heat_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = HEAT_RADIUS
	heat_shape.shape = sphere
	_heat.add_child(heat_shape)
	_heat.position.y = 1.0
	add_child(_heat)
	_hum = Sound.attach_loop("lamp_hum", self, -8.0, 10.0)
	_hum.position = lamp.position


## A soft orange glow round the bulb, always facing you, added over whatever is behind it
## and drawn past the fog: through the snow it reads as light, not as a lamp.
func _make_halo() -> MeshInstance3D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.72, 0.35, 0.9))
	gradient.set_color(1, Color(1.0, 0.6, 0.25, 0.0))
	gradient.add_point(0.35, Color(1.0, 0.65, 0.3, 0.35))
	var glow := GradientTexture2D.new()
	glow.gradient = gradient
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	glow.width = 64
	glow.height = 64
	var material := StandardMaterial3D.new()
	material.albedo_texture = glow
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.disable_fog = true
	material.set_meta("retro_skip", true)
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * HALO_SIZE
	halo.mesh = quad
	halo.material_override = material
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return halo


## The post itself: a concrete footing half buried in the snow, a steel pole with a hazard
## band and a cable run, and a cross-arm carrying the lamp in a hooded wire cage.
func _build_post() -> void:
	var steel: Material = load("res://kit/materials/metal_dark.tres")
	var concrete: Material = load("res://kit/materials/floor_concrete.tres")
	var hazard: Material = load("res://kit/materials/floor_hazard.tres")
	var rust: Material = load("res://kit/materials/rust.tres")
	_part(_box(Vector3(0.7, 0.35, 0.7)), Vector3(0, 0.12, 0), concrete)
	_part(_cylinder(0.08, 0.11, POST_HEIGHT), Vector3(0, POST_HEIGHT / 2.0, 0), steel)
	_part(_cylinder(0.115, 0.115, 0.35), Vector3(0, 0.55, 0), hazard)
	_part(_cylinder(0.025, 0.025, POST_HEIGHT - 0.4), Vector3(-0.1, POST_HEIGHT / 2.0, 0.06), rust)
	_part(_box(Vector3(0.18, 0.28, 0.12)), Vector3(-0.1, 0.95, 0.1), steel) # the junction box
	# The arm, and the lamp at its end under a hood, caged.
	var lamp_at := Vector3(0.45, POST_HEIGHT - 0.3, 0)
	_part(_box(Vector3(0.6, 0.06, 0.06)), Vector3(0.24, POST_HEIGHT - 0.05, 0), steel)
	_part(_cylinder(0.04, 0.3, 0.16), lamp_at + Vector3(0, 0.26, 0), steel) # the hood
	for i in 4:
		var angle := i * PI / 2.0 + PI / 4.0
		_part(_box(Vector3(0.02, 0.5, 0.02)), lamp_at + Vector3(cos(angle) * 0.26, 0.0, sin(angle) * 0.26), steel)
	_part(_cylinder(0.27, 0.27, 0.03), lamp_at + Vector3(0, -0.25, 0), steel) # the cage's base ring


func _part(mesh: Mesh, at: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	add_child(part)


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 8
	return mesh


## A Visitor who collapses in the snow wakes by the nearest lit lamp (Player._recover).
func can_recover() -> bool:
	return _lit


func recovery_position() -> Vector3:
	return global_position + global_basis.z * 1.5


func set_active(active: bool) -> void:
	_lamp_material.albedo_color = LAMP_ON_COLOR if active else LAMP_OFF_COLOR
	_lit = active
	_halo.visible = active
	_light.light_energy = 2.5 if active else 0.0
	_heat.set_active(active)
	if active and not _hum.playing:
		_hum.play()
	elif not active:
		_hum.stop()
