class_name Player
extends CharacterBody3D
## A player character. Each peer simulates its own player (authority = owning peer)
## and MultiplayerSynchronizer mirrors position/rotation/health/aiming to the other peer.
## World state (puzzles, enemies, pickups) stays server-authoritative.
##
## Perspective: third person (top-down) while exploring; using an Interactable
## with a view point hard-cuts to first person until the player steps back.
##
## Combat: hold aim to raise the pistol (laser sight), fire while aiming. The owner
## spends ammo locally; the server raycasts the shot and applies the damage.
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
const SUBJECT_COLOR := Color(0.78, 0.8, 0.82)
const VISITOR_COLOR := Color(0.9, 0.5, 0.25)
const MAX_HEALTH := 100
const MAGAZINE_SIZE := 6
const FIRE_COOLDOWN := 0.35
const RELOAD_TIME := 0.9
const SHOT_RANGE := 25.0
const SHOT_DAMAGE := 10
const SHOT_MASK := 11 # physics layers 1 + 2 + 4: world, enemies and players (friendly fire)
const RESPAWN_DELAY := 1.5
const MAX_WARMTH := 100.0
const FREEZING_DAMAGE_PER_SECOND := 4.0
const NORMAL_BODY_TEMPERATURE := 36.6
## Metres walked per footstep sound.
const STRIDE := 1.7
const ZONE_LAYER := 32 # physics layer 6, "zones"
const FROZEN_BODY_TEMPERATURE := 29.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var role := Session.Role.NONE
var feels_cold := false

# Synced from the owner to the other peer.
var health := MAX_HEALTH
var is_aiming := false

# Only meaningful on the owning peer.
var inventory := Inventory.new()
## The weapon in hand ("" for none). Only an equipped weapon can be raised and fired.
var equipped := ""
## Personal storage, opened from any item box.
var stash := Inventory.new(ItemBox.STASH_SLOTS)
var loaded_rounds := 0
var checkpoint := Vector3.ZERO
var warmth := MAX_WARMTH
var _freeze_damage := 0.0
var _warned_cold := false
var is_dead := false
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

@onready var body_mesh: MeshInstance3D = $Body
@onready var nose: MeshInstance3D = $Nose
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
		overlay.reparent(get_tree().root, false)
		third_person_camera.make_current()
		# Hear the world from the character (not the camera, which may be framing a room),
		# oriented like the screen: up = north.
		_listener.top_level = true
		add_child(_listener)
		_listener.make_current()
		checkpoint = global_position
		inventory.changed.connect(_refresh_hud)
		_refresh_hud()
	else:
		# Remote players are positioned by the synchronizer, not simulated or controlled here.
		set_physics_process(false)
		set_process_unhandled_input(false)
		camera_rig.queue_free()
		interaction_area.queue_free()
		zone_probe.queue_free()
		_listener.free() # never entered the tree; only the local player listens


func _exit_tree() -> void:
	if is_multiplayer_authority() and is_instance_valid(overlay) and overlay.get_parent() == get_tree().root:
		overlay.queue_free()
		Retro.set_condition(0.0, 0.0)
		Radio.local_interference = 0.0


func _apply_role() -> void:
	role = Session.role_of(name.to_int())
	feels_cold = role == Session.Role.VISITOR
	nameplate.text = Session.ROLE_NAMES[role]
	# Only your partner's name floats over them; you know who you are.
	nameplate.visible = not is_multiplayer_authority()
	var material := StandardMaterial3D.new()
	material.albedo_color = SUBJECT_COLOR if role == Session.Role.SUBJECT else VISITOR_COLOR
	body_mesh.material_override = material


func _unhandled_input(event: InputEvent) -> void:
	if _cutting or _in_cutaway or is_dead or inventory_screen.visible or _pause_menu_open():
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
		_try_fire()
	elif event.is_action_pressed("reload"):
		_reload()
	elif event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		open_inventory()


func _process(_delta: float) -> void:
	_update_footsteps()
	# Runs on every peer so the partner sees your laser too.
	laser.visible = is_aiming
	if is_aiming:
		var length := SHOT_RANGE
		if aim_ray.is_colliding():
			length = laser_pivot.global_position.distance_to(aim_ray.get_collision_point())
		laser.scale.z = length
		laser.position.z = -length / 2.0


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)

	var frozen := (focus != null or _cutting or _in_cutaway or is_dead or inventory_screen.visible
			or _pause_menu_open())
	var input := Vector2.ZERO if frozen else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	is_aiming = not frozen and Input.is_action_pressed("aim") and equipped != "" and inventory.has(equipped)
	hud.set_ammo(is_aiming, "%s  %d / %d" % [Items.display_name(equipped).to_upper(), loaded_rounds,
			inventory.count_of("ammo")] if is_aiming else "")
	hud.set_radio(Radio.status_text())
	Radio.listener_position = global_position
	_update_condition()
	var speed := AIM_SPEED if is_aiming else WALK_SPEED
	# The top-down camera never rotates, so screen-up is always world -Z.
	var direction := Vector3(input.x, 0.0, input.y)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()

	var look_direction := _get_aim_direction() if is_aiming else direction
	if look_direction.length_squared() > 0.001:
		var target_yaw := atan2(-look_direction.x, -look_direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, TURN_SPEED * delta)

	_update_camera(delta)
	_update_warmth(delta)
	_update_environment()
	_update_prompt()


