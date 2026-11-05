extends SceneTree
## Builds the level kit's grid pieces: the shared surface materials (res://kit/materials/)
## and the MeshLibrary a LevelGrid paints with (res://kit/kit_library.tres).
## Run from the project root after importing textures:
##   godot --headless -s tools/build_kit.gd
## Rerunning overwrites both; item ids stay fixed so painted levels keep working.
##
## The grid: 1 m cells, 2.5 m storeys (Kit.CELL). A floor piece is a slab whose top is the
## storey's floor (y = 0); a wall piece is a solid block filling the whole cell up to the
## ceiling line, so rooms read as hollows in solid black mass from the top-down camera.

const MATERIAL_DIR := "res://kit/materials/"
const LIBRARY_PATH := "res://kit/kit_library.tres"

## id: [name, kind, material]. Kinds: floor (slab, top at 0), wall (full block, black top),
## low (1 m block: counters, ledges, railings). Never renumber: levels store these ids.
const ITEMS := {
	0: ["floor_tiles", "floor", "floor_tiles"],
	1: ["floor_grate", "floor", "floor_grate"],
	2: ["floor_concrete", "floor", "floor_concrete"],
	3: ["floor_hazard", "floor", "floor_hazard"],
	4: ["floor_snow", "floor", "snow"],
	# Area sets: chambers (the Subject), offices (the Visitor), safe rooms (shared).
	5: ["floor_chamber", "floor", "floor_chamber"],
	6: ["floor_carpet", "floor", "floor_carpet"],
	7: ["floor_linoleum", "floor", "floor_linoleum"],
	8: ["floor_safe", "floor", "floor_safe"],
	10: ["wall_panel", "wall", "wall_panel"],
	11: ["wall_concrete", "wall", "wall_concrete"],
	12: ["wall_lab", "wall", "wall_lab"],
	13: ["wall_ice", "wall", "wall_ice"],
	14: ["wall_chamber", "wall", "wall_chamber"],
	15: ["wall_chamber_decayed", "wall", "wall_chamber_decayed"],
	16: ["wall_office", "wall", "wall_office"],
	17: ["wall_machinery", "wall", "wall_machinery"],
	18: ["wall_safe", "wall", "wall_safe"],
	20: ["low_concrete", "low", "low_concrete"],
	21: ["low_panel", "low", "low_panel"],
	22: ["low_chamber", "low", "low_chamber"],
	23: ["low_office", "low", "low_office"],
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MATERIAL_DIR))
	var materials := _build_materials()
	var library := MeshLibrary.new()
	for id: int in ITEMS:
		var item_name: String = ITEMS[id][0]
		var kind: String = ITEMS[id][1]
		var material: StandardMaterial3D = materials[ITEMS[id][2]]
		var bottom := -0.5
		var top: float = {"floor": 0.0, "wall": Kit.WALL_HEIGHT, "low": 1.0}[kind]
		library.create_item(id)
		library.set_item_name(id, item_name)
		library.set_item_mesh(id, _block(bottom, top, material))
		var shape := BoxShape3D.new()
		shape.size = Vector3(1, top - bottom, 1)
		library.set_item_shapes(id, [shape, Transform3D(Basis(), Vector3(0, (top + bottom) / 2.0, 0))])
		var preview: Texture2D = material.get_meta("retro_wall_texture") if kind != "floor" else material.albedo_texture
		library.set_item_preview(id, preview)
	var err := ResourceSaver.save(library, LIBRARY_PATH)
	print("kit: %d grid pieces -> %s (%s)" % [ITEMS.size(), LIBRARY_PATH, error_string(err)])
	_build_environments()
	quit()


