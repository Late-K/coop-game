class_name Items
## Item definitions. Ids are plain strings so they travel cheaply over RPC.

const DEFS := {
	"pistol": {"name": "Pistol", "max_stack": 1, "color": Color(0.3, 0.3, 0.34)},
	"ammo": {"name": "Pistol rounds", "max_stack": 12, "color": Color(0.85, 0.7, 0.25)},
	"medkit": {"name": "Med kit", "max_stack": 2, "color": Color(0.8, 0.15, 0.15), "heal": 50},
	"heat_cell": {"name": "Heat cell", "max_stack": 1, "color": Color(1.0, 0.45, 0.1)},
}


static func exists(id: String) -> bool:
	return DEFS.has(id)


static func display_name(id: String) -> String:
	return DEFS[id]["name"] if exists(id) else id


static func max_stack(id: String) -> int:
	return DEFS[id]["max_stack"] if exists(id) else 1


static func color(id: String) -> Color:
	return DEFS[id]["color"] if exists(id) else Color.MAGENTA


static func get_value(id: String, key: String, default: Variant = null) -> Variant:
	return DEFS[id].get(key, default) if exists(id) else default
