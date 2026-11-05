class_name PlantRestart
extends Node
## Bringing sector 4's plant back (Chapter 1, puzzle 7): two people, two rooms, one wall
## between them that neither knows about. The Subject holds the restart lever (the `gauge`,
## a console used in first person); while it's held, pressure builds. The gauge has six
## bands. The Visitor, at the `panel` in the breaker room, throws the breakers in the
## schematic's `order`, each while the needle is in its band, which only the Subject can
## see: someone has to call it. A wrong breaker, or one thrown out of its band, or a band
## let pass, vents the pressure: start over. Letting go of the lever does too.
## Done, the plant catches: the `lights` (dark till then) come up, and the machine spins up
## through the wall. The server owns it all; saved, and done stays done.

signal restored

## Breaker numbers (1-6) in the order they're thrown: the power schematic's.
const ORDER := [3, 1, 6, 2, 5, 4]
## Where each band starts on the gauge (0-100), and how wide it is.
const BANDS := [12.0, 26.0, 40.0, 54.0, 68.0, 82.0]
const BAND_WIDTH := 8.0
## Pressure per second while the lever is held; how fast it falls once let go.
const RISE := 4.0
const FALL := 30.0
const SYNC_INTERVAL := 0.1

@export var gauge: PressureGauge
@export var panel: BreakerPanel
@export var lights: Array[KitLight] = []
## Story lines for both players: when it's done, and when the pressure vents.
@export var done_lines: Array[String] = []
@export var vent_lines: Array[String] = []
@export var keep_on_reload := true

var pressure := 0.0
var holding := false
## Breakers thrown so far, in order (breaker numbers).
var thrown := PackedInt32Array()
var done := false

var _sync_time := 0.0


func _ready() -> void:
	add_to_group(SaveGame.SAVED_GROUP)
	add_to_group("plant_restart")
	for light in lights:
		light.power_off.call_deferred()
	gauge.plant = self
	panel.plant = self
	panel.breaker_pressed.connect(func(breaker: int) -> void: _throw.rpc_id(1, breaker))
	set_physics_process(multiplayer.is_server())
	if not multiplayer.is_server():
		_request_state.rpc_id(1)


## The band the next breaker belongs in (0-5), or -1 when all are thrown.
func next_band() -> int:
	return thrown.size() if thrown.size() < ORDER.size() else -1


func in_band(band: int) -> bool:
	return band >= 0 and pressure >= BANDS[band] and pressure < BANDS[band] + BAND_WIDTH


func _physics_process(delta: float) -> void:
	if done:
		return
	if holding:
		pressure = minf(pressure + RISE * delta, 100.0)
		var band := next_band()
		if band >= 0 and pressure >= BANDS[band] + BAND_WIDTH:
			_vent()
	elif pressure > 0.0 or not thrown.is_empty():
		pressure = maxf(pressure - FALL * delta, 0.0)
		if not thrown.is_empty():
			thrown = PackedInt32Array()
			_apply.rpc(pressure, thrown, done)
	_sync_time -= delta
	if _sync_time <= 0.0:
		_sync_time = SYNC_INTERVAL
		_pressure.rpc(pressure, holding)


## The Subject's gauge: the lever taken or let go.
@rpc("any_peer", "call_local", "reliable")
func set_holding(on: bool) -> void:
	if multiplayer.is_server() and not done:
		holding = on


@rpc("any_peer", "call_local", "reliable")
func _throw(breaker: int) -> void:
	if not multiplayer.is_server() or done or breaker in thrown:
		return
	var band := next_band()
	if not holding or not in_band(band) or breaker != ORDER[band]:
		_vent()
		return
	thrown.append(breaker)
	_thrown_feedback.rpc(breaker)
	if thrown.size() == ORDER.size():
		done = true
		holding = false
		_apply.rpc(pressure, thrown, done)
		_catch.rpc()
		Story.play(done_lines)
		return
	_apply.rpc(pressure, thrown, done)


## Server: out of turn, out of band, or a band let pass. The pressure goes.
func _vent() -> void:
	pressure = 0.0
	thrown = PackedInt32Array()
	_vented.rpc()
	_apply.rpc(pressure, thrown, done)
	Story.play(vent_lines)


@rpc("authority", "call_local", "unreliable")
func _pressure(new_pressure: float, new_holding: bool) -> void:
	pressure = new_pressure
	holding = new_holding


@rpc("authority", "call_local", "reliable")
func _apply(new_pressure: float, new_thrown: PackedInt32Array, new_done: bool) -> void:
	pressure = new_pressure
	thrown = new_thrown
	done = new_done
	panel.show_thrown(thrown)


@rpc("authority", "call_local", "reliable")
func _thrown_feedback(breaker: int) -> void:
	panel.clunk(breaker, true)


@rpc("authority", "call_local", "reliable")
func _vented() -> void:
	Sound.play_at("code_wrong", gauge.global_position + Vector3.UP, 4.0, 25.0, 0.0, 0.6)
	Sound.play_at("code_wrong", panel.global_position + Vector3.UP, 4.0, 25.0, 0.0, 0.6)
	panel.clunk(-1, false)


## The plant catches: the lights come up, and on both sides of the wall the machine spins up.
@rpc("authority", "call_local", "reliable")
func _catch() -> void:
	_power_up(false)


func _power_up(instant: bool) -> void:
	for light in lights:
		light.power_on()
	if not instant:
		Sound.play_at("spin_up", gauge.global_position + Vector3.UP * 1.5, 6.0, 40.0, 0.0)
	restored.emit()


@rpc("any_peer", "reliable")
func _request_state() -> void:
	if multiplayer.is_server():
		_apply.rpc_id(multiplayer.get_remote_sender_id(), pressure, thrown, done)


func save_state() -> Variant:
	return done


func load_state(state: Variant) -> void:
	done = state
	if done:
		thrown = PackedInt32Array(ORDER)
		panel.show_thrown(thrown)
		_power_up(true)
