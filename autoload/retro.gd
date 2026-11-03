extends Node
## PS1-style rendering.
##
## - Every StandardMaterial3D that enters the tree is swapped for the PS1 surface shader
##   (vertex snapping, affine textures, nearest filtering), so content is authored with
##   normal materials. Opt a material out with `material.set_meta("retro_skip", true)`,
##   e.g. one a script animates. Transparent materials are left alone. A material with
##   the "retro_black_tops" meta renders its upward faces pure black (wall tops in the void).
##   With "UV1 world triplanar" on, textures are laid out in world space (uv1_scale = repeats
##   per metre); a "retro_wall_texture" meta gives vertical faces their own texture.
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
var _converted := {} # source StandardMaterial3D -> ShaderMaterial; source MeshLibrary -> PS1 copy


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


## Player condition shown on screen (0..1 each): see ps1_screen.gdshader.
func set_condition(hurt: float, cold: float) -> void:
	_screen_material.set_shader_parameter("hurt", hurt)
	_screen_material.set_shader_parameter("cold", cold)


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
		_convert_node.call_deferred(node.get_instance_id())
	elif node is GridMap:
		_convert_grid.call_deferred(node.get_instance_id())


## A GridMap draws its MeshLibrary's meshes directly, so the library itself is swapped for
## a copy whose meshes use the PS1 materials (one copy per library, shared by all grids).
## Takes the node's instance id: by the time this deferred call runs the node may already be
## freed (scripts that rebuild their meshes), and a freed object can't be passed along.
func _convert_grid(instance_id: int) -> void:
	var grid := instance_from_id(instance_id) as GridMap
	if grid == null or grid.mesh_library == null:
		return
	var source := grid.mesh_library
	if not _converted.has(source):
		var library: MeshLibrary = source.duplicate()
		for id in library.get_item_list():
			var mesh := library.get_item_mesh(id)
			if mesh == null:
				continue
			mesh = mesh.duplicate()
			for i in mesh.get_surface_count():
				var material := mesh.surface_get_material(i)
				mesh.surface_set_material(i, _convert(material if material else _default_material))
			library.set_item_mesh(id, mesh)
		_converted[source] = library
		_converted[library] = library
	grid.mesh_library = _converted[source]


func _convert_node(instance_id: int) -> void:
	var node := instance_from_id(instance_id) as GeometryInstance3D
	if node == null:
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
	material.set_shader_parameter("black_tops", standard.get_meta("retro_black_tops", false))
	if standard.uv1_world_triplanar:
		material.set_shader_parameter("world_uv", true)
		if standard.has_meta("retro_wall_texture"):
			material.set_shader_parameter("wall_texture", standard.get_meta("retro_wall_texture"))
			material.set_shader_parameter("has_wall_texture", true)
	_converted[standard] = material
	return material
