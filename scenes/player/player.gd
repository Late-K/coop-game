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

const WALK_SPEED := 4.0
const AIM_SPEED := 1.5
const TURN_SPEED := 12.0
const CUT_FADE_TIME := 0.12
const HOST_COLOR := Color(0.35, 0.55, 0.9)
const CLIENT_COLOR := Color(0.9, 0.5, 0.25)
const MAX_HEALTH := 100
const MAGAZINE_SIZE := 6
const FIRE_COOLDOWN := 0.35
const RELOAD_TIME := 0.9
const SHOT_RANGE := 25.0
const SHOT_DAMAGE := 10
const SHOT_MASK := 3 # physics layers 1 + 2: world and enemies (no friendly fire)
const RESPAWN_DELAY := 1.5

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Synced from the owner to the other peer.
var health := MAX_HEALTH
var is_aiming := false

# Only meaningful on the owning peer.
var inventory := Inventory.new()
var selected_slot := 0
var loaded_rounds := 0
var checkpoint := Vector3.ZERO
var is_dead := false
## The Interactable this player is looking at in first person, or null.
var focus: Interactable = null
var _cutting := false
var _reloading := false
var _fire_cooldown := 0.0
var _tracer_material := StandardMaterial3D.new()

@onready var body_mesh: MeshInstance3D = $Body
@onready var nameplate: Label3D = $Nameplate
@onready var interaction_area: Area3D = $InteractionArea
@onready var laser_pivot: Node3D = $LaserPivot
@onready var laser: MeshInstance3D = $LaserPivot/Laser
@onready var aim_ray: RayCast3D = $LaserPivot/AimRay
@onready var camera_rig: Node3D = $CameraRig
@onready var third_person_camera: Camera3D = $CameraRig/ThirdPersonCamera
@onready var hud: PlayerHud = $CameraRig/Overlay/Hud
@onready var hurt_flash: ColorRect = $CameraRig/Overlay/HurtFlash
@onready var fade: ColorRect = $CameraRig/Overlay/Fade
@onready var first_person_camera: Camera3D = $FirstPersonCamera
@onready var head_transform: Transform3D = first_person_camera.transform


func _enter_tree() -> void:
	# The node is named after its peer id by the spawner; that peer drives it.
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	add_to_group("players")
	var is_host_player := name.to_int() == 1
	nameplate.text = "Host" if is_host_player else "Client"
	var material := StandardMaterial3D.new()
	material.albedo_color = HOST_COLOR if is_host_player else CLIENT_COLOR
	body_mesh.material_override = material
	_tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tracer_material.albedo_color = Color(1, 0.9, 0.6)
	print("[player] %s ready on peer %d (%s)" % [name, multiplayer.get_unique_id(),
			"local" if is_multiplayer_authority() else "remote"])

	if is_multiplayer_authority():
		third_person_camera.make_current()
		checkpoint = global_position
		inventory.changed.connect(_refresh_hud)
		_refresh_hud()
	else:
		# Remote players are positioned by the synchronizer, not simulated or controlled here.
		set_physics_process(false)
		set_process_unhandled_input(false)
		camera_rig.queue_free()
		interaction_area.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if _cutting or is_dead:
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
	elif event.is_action_pressed("use_item"):
		_use_selected_item()
	elif event.is_action_pressed("slot_next"):
		_select_slot(selected_slot + 1)
	elif event.is_action_pressed("slot_prev"):
		_select_slot(selected_slot - 1)
	else:
		for i in Inventory.SLOT_COUNT:
			if event.is_action_pressed("slot_%d" % (i + 1)):
				_select_slot(i)


func _process(_delta: float) -> void:
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

	var frozen := focus != null or _cutting or is_dead
	var input := Vector2.ZERO if frozen else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	is_aiming = not frozen and Input.is_action_pressed("aim") and inventory.has("pistol")
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

	camera_rig.global_position = global_position
	_update_prompt()


# --- Interaction & perspective ---------------------------------------------

func _use(target: Interactable) -> void:
	if target.view_point:
		_enter_focus(target)
	else:
		target.interact(self)


func _enter_focus(target: Interactable) -> void:
	focus = target
	await _cut(func() -> void:
		first_person_camera.global_transform = target.view_point.global_transform
		first_person_camera.make_current()
		target.has_local_focus = true
	)
	target.interact(self)


