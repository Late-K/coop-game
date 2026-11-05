class_name Player
extends CharacterBody3D
## A player character. Each peer simulates its own player (authority = owning peer)
## and MultiplayerSynchronizer mirrors position/rotation/health/aiming to the other peer.
## World state (puzzles, enemies, pickups) stays server-authoritative.
##
## Perspective: third person (top-down) while exploring; using an Interactable
## with a view point hard-cuts to first person until the player steps back. In the
## Visitor's opening (Level.visitor_opening) they walk in first person instead: mouse look,
## slow steps, the camera at the head, until set_first_person(false).
##
## Combat: hold aim (right mouse) to turn toward the cursor, armed or not. Armed, the pistol
## comes up with its laser and fire shoots; with nothing raised, fire (or shove, F) pushes
## whatever is in front. The owner spends ammo locally; the server raycasts the shot and
## applies the damage.
##
## Cold: the Visitor loses warmth in cold zones and freezes at zero. The Subject
## never does; its HUD reads a steady 36.6 °C no matter what (it is not human).

const WALK_SPEED := 4.0
const AIM_SPEED := 1.5
const TURN_SPEED := 12.0
## How quickly the top-down camera glides to its target (player, or a room's framing).
const CAMERA_FOLLOW := 5.0
## Farther than this and the camera cuts instead of gliding (respawn, room-to-room teleport).
const CAMERA_SNAP_DISTANCE := 12.0
## The top-down camera looks down 60 degrees from this far away (CameraZones can pull it back).
const CAMERA_DISTANCE := 18.0
const CAMERA_DIRECTION := Vector3(0, 0.866025, 0.5)
const CUT_FADE_TIME := 0.12
const MAX_HEALTH := 100
const MAGAZINE_SIZE := 6
const FIRE_COOLDOWN := 0.35
const RELOAD_TIME := 0.9
const SHOT_RANGE := 25.0
const SHOT_DAMAGE := 10
const SHOT_MASK := 11 # physics layers 1 + 2 + 4: world, enemies and players (friendly fire)
## How far noises carry to enemies (metres): each footstep, each shot.
const STEP_NOISE := 4.0
const GUNSHOT_NOISE := 24.0
## The shove: reach, cone (degrees either side), knockback, and how often.
const SHOVE_RANGE := 1.6
const SHOVE_ANGLE := 70.0
const SHOVE_COOLDOWN := 0.8
const SHOVED_SPEED := 4.0
## Seconds the dead player watches themselves fall before the screen goes black.
const DEATH_WATCH := 0.6
## Seconds a collapsed player stays out before waking by a lamp.
const COLLAPSE_TIME := 1.2
## The first-person moment inside the respawn pod.
const POD_BEAT := 1.8
## Black and silence after the entrance doors come down, before the pod.
const CRUSH_SILENCE := 4.0
const MAX_WARMTH := 100.0
const FREEZING_DAMAGE_PER_SECOND := 4.0
const NORMAL_BODY_TEMPERATURE := 36.6
## Metres walked per footstep sound.
const STRIDE := 1.7
const ZONE_LAYER := 32 # physics layer 6, "zones"
const FROZEN_BODY_TEMPERATURE := 29.0
## Render layer 10, "players": everything that shows a player is drawn on it alone, so no
## CCTV camera (CctvBank leaves it out) can ever show the partner.
const VISUAL_LAYER := 1 << 9
## Walking in first person: slow, heavy steps (deep snow), mouse look, a little head bob.
const FIRST_PERSON_SPEED := 2.2
const LOOK_SENSITIVITY := 0.0025
const MAX_PITCH := 1.3
const HEAD_BOB := 0.035
## Going through a door by hand: how far past the doorway you end up, and the longest it
## may take before giving up (something in the way).
const PASS_BEYOND := 1.7
## Seconds the screen takes to go black as they walk into a way down (WayDown).
const LEAVE_FADE := 1.6
const PASS_TIMEOUT := 4.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var role := Session.Role.NONE
var feels_cold := false

# Synced from the owner to the other peer.
var health := MAX_HEALTH
var is_aiming := false
## Synced: whether this player's radio is switched on (special enemies track radios).
var radio_on := true

# Only meaningful on the owning peer.
var inventory := Inventory.new()
## The weapon in hand ("" for none). Only an equipped weapon can be raised and fired.
var equipped := ""
## Personal storage, opened from any item box.
var stash := Inventory.new(ItemBox.STASH_SLOTS)
var loaded_rounds := 0
## Documents read (ids, see Documents) and floor plans found (area -> name). Each player
## keeps their own: what one knows, the other only hears about.
var files: Array[String] = []
var maps := {}
## Rooms this player has been in (MapRoom paths from the level): brighter on the MAP.
var visited := {}
var _visit_check := 0.0
## The joint save screen (only the local player has one in its overlay).
var save_prompt := SavePrompt.new()
var warmth := MAX_WARMTH
var _freeze_damage := 0.0
var _warned_cold := false
var is_dead := false
## Gone down a way out of the level (WayDown), on every peer: out of play behind the black
## screen, so nothing left behind (husks, the cold) can touch them.
var gone_down := false
## The Interactable this player is looking at in first person, or null.
var focus: Interactable = null
var _cutting := false
var _in_cutaway := false
var _reloading := false
var _fire_cooldown := 0.0
var _tracer_material := StandardMaterial3D.new()
var _last_position := Vector3.ZERO
var _listener := AudioListener3D.new()
var _camera_distance := CAMERA_DISTANCE
var _stride_left := STRIDE
var _last_health := MAX_HEALTH
## Waiting out a reload (the partner died): black screen, standing still.
var _reload_wait := false
var _partner_save_status := SaveGame.Status.AWAY
var _shove_cooldown := 0.0
## A shove from the partner: pushed back, fading out.
var _knockback := Vector3.ZERO
## Walking in first person (the Visitor's opening) instead of the top-down view.
var walking_first_person := false
## The handheld's screen is cracked (the Visitor's opening; the copy's is whole).
var handheld_cracked := false
var _pitch := 0.0
var _bob := 0.0
var _opening_applied := false
var _wake_checked := false
## Driving snow around the local player in a blizzard (EnvironmentZone.snowfall).
var _snow := Snowfall.new()
## The room the local player is in: its shroud is lifted, every other room is black.
var _room: RoomShroud = null
## The last room framing the camera held, and the room it was in then (kept through the
## doorway out, until the next room).
var _camera_zone: CameraZone = null
var _camera_room: RoomShroud = null
## Walking through a door on its own (pass_through): the points still to reach.
var _passing := false
var _pass_path: Array[Vector3] = []
var _pass_time := 0.0

