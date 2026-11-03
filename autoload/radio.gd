extends Node
## The walkie-talkie between the two players: hold `radio` (V) to talk. The player
## characters never speak, so the real players' voices are the only voices they have.
##
## Microphone (AudioServer input) -> mono, low-passed and decimated to RATE (8 kHz, the
## radio band) -> mu-law bytes -> unreliable RPC every PACKET_SAMPLES -> the partner's
## jitter buffer -> AudioStreamGenerator on the Radio bus (band-pass, grit). Levels are
## evened out before sending (a slow automatic gain), so quiet and loud mics sound alike.
## No codec plugin: 8 kHz mu-law is 64 kbit/s, small for any connection.
##
## Interference comes from EnvironmentZone.radio_interference where each player stands;
## the worse end wins. It adds static, crackle and drop-outs, so some places are bad for
## talking, and players have to move (or wait) to be understood.
## Works whenever a partner is connected, the lobby included. Full duplex.
##
## The band: both radios start on HOME_FREQUENCY, the partner channel. The terminal's RADIO
## tab (RadioTuner) tunes elsewhere to find stations (RadioSignal), but voice and messages
## only reach a radio tuned to the sender's frequency; slightly off comes through as static
## and garble, further off not at all. So tuning away loses the partner, unless they follow.
##
## The radio can be switched off (RADIO tab: POWER): no voice or messages either way, no
## stations, nothing on the HUD, and the map goes dark. Special enemies track any radio that
## is on, so switching off hides you from them, at the cost of your partner.
##
## Text messages travel the same way, for players without a microphone. They are written
## and read only in the RADIO tab; the HUD just says one is waiting. A player whose
## microphone is closed gets noticed: PROCTOR says so, once per session, and keeps count.

signal transmitting_changed(on: bool)
signal receiving_changed(on: bool)
signal frequency_changed(frequency: float)

const RATE := 8000
const PACKET_SAMPLES := 320 # 40 ms
## Incoming audio held back before playback starts, to absorb network jitter (120 ms).
const PREBUFFER := 960
## Backlog beyond this is dropped, so latency can't creep up over a long transmission.
const MAX_QUEUE := 4000
## Silence from the partner for this long ends their transmission.
const RX_TIMEOUT := 0.35
const MIC_GAIN := 1.6
## Automatic gain: each packet with speech in it steers the gain toward AGC_TARGET (RMS),
## within AGC_MIN..AGC_MAX. Packets quieter than AGC_GATE (room noise) leave it alone.
const AGC_TARGET := 0.2
const AGC_GATE := 0.015
const AGC_MIN := 0.5
const AGC_MAX := 4.0
## Anti-alias low-pass before decimation (two one-pole stages), in Hz.
const MIC_CUTOFF := 3400.0
## Static under every incoming transmission, plus more per unit of interference.
const BASE_STATIC := 0.012
const INTERFERENCE_STATIC := 0.15
const SETTINGS_PATH := "user://settings.cfg"
const HOME_FREQUENCY := 140.0
const MIN_FREQUENCY := 100.0
const MAX_FREQUENCY := 180.0
const FREQUENCY_STEP := 0.1
## How far off (MHz) a station or the partner is still heard, through static.
const BANDWIDTH := 0.5
## From this strength a station counts as clear: its transcript shows, `heard` fires.
const LOCK_STRENGTH := 0.75
## Stations and between-station static play this much softer with the RADIO tab closed.
const CLOSED_DB := -10.0
const CHAT_MAX := 140
const CHAT_HISTORY := 30
## Characters a badly tuned message turns into.
const CHAT_NOISE := "#%&*/?=~"
## Voice packet header: interference (1 byte), then the frequency x10 (2 bytes).
const HEADER := 3
## Seconds into a chapter before PROCTOR remarks on a closed microphone; sooner if the
## player tries to talk or types a message.
const MIC_NOTICE_DELAY := 40.0

