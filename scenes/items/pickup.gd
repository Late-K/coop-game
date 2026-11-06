class_name Pickup
extends Interactable
## An item lying in the world. Always spawned by the server through the level's
## WorldSpawner, so taking it is replicated and late joiners never see it again. A glint
## catches on it every few seconds, so it reads in the dark from across the room.

const SPIN_SPEED := 1.5
## Seconds between glints, and how long one lasts.
const GLINT_EVERY := 2.6
const GLINT_LENGTH := 0.35

@export var item_id := "ammo"
@export var count := 1

@onready var mesh: MeshInstance3D = $Mesh

var _glint := MeshInstance3D.new()
## The room it lies in (its glint shows only while that room is lit), looked up once.
var _room: RoomShroud = null
var _room_checked := false
var _glint_time := randf() * GLINT_EVERY


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Items.color(item_id)
	material.emission_enabled = true
	material.emission = Items.color(item_id) * 0.3
	mesh.material_override = material
	# A four-point sparkle above it, facing the camera: two thin crossed bars.
	var sparkle := StandardMaterial3D.new()
	sparkle.albedo_color = Color(1.0, 1.0, 0.95)
	sparkle.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sparkle.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sparkle.set_meta("retro_skip", true) # keeps facing the camera
	for bar in [Vector2(0.34, 0.04), Vector2(0.04, 0.34)]:
		var quad := QuadMesh.new()
		quad.size = bar
		var piece := MeshInstance3D.new()
		piece.mesh = quad
		piece.material_override = sparkle
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_glint.add_child(piece)
	_glint.position = Vector3(0.12, 0.42, 0.0)
	_glint.scale = Vector3.ZERO
	add_child(_glint)


func _process(delta: float) -> void:
	mesh.rotate_y(SPIN_SPEED * delta)
	_glint_time = fmod(_glint_time + delta, GLINT_EVERY)
	var flash := clampf(1.0 - absf(_glint_time - GLINT_LENGTH / 2.0) / (GLINT_LENGTH / 2.0), 0.0, 1.0)
	if not _room_checked and is_inside_tree():
		_room_checked = true
		_room = RoomShroud.at(get_tree(), global_position + Vector3.UP * 0.2)
	_glint.scale = Vector3.ONE * flash if _room == null or not _room.dark else Vector3.ZERO


func get_prompt(_player: Player) -> String:
	var text := "Take %s" % Items.display_name(item_id)
	return text + (" x%d" % count if count > 1 else "")


func interact(player: Player) -> void:
	player.request_pickup(self)


func get_spawn_data() -> Dictionary:
	return {"item_id": item_id, "count": count}


func apply_spawn_data(data: Dictionary) -> void:
	item_id = data["item_id"]
	count = data["count"]