@onready var model: CharacterModel = $Model
@onready var nameplate: Label3D = $Nameplate
@onready var interaction_area: Area3D = $InteractionArea
@onready var zone_probe: Area3D = $ZoneProbe
@onready var laser_pivot: Node3D = $LaserPivot
@onready var laser: MeshInstance3D = $LaserPivot/Laser
@onready var aim_ray: RayCast3D = $LaserPivot/AimRay
@onready var camera_rig: Node3D = $CameraRig
@onready var third_person_camera: Camera3D = $CameraRig/ThirdPersonCamera
@onready var overlay: CanvasLayer = $CameraRig/Overlay
@onready var hud: PlayerHud = $CameraRig/Overlay/Hud
@onready var inventory_screen: InventoryScreen = $CameraRig/Overlay/InventoryScreen
@onready var hurt_flash: ColorRect = $CameraRig/Overlay/HurtFlash
@onready var fade: ColorRect = $CameraRig/Overlay/Fade
@onready var first_person_camera: Camera3D = $FirstPersonCamera
@onready var head_transform: Transform3D = first_person_camera.transform


func _enter_tree() -> void:
	# The node is named after its peer id by the spawner; that peer drives it.
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	add_to_group("players")
	aim_ray.add_exception(self)
	model.visual_layers = VISUAL_LAYER
	nameplate.layers = VISUAL_LAYER
	laser.layers = VISUAL_LAYER
	_apply_role()
	# A player that already existed when the partner joined may arrive before the role table.
	Session.roles_changed.connect(_apply_role)
	_tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tracer_material.albedo_color = Color(1, 0.9, 0.6)
	print("[player] %s ready on peer %d (%s)" % [name, multiplayer.get_unique_id(),
			"local" if is_multiplayer_authority() else "remote"])

	if is_multiplayer_authority():
		# The world renders at low res; move the HUD and fades out to the window itself
		# so they stay sharp. They are no longer our children, so _exit_tree frees them.
		overlay.add_child(save_prompt)
		overlay.reparent(get_tree().root, false)
		third_person_camera.make_current()
		# Hear the world from the character (not the camera, which may be framing a room),
		# oriented like the screen: up = north.
		_listener.top_level = true
		add_child(_listener)
		_listener.make_current()
		inventory.changed.connect(_refresh_hud)
		_refresh_hud()
		SaveGame.statuses_changed.connect(_on_save_statuses)
		# Continuing a save: the server puts us where the save has us.
		SaveGame.request_player_state.call_deferred()
		_begin_opening.call_deferred()
		_begin_wake.call_deferred()
		_snow.top_level = true
		add_child(_snow)
	else:
		# Remote players are positioned by the synchronizer, not simulated or controlled here.
		# Nor drawn: the two never see each other, not even past a wall the top-down camera
		# looks over (docs/design.md, two worlds). Their sounds still carry.
		model.visible = false
		set_physics_process(false)
		set_process_unhandled_input(false)
		camera_rig.queue_free()
		interaction_area.queue_free()
		zone_probe.queue_free()
		_listener.free() # never entered the tree; only the local player listens
		_snow.free()


func _exit_tree() -> void:
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_multiplayer_authority() and is_instance_valid(overlay) and overlay.get_parent() == get_tree().root:
		overlay.queue_free()
		Retro.set_condition(0.0, 0.0)
		Radio.local_interference = 0.0


func _apply_role() -> void:
	role = Session.role_of(name.to_int())
	feels_cold = role == Session.Role.VISITOR
	nameplate.text = Session.ROLE_NAMES[role]
	# No name floats over anyone: you know who you are, and the partner is never in view.
	nameplate.visible = false
	# This machine's interface: ZP-SYS for the Subject, the handheld for the Visitor. (Roles
	# reset to none as a session ends, while the HUD is already being freed.)
	if is_multiplayer_authority() and role != Session.Role.NONE and is_instance_valid(hud) and hud.is_inside_tree():
		UiStyle.use(role)
		hud.apply_style()
	model.look = CharacterModel.Look.SUBJECT if role == Session.Role.SUBJECT else CharacterModel.Look.VISITOR
	if is_multiplayer_authority() and is_node_ready():
		_begin_opening.call_deferred() # the role may only now be known
		_begin_wake.call_deferred()


## The Visitor's opening (Level.visitor_opening): outside, on foot in first person, the
## handheld cracked. Once per spawn; a loaded save (restore) has the last word.
func _begin_opening() -> void:
	if _opening_applied or role != Session.Role.VISITOR or not is_inside_tree():
		return
	var level := get_tree().get_first_node_in_group("level") as Level
	if level and level.visitor_opening:
		_opening_applied = true
		set_first_person(true)
		set_handheld_cracked(true)


## The Subject's wake (SubjectWake), once per spawn: not when continuing a save, which
## starts after it, nor once it has played.
func _begin_wake() -> void:
	if _wake_checked or role != Session.Role.SUBJECT or not is_inside_tree():
		return
	_wake_checked = true
	var wake := get_tree().get_first_node_in_group("subject_wake") as SubjectWake
	if wake and not wake.done and SaveGame.pending.is_empty():
		wake.play_for(self)


## A scripted first-person moment (SubjectWake): from black, held at `view` until
## end_scene_view(). The fade is the caller's.
func begin_scene_view(view: Transform3D) -> void:
	_in_cutaway = true
	fade.color.a = 1.0
	_view_first_person(view)


## Cuts back to the player's own view, standing at `at`.
func end_scene_view(at: Transform3D) -> void:
	await _cut(func() -> void:
		global_position = at.origin
		rotation.y = at.basis.get_euler().y
		camera_rig.global_position = global_position
		_view_third_person()
	)
	_in_cutaway = false


