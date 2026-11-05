class_name ConsoleScreen
extends Interactable
## A console with a live screen, used in first person: a slanted desk, the screen in its
## hood, its reach and where the eye goes, all built in code. Subclasses draw the screen
## in _draw_screen() on `canvas` (PIXELS across) and call canvas.queue_redraw() when it
## changes. RadarScope and OccupantRegister are consoles.

const PIXELS := Vector2i(320, 320)
const SCREEN_SIZE := 0.62

var canvas := Control.new()


func _ready() -> void:
	_build_console()
	var viewport := SubViewport.new()
	viewport.size = PIXELS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	canvas.size = PIXELS
	canvas.draw.connect(_draw_screen)
	viewport.add_child(canvas)
	add_child(viewport)
	var screen := Sprite3D.new()
	screen.texture = viewport.get_texture()
	screen.pixel_size = SCREEN_SIZE / PIXELS.x
	screen.position = Vector3(0, 1.35, 0.32)
	screen.basis = Basis(Vector3.RIGHT, -0.35)
	screen.shaded = false
	screen.set_meta("retro_skip", true)
	add_child(screen)


func _draw_screen() -> void:
	pass


func _build_console() -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.13, 0.14, 0.15)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.2, 1.0, 0.7)
	body.mesh = body_mesh
	body.material_override = dark
	body.position = Vector3(0, 0.5, 0.0)
	add_child(body)
	var hood := MeshInstance3D.new()
	var hood_mesh := BoxMesh.new()
	hood_mesh.size = Vector3(1.0, 0.75, 0.35)
	hood.mesh = hood_mesh
	hood.material_override = dark
	hood.position = Vector3(0, 1.35, 0.1)
	hood.basis = Basis(Vector3.RIGHT, -0.35)
	add_child(hood)
	var solid := StaticBody3D.new()
	var solid_shape := CollisionShape3D.new()
	var solid_box := BoxShape3D.new()
	solid_box.size = Vector3(1.2, 1.6, 0.7)
	solid_shape.shape = solid_box
	solid_shape.position.y = 0.8
	solid.add_child(solid_shape)
	add_child(solid)
	var reach := CollisionShape3D.new()
	var reach_box := BoxShape3D.new()
	reach_box.size = Vector3(1.4, 2.0, 1.0)
	reach.shape = reach_box
	reach.position = Vector3(0, 1.0, 0.9)
	add_child(reach)
	var eye := Marker3D.new()
	eye.position = Vector3(0, 1.62, 1.05)
	eye.basis = Basis(Vector3.RIGHT, -0.38)
	add_child(eye)
	view_point = eye
