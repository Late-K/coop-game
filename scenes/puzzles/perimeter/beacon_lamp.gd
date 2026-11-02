class_name BeaconLamp
extends Node3D
## A marker post in the snow: a painted symbol on top (what the Visitor reads out)
## and a heat lamp the Subject can switch on from inside. When lit it glows, throws
## a pillar of light that cuts through the whiteout, and warms whoever stands near it.
## Built in code; BeaconNetwork switches it with set_active().

const POST_HEIGHT := 2.2
const SIGN_SIZE := 0.9
const SIGN_COLOR := Color(0.12, 0.12, 0.14)
const LAMP_ON_COLOR := Color(1.0, 0.75, 0.35)
const LAMP_OFF_COLOR := Color(0.15, 0.13, 0.1)
const HEAT_RATE := 5.0
const HEAT_RADIUS := 3.5

@export_range(0, 7) var symbol := 0

var _lamp_material := StandardMaterial3D.new()
var _pillar: MeshInstance3D
var _light := OmniLight3D.new()
var _heat := TemperatureZone.new()


func _ready() -> void:
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.08
	pole_mesh.bottom_radius = 0.1
	pole_mesh.height = POST_HEIGHT
	pole.mesh = pole_mesh
	pole.position.y = POST_HEIGHT / 2.0
	add_child(pole)

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

	# Lamp and pillar ignore fog (and the PS1 material swap) so they show through the whiteout.
	_lamp_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lamp_material.disable_fog = true
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

	_pillar = MeshInstance3D.new()
	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = 0.06
	pillar_mesh.bottom_radius = 0.06
	pillar_mesh.height = 14.0
	_pillar.mesh = pillar_mesh
	_pillar.material_override = _lamp_material
	_pillar.position = Vector3(0.45, POST_HEIGHT + 7.0, 0)
	_pillar.visible = false
	add_child(_pillar)

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


func set_active(active: bool) -> void:
	_lamp_material.albedo_color = LAMP_ON_COLOR if active else LAMP_OFF_COLOR
	_pillar.visible = active
	_light.light_energy = 2.5 if active else 0.0
	_heat.set_active(active)