# --- Interaction & perspective ---------------------------------------------

## The top-down camera follows the player, except inside a CameraZone, where it holds that
## room's framing (Signalis-style fixed compositions).
func _update_camera(delta: float) -> void:
	var target := global_position
	var distance := CAMERA_DISTANCE
	for area in zone_probe.get_overlapping_areas():
		if area is CameraZone:
			target = area.focus_point()
			distance = area.distance
	var blend := 1.0 - exp(-CAMERA_FOLLOW * delta)
	if camera_rig.global_position.distance_to(target) > CAMERA_SNAP_DISTANCE:
		camera_rig.global_position = target
		_camera_distance = distance
	else:
		camera_rig.global_position = camera_rig.global_position.lerp(target, blend)
		_camera_distance = lerpf(_camera_distance, distance, blend)
	third_person_camera.position = CAMERA_DIRECTION * _camera_distance
	_listener.global_position = global_position + Vector3.UP * 1.5


func _use(target: Interactable) -> void:
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


func _view_third_person() -> void:
	first_person_camera.transform = head_transform
	third_person_camera.make_current()
	_set_own_body_visible(true)


## Hidden on this machine only while in first person, so you never see your own back.
func _set_own_body_visible(shown: bool) -> void:
	body_mesh.visible = shown
	nose.visible = shown


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
		if area is Interactable:
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
	hud.set_prompt("[E] %s" % target.get_prompt(self) if target else "")


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


func set_checkpoint(point: Vector3) -> void:
	checkpoint = point
	notify("Checkpoint saved")


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
	# Loud and far-reaching: the partner hears your fights, muffled, from other rooms.
	Sound.play_at("gunshot", from, 8.0, 60.0)
	if from.distance_to(to) < 0.05:
		return # point-blank: nothing to draw
	var tracer := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.03, 0.03, from.distance_to(to))
	tracer.mesh = mesh
	tracer.material_override = _tracer_material
	tracer.top_level = true
	add_child(tracer)
	tracer.look_at_from_position((from + to) / 2.0, to)
	get_tree().create_timer(0.06).timeout.connect(tracer.queue_free)


## Called by the server (enemies) on the owning peer.
@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: int) -> void:
	if multiplayer.get_remote_sender_id() != 1 or not is_multiplayer_authority():
		return
	_hurt(amount)


func _hurt(amount: int) -> void:
	if is_dead:
		return
	health = maxi(health - amount, 0)
	_refresh_hud()
	Sound.play_ui("hurt")
	var tween := create_tween()
	hurt_flash.color.a = 0.45
	tween.tween_property(hurt_flash, "color:a", 0.0, 0.4)
	if health == 0:
		_die()


func _die() -> void:
	is_dead = true
	Sound.play_ui("death")
	if inventory_screen.visible:
		inventory_screen.close()
	MetaSave.record("deaths")
	if focus:
		focus.has_local_focus = false
		focus = null
	notify("You died")
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.6)
	tween.tween_interval(RESPAWN_DELAY)
	tween.tween_callback(_respawn)
	tween.tween_property(fade, "color:a", 0.0, 0.4)


func _respawn() -> void:
	global_position = checkpoint
	velocity = Vector3.ZERO
	health = MAX_HEALTH
	warmth = MAX_WARMTH
	is_dead = false
	Story.show_local("death")
	_view_third_person()
	camera_rig.global_position = global_position
	_refresh_hud()


# --- Cold --------------------------------------------------------------------

## Applies the look, sound and radio interference of the EnvironmentZone we stand in
## (e.g. the whiteout).
func _update_environment() -> void:
	var environment: Environment = null
	var level := get_tree().get_first_node_in_group("level") as Level
	var ambience := level.ambience if level else ""
	var interference := 0.0
	for area in zone_probe.get_overlapping_areas():
		if area is EnvironmentZone:
			if area.environment:
				environment = area.environment
			if area.ambience:
				ambience = area.ambience
			interference = maxf(interference, area.radio_interference)
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
	if not feels_cold or is_dead:
		return
	var rate := 0.0
	for area in zone_probe.get_overlapping_areas():
		if area is TemperatureZone:
			rate += area.warmth_rate
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
