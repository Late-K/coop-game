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


static func description(id: String) -> String:
	return DEFS[id].get("description", "") if exists(id) else ""


## What combining `a` with `b` does ("load", "merge"...), or "" if they don't combine.
static func combination(a: String, b: String) -> String:
	return DEFS[a].get("combine", {}).get(b, "") if exists(a) else ""


static func icon(id: String) -> Texture2D:
	var path := "res://textures/icons/%s.png" % id
	return load(path) if ResourceLoader.exists(path) else null


static func get_value(id: String, key: String, default: Variant = null) -> Variant:
	return DEFS[id].get(key, default) if exists(id) else default