## The two looks every level uses: the dark facility interior and the whiteout outside
## (the whiteout is applied per area through an EnvironmentZone).
func _build_environments() -> void:
	var facility := Environment.new()
	facility.background_mode = Environment.BG_COLOR
	facility.background_color = Color.BLACK
	facility.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	facility.ambient_light_color = Color(0.5, 0.5, 0.52)
	facility.ambient_light_energy = 0.12
	facility.fog_enabled = true
	facility.fog_light_color = Color.BLACK
	facility.fog_density = 0.008
	facility.glow_enabled = true
	facility.glow_intensity = 1.0
	facility.glow_strength = 1.1
	facility.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	facility.glow_hdr_threshold = 1.0
	facility.adjustment_enabled = true
	facility.adjustment_contrast = 1.12
	facility.adjustment_saturation = 0.85
	ResourceSaver.save(facility, "res://kit/facility_environment.tres")

	# A blizzard: an arm's length of ground, then nothing but white. Lit lamps (which ignore
	# fog) are the only thing that carries.
	var whiteout := Environment.new()
	whiteout.background_mode = Environment.BG_COLOR
	whiteout.background_color = Color(0.62, 0.66, 0.71)
	whiteout.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	whiteout.ambient_light_color = Color(0.62, 0.67, 0.74)
	whiteout.ambient_light_energy = 0.55
	whiteout.fog_enabled = true
	whiteout.fog_mode = Environment.FOG_MODE_DEPTH
	whiteout.fog_light_color = Color(0.62, 0.66, 0.71)
	whiteout.fog_density = 1.0
	whiteout.fog_depth_begin = 1.0
	whiteout.fog_depth_end = 7.0
	ResourceSaver.save(whiteout, "res://kit/whiteout_environment.tres")
	print("kit: environments -> res://kit/")


## A 1 x 1 m box from `bottom` to `top`, as an ArrayMesh so its surface material can be
## swapped per surface (Retro converts it for the PS1 shader at runtime).
func _block(bottom: float, top: float, material: Material) -> ArrayMesh:
	var box := BoxMesh.new()
	box.size = Vector3(1, top - bottom, 1)
	var arrays := box.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		vertices[i].y += (top + bottom) / 2.0
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh


## Surface materials, saved one per file so props and hand-made geometry can share them.
## World-space UVs: uv1_scale is texture repeats per metre (the textures are 2 m wide).
func _build_materials() -> Dictionary:
	var made := {}
	var surfaces := {
		# name: [albedo texture, wall texture or "", repeats per metre, black tops, tint]
		"floor_tiles": ["floor_tiles", "", 1.0, false, Color(0.85, 0.85, 0.85)],
		"floor_grate": ["floor_grate", "", 0.5, false, Color.WHITE],
		"floor_concrete": ["floor_concrete", "", 0.5, false, Color.WHITE],
		"floor_hazard": ["hazard", "", 2.0, false, Color.WHITE],
		"snow": ["snow", "", 0.5, false, Color.WHITE],
		"wall_panel": ["wall_panel", "wall_panel", 0.5, true, Color(0.9, 0.9, 0.9)],
		"wall_concrete": ["wall_concrete", "wall_concrete", 0.5, true, Color(0.9, 0.9, 0.9)],
		"wall_lab": ["wall_lab", "wall_lab", 0.5, true, Color(0.9, 0.9, 0.9)],
		"wall_ice": ["snow", "ice_face", 0.5, false, Color(0.85, 0.9, 0.95)],
		"low_concrete": ["floor_concrete", "wall_concrete", 0.5, false, Color(0.85, 0.85, 0.85)],
		"low_panel": ["floor_grate", "wall_panel", 0.5, false, Color(0.85, 0.85, 0.85)],
		"floor_chamber": ["floor_chamber", "", 0.5, false, Color(0.9, 0.9, 0.9)],
		"floor_carpet": ["floor_carpet", "", 0.5, false, Color.WHITE],
		"floor_linoleum": ["floor_linoleum", "", 0.5, false, Color.WHITE],
		"floor_safe": ["floor_safe", "", 0.5, false, Color.WHITE],
		"wall_chamber": ["wall_chamber", "wall_chamber", 0.5, true, Color(0.92, 0.92, 0.92)],
		"wall_chamber_decayed": ["wall_chamber_decayed", "wall_chamber_decayed", 1.0 / 6.0, true, Color(0.9, 0.9, 0.9)], # 6 m wide
		"wall_office": ["wall_office", "wall_office", 0.5, true, Color(0.9, 0.9, 0.9)],
		"wall_machinery": ["wall_machinery", "wall_machinery", 0.5, true, Color(0.9, 0.9, 0.9)],
		"wall_safe": ["wall_safe", "wall_safe", 0.5, true, Color(0.92, 0.92, 0.92)],
		"low_chamber": ["floor_chamber", "wall_chamber", 0.5, false, Color(0.9, 0.9, 0.9)],
		"low_office": ["floor_carpet", "wall_office", 0.5, false, Color(0.85, 0.85, 0.85)],
	}
	for material_name: String in surfaces:
		var spec: Array = surfaces[material_name]
		var material := StandardMaterial3D.new()
		material.albedo_texture = load("res://textures/%s.png" % spec[0])
		material.albedo_color = spec[4]
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE * spec[2]
		if spec[1] != "":
			material.set_meta("retro_wall_texture", load("res://textures/%s.png" % spec[1]))
		if spec[3]:
			material.set_meta("retro_black_tops", true)
		made[material_name] = _save(material, material_name)

	# Plain surfaces for props, ceilings and fixtures.
	var plain := {
		"ceiling": [Color(0.16, 0.17, 0.18), 0.0],
		"metal_dark": [Color(0.2, 0.22, 0.23), 0.4],
		"metal_light": [Color(0.48, 0.51, 0.52), 0.4],
		"paint_teal": [Color(0.2, 0.31, 0.33), 0.1],
		"paint_red": [Color(0.42, 0.13, 0.1), 0.1],
		"rust": [Color(0.3, 0.18, 0.12), 0.2],
		"wood": [Color(0.34, 0.25, 0.17), 0.0],
		# Area props: chamber white, grown tissue, office wood and fabric, safe room colours.
		"panel_white": [Color(0.78, 0.8, 0.79), 0.0],
		"tissue": [Color(0.5, 0.18, 0.2), 0.0],
		"wood_dark": [Color(0.24, 0.15, 0.09), 0.0],
		"fabric": [Color(0.3, 0.26, 0.24), 0.0],
		"paint_cream": [Color(0.72, 0.66, 0.52), 0.0],
		"paint_green": [Color(0.17, 0.32, 0.26), 0.1],
		"plant_dead": [Color(0.32, 0.28, 0.16), 0.0],
	}
	for material_name: String in plain:
		var material := StandardMaterial3D.new()
		material.albedo_color = plain[material_name][0]
		material.metallic = plain[material_name][1]
		made[material_name] = _save(material, material_name)

	var screen := StandardMaterial3D.new()
	screen.albedo_color = Color(0.1, 0.25, 0.22)
	screen.emission_enabled = true
	screen.emission = Color(0.45, 0.95, 0.82)
	screen.emission_energy_multiplier = 1.2
	made["screen"] = _save(screen, "screen")
	# Glowing fixtures: a chamber's cold strip light, a safe room's warm radiator and lamp.
	var glows := {
		"glow_cold": [Color(0.85, 0.92, 1.0), 2.2],
		"glow_warm": [Color(1.0, 0.62, 0.3), 1.6],
	}
	for material_name: String in glows:
		var glow := StandardMaterial3D.new()
		glow.albedo_color = glows[material_name][0]
		glow.emission_enabled = true
		glow.emission = glows[material_name][0]
		glow.emission_energy_multiplier = glows[material_name][1]
		made[material_name] = _save(glow, material_name)
	return made


func _save(material: Material, material_name: String) -> Material:
	var path := MATERIAL_DIR + material_name + ".tres"
	ResourceSaver.save(material, path)
	material.take_over_path(path)
	return material