## Through a door just opened by hand (Door.use): wait for it to sink, walk to the
## doorway and out the far side. The door shuts behind once the doorway is clear.
func pass_through(door: Door) -> void:
	if _passing or not is_multiplayer_authority():
		return
	_passing = true
	_pass_time = 0.0
	_pass_path.clear()
	var side := signf(door.to_local(global_position).x)
	if side == 0.0:
		side = 1.0
	var doorway := door.frame_position()
	doorway.y = global_position.y
	var across := door.global_basis.x.normalized() * -side
	await get_tree().create_timer(Door.MOVE_TIME * 0.6).timeout
	_pass_path.assign([doorway - across * 0.2, doorway + across * PASS_BEYOND])


## Up or down a flight (Stairs): a few steps into it, a cut through black, and out at the
## other end, a storey away.
func take_stairs(stairs: Stairs) -> void:
	if _passing or not is_multiplayer_authority():
		return
	_passing = true
	_pass_time = Door.MOVE_TIME # nothing to wait for: start walking at once
	var into := stairs.global_transform * Vector3(0, 0, Stairs.WALK_IN)
	into.y = global_position.y
	_pass_path.assign([into])
	await get_tree().create_timer(Stairs.DARK).timeout
	var exit := stairs.other.exit_transform()
	await _cut(func() -> void:
		global_position = exit.origin
		rotation.y = exit.basis.get_euler().y
		velocity = Vector3.ZERO
		camera_rig.global_position = global_position
	)
	_pass_path.clear()
	_passing = false


## The way to walk this frame while passing through a door (zero while it opens).
func _pass_step(delta: float) -> Vector3:
	_pass_time += delta
	if _pass_time > PASS_TIMEOUT:
		_pass_path.clear()
	if _pass_path.is_empty():
		_passing = _pass_time < Door.MOVE_TIME * 0.6 + 0.1 # still waiting for the door
		return Vector3.ZERO
	var to := _pass_path[0] - global_position
	to.y = 0.0
	if to.length() < 0.2:
		_pass_path.remove_at(0)
		if _pass_path.is_empty():
			_passing = false
		return Vector3.ZERO
	return to.normalized()


## On foot in first person (the Visitor's opening), or back to the top-down view.
func set_first_person(on: bool) -> void:
	walking_first_person = on
	_pitch = 0.0
	if is_multiplayer_authority() and not focus and not _in_cutaway:
		_view_third_person()


## The handheld's screen: cracked across, or whole.
func set_handheld_cracked(cracked: bool) -> void:
	handheld_cracked = cracked
	inventory_screen.set_cracked(cracked)


func _unhandled_input(event: InputEvent) -> void:
	if (_cutting or _in_cutaway or is_dead or inventory_screen.visible or _pause_menu_open()
			or save_prompt.visible or _reload_wait):
		return
	if event is InputEventMouseMotion and walking_first_person and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * LOOK_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * LOOK_SENSITIVITY, -MAX_PITCH, MAX_PITCH)
		first_person_camera.rotation.x = _pitch
		return
	if focus:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_exit_focus()
		return

	if event.is_action_pressed("interact"):
		var target := _find_interactable()
		if target:
			get_viewport().set_input_as_handled()
			_use(target)
	elif event.is_action_pressed("fire") and is_aiming:
		if armed():
			_try_fire()
		else:
			_shove() # nothing in hand: the hands push
	elif event.is_action_pressed("reload"):
		_reload()
	elif event.is_action_pressed("shove") and is_aiming:
		_shove()
	elif event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		open_inventory()


func _process(delta: float) -> void:
	_update_footsteps()
	_update_model()
	if is_multiplayer_authority():
		_update_mouse()
		_room = RoomShroud.update(get_tree(), global_position, _room)
		_visit_check -= delta
		if _visit_check <= 0.0:
			_visit_check = 0.5
			_note_visited_room()
	# Runs on every peer so the partner sees your laser too.
	laser.visible = is_aiming and armed() and is_multiplayer_authority()
	if laser.visible:
		var length := SHOT_RANGE
		if aim_ray.is_colliding():
			length = laser_pivot.global_position.distance_to(aim_ray.get_collision_point())
		laser.scale.z = length
		laser.position.z = -length / 2.0


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	_shove_cooldown = maxf(_shove_cooldown - delta, 0.0)
	radio_on = Radio.powered

	var frozen := (focus != null or _cutting or _in_cutaway or is_dead or inventory_screen.visible
			or _pause_menu_open() or save_prompt.visible or _reload_wait or _passing)
	var input := Vector2.ZERO if frozen else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if model.pose == CharacterModel.Pose.WAITING and input != Vector2.ZERO:
		_set_waiting.rpc(false) # done waiting: stand up
	is_aiming = not frozen and not walking_first_person and Input.is_action_pressed("aim")
	var raised := is_aiming and armed()
	hud.set_ammo(raised, "%s  %d / %d" % [Items.display_name(equipped).to_upper(), loaded_rounds,
			inventory.count_of("ammo")] if raised else "")
	hud.set_radio(Radio.status_text())
	Radio.listener_position = global_position
	_update_condition()
	var speed := AIM_SPEED if is_aiming else WALK_SPEED
	# The top-down camera never rotates, so screen-up is always world -Z. In first person,
	# forward is where they look.
	var direction := Vector3(input.x, 0.0, input.y)
	if walking_first_person:
		direction = global_basis * direction
		speed = FIRST_PERSON_SPEED
	if _passing:
		direction = _pass_step(delta)
		speed = WALK_SPEED * 0.8
	velocity.x = direction.x * speed + _knockback.x
	velocity.z = direction.z * speed + _knockback.z
	_knockback = _knockback.lerp(Vector3.ZERO, 1.0 - exp(-8.0 * delta))
	move_and_slide()
	if walking_first_person and first_person_camera.current and not focus and not _in_cutaway:
		var pace := Vector2(velocity.x, velocity.z).length()
		_bob += pace * delta * 2.4
		first_person_camera.position.y = head_transform.origin.y + sin(_bob) * HEAD_BOB * minf(pace / FIRST_PERSON_SPEED, 1.0)

	var look_direction := _get_aim_direction() if is_aiming else direction
	if not walking_first_person and look_direction.length_squared() > 0.001:
		var target_yaw := atan2(-look_direction.x, -look_direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, TURN_SPEED * delta)

	_update_camera(delta)
	_update_warmth(delta)
	_update_environment()
	_update_prompt()


# --- Interaction & perspective ---------------------------------------------

