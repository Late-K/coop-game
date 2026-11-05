class_name Stairs
extends Interactable
## One end of a flight of stairs between storeys, used like a door: the player walks into it,
## the screen goes to black, and they come out at the `other` end, a storey up or down. Pair
## two (each the other's `other`). The bottom end shows steps climbing into the wall, the top
## end a stairwell dropping away. Back against a wall, facing +Z. Built in code. Enemies
## never follow: the storeys share no navigation.

## How far into the stairs the player walks before the cut, and the cut's length.
const WALK_IN := 0.9
const DARK := 0.5

@export var other: Stairs
## Climbing (the bottom end) or going down (the top end): only changes how it looks.
@export var up := true


func _ready() -> void:
	prompt = "Go up the stairs" if up else "Go down the stairs"
	var concrete: Material = load("res://kit/materials/floor_concrete.tres")
	var dark: Material = load("res://kit/materials/metal_dark.tres")
	if up:
		for step in 5:
			var block := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(2.4, 0.22 * (step + 1), 0.3)
			block.mesh = mesh
			block.material_override = concrete
			block.position = Vector3(0, mesh.size.y / 2.0, 0.75 - step * 0.3)
			add_child(block)
	else:
		var hole := MeshInstance3D.new()
		var hole_mesh := BoxMesh.new()
		hole_mesh.size = Vector3(2.4, 0.02, 1.4)
		hole.mesh = hole_mesh
		var black := StandardMaterial3D.new()
		black.albedo_color = Color.BLACK
		hole.material_override = black
		hole.position = Vector3(0, 0.02, 0.7)
		add_child(hole)
	for side in [-1, 1]:
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(0.06, 0.06, 1.5)
		rail.mesh = rail_mesh
		rail.material_override = dark
		rail.position = Vector3(side * 1.25, 1.0, 0.7)
		add_child(rail)
	var reach := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 2.0, 1.6)
	reach.shape = box
	reach.position = Vector3(0, 1.0, 1.6)
	add_child(reach)


## Where you come out at this end: in front of it, facing away.
func exit_transform() -> Transform3D:
	return global_transform * Transform3D(Basis(), Vector3(0, 0.1, 2.2))


func interact(player: Player) -> void:
	if other:
		player.take_stairs(self)
