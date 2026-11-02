class_name SaveTerminal
extends Interactable
## Checkpoint terminal: using it makes this the player's respawn point.
## Saving to disk comes later; for now it only decides where you come back after dying.

@onready var respawn_point: Marker3D = $RespawnPoint


func interact(player: Player) -> void:
	player.set_checkpoint(respawn_point.global_position)
	used.emit(player)
