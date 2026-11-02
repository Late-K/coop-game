class_name Pickup
extends Interactable
## An item lying in the world. Always spawned by the server through the level's
## WorldSpawner, so taking it is replicated and late joiners never see it again.

const SPIN_SPEED := 1.5

@export var item_id := "ammo"
@export var count := 1

@onready var mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Items.color(item_id)
	material.emission_enabled = true
	material.emission = Items.color(item_id) * 0.3
	mesh.material_override = material


func _process(delta: float) -> void:
	mesh.rotate_y(SPIN_SPEED * delta)


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