## The top-down camera follows the player, except inside a CameraZone, where it holds that
## room's framing (Signalis-style fixed compositions). It keeps the framing through the
## doorway out, and only moves on once they're in the next room (RoomShroud), as its
## lights come on.
func _update_camera(delta: float) -> void:
	var target := global_position
	var distance := CAMERA_DISTANCE
	var zone: CameraZone = null
	for area in zone_probe.get_overlapping_areas():
		if area is CameraZone:
			zone = area
	if is_instance_valid(_camera_zone) and _room == _camera_room and _near_zone(_camera_zone):
		zone = _camera_zone # same room, or its doorway: not in the next room yet
	elif zone:
		_camera_zone = zone
		_camera_room = _room
	if zone:
		target = zone.focus_point()
		distance = zone.distance
	var blend := 1.0 - exp(-CAMERA_FOLLOW * delta)
	if camera_rig.global_position.distance_to(target) > CAMERA_SNAP_DISTANCE:
		camera_rig.global_position = target
		_camera_distance = distance
	else:
		camera_rig.global_position = camera_rig.global_position.lerp(target, blend)
		_camera_distance = lerpf(_camera_distance, distance, blend)
	third_person_camera.position = CAMERA_DIRECTION * _camera_distance
	_listener.global_position = global_position + Vector3.UP * 1.5
	# Top-down, up on screen is north; in first person, you hear the way you face.
	_listener.global_basis = global_basis if walking_first_person else Basis()


## Within a doorway's reach of the zone's box: just stepped out of it, not walked off.
func _near_zone(zone: CameraZone) -> bool:
	for child in zone.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			var local: Vector3 = zone.global_transform.affine_inverse() * global_position
			var half: Vector3 = (child.shape as BoxShape3D).size / 2.0 + Vector3.ONE * 2.0
			return absf(local.x) < half.x and absf(local.z) < half.z
	return false


## Walking in first person the mouse is captured for looking around, and freed for any
## screen, menu or console.
func _update_mouse() -> void:
	var look := walking_first_person and not (focus or _cutting or _in_cutaway or is_dead
			or inventory_screen.visible or _pause_menu_open() or save_prompt.visible or _reload_wait)
	var mode := Input.MOUSE_MODE_CAPTURED if look else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode


func _use(target: Interactable) -> void:
	model.play_gesture("interact")
	_play_gesture.rpc("interact")
	if target.view_point:
		_enter_focus(target)
	else:
		target.interact(self)


func _enter_focus(target: Interactable) -> void:
	focus = target
	await _cut(func() -> void:
		_view_first_person(target.view_point.global_transform)
		target.has_local_focus = true
	)
	target.interact(self)


func _exit_focus() -> void:
	var target := focus
	target.has_local_focus = false
	focus = null
	await _cut(func() -> void:
		_view_third_person()
	)


## A story beat: hard cut to a first-person view for `duration` seconds, then back.
## Local only; StoryTrigger asks each peer's own player to play it.
func play_cutaway(view: Transform3D, duration: float) -> void:
	if focus or _cutting or _in_cutaway or is_dead:
		return
	_in_cutaway = true
	await _cut(func() -> void:
		_view_first_person(view)
	)
	await get_tree().create_timer(duration).timeout
	await _cut(func() -> void:
		_view_third_person()
	)
	_in_cutaway = false


func head_position() -> Vector3:
	return global_position + Vector3.UP * 1.6


func _view_first_person(view: Transform3D) -> void:
	first_person_camera.global_transform = view
	first_person_camera.make_current()
	_set_own_body_visible(false)


## Back to the player's own view: top-down, or the head when walking in first person.
func _view_third_person() -> void:
	first_person_camera.transform = head_transform
	if walking_first_person:
		first_person_camera.rotation.x = _pitch
		first_person_camera.make_current()
		_set_own_body_visible(false)
		return
	third_person_camera.make_current()
	_set_own_body_visible(true)


## Hidden on this machine only while in first person, so you never see your own back.
func _set_own_body_visible(shown: bool) -> void:
	model.visible = shown


## Hard cut through black, Signalis-style: fade out, `swap`, fade in.
func _cut(swap: Callable) -> void:
	_cutting = true
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, CUT_FADE_TIME)
	tween.tween_callback(swap)
	tween.tween_property(fade, "color:a", 0.0, CUT_FADE_TIME)
	await tween.finished
	_cutting = false


func _find_interactable() -> Interactable:
	var nearest: Interactable = null
	var nearest_distance := INF
	for area in interaction_area.get_overlapping_areas():
		# Something with nothing to offer right now (an open door) isn't a target.
		if area is Interactable and area.get_prompt(self) != "":
			var point: Vector3 = area.interaction_point()
			var distance := Vector2(global_position.x, global_position.z).distance_squared_to(Vector2(point.x, point.z))
			if distance < nearest_distance:
				nearest = area
				nearest_distance = distance
	return nearest


func _update_prompt() -> void:
	if inventory_screen.visible:
		hud.set_prompt("")
		return
	if focus:
		hud.set_prompt("[E / Esc] Step back")
		return
	var target := _find_interactable()
	if target:
		hud.set_prompt("[E] %s" % target.get_prompt(self))
	elif _enemy_near():
		if not is_aiming:
			hud.set_prompt("[Right mouse] Aim")
		elif not armed():
			hud.set_prompt("[F / Click] Shove")
		else:
			hud.set_prompt("[Click] Fire   [F] Shove")
	else:
		hud.set_prompt("")


## An enemy up and close enough to be worth shoving (the prompt says how).
func _enemy_near() -> bool:
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.state != Enemy.State.DOWNED and enemy.global_position.distance_to(global_position) < SHOVE_RANGE + 1.5:
			return true
	return false


## Direction from the player to the mouse cursor on the player's floor plane.
func _get_aim_direction() -> Vector3:
	var mouse := get_viewport().get_mouse_position()
	var ray_origin := third_person_camera.project_ray_origin(mouse)
	var ray_normal := third_person_camera.project_ray_normal(mouse)
	var hit: Variant = Plane(Vector3.UP, global_position.y).intersects_ray(ray_origin, ray_normal)
	if hit == null:
		return Vector3.ZERO
	var direction: Vector3 = hit - global_position
	direction.y = 0.0
	return direction