var transmitting := false
var receiving := false
## Peak microphone level (0..1) while transmitting, for the HUD meter.
var mic_level := 0.0
## Set by the local player from the EnvironmentZone they stand in (0 = clear, 1 = unusable).
var local_interference := 0.0
## Replaces the microphone with a test tone (automated tests; no microphone needed).
var test_tone := false

## True when the microphone could not be opened (none, or blocked by the OS).
var mic_failed := false
var frequency := HOME_FREQUENCY
var powered := true
## The station heard best on the current frequency (null for none), and how well (0..1).
var station: RadioSignal = null
var station_strength := 0.0
## Set by the local player: where range-limited stations are heard from.
var listener_position := Vector3.ZERO
## True while the RADIO tab is on screen (stations and static play louder).
var tuner_open := false
## True while the player types a message: V types a letter instead of transmitting.
var typing := false
## Recent messages, oldest first ("TX> ..." / "RX< ...").
var chat_history: PackedStringArray = []
## Messages received since the RADIO tab was last open.
var unread := 0

var _mic_on := false
var _agc := 1.0
var _lp1 := 0.0
var _lp2 := 0.0
var _phase := 0.0
var _acc := 0.0
var _acc_n := 0
var _tone_time := 0.0
var _tx_time := 0.0
var _tx := PackedFloat32Array()
var _rx := PackedFloat32Array()
var _rx_interference := 0.0
var _rx_quiet := 0.0
var _rx_started := false
## Frames the generator holds when empty; queued audio is this minus frames_available.
var _rx_capacity := 0
var _decode := PackedFloat32Array()
var _player := AudioStreamPlayer.new()
var _playback: AudioStreamGeneratorPlayback
var _rng := RandomNumberGenerator.new()
var _static_player := AudioStreamPlayer.new()
var _station_player := AudioStreamPlayer.new()
var _station_sound := ""
var _heard := {} # RadioSignal -> true once heard clearly this session
var _level_time := 0.0
var _mic_noticed := false
var _wants_mic := false
var _was_online := false


func _ready() -> void:
	_decode.resize(256)
	for b in 256:
		var y := b / 127.5 - 1.0
		_decode[b] = signf(y) * (pow(256.0, absf(y)) - 1.0) / 255.0
	var generator := AudioStreamGenerator.new()
	generator.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
	generator.mix_rate = RATE
	generator.buffer_length = 0.5
	_player.stream = generator
	_player.bus = &"Radio"
	add_child(_player)
	for player in [_static_player, _station_player]:
		player.bus = &"Radio"
		add_child(player)
	_static_player.stream = Sound.stream("radio_static")
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		var device: String = settings.get_value("radio", "input_device", "")
		if device in AudioServer.get_input_device_list():
			AudioServer.input_device = device


func _process(delta: float) -> void:
	var online := Net.is_online() and not multiplayer.get_peers().is_empty()
	_set_mic(online)
	var want := online and powered and not typing and Input.is_action_pressed("radio")
	if want != transmitting:
		_set_transmitting(want)
	if transmitting:
		_capture(delta)
	elif _mic_on:
		# Keep the input buffer empty so a transmission never starts with stale audio.
		AudioServer.get_input_frames(AudioServer.get_input_frames_available())
	mic_level = maxf(mic_level - delta * 1.5, 0.0)
	_feed_playback(delta)
	if receiving and not online:
		_end_receiving()
	if _was_online and not online:
		_reset_session() # the session ended
	_was_online = online
	_update_stations()
	_check_mic_notice(delta)
	if tuner_open:
		unread = 0


func set_powered(on: bool) -> void:
	if on == powered:
		return
	powered = on
	if not on:
		if transmitting:
			_set_transmitting(false)
		if receiving:
			_end_receiving()
	Sound.play_ui("radio_key" if on else "radio_unkey", -6.0, 0.8)


func on_home_channel() -> bool:
	return absf(frequency - HOME_FREQUENCY) < 0.01


func tune(to: float) -> void:
	var tuned := clampf(snappedf(to, FREQUENCY_STEP), MIN_FREQUENCY, MAX_FREQUENCY)
	if not is_equal_approx(tuned, frequency):
		frequency = tuned
		frequency_changed.emit(frequency)


