class_name SubjectWake
extends Node
## The Subject's first moments (Chapter 1's opening). From black, inside the `pod`, looking
## out through the glass at a dark test cell; ZP-SYS comes up on emergency power and the
## cell's `lights` stutter on; the seal releases, the glass lifts, and a cut puts the Subject
## on its feet in front of the pod, in third person. Then the cell `door` opens onto the
## passage. Plays once (saved, kept on reload); a loaded save starts after it.
##
## The Subject's own machine plays it (Player._begin_wake asks); the glass, lights and door
## follow on every machine.

## Seconds from black until the glass lifts, and from then until the cut.
const LIGHTS_AT := 2.2
const OPEN_AT := 6.5
const STAND_AT := 8.4

@export var pod: WakePod
@export var lights: Array[KitLight] = []
@export var door: Door
@export var keep_on_reload := true

var done := false


func _ready() -> void:
	add_to_group(SaveGame.SAVED_GROUP)
	add_to_group("subject_wake")
	# Dark until it plays (or until a loaded save says it's long over).
	for light in lights:
		light.power_off.call_deferred()


## On the Subject's machine, at spawn: the whole sequence for `player`.
func play_for(player: Player) -> void:
	player.begin_scene_view(pod.view_transform())
	var tween := player.create_tween()
	tween.tween_property(player.fade, "color:a", 0.0, 2.5)
	await get_tree().create_timer(LIGHTS_AT).timeout
	_power_lights.rpc()
	await get_tree().create_timer(OPEN_AT - LIGHTS_AT).timeout
	_open_pod.rpc()
	await get_tree().create_timer(STAND_AT - OPEN_AT).timeout
	await player.end_scene_view(pod.stand_transform())
	_finished.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _power_lights() -> void:
	for light in lights:
		light.power_on()


@rpc("any_peer", "call_local", "reliable")
func _open_pod() -> void:
	pod.open()


## Server: the Subject is up. The cell opens onto the passage.
@rpc("any_peer", "call_local", "reliable")
func _finished() -> void:
	if not multiplayer.is_server() or done:
		return
	_set_done.rpc()
	door.sync_open.rpc(true)


@rpc("authority", "call_local", "reliable")
func _set_done() -> void:
	done = true


func save_state() -> Variant:
	return done


## Instant: a loaded save is past the wake (or, if it isn't, it plays on the next spawn).
func load_state(state: Variant) -> void:
	done = state
	if done:
		pod.open(true)
		for light in lights:
			light.power_on()
