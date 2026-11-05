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
	_dress()


func interact(player: Player) -> void:
	used.emit(player)
	# A moment looking at the terminal before its screen fills yours.
	await get_tree().create_timer(0.3).timeout
	if player.focus == self:
		player.open_save_prompt(self)


## The details over the scene's blocks, the same in every safe room: a bezel round the
## screen, a keyboard ledge, status lamps and vent slats on the cabinet; a cable conduit
## into the pod; ribs and a warm header strip on the pod, and its plate.
func _dress() -> void:
	var dark: Material = load("res://kit/materials/metal_dark.tres")
	var light: Material = load("res://kit/materials/metal_light.tres")
	var glow: Material = load("res://kit/materials/glow_warm.tres")
	for spec: Array in [
			# size, position
			[Vector3(0.55, 0.05, 0.05), Vector3(0, 1.075, 0.42)], # bezel
			[Vector3(0.55, 0.05, 0.05), Vector3(0, 0.725, 0.42)],
			[Vector3(0.05, 0.4, 0.05), Vector3(-0.25, 0.9, 0.42)],
			[Vector3(0.05, 0.4, 0.05), Vector3(0.25, 0.9, 0.42)],
			[Vector3(0.5, 0.04, 0.2), Vector3(0, 0.62, 0.48)], # keyboard ledge
			[Vector3(0.62, 0.06, 0.44), Vector3(0, 1.23, 0.2)], # top cap
			[Vector3(0.14, 0.14, 0.7), Vector3(0.62, 0.15, 0.2)], # conduit to the pod
			[Vector3(0.06, 2.2, 0.06), Vector3(0.74, 1.1, 0.9)], # pod ribs
			[Vector3(0.06, 2.2, 0.06), Vector3(1.66, 1.1, 0.9)],
	]:
		_part(spec[0], spec[1], dark)
	_part(Vector3(0.44, 0.1, 0.14), Vector3(0, 0.66, 0.53), light) # the keys
	for i in 4:
		_part(Vector3(0.5, 0.02, 0.02), Vector3(0, 0.18 + i * 0.08, 0.41), dark) # vents
	for i in 3:
		var lamp := _part(Vector3(0.04, 0.03, 0.02), Vector3(-0.12 + i * 0.12, 1.15, 0.41), glow)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var strip := _part(Vector3(0.84, 0.05, 0.03), Vector3(1.2, 2.02, 0.9), glow)
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plate := Label3D.new()
	plate.text = "PATTERN STORE"
	plate.font_size = 16
	plate.pixel_size = 0.003
	plate.modulate = Color(0.85, 0.8, 0.65)
	plate.outline_size = 0
	plate.position = Vector3(1.2, 2.14, 0.915)
	add_child(plate)


func _part(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.material_override = material
	part.position = at
	add_child(part)
	return part


## Where a player comes back: in front of the pod, or (waiting) by the terminal. The pod's
## first-person view is 0.8 m behind and 1.55 m above the respawn point, inside the pod.
func respawn_transform(waiting: bool) -> Transform3D:
	return (wait_point if waiting else respawn_point).global_transform