# --- Inventory ---------------------------------------------------------------

func request_pickup(pickup: Pickup) -> void:
	if inventory.space_for(pickup.item_id) < pickup.count:
		notify("Inventory full")
		return
	_request_pickup.rpc_id(1, pickup.get_path())


@rpc("any_peer", "call_local", "reliable")
func _request_pickup(pickup_path: NodePath) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	var pickup := get_node_or_null(pickup_path) as Pickup
	if pickup == null or pickup.is_queued_for_deletion():
		return
	_receive_item.rpc_id(get_multiplayer_authority(), pickup.item_id, pickup.count)
	pickup.queue_free() # WorldSpawner despawns it on the other peer


@rpc("any_peer", "call_local", "reliable")
func _receive_item(id: String, count: int) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	var leftover := inventory.add(id, count)
	Sound.play_ui("pickup")
	if leftover > 0:
		push_warning("Inventory overflowed by %d %s" % [leftover, id])
	notify("Took %s" % Items.display_name(id))


## Opens the ZP-SYS terminal: plain (Tab), on an item box's stash, or on a tube to send from.
func open_inventory(target: Variant = null) -> void:
	if focus or _cutting or _in_cutaway or is_dead or inventory_screen.visible:
		return
	inventory_screen.open(self, target)


func close_inventory() -> void:
	inventory_screen.close()


func send_slot_through_tube(index: int, tube: ItemTube) -> void:
	var slot := inventory.take_slot(index)
	if slot.is_empty():
		return
	tube.request_send.rpc_id(1, slot["id"], slot["count"])
	if slot["id"] == "pistol":
		_unload_into(func(count: int) -> void: tube.request_send.rpc_id(1, "ammo", count))
	notify("Sent %s" % Items.display_name(slot["id"]))


## Terminal "Use": med kits heal, rounds reload the equipped weapon.
func use_slot(index: int) -> void:
	var slot := inventory.slots[index]
	if slot.is_empty():
		return
	match slot["id"]:
		"medkit":
			if health >= MAX_HEALTH:
				notify("Already at full health")
				return
			inventory.remove_from(index, 1)
			health = mini(health + Items.get_value("medkit", "heal", 50), MAX_HEALTH)
			Sound.play_ui("pickup", -6.0, 0.7)
			notify("Patched up")
		"ammo":
			_reload()
		_:
			notify("Can't use that here")
	_refresh_hud()


func equip_slot(index: int) -> void:
	var slot := inventory.slots[index]
	if slot.is_empty() or Items.kind(slot["id"]) != "weapon":
		return
	equipped = "" if equipped == slot["id"] else String(slot["id"])
	Sound.play_ui("reload", -8.0, 1.3)
	notify("Equipped %s" % Items.display_name(equipped) if equipped else "Unequipped")
	_refresh_hud()


## Terminal "Combine": rounds + pistol loads it; two stacks of the same item merge.
func combine_slots(a: int, b: int) -> void:
	var first := inventory.slots[a]
	var second := inventory.slots[b]
	if a == b or first.is_empty() or second.is_empty():
		return
	match Items.combination(first["id"], second["id"]):
		"load":
			var needed: int = Items.get_value("pistol", "magazine", MAGAZINE_SIZE) - loaded_rounds
			if needed <= 0:
				notify("Already fully loaded")
				return
			loaded_rounds += inventory.remove_from(a if first["id"] == "ammo" else b, needed)
			Sound.play_ui("reload")
			notify("Loaded")
		"merge":
			var moved := mini(first["count"], Items.max_stack(second["id"]) - second["count"])
			if moved <= 0:
				notify("No room to combine")
				return
			second["count"] += moved
			inventory.remove_from(a, moved)
		_:
			notify("Those don't go together")
	_refresh_hud()


## Terminal "Drop": the item lands at your feet for anyone (your partner) to pick up.
func drop_slot(index: int) -> void:
	var slot := inventory.take_slot(index)
	if slot.is_empty():
		return
	var at := global_position - global_basis.z * 0.7
	_request_drop.rpc_id(1, slot["id"], slot["count"], at)
	if slot["id"] == "pistol":
		_unload_into(func(count: int) -> void: _request_drop.rpc_id(1, "ammo", count, at + Vector3(0.4, 0, 0)))
	notify("Dropped %s" % Items.display_name(slot["id"]))


@rpc("any_peer", "call_local", "reliable")
func _request_drop(id: String, count: int, at: Vector3) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	if not Items.exists(id) or count <= 0:
		return
	var level := get_tree().get_first_node_in_group("level") as Level
	level.spawn_world_object(ItemTube.PICKUP_SCENE, Transform3D(Basis(), at), {"item_id": id, "count": count})


## Item box: move a carried slot into the stash.
func store_slot(index: int, box: Inventory) -> void:
	var slot := inventory.slots[index]
	if slot.is_empty():
		return
	if box.space_for(slot["id"]) < slot["count"]:
		notify("The box is full")
		return
	inventory.take_slot(index)
	box.add(slot["id"], slot["count"])
	if slot["id"] == "pistol":
		_unload_into(func(count: int) -> void: box.add("ammo", count))


## Item box: move a stash slot back into your hands.
func take_from_box(index: int, box: Inventory) -> void:
	var slot := box.slots[index]
	if slot.is_empty():
		return
	if inventory.space_for(slot["id"]) < slot["count"]:
		notify("No room to carry that")
		return
	box.take_slot(index)
	inventory.add(slot["id"], slot["count"])


## When the gun leaves your hands, its loaded rounds go with it (as loose rounds).
func _unload_into(put: Callable) -> void:
	if equipped == "pistol":
		equipped = ""
	if loaded_rounds > 0:
		put.call(loaded_rounds)
		loaded_rounds = 0
	_refresh_hud()


# --- Saving and reloading (see SaveGame) ----------------------------------------------

## Marks the MapRoom this player stands in as visited.
func _note_visited_room() -> void:
	var level := get_tree().get_first_node_in_group("level") as Level
	if level == null:
		return
	for room: MapRoom in get_tree().get_nodes_in_group("map_rooms"):
		if room.contains(global_position):
			visited[String(level.get_path_to(room))] = true


func visited_room(room: MapRoom) -> bool:
	var level := get_tree().get_first_node_in_group("level") as Level
	return level != null and visited.has(String(level.get_path_to(room)))


