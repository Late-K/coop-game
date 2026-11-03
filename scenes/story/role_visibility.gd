class_name RoleVisibility
extends Node
## Makes its parent exist for one role only: add it as a child of anything (a mesh, a
## label, a document, an interactable). On the other player's machine the parent is
## hidden and can't be touched or used. Both players have the same world; each sees a
## different version of it, so one has to describe to the other what only they can see.
##
## The Visitor sees what the facility hides from its occupants (writing on walls, certain
## bodies, PROCTOR's traces); the Subject sees the facility's own code (hidden door IDs,
## machine states, PROCTOR's markers).

@export_enum("both", "subject", "visitor") var visible_to := "visitor"

var _layer := -1


## Censoring is the other half: something both players can see, but scrambled for one of
## them (WallText, documents). It's there for the Subject too; the Subject just can't read
## it, as if something filters what it is allowed to see. Only the Visitor can say what it says.
const CENSOR_GLYPHS := "█▓▒#%&@?"


## True when a thing marked `visible_to` exists for the local player.
static func seen_locally(visible_to: String) -> bool:
	if visible_to == "both":
		return true
	return _local_role() == visible_to


## True when a thing marked `censored_for` ("nobody", "subject" or "visitor") is scrambled
## for the local player.
static func censored_locally(censored_for: String) -> bool:
	return censored_for != "nobody" and _local_role() == censored_for


## `text` with every letter and digit replaced by noise; spaces, line breaks and punctuation
## stay, so the shape of the message shows through. Pass a fixed `seed` for a steady
## redaction, or a changing one for a glitch; `glyphs` are what the letters turn into.
static func censor(text: String, seed: int, glyphs := CENSOR_GLYPHS) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out := ""
	for c in text:
		var letter := c.to_upper() != c.to_lower() or c.is_valid_int()
		out += glyphs[rng.randi() % glyphs.length()] if letter else c
	return out


static func _local_role() -> String:
	return Session.ROLE_NAMES[Session.local_role()].to_lower()


func _ready() -> void:
	Session.roles_changed.connect(_apply)
	_apply()


func _apply() -> void:
	var target := get_parent()
	var shown := seen_locally(visible_to)
	if target is Node3D:
		target.visible = shown
	if target is CollisionObject3D:
		if _layer < 0:
			_layer = target.collision_layer
		target.collision_layer = _layer if shown else 0
