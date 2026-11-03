@tool
class_name KitLight
extends Light3D
## A facility lamp: the light plus a small glowing fixture in its colour, so players see
## where light comes from. Used by ceiling_light.tscn (omni) and wall_lamp.tscn (spot aimed
## down and forward). Change colour, energy and range on the light itself.
##
## Lighting rules (docs/level_kit.md): one key lamp per room, hung on the far (north) wall
## or over a doorway so its fixture is in view and shadows fall toward the camera; corners
## stay dark.

## Adds a soft omni fill of this energy around a spot lamp (0 for none).
@export var fill := 0.0
## Uneven, failing light: the lamp dips and stutters.
@export var flicker := false

var _fixture := MeshInstance3D.new()
var _fill_light: OmniLight3D = null
var _base_energy := 0.0
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var strip := BoxMesh.new()
	strip.size = Vector3(1.2, 0.06, 0.25)
	_fixture.mesh = strip
	_fixture.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fixture)
	if fill > 0.0 and get_class() == "SpotLight3D":
		_fill_light = OmniLight3D.new()
		_fill_light.light_color = light_color
		_fill_light.light_energy = fill
		_fill_light.omni_range = float(get("spot_range")) * 0.8
		add_child(_fill_light)
	_base_energy = light_energy
	_update_fixture()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_update_fixture()
		return
	if not flicker:
		return
	_time += delta
	var dip := 1.0
	if _rng.randf() < delta * 0.8:
		dip = _rng.randf_range(0.0, 0.4) # a stutter
	else:
		dip = 0.85 + 0.15 * sin(_time * 23.0) * sin(_time * 3.1)
	light_energy = _base_energy * dip
	if _fill_light:
		_fill_light.light_energy = fill * dip


## The strip glows in the light's colour (Retro converts it for the PS1 shader).
func _update_fixture() -> void:
	var glow := _fixture.material_override as StandardMaterial3D
	if glow and glow.albedo_color == light_color:
		return
	glow = StandardMaterial3D.new()
	glow.albedo_color = light_color
	glow.emission_enabled = true
	glow.emission = light_color
	glow.emission_energy_multiplier = 4.0
	_fixture.material_override = glow
