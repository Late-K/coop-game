class_name ItemBox
extends Interactable
## Storage in save rooms. Every box opens the same personal stash (per player, kept for the
## session), so what you leave in one you can take from any other. Boxes are not shared
## between the two players: the pneumatic tube stays the way to hand things over.

const STASH_SLOTS := 16


func interact(player: Player) -> void:
	player.open_inventory(player.stash)
	used.emit(player)
