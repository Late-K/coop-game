class_name FloorPlan
extends Interactable
## A floor plan posted on a wall. Reading it adds its `area` to the player's map (the MapRooms
## with that area) and opens the MAP tab. Each player keeps their own map: finding a plan
## doesn't give it to the partner. Place it against a wall face, facing into the room (+Z).

@export var area := ""
## Shown on the map and in the message, e.g. "East wing".
@export var area_name := ""


func get_prompt(player: Player) -> String:
	return "Floor plan (on your map)" if player.maps.has(area) else "Read floor plan"


func interact(player: Player) -> void:
	player.learn_map(area, area_name)
	used.emit(player)
