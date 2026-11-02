class_name ExamineSpot
extends Interactable
## Something to look at. Shows a story line to the examining player only, and each
## role can get different text for the same thing. With a view point, it is examined
## in first person.

## Optional: some spots are just for looking at in first person.
@export var line_id := ""


func interact(player: Player) -> void:
	super(player)
	if line_id:
		Story.show_local(line_id)
