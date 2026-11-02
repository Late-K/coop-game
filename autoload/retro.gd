extends Node
## PS1-style rendering.
##
## - Every StandardMaterial3D that enters the tree is swapped for the PS1 surface shader
##   (vertex snapping, affine textures, nearest filtering), so content is authored with
##   normal materials. Opt a material out with `material.set_meta("retro_skip", true)`,
##   e.g. one a script animates. Transparent materials are left alone.
## - main.tscn renders the game world into a low-res SubViewport (`attach()`), scaled up
##   with hard pixels plus colour reduction and dithering (shaders/ps1_screen.gdshader).
## - F2 toggles the whole effect, for comparison while developing.

const LIT_SHADER := preload("res://shaders/ps1_lit.gdshader")
const UNSHADED_SHADER := preload("res://shaders/ps1_unshaded.gdshader")
const SCREEN_SHADER := preload("res://shaders/ps1_screen.gdshader")
## Roughly how many pixel rows the game world is rendered with.
const TARGET_HEIGHT := 270.0

var enabled := true

var _view: SubViewportContainer
var _screen_material := ShaderMaterial.new()
var _default_material := StandardMaterial3D.new()
var _converted := {} # source StandardMaterial3D -> ShaderMaterial


func _ready() -> void:
	_screen_material.shader = SCREEN_SHADER
	get_tree().node_added.connect(_on_node_added)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_retro"):
		enabled = not enabled
		_update_view()


## Called by main.gd with the container that holds the game world.
func attach(view: SubViewportContainer) -> void:
	_view = view
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.resized.connect(_update_view)
	_update_view()


func _update_view() -> void:
	if not _view:
		return
	var shrink := maxi(1, roundi(_view.size.y / TARGET_HEIGHT)) if enabled else 1
	_view.stretch_shrink = shrink
	_view.material = _screen_material if enabled else null
	var resolution := (_view.size / shrink).floor()
	_screen_material.set_shader_parameter("resolution", resolution)
	RenderingServer.global_shader_parameter_set("retro_resolution", resolution if enabled else Vector2.ZERO)


func _on_node_added(node: Node) -> void:
	if node is GeometryInstance3D:
		# Deferred: scripts usually assign their materials in _ready, after this signal.
		_convert_node.call_deferred(node)


func _convert_node(node: GeometryInstance3D) -> void:
	if not is_instance_valid(node):
		return
	if node.material_override:
		node.material_override = _convert(node.material_override)
	if node is CSGPrimitive3D:
		node.material = _convert(node.material if node.material else _default_material)
	elif node is MeshInstance3D and node.mesh:
		for i in node.mesh.get_surface_count():
			var source: Material = node.get_surface_override_material(i)
			if source == null:
				source = node.mesh.surface_get_material(i)
			node.set_surface_override_material(i, _convert(source if source else _default_material))


func _convert(source: Material) -> Material:
	var standard := source as StandardMaterial3D
	if standard == null or standard.get_meta("retro_skip", false) \
			or standard.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return source
	if _converted.has(standard):
		return _converted[standard]
	var material := ShaderMaterial.new()
	var unshaded := standard.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
	material.shader = UNSHADED_SHADER if unshaded else LIT_SHADER
	material.set_shader_parameter("albedo_color", standard.albedo_color)
	if standard.albedo_texture:
		material.set_shader_parameter("albedo_texture", standard.albedo_texture)
	if standard.emission_enabled:
		var emission := standard.emission * standard.emission_energy_multiplier
		material.set_shader_parameter("emission_color", Vector3(emission.r, emission.g, emission.b))
	material.set_shader_parameter("metallic", standard.metallic)
	material.set_shader_parameter("roughness", standard.roughness)
	material.set_shader_parameter("uv_scale", Vector2(standard.uv1_scale.x, standard.uv1_scale.y))
	_converted[standard] = material
	return material