## A floor plan: its area goes on this player's map, and the map opens on it.
func learn_map(area: String, area_name: String) -> void:
	if not maps.has(area):
		maps[area] = area_name
		Sound.play_ui("pickup", -6.0, 0.8)
	open_inventory()
	inventory_screen.show_tab("map")


## A document: kept in FILES, and opened there to read.
func read_document(doc_id: String) -> void:
	if not Documents.exists(doc_id):
		return
	if doc_id not in files:
		files.append(doc_id)
	Sound.play_ui("pickup", -10.0, 1.3)
	open_inventory()
	inventory_screen.show_tab("files", doc_id)


func open_save_prompt(terminal: SaveTerminal) -> void:
	if (focus and focus != terminal) or _cutting or _in_cutaway or is_dead or inventory_screen.visible:
		return
	save_prompt.open(self, terminal)


## Out of first person at `target` (the save screen closing), unless something else (a death,
## a reload) is already taking over the view.
func leave_focus(target: Interactable) -> void:
	if focus == target and not is_dead and not _reload_wait:
		_exit_focus()


## What a save keeps of this player (sent when confirming at a terminal).
func save_state() -> Dictionary:
	return {
		"inventory": inventory.slots.duplicate(true), "stash": stash.slots.duplicate(true),
		"equipped": equipped, "loaded_rounds": loaded_rounds, "health": health, "warmth": warmth,
		"files": files.duplicate(), "maps": maps.duplicate(), "visited": visited.keys(),
		"first_person": walking_first_person, "cracked": handheld_cracked,
	}


## Server -> owner: put this player back as `state` has it (empty: as at the chapter start)
## at `at`. Modes: "start" (continuing a save), "pod" (died: wake in the respawn pod),
## "respawn" (died before any save: back at the start), "waiting" (the partner died: back
## at the save room, sitting).
@rpc("any_peer", "call_local", "reliable")
func restore(state: Dictionary, at: Transform3D, mode: String) -> void:
	if multiplayer.get_remote_sender_id() != 1 or not is_multiplayer_authority():
		return
	_fill(inventory, state.get("inventory", []))
	_fill(stash, state.get("stash", []))
	equipped = state.get("equipped", "")
	loaded_rounds = state.get("loaded_rounds", 0)
	health = state.get("health", MAX_HEALTH)
	warmth = state.get("warmth", MAX_WARMTH)
	files.assign(state.get("files", []))
	maps = (state.get("maps", {}) as Dictionary).duplicate()
	visited.clear()
	for path in state.get("visited", []):
		visited[path] = true
	_last_health = health
	is_dead = false
	_reload_wait = false
	if gone_down:
		_set_gone_down.rpc(false)
	if inventory_screen.visible:
		close_inventory()
	save_prompt.close(false)
	if focus:
		focus.has_local_focus = false
		focus = null
	global_position = at.origin
	rotation.y = at.basis.get_euler().y
	velocity = Vector3.ZERO
	camera_rig.global_position = global_position
	set_handheld_cracked(state.get("cracked", false))
	set_first_person(state.get("first_person", false))
	if state.is_empty():
		# Back as at the chapter start, the opening included.
		_opening_applied = false
		_begin_opening()
	_refresh_hud()
	if mode == "start":
		return
	_set_waiting.rpc(mode == "waiting")
	if mode == "pod":
		_wake_in_pod(at, 0.8, "death")
	else:
		_view_third_person()
		create_tween().tween_property(fade, "color:a", 0.0, 1.2)


## From black: inside the pod at `at`, looking out through the glass, then step out.
func _wake_in_pod(at: Transform3D, fade_in: float, line: String) -> void:
	_in_cutaway = true
	_view_first_person(Transform3D(at.basis, at.origin + at.basis.z * 0.9 + Vector3.UP * 1.55))
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, fade_in)
	tween.tween_interval(POD_BEAT)
	tween.tween_callback(func() -> void:
		_view_third_person()
		_in_cutaway = false
		if line:
			Story.show_local(line)
	)


## Server -> the Visitor (EntranceCrush): the entrance doors came down on them. A hard cut
## to black and silence; then they wake in the pod at `at`, printed: in third person, the
## handheld whole, as if the facility always had their pattern. Nothing remarks on it.
@rpc("any_peer", "call_local", "reliable")
func reprint_after_crush(at: Transform3D) -> void:
	if multiplayer.get_remote_sender_id() != 1 or not is_multiplayer_authority():
		return
	_reload_wait = true
	fade.color.a = 1.0
	if inventory_screen.visible:
		close_inventory()
	save_prompt.close(false)
	if focus:
		focus.has_local_focus = false
		focus = null
	# Out of the doorway at once: what's under the doors is the body, not us.
	velocity = Vector3.ZERO
	global_position = at.origin
	rotation.y = at.basis.get_euler().y
	camera_rig.global_position = global_position
	warmth = MAX_WARMTH
	await get_tree().create_timer(CRUSH_SILENCE).timeout
	set_handheld_cracked(false)
	set_first_person(false)
	_reload_wait = false
	_wake_in_pod(at, 2.0, "")


func _fill(target: Inventory, slots: Array) -> void:
	for i in target.slots.size():
		target.slots[i] = (slots[i] as Dictionary).duplicate() if i < slots.size() else {}
	target.changed.emit()


## Gone down a way out of the level (WayDown): they walk on to `walk_to` (into the lift,
## down the first steps) as the screen goes black, then wait there, still and silent, for
## the partner to follow. Out of play from now on: nothing in the level can hurt them.
func leave_level(walk_to: Variant = null) -> void:
	_set_gone_down.rpc(true)
	if walk_to is Vector3 and is_multiplayer_authority():
		_passing = true
		_pass_time = Door.MOVE_TIME # nothing to wait for: start walking at once
		var into: Vector3 = walk_to
		into.y = global_position.y
		_pass_path.assign([into])
	wait_for_reload(LEAVE_FADE)


@rpc("authority", "call_local", "reliable")
func _set_gone_down(gone: bool) -> void:
	gone_down = gone


## The partner died: this screen goes black too, while the server reloads the save.
func wait_for_reload(fade_time := 1.0) -> void:
	_reload_wait = true
	if inventory_screen.visible:
		close_inventory()
	save_prompt.close(false)
	create_tween().tween_property(fade, "color:a", 1.0, fade_time)


