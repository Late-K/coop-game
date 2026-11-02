extends Node
## All game audio goes through here. Sounds are looked up by name in SOUND_DIR, so a
## placeholder (made by tools/generate_audio.py) is replaced by dropping in a real
## recording with the same file name.
##
## Buses (audio/default_bus_layout.tres): World (3D, with reverb), Ambience, Voice
## (text blips), UI. 3D sounds are heard from the local player's position.

const SOUND_DIR := "res://audio/placeholder/"
const AMBIENCE_FADE := 1.5
const UI_VOICES := 6
const SILENT_DB := -60.0

var _cache := {}
var _ui_players: Array[AudioStreamPlayer] = []
var _next_ui := 0
var _ambience: Array[AudioStreamPlayer] = []
var _ambience_name := ""
var _voice := AudioStreamPlayer.new()


func _ready() -> void:
	for i in UI_VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = &"UI"
		add_child(player)
		_ui_players.append(player)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Ambience"
		player.volume_db = SILENT_DB
		add_child(player)
		_ambience.append(player)
	_voice.bus = &"Voice"
	add_child(_voice)


func stream(sound: String) -> AudioStream:
	if not _cache.has(sound):
		var path := SOUND_DIR + sound + ".wav"
		_cache[sound] = load(path) if ResourceLoader.exists(path) else null
		if _cache[sound] == null:
			push_warning("Missing sound: %s" % path)
	return _cache[sound]


## Flat sound heard only on this machine (HUD feedback, your own hits).
func play_ui(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var player := _ui_players[_next_ui]
	_next_ui = (_next_ui + 1) % UI_VOICES
	player.stream = stream(sound)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


## One-shot in the game world. Distant sounds fade and get muffled by distance.
func play_at(sound: String, at: Vector3, volume_db := 0.0, max_distance := 30.0, pitch_variation := 0.05,
		pitch := 1.0) -> void:
	var level := get_tree().get_first_node_in_group("level")
	if level == null:
		return
	var player := _make_3d(sound, volume_db, max_distance)
	player.pitch_scale = pitch * randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	level.add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()


## A looping 3D emitter attached to `parent` (heater, lamp). The caller plays and stops it.
func attach_loop(sound: String, parent: Node3D, volume_db := 0.0, max_distance := 12.0) -> AudioStreamPlayer3D:
	var player := _make_3d(sound, volume_db, max_distance)
	parent.add_child(player)
	return player


## The background loop for this player; crossfades from the previous one. "" for silence.
func set_ambience(sound: String) -> void:
	if sound == _ambience_name:
		return
	_ambience_name = sound
	var outgoing := _ambience[0]
	var incoming := _ambience[1]
	_ambience.reverse()
	create_tween().tween_property(outgoing, "volume_db", SILENT_DB, AMBIENCE_FADE)
	if sound.is_empty():
		return
	incoming.stream = stream(sound)
	incoming.volume_db = SILENT_DB
	incoming.play()
	create_tween().tween_property(incoming, "volume_db", 0.0, AMBIENCE_FADE)


## Text typing sound for a voice ("sys", "proctor", "thought").
func blip(voice: String) -> void:
	_voice.stream = stream("blip_" + voice)
	_voice.pitch_scale = randf_range(0.96, 1.04)
	_voice.play()


func _make_3d(sound: String, volume_db: float, max_distance: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream(sound)
	player.bus = &"World"
	player.volume_db = volume_db
	player.max_distance = max_distance
	player.unit_size = 4.0
	return player
