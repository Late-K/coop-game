@tool
class_name MapRoom
extends Node3D
## One room or corridor on the terminal's MAP, as a rectangle `size` metres across (X by Z,
## centred here). It shows once the player has found the floor plan for its `area`.
## Place one per room and corridor; in the editor it draws its outline on the floor.

@export var size := Vector2(8, 8):
	set(value):
		size = value
		_update_outline()
## Shown in the room on the map (keep it short: "STORAGE").
@export var label := ""
## Which floor plan reveals it (FloorPlan.area).
@export var area := ""
## Which storey it is on (0 = ground; the grid's floor index). The MAP shows one at a time.
@export var floor := 0

var _outline: MeshInstance3D


func _ready() -> void:
	add_to_group("map_rooms")
	_update_outline()


## True when `world` is inside this room (on its floor).
func contains(world: Vector3) -> bool:
	return floori((world.y + 0.5) / Kit.CELL.y) == floor and rect().has_point(Vector2(world.x, world.z))


## The room's rectangle on the ground plane (X, Z).
func rect() -> Rect2:
	return Rect2(Vector2(global_position.x, global_position.z) - size / 2.0, size)


func _update_outline() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _outline == null:
		_outline = MeshInstance3D.new()
		add_child(_outline)
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]:
		lines.surface_add_vertex(Vector3(corner.x * size.x / 2.0, 0.05, corner.y * size.y / 2.0))
	lines.surface_end()
	_outline.mesh = lines
