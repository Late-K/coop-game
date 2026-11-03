class_name Document
extends Interactable
## A document lying in the facility (story/documents.json). Reading it opens the terminal
## on the FILES tab, where it stays to be reread. Each player keeps their own files: what
## one has read, the other has only heard about. Add a RoleVisibility child for papers
## only one player can see.

@export var doc_id := ""


func get_prompt(player: Player) -> String:
	return "Read %s" % ("again" if doc_id in player.files else Documents.title(doc_id).to_lower())


func interact(player: Player) -> void:
	player.read_document(doc_id)
	used.emit(player)
