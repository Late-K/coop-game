class_name Interactable
extends Area3D
## Something a player can use with the interact action.
##
## With a `view_point`, using it hard-cuts the local player to a first-person view
## there (consoles, panels, documents). Perspective is local only and never synced.
## Without one, `interact()` is called directly and the player stays in third person.

signal used(player: Player)

const INTERACTABLE_LAYER := 4 # physics layer 3, "interactable"

@export var prompt := "Use"
@export var view_point: Marker3D

## True while the local player is looking at this in first person.
var has_local_focus := false


func _init() -> void:
	collision_layer = INTERACTABLE_LAYER
	collision_mask = 0
	monitoring = false
	input_ray_pickable = false


## Text after "[E]" in the prompt. Override for prompts that depend on the player.
func get_prompt(_player: Player) -> String:
	return prompt


func interact(player: Player) -> void:
	used.emit(player)
