class_name Items
## Item definitions. Ids are plain strings so they travel cheaply over RPC.
##   kind: "weapon" (equip to aim), "ammo", "consumable" (Use), "key" (puzzle items)
##   combine: other item id -> what combining them does (see Player.combine_slots)
## Icons live in res://textures/icons/<id>.png (made by tools/generate_textures.py).

const DEFS := {
	"pistol": {
		"name": "Pistol", "kind": "weapon", "max_stack": 1, "color": Color(0.3, 0.3, 0.34),
		"magazine": 6, "combine": {"ammo": "load"},
		"description": "A service pistol, six-round magazine. The grip is worn smooth by someone else's hand.",
	},
	"ammo": {
		"name": "Pistol rounds", "kind": "ammo", "max_stack": 12, "color": Color(0.85, 0.7, 0.25),
		"combine": {"pistol": "load", "ammo": "merge"},
		"description": "Loose 9 mm rounds. Combine with the pistol to load it.",
	},
	"medkit": {
		"name": "Med kit", "kind": "consumable", "max_stack": 2, "color": Color(0.8, 0.15, 0.15), "heal": 50,
		"combine": {"medkit": "merge"},
		"description": "Gauze, coagulant, a single-use injector. The label lists a dosage for 'organic personnel'.",
	},
	"service_key": {
		"name": "Service key", "kind": "key", "max_stack": 1, "color": Color(0.75, 0.62, 0.3),
		"description": "A heavy key on a tag stamped MAINT-2. The teeth are worn smooth; someone used it every day, then stopped.",
	},
	# The one thing the body had that the copy didn't get. Read differently by each player:
	# the Subject found it on a stranger; the Visitor knows whose pocket it came from.
	"photograph": {
		"name": "Photograph", "kind": "key", "max_stack": 1, "color": Color(0.8, 0.72, 0.55),
		"description": "A creased photograph from the stranger's inside pocket. Two people in the snow outside this facility, arms around each other. One wears the stranger's orange jacket. The other face is worn white where a thumb held it, again and again.",
		"visitor_description": "From the inside pocket of the jacket on your body: you, in the snow outside this facility, with someone whose face is worn white where a thumb held it. The same pocket on the jacket you're wearing is empty. Whatever made you didn't make this.",
	},
	"heat_cell": {
		"name": "Heat cell", "kind": "key", "max_stack": 1, "color": Color(1.0, 0.45, 0.1),
		"description": "A sealed thermal cell, still warm. Fits facility heaters.",
	},
}


static func exists(id: String) -> bool:
	return DEFS.has(id)


static func display_name(id: String) -> String:
	return DEFS[id]["name"] if exists(id) else id


static func max_stack(id: String) -> int:
	return DEFS[id]["max_stack"] if exists(id) else 1


static func color(id: String) -> Color:
	return DEFS[id]["color"] if exists(id) else Color.MAGENTA


static func kind(id: String) -> String:
	return DEFS[id].get("kind", "") if exists(id) else ""


## Some things read differently to the Visitor ("visitor_description").
static func description(id: String) -> String:
	if not exists(id):
		return ""
	if Session.local_role() == Session.Role.VISITOR and DEFS[id].has("visitor_description"):
		return DEFS[id]["visitor_description"]
	return DEFS[id].get("description", "")


## What combining `a` with `b` does ("load", "merge"...), or "" if they don't combine.
static func combination(a: String, b: String) -> String:
	return DEFS[a].get("combine", {}).get(b, "") if exists(a) else ""


static func icon(id: String) -> Texture2D:
	var path := "res://textures/icons/%s.png" % id
	return load(path) if ResourceLoader.exists(path) else null


static func get_value(id: String, key: String, default: Variant = null) -> Variant:
	return DEFS[id].get(key, default) if exists(id) else default