func _exit_focus() -> void:
	var target := focus
	target.has_local_focus = false
	focus = null
	await _cut(func() -> void:
		first_person_camera.transform = head_transform
		third_person_camera.make_current()
	)


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
			var distance := global_position.distance_squared_to(area.global_position)
			if distance < nearest_distance:
				nearest = area
				nearest_distance = distance
	return nearest


func _update_prompt() -> void:
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
		hud.show_message("Inventory full")
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
	if leftover > 0:
		push_warning("Inventory overflowed by %d %s" % [leftover, id])
	hud.show_message("Took %s" % Items.display_name(id))


func send_through_tube(tube: ItemTube) -> void:
	var slot := inventory.slots[selected_slot]
	if slot.is_empty():
		hud.show_message("Select an item to send first")
		return
	inventory.take_slot(selected_slot)
	tube.request_send.rpc_id(1, slot["id"], slot["count"])
	if slot["id"] == "pistol" and loaded_rounds > 0:
		# Whatever was loaded goes along with the gun.
		tube.request_send.rpc_id(1, "ammo", loaded_rounds)
		loaded_rounds = 0
		_refresh_hud()
	hud.show_message("Sent %s" % Items.display_name(slot["id"]))


func set_checkpoint(point: Vector3) -> void:
	checkpoint = point
	hud.show_message("Checkpoint saved")


func _select_slot(index: int) -> void:
	selected_slot = posmod(index, Inventory.SLOT_COUNT)
	_refresh_hud()


func _use_selected_item() -> void:
	var slot := inventory.slots[selected_slot]
	if slot.is_empty():
		return
	match slot["id"]:
		"medkit":
			if health >= MAX_HEALTH:
				hud.show_message("Already at full health")
				return
			inventory.remove("medkit", 1)
			health = mini(health + Items.get_value("medkit", "heal", 50), MAX_HEALTH)
			hud.show_message("Patched up")
			_refresh_hud()
		"ammo":
			_reload()


func _refresh_hud() -> void:
	hud.refresh(self)


# --- Combat ------------------------------------------------------------------

func _try_fire() -> void:
	if _fire_cooldown > 0.0 or _reloading:
		return
	if loaded_rounds == 0:
		hud.show_message("Empty  [R] reload")
		return
	loaded_rounds -= 1
	_fire_cooldown = FIRE_COOLDOWN
	_refresh_hud()
	_request_shot.rpc_id(1, laser_pivot.global_position, -global_basis.z)


func _reload() -> void:
	if _reloading or loaded_rounds == MAGAZINE_SIZE or not inventory.has("pistol"):
		return
	if not inventory.has("ammo"):
		hud.show_message("No ammo")
		return
	_reloading = true
	hud.show_message("Reloading...")
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
	var query := PhysicsRayQueryParameters3D.create(origin, end, SHOT_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		end = hit["position"]
		if hit["collider"] is Enemy:
			hit["collider"].take_damage(SHOT_DAMAGE, self)
	_show_shot.rpc(origin, end)


@rpc("any_peer", "call_local", "unreliable")
func _show_shot(from: Vector3, to: Vector3) -> void:
	if multiplayer.get_remote_sender_id() != 1 or from.distance_to(to) < 0.05:
		return
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
	if multiplayer.get_remote_sender_id() != 1 or not is_multiplayer_authority() or is_dead:
		return
	health = maxi(health - amount, 0)
	_refresh_hud()
	var tween := create_tween()
	hurt_flash.color.a = 0.45
	tween.tween_property(hurt_flash, "color:a", 0.0, 0.4)
	if health == 0:
		_die()


func _die() -> void:
	is_dead = true
	if focus:
		focus.has_local_focus = false
		focus = null
	hud.show_message("You died")
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.6)
	tween.tween_interval(RESPAWN_DELAY)
	tween.tween_callback(_respawn)
	tween.tween_property(fade, "color:a", 0.0, 0.4)


func _respawn() -> void:
	global_position = checkpoint
	velocity = Vector3.ZERO
	health = MAX_HEALTH
	is_dead = false
	first_person_camera.transform = head_transform
	third_person_camera.make_current()
	camera_rig.global_position = global_position
	_refresh_hud()