## How well something sent on `sent` is heard on `tuned`: 1 clear, 0 nothing.
static func reception(tuned: float, sent: float) -> float:
	var off := absf(tuned - sent)
	if off < 0.05:
		return 1.0
	return clampf(1.0 - off / BANDWIDTH, 0.0, 1.0)


## Sends a text message on the current frequency. Only a radio tuned to it receives it.
func send_chat(text: String) -> void:
	text = text.strip_edges().left(CHAT_MAX)
	if text.is_empty() or not Net.is_online() or not powered:
		return
	MetaSave.session["radio_presses"] += 1
	if mic_failed:
		_wants_mic = true
	_add_chat("TX> " + text, true)
	_chat.rpc(text, frequency)


## One line for the HUD and lobby: "TX [||||....]" while talking, "RX  signal [||.]" while
## listening, empty otherwise.
func status_text() -> String:
	if not powered:
		return ""
	var lines: PackedStringArray = []
	var tx := "TX" if on_home_channel() else "TX %.1f" % frequency
	if transmitting and mic_failed:
		lines.append("%s  [no microphone]" % tx)
	elif transmitting:
		var bars := clampi(roundi(mic_level * 10.0), 0, 10)
		lines.append("%s  [%s%s]" % [tx, "|".repeat(bars), ".".repeat(10 - bars)])
	if receiving:
		var signal_bars := clampi(roundi((1.0 - _rx_interference) * 4.0), 0, 4)
		lines.append("RX  signal [%s%s]" % ["|".repeat(signal_bars), ".".repeat(4 - signal_bars)])
	if unread > 0:
		lines.append("RX< %d new message%s  [Tab] radio" % [unread, "" if unread == 1 else "s"])
	if lines.is_empty() and not on_home_channel():
		lines.append("FREQ %.1f  off channel" % frequency)
	return "\n".join(lines)


## A "Microphone: ..." button that steps through the input devices (pause menu, lobby).
func make_device_button() -> Button:
	var button := Button.new()
	button.clip_text = true
	button.text = "Microphone: %s" % AudioServer.input_device
	button.pressed.connect(func() -> void: button.text = "Microphone: %s" % cycle_input_device())
	return button


## Steps to the next microphone and remembers it.
func cycle_input_device() -> String:
	var devices := AudioServer.get_input_device_list()
	if devices.is_empty():
		return AudioServer.input_device
	var next := devices[(devices.find(AudioServer.input_device) + 1) % devices.size()]
	AudioServer.input_device = next
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("radio", "input_device", next)
	settings.save(SETTINGS_PATH)
	mic_failed = false
	return next


# --- Sending -----------------------------------------------------------------

func _set_mic(on: bool) -> void:
	if on == _mic_on or (on and mic_failed):
		return
	var err := AudioServer.set_input_device_active(on)
	if on and err != OK:
		mic_failed = true
		push_warning("Radio: no microphone (%s)" % error_string(err))
		return
	_mic_on = on


func _set_transmitting(on: bool) -> void:
	transmitting = on
	if on:
		_tx.clear()
		_tx_time = 0.0
		MetaSave.session["radio_presses"] += 1
		if mic_failed:
			_wants_mic = true
		Sound.play_ui("radio_key", -14.0)
	else:
		_flush_tx()
		Sound.play_ui("radio_unkey", -16.0)
		if _tx_time >= 1.0:
			MetaSave.record("radio_seconds", roundi(_tx_time))
	transmitting_changed.emit(on)


