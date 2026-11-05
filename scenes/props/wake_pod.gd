class_name WakePod
extends Node3D
## The pod the Subject wakes in (Chapter 1's test cell): an upright white housing, a glass
## front that lifts, cables and grown tubing running into the back, a status lamp. Not the
## safe rooms' respawn pod: this one belongs to the tests. Back against a wall, facing +Z.
## Built in code; SubjectWake opens it.

const GLASS_LIFT := 2.2
const OPEN_TIME := 1.6
const WIDTH := 1.1
const DEPTH := 0.9
const HEIGHT := 2.3

var is_open := false

var _glass: MeshInstance3D
var _lamp_material := StandardMaterial3D.new()
var _inner := OmniLight3D.new()


func _ready() -> void:
	var white: Material = load("res://kit/materials/panel_white.tres")
	var dark: Material = load("res://kit/materials/metal_dark.tres")
	var tissue: Material = load("res://kit/materials/tissue.tres")
	_box(Vector3(WIDTH, HEIGHT, 0.08), Vector3(0, HEIGHT / 2.0, 0.04), white) # back
	for side in [-1, 1]:
		_box(Vector3(0.08, HEIGHT, DEPTH), Vector3(side * (WIDTH - 0.08) / 2.0, HEIGHT / 2.0, DEPTH / 2.0), white)
	_box(Vector3(WIDTH, 0.18, DEPTH), Vector3(0, HEIGHT - 0.09, DEPTH / 2.0), white) # hood
	_box(Vector3(WIDTH, 0.12, DEPTH), Vector3(0, 0.06, DEPTH / 2.0), dark) # step
	_box(Vector3(0.7, 0.9, 0.06), Vector3(0, 1.45, 0.11), dark) # the back rest
	# Cables and grown tubing into the back panel: what kept it alive in there.
	for i in 3:
		var cable := _cylinder(0.035, 1.2, Vector3(-0.25 + i * 0.25, 1.1, 0.16), dark if i != 1 else tissue)
		cable.rotation.x = 0.5
	var solid := StaticBody3D.new()
	for spec: Array in [[Vector3(WIDTH, HEIGHT, 0.08), Vector3(0, HEIGHT / 2.0, 0.04)],
			[Vector3(0.08, HEIGHT, DEPTH), Vector3(-(WIDTH - 0.08) / 2.0, HEIGHT / 2.0, DEPTH / 2.0)],
			[Vector3(0.08, HEIGHT, DEPTH), Vector3((WIDTH - 0.08) / 2.0, HEIGHT / 2.0, DEPTH / 2.0)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec[0]
		shape.shape = box
		shape.position = spec[1]
		solid.add_child(shape)
	add_child(solid)

	var glass_material := StandardMaterial3D.new()
	glass_material.albedo_color = Color(0.6, 0.85, 0.9, 0.22)
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass_material.set_meta("retro_skip", true)
	_glass = _box(Vector3(WIDTH - 0.16, HEIGHT - 0.3, 0.03), Vector3(0, (HEIGHT - 0.3) / 2.0 + 0.12, DEPTH - 0.04), glass_material)

	_lamp_material.albedo_color = Color(0.9, 0.2, 0.15)
	_lamp_material.emission_enabled = true
	_lamp_material.emission = Color(0.9, 0.2, 0.15)
	_lamp_material.emission_energy_multiplier = 2.0
	_lamp_material.set_meta("retro_skip", true)
	_box(Vector3(0.12, 0.05, 0.02), Vector3(0, HEIGHT - 0.1, DEPTH + 0.005), _lamp_material)
	_inner.light_color = Color(0.7, 0.85, 1.0)
	_inner.light_energy = 0.6
	_inner.omni_range = 1.6
	_inner.position = Vector3(0, 2.0, 0.45)
	add_child(_inner)


## Where the eye is, inside, looking out through the glass.
func view_transform() -> Transform3D:
	return global_transform * Transform3D(Basis(Vector3.RIGHT, -0.05).rotated(Vector3.UP, PI), Vector3(0, 1.62, 0.42))


## Where whoever woke in it stands once it's open, facing out.
func stand_transform() -> Transform3D:
	return global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.1, DEPTH + 0.7))


## The seal releases: the lamp goes green and the glass lifts. `instant` for a loaded save.
func open(instant := false) -> void:
	if is_open:
		return
	is_open = true
	_lamp_material.albedo_color = Color(0.3, 0.95, 0.5)
	_lamp_material.emission = Color(0.3, 0.95, 0.5)
	var lifted := _glass.position + Vector3.UP * GLASS_LIFT
	if instant:
		_glass.position = lifted
		return
	Sound.play_at("door", global_position + Vector3.UP * 1.5, -4.0, 15.0, 0.0, 1.3)
	create_tween().tween_property(_glass, "position", lifted, OPEN_TIME).set_trans(Tween.TRANS_SINE)


func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	add_child(mesh)
	return mesh


func _cylinder(radius: float, length: float, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = length
	cylinder.radial_segments = 6
	mesh.mesh = cylinder
	mesh.material_override = material
	mesh.position = at
	add_child(mesh)
	return mesh
