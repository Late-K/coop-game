extends SceneTree
## Builds the kit props that are made in code rather than by hand, into scenes/kit/props/:
## a service trolley, a run of cable on the floor, a stain, and a dead equipment rack. Low
## poly, from boxes and cylinders, with the kit's own materials (kit/materials), like the
## hand-made props. Rerunning overwrites them:
##   godot --headless --path . --script res://tools/build_props.gd

const OUT := "res://scenes/kit/props/"
const MAT := "res://kit/materials/"


func _init() -> void:
	_stain_material()
	_save(_trolley(), "trolley")
	_save(_cable_run(), "cable_run")
	_save(_stain(), "stain")
	_save(_equipment_rack(), "equipment_rack")
	print("[props] built")
	quit()


## A dark, dried stain: on floors, under things, by doors (opaque, so it takes the PS1 look).
func _stain_material() -> void:
	var stain := StandardMaterial3D.new()
	stain.albedo_color = Color(0.16, 0.06, 0.05)
	stain.roughness = 1.0
	ResourceSaver.save(stain, MAT + "stain.tres")


## A two-shelf service trolley on castors, something left on each shelf.
func _trolley() -> Node3D:
	var root := _body("Trolley", Vector3(0.9, 0.95, 0.55), 0.475)
	var light: Material = load(MAT + "metal_light.tres")
	var dark: Material = load(MAT + "metal_dark.tres")
	for y in [0.3, 0.85]:
		_box(root, "Shelf", Vector3(0.9, 0.04, 0.55), Vector3(0, y, 0), light)
	for x in [-0.42, 0.42]:
		for z in [-0.24, 0.24]:
			_box(root, "Post", Vector3(0.04, 0.86, 0.04), Vector3(x, 0.5, z), light)
			_cylinder(root, "Castor", 0.05, 0.04, Vector3(x, 0.05, z), dark, Vector3(PI / 2, 0, 0))
	_box(root, "Handle", Vector3(0.04, 0.04, 0.5), Vector3(-0.5, 0.95, 0), light)
	_box(root, "Tray", Vector3(0.36, 0.06, 0.26), Vector3(0.15, 0.9, 0.05), dark, Vector3(0, 0.3, 0))
	_box(root, "Case", Vector3(0.3, 0.16, 0.22), Vector3(-0.15, 0.4, -0.05), load(MAT + "paint_teal.tres"))
	return root


## Cables run along the floor from the wall: a few, side by side, kinking as they go. Flat:
## nothing to walk round.
func _cable_run() -> Node3D:
	var root := Node3D.new()
	root.name = "CableRun"
	var dark: Material = load(MAT + "metal_dark.tres")
	var rust: Material = load(MAT + "rust.tres")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for strand in 3:
		var at := Vector3(-0.12 + strand * 0.12, 0.03, 0.0)
		var heading := 0.0
		for piece in 6:
			heading += rng.randf_range(-0.45, 0.45)
			var length := rng.randf_range(0.3, 0.45)
			var step := Vector3(sin(heading), 0, cos(heading)) * length
			var mid := at + step / 2.0
			_cylinder(root, "Cable", 0.022, length, mid, dark if strand != 1 else rust,
					Vector3(PI / 2, heading, 0))
			at += step
	return root


## A dried stain: overlapping flat blots, just above the floor.
func _stain() -> Node3D:
	var root := Node3D.new()
	root.name = "Stain"
	var stain: Material = load(MAT + "stain.tres")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for blot in 5:
		var radius := rng.randf_range(0.18, 0.42) if blot > 0 else 0.5
		var at := Vector3(rng.randf_range(-0.4, 0.4), 0.006 + blot * 0.001, rng.randf_range(-0.3, 0.3)) if blot > 0 \
				else Vector3(0, 0.006, 0)
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = 0.002
		mesh.radial_segments = 7
		mesh.rings = 1
		var node := MeshInstance3D.new()
		node.name = "Blot"
		node.mesh = mesh
		node.material_override = stain
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.position = at
		node.scale = Vector3(1.0, 1.0, rng.randf_range(0.6, 1.0))
		root.add_child(node)
	return root


## A tall rack of dead equipment against a wall: vented panels, a cracked dark screen, a
## module pulled half out and hanging, cables down the side.
func _equipment_rack() -> Node3D:
	var root := _body("EquipmentRack", Vector3(0.8, 2.0, 0.6), 1.0)
	var case: Material = load(MAT + "metal_dark.tres")
	var light: Material = load(MAT + "metal_light.tres")
	var screen: Material = load(MAT + "screen.tres")
	_box(root, "Case", Vector3(0.8, 2.0, 0.6), Vector3(0, 1.0, 0), case)
	for y in [0.35, 0.75, 1.55, 1.85]:
		_box(root, "Panel", Vector3(0.7, 0.24, 0.02), Vector3(0, y, 0.31), light)
		for v in 4:
			_box(root, "Vent", Vector3(0.5, 0.02, 0.01), Vector3(0, y - 0.08 + v * 0.05, 0.325), case)
	_box(root, "Screen", Vector3(0.5, 0.3, 0.02), Vector3(0, 1.15, 0.31), screen)
	_box(root, "Module", Vector3(0.6, 0.12, 0.45), Vector3(0.05, 0.98, 0.42), light, Vector3(0.15, 0, -0.05))
	_cylinder(root, "Lead", 0.02, 1.1, Vector3(0.43, 0.55, 0.2), case)
	return root


# --- Building blocks ---------------------------------------------------------------

## A static body with one box collision `size`, its centre `centre_y` up.
func _body(prop_name: String, size: Vector3, centre_y: float) -> StaticBody3D:
	var root := StaticBody3D.new()
	root.name = prop_name
	root.input_ray_pickable = false
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = centre_y
	root.add_child(shape)
	return root


func _box(parent: Node3D, part: String, size: Vector3, at: Vector3, material: Material, turn := Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_mesh(parent, part, mesh, at, material, turn)


func _cylinder(parent: Node3D, part: String, radius: float, height: float, at: Vector3, material: Material,
		turn := Vector3.ZERO) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	mesh.rings = 1
	_mesh(parent, part, mesh, at, material, turn)


func _mesh(parent: Node3D, part: String, mesh: Mesh, at: Vector3, material: Material, turn: Vector3) -> void:
	var node := MeshInstance3D.new()
	node.name = part
	node.mesh = mesh
	node.set_surface_override_material(0, material)
	node.position = at
	node.rotation = turn
	parent.add_child(node, true)


func _save(root: Node3D, file: String) -> void:
	for child in _all(root):
		child.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	ResourceSaver.save(scene, OUT + file + ".tscn")


func _all(node: Node) -> Array[Node]:
	var nodes: Array[Node] = []
	for child in node.get_children():
		nodes.append(child)
		nodes.append_array(_all(child))
	return nodes