func _capture(delta: float) -> void:
	_tx_time += delta
	var frames: PackedVector2Array
	var rate := AudioServer.get_input_mix_rate()
	if test_tone:
		rate = AudioServer.get_mix_rate()
		frames.resize(int(delta * rate))
		for i in frames.size():
			_tone_time += 1.0 / rate
			# A warbling tone with syllable-like bursts: easy to find in a recording.
			var s := 0.5 * sin(TAU * 600.0 * _tone_time) * (0.6 + 0.4 * sin(TAU * 4.0 * _tone_time))
			frames[i] = Vector2(s, s)
	elif _mic_on:
		frames = AudioServer.get_input_frames(AudioServer.get_input_frames_available())
	if rate <= 0.0:
		return
	var step := rate / RATE
	var a := 1.0 - exp(-TAU * MIC_CUTOFF / rate)
	var peak := 0.0
	for frame in frames:
		var s := (frame.x + frame.y) * 0.5 * MIC_GAIN
		peak = maxf(peak, absf(s))
		_lp1 += a * (s - _lp1)
		_lp2 += a * (_lp1 - _lp2)
		_acc += _lp2
		_acc_n += 1
		_phase += 1.0
		if _phase >= step:
			_phase -= step
			_tx.append(clampf(_acc / _acc_n, -1.0, 1.0))
			_acc = 0.0
			_acc_n = 0
	mic_level = maxf(mic_level, minf(peak, 1.0))
	while _tx.size() >= PACKET_SAMPLES:
		_send(_tx.slice(0, PACKET_SAMPLES))
		_tx = _tx.slice(PACKET_SAMPLES)


func _flush_tx() -> void:
	if not _tx.is_empty():
		_send(_tx)
		_tx.clear()


## HEADER (interference, frequency), then one mu-law byte per sample.
func _send(samples: PackedFloat32Array) -> void:
	var packet := PackedByteArray()
	packet.resize(samples.size() + HEADER)
	packet[0] = clampi(roundi(local_interference * 255.0), 0, 255)
	packet.encode_u16(1, roundi(frequency * 10.0))
	var sum := 0.0
	for x in samples:
		sum += x * x
	var rms := sqrt(sum / samples.size())
	if rms > AGC_GATE:
		_agc = lerpf(_agc, clampf(AGC_TARGET / rms, AGC_MIN, AGC_MAX), 0.2)
	var log256 := log(256.0)
	for i in samples.size():
		var x := clampf(samples[i] * _agc, -1.0, 1.0)
		var y := signf(x) * log(1.0 + 255.0 * absf(x)) / log256
		packet[i + HEADER] = clampi(roundi((y + 1.0) * 127.5), 0, 255)
	_voice.rpc(packet)


# --- Receiving ---------------------------------------------------------------

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _voice(packet: PackedByteArray) -> void:
	if not powered or packet.size() <= HEADER or packet.size() > PACKET_SAMPLES + HEADER:
		return
	var heard := reception(frequency, packet.decode_u16(1) / 10.0)
	if heard <= 0.0:
		return # tuned elsewhere: this transmission never reaches us
	_rx_interference = maxf(maxf(local_interference, packet[0] / 255.0), 1.0 - heard)
	var interference := _rx_interference
	# Bad signal: whole chunks of speech fall out, leaving only static.
	var voice := 0.0 if _rng.randf() < interference * interference * 0.6 else 1.0
	var static_level := BASE_STATIC + interference * INTERFERENCE_STATIC
	var start := _rx.size()
	_rx.resize(start + packet.size() - HEADER)
	for i in range(HEADER, packet.size()):
		var v := _decode[packet[i]] * voice + _rng.randf_range(-1.0, 1.0) * static_level
		if _rng.randf() < interference * 0.004:
			v += _rng.randf_range(-0.6, 0.6)
		_rx[start + i - HEADER] = v
	if _rx.size() > MAX_QUEUE:
		_rx = _rx.slice(_rx.size() - PREBUFFER)
	_rx_quiet = 0.0
	if not receiving:
		receiving = true
		Sound.play_ui("radio_key", -10.0, 0.94)
		receiving_changed.emit(true)