@rpc("authority", "call_local", "reliable")
func _set_waiting(waiting: bool) -> void:
	model.pose = CharacterModel.Pose.WAITING if waiting else CharacterModel.Pose.LIVE


## Tells this player when the partner goes to a save terminal while they are elsewhere.
func _on_save_statuses() -> void:
	var partner := SaveGame.partner_status()
	if partner != _partner_save_status and not save_prompt.visible:
		if partner == SaveGame.Status.AT_TERMINAL:
			notify("Your partner is at a save terminal")
		elif partner == SaveGame.Status.READY:
			notify("Your partner is ready to save. Find a save terminal")
	_partner_save_status = partner


## A short message for this player: on the terminal's hint line while it's open, else on the HUD.
func notify(text: String) -> void:
	if inventory_screen.visible:
		inventory_screen.show_notice(text)
	else:
		hud.show_message(text)


func _pause_menu_open() -> bool:
	var main := get_tree().get_first_node_in_group("main")
	return main != null and main.menu_open


func _refresh_hud() -> void:
	if equipped and not inventory.has(equipped):
		equipped = ""
	inventory_screen.refresh()


## Damage and cold show on screen (red / frost vignettes), not as bars.
func _update_condition() -> void:
	var hurt := clampf((0.66 - float(health) / MAX_HEALTH) / 0.66, 0.0, 1.0)
	var cold := clampf((0.6 - warmth / MAX_WARMTH) / 0.6, 0.0, 1.0) if feels_cold else 0.0
	Retro.set_condition(hurt, cold)


# --- Combat ------------------------------------------------------------------

func _try_fire() -> void:
	if _fire_cooldown > 0.0 or _reloading:
		return
	if loaded_rounds == 0:
		notify("Empty  [R] reload")
		Sound.play_ui("gun_empty")
		return
	loaded_rounds -= 1
	_fire_cooldown = FIRE_COOLDOWN
	_refresh_hud()
	_request_shot.rpc_id(1, laser_pivot.global_position, -global_basis.z)


func _reload() -> void:
	if _reloading or loaded_rounds == MAGAZINE_SIZE or not inventory.has("pistol"):
		return
	if not inventory.has("ammo"):
		notify("No ammo")
		return
	_reloading = true
	Sound.play_ui("reload")
	notify("Reloading...")
	get_tree().create_timer(RELOAD_TIME).timeout.connect(_finish_reload)


func _finish_reload() -> void:
	loaded_rounds += inventory.remove("ammo", MAGAZINE_SIZE - loaded_rounds)
	_reloading = false
	_refresh_hud()


@rpc("any_peer", "call_local", "reliable")
func _request_shot(origin: Vector3, direction: Vector3) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	Enemy.make_noise(get_tree(), origin, GUNSHOT_NOISE)
	var end := origin + direction.normalized() * SHOT_RANGE
	var query := PhysicsRayQueryParameters3D.create(origin, end, SHOT_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		end = hit["position"]
		var target: Object = hit["collider"]
		if target is Enemy:
			target.take_damage(SHOT_DAMAGE, self)
		elif target is Player:
			target.take_damage.rpc_id(target.get_multiplayer_authority(), SHOT_DAMAGE)
			Story.play_once("friendly_fire")
	_show_shot.rpc(origin, end)


@rpc("any_peer", "call_local", "unreliable")
func _show_shot(from: Vector3, to: Vector3) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	model.play_shot()
	# Loud and far-reaching: the partner hears your fights, muffled, from other rooms.
	Sound.play_at("gunshot", from, 8.0, 60.0)
	if from.distance_to(to) < 0.05 or not is_multiplayer_authority():
		return # point-blank, or the partner's: nothing to draw
	var tracer := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.03, 0.03, from.distance_to(to))
	tracer.mesh = mesh
	tracer.material_override = _tracer_material
	tracer.top_level = true
	add_child(tracer)
	tracer.look_at_from_position((from + to) / 2.0, to)
	get_tree().create_timer(0.06).timeout.connect(tracer.queue_free)


## The model follows synced state on every peer: aiming, and health (a drop is a hit; zero
## is death, until the respawn restores it).
func _update_model() -> void:
	model.aiming = is_aiming and armed()
	model.dead = health <= 0
	if health < _last_health and health > 0:
		model.play_hurt()
	_last_health = health


## A gesture for the partner's copy of this character (they can't see your input).
@rpc("authority", "call_remote", "unreliable")
func _play_gesture(gesture: String) -> void:
	model.play_gesture(gesture)
	if gesture == "shove":
		Sound.play_at("shove", global_position, -2.0, 15.0)


## A short push: knocks back and staggers whatever is in front (an enemy, or the partner).
## No damage. The server decides what it hits.
## Holding a weapon that can be raised (equipped and still carried).
func armed() -> bool:
	return equipped != "" and inventory.has(equipped)


## A push the way you're aiming: knocks back and staggers what's in front, no damage.
func _shove() -> void:
	if _shove_cooldown > 0.0:
		return
	_shove_cooldown = SHOVE_COOLDOWN
	model.play_gesture("shove")
	_play_gesture.rpc("shove")
	Sound.play_at("shove", global_position, -2.0, 15.0)
	_request_shove.rpc_id(1, -global_basis.z)


@rpc("any_peer", "call_local", "reliable")
func _request_shove(direction: Vector3) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	for body: Node3D in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("players"):
		if body == self:
			continue
		var to := body.global_position - global_position
		to.y = 0.0
		if to.length() > SHOVE_RANGE or (to.length() > 0.3 and rad_to_deg(direction.angle_to(to.normalized())) > SHOVE_ANGLE):
			continue
		if body is Enemy:
			body.shove(direction)
		elif body is Player:
			body.receive_shove.rpc_id(body.get_multiplayer_authority(), direction)


## Server -> owner: the partner shoved this player.
@rpc("any_peer", "call_local", "reliable")
func receive_shove(direction: Vector3) -> void:
	if multiplayer.get_remote_sender_id() != 1 or not is_multiplayer_authority():
		return
	_knockback = Vector3(direction.x, 0, direction.z).normalized() * SHOVED_SPEED
	model.play_hurt()


