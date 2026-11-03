class_name SaveTerminal
extends Interactable
## Save terminal with its respawn pod. Using it cuts to first person at its screen, and then
## the screen becomes the whole screen: the joint save prompt (SavePrompt):
## saving needs both players, each at a terminal. Whoever saved here comes back here: out of
## the pod after dying, or sitting by the terminal when their partner died.

@onready var respawn_point: Marker3D = $RespawnPoint
@onready var wait_point: Marker3D = $WaitPoint


func _ready() -> void:
	add_to_group("save_terminals") # the MAP marks save rooms


func interact(player: Player) -> void:
	used.emit(player)
	# A moment looking at the terminal before its screen fills yours.
	await get_tree().create_timer(0.3).timeout
	if player.focus == self:
		player.open_save_prompt(self)


## Where a player comes back: in front of the pod, or (waiting) by the terminal. The pod's
## first-person view is 0.8 m behind and 1.55 m above the respawn point, inside the pod.
func respawn_transform(waiting: bool) -> Transform3D:
	return (wait_point if waiting else respawn_point).global_transform