func _feed_playback(delta: float) -> void:
	if not receiving:
		return
	_rx_quiet += delta
	# Start once enough is buffered, or at once for a transmission shorter than that.
	if not _rx_started and (_rx.size() >= PREBUFFER or _rx_quiet > 0.15):
		_rx_started = true
		_player.play()
		_playback = _player.get_stream_playback()
		_rx_capacity = _playback.get_frames_available()
	if _rx_started and not _rx.is_empty():
		var n := mini(_playback.get_frames_available(), _rx.size())
		var frames := PackedVector2Array()
		frames.resize(n)
		for i in n:
			frames[i] = Vector2(_rx[i], _rx[i])
		_playback.push_buffer(frames)
		_rx = _rx.slice(n)
	# Over once the partner is quiet and everything they said has been played.
	var played_out := not _rx_started or _playback.get_frames_available() >= _rx_capacity - 64
	if _rx_quiet > RX_TIMEOUT and _rx.is_empty() and played_out:
		_end_receiving()


func _end_receiving() -> void:
	receiving = false
	_rx_started = false
	_rx.clear()
	_player.stop()
	Sound.play_ui("radio_unkey", -10.0)
	receiving_changed.emit(false)


# --- Chat --------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _chat(text: String, sent: float) -> void:
	var heard := reception(frequency, sent)
	if heard <= 0.0 or not powered:
		return # nobody was listening on that frequency
	text = text.left(CHAT_MAX)
	if heard < 1.0:
		var garbled := ""
		for c in text:
			var lost := c != " " and _rng.randf() < (1.0 - heard) * 0.9
			garbled += CHAT_NOISE[_rng.randi() % CHAT_NOISE.length()] if lost else c
		text = garbled
	Sound.play_ui("radio_key", -12.0, 1.25)
	_add_chat("RX< " + text, false)


func _add_chat(line: String, outgoing: bool) -> void:
	chat_history.append(line)
	if chat_history.size() > CHAT_HISTORY:
		chat_history = chat_history.slice(-CHAT_HISTORY)
	Story.history.append({"text": line, "color": PlayerHud.RADIO_COLOR})
	if not outgoing and not tuner_open:
		unread += 1


# --- Stations ----------------------------------------------------------------

## Finds the best station on the current frequency and sets the station / static loops.
func _update_stations() -> void:
	station = null
	station_strength = 0.0
	if not powered:
		_static_player.stop()
		_station_player.stop()
		return
	for node in get_tree().get_nodes_in_group("radio_signals"):
		var strength: float = node.strength_at(frequency, listener_position)
		if strength > station_strength:
			station = node
			station_strength = strength
	if station and station_strength >= LOCK_STRENGTH and not _heard.has(station):
		_heard[station] = true
		station.heard.emit()

	var loudness := 0.0 if tuner_open else CLOSED_DB
	var hiss := 0.0 if on_home_channel() else 1.0 - station_strength
	_set_loop(_static_player, hiss * 0.5, loudness)
	var sound := station.sound if station else ""
	if sound != _station_sound:
		_station_sound = sound
		_station_player.stream = Sound.stream(sound) if sound else null
	_set_loop(_station_player, station_strength if sound else 0.0, loudness)


func _set_loop(player: AudioStreamPlayer, amount: float, offset_db: float) -> void:
	if amount <= 0.01 or player.stream == null:
		player.stop()
		return
	player.volume_db = linear_to_db(amount) + offset_db
	if not player.playing:
		player.play()


func _reset_session() -> void:
	tune(HOME_FREQUENCY)
	powered = true
	_heard.clear()
	chat_history.clear()
	unread = 0
	_level_time = 0.0
	_mic_noticed = false
	_wants_mic = false


## A player with a closed microphone has stepped outside the script: PROCTOR notices,
## once per session, and remembers across sessions.
func _check_mic_notice(delta: float) -> void:
	if _mic_noticed or not mic_failed or get_tree().get_first_node_in_group("level") == null:
		return
	_level_time += delta
	if _wants_mic or _level_time > MIC_NOTICE_DELAY:
		_mic_noticed = true
		MetaSave.record("sessions_without_mic")
		Story.show_local("mic_blocked" if MetaSave.counters["sessions_without_mic"] <= 1 else "mic_blocked_again")