## Called by the server (enemies) on the owning peer.
@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: int) -> void:
	if multiplayer.get_remote_sender_id() != 1 or not is_multiplayer_authority():
		return
	_hurt(amount)


func _hurt(amount: int) -> void:
	if is_dead or gone_down:
		return
	health = maxi(health - amount, 0)
	_refresh_hud()
	Sound.play_ui("hurt")
	var tween := create_tween()
	hurt_flash.color.a = 0.45
	tween.tween_property(hurt_flash, "color:a", 0.0, 0.4)
	if health == 0:
		_die()


## You watch yourself fall, then black. A real death reloads both players to the save
## (SaveGame); where nothing can kill yet (a non-lethal EnvironmentZone), it is a collapse:
## you wake by the nearest lit lamp and nothing else changes.
func _die() -> void:
	is_dead = true
	Sound.play_ui("death")
	if inventory_screen.visible:
		inventory_screen.close()
	save_prompt.close(false)
	MetaSave.record("deaths")
	if focus:
		focus.has_local_focus = false
		focus = null
	var tween := create_tween()
	tween.tween_interval(DEATH_WATCH)
	tween.tween_property(fade, "color:a", 1.0, 0.8)
	if _in_safe_zone():
		tween.tween_interval(COLLAPSE_TIME)
		tween.tween_callback(_recover)
		tween.tween_property(fade, "color:a", 0.0, 0.8)
	else:
		tween.tween_callback(func() -> void: SaveGame.report_death(global_position, rotation.y))


func _in_safe_zone() -> bool:
	for area in zone_probe.get_overlapping_areas():
		if area is EnvironmentZone and not area.lethal:
			return true
	return false


func _recover() -> void:
	global_position = _recovery_point()
	velocity = Vector3.ZERO
	health = MAX_HEALTH
	warmth = MAX_WARMTH
	_last_health = health
	is_dead = false
	_view_third_person()
	camera_rig.global_position = global_position
	_refresh_hud()
	Story.show_local("collapse")


## The nearest lit lamp, else this role's start point.
func _recovery_point() -> Vector3:
	var best := Vector3.INF
	for point in get_tree().get_nodes_in_group("recovery_points"):
		if point.can_recover():
			var at: Vector3 = point.recovery_position()
			if best == Vector3.INF or at.distance_to(global_position) < best.distance_to(global_position):
				best = at
	if best != Vector3.INF:
		return best
	var level := get_tree().get_first_node_in_group("level") as Level
	return (level.subject_start if role == Session.Role.SUBJECT else level.visitor_start).global_position


# --- Cold --------------------------------------------------------------------

## Applies the look, sound and radio interference of the EnvironmentZone we stand in
## (e.g. the whiteout). A save room's calm ambience wins over any zone's.
func _update_environment() -> void:
	var environment: Environment = null
	var level := get_tree().get_first_node_in_group("level") as Level
	var ambience := level.ambience if level else ""
	var haven_ambience := ""
	var interference := 0.0
	var snowing := false
	for area in zone_probe.get_overlapping_areas():
		if area is EnvironmentZone:
			if area.environment:
				environment = area.environment
			if area.ambience:
				ambience = area.ambience
			interference = maxf(interference, area.radio_interference)
			snowing = snowing or area.snowfall
		elif area is SafeRoom and area.ambience:
			haven_ambience = area.ambience
	if haven_ambience:
		ambience = haven_ambience
	_snow.emitting = snowing
	_snow.global_position = global_position + Vector3.UP * 2.0
	if _reload_wait:
		ambience = "" # behind a black screen there is nothing to hear
	Radio.local_interference = interference
	if third_person_camera.environment != environment:
		third_person_camera.environment = environment
		first_person_camera.environment = environment
	Sound.set_ambience(ambience)


## Footsteps for every player on every machine, from distance moved (remote players
## are moved by the synchronizer, so velocity isn't available for them).
func _update_footsteps() -> void:
	var moved := Vector2(global_position.x - _last_position.x, global_position.z - _last_position.z).length()
	_last_position = global_position
	if moved > 1.0: # a teleport (respawn), not a step
		return
	_stride_left -= moved
	if _stride_left <= 0.0:
		_stride_left = STRIDE
		var local := is_multiplayer_authority()
		# Soft, like Signalis: steps sit under the bed instead of ticking over it.
		Sound.play_at(_surface_footsteps(), global_position, -16.0 if local else -12.0, 18.0, 0.12)
		if multiplayer.is_server():
			Enemy.make_noise(get_tree(), global_position, STEP_NOISE)


func _surface_footsteps() -> String:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = global_position + Vector3.UP * 0.5
	query.collision_mask = ZONE_LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in get_world_3d().direct_space_state.intersect_point(query):
		if hit["collider"] is EnvironmentZone and hit["collider"].footsteps:
			return hit["collider"].footsteps
	var level := get_tree().get_first_node_in_group("level") as Level
	return level.footsteps if level else "step_metal"


## What the HUD shows. The Subject's reading never moves.
func body_temperature() -> float:
	if not feels_cold:
		return NORMAL_BODY_TEMPERATURE
	return lerpf(FROZEN_BODY_TEMPERATURE, NORMAL_BODY_TEMPERATURE, warmth / MAX_WARMTH)


func _update_warmth(delta: float) -> void:
	if not feels_cold or is_dead or gone_down:
		return
	var rate := 0.0
	var haven_rate := -INF
	for area in zone_probe.get_overlapping_areas():
		if area is TemperatureZone:
			rate += area.warmth_rate
		elif area is SafeRoom:
			haven_rate = maxf(haven_rate, area.warmth_rate)
	# A save room is always warm, however cold the area around it.
	rate = maxf(rate, haven_rate)
	var shown_before := snappedf(body_temperature(), 0.1)
	warmth = clampf(warmth + rate * delta, 0.0, MAX_WARMTH)
	if warmth < MAX_WARMTH * 0.4 and not _warned_cold:
		_warned_cold = true
		Story.show_local("cold_warning")
	if warmth == 0.0:
		_freeze_damage += FREEZING_DAMAGE_PER_SECOND * delta
		if _freeze_damage >= 1.0:
			var damage := floori(_freeze_damage)
			_freeze_damage -= damage
			_hurt(damage)
	if snappedf(body_temperature(), 0.1) != shown_before:
		_refresh_hud()
