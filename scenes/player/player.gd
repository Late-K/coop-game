class_name Player
extends CharacterBody3D
## A player character. Each peer simulates its own player (authority = owning peer)
## and MultiplayerSynchronizer mirrors position/rotation to the other peer.
## World state (puzzles, enemies) will stay server-authoritative.

const WALK_SPEED := 4.0
const AIM_SPEED := 1.5
const TURN_SPEED := 12.0
const HOST_COLOR := Color(0.35, 0.55, 0.9)
const CLIENT_COLOR := Color(0.9, 0.5, 0.25)

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var body_mesh: MeshInstance3D = $Body
@onready var nameplate: Label3D = $Nameplate
@onready var camera_rig: Node3D = $CameraRig
@onready var third_person_camera: Camera3D = $CameraRig/ThirdPersonCamera
@onready var first_person_camera: Camera3D = $FirstPersonCamera # used from M2 onward


func _enter_tree() -> void:
	# The node is named after its peer id by the spawner; that peer drives it.
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	var is_host_player := name.to_int() == 1
	nameplate.text = "Host" if is_host_player else "Client"
	var material := StandardMaterial3D.new()
	material.albedo_color = HOST_COLOR if is_host_player else CLIENT_COLOR
	body_mesh.material_override = material
	print("[player] %s ready on peer %d (%s)" % [name, multiplayer.get_unique_id(),
			"local" if is_multiplayer_authority() else "remote"])

	if is_multiplayer_authority():
		third_person_camera.make_current()
	else:
		# Remote players are positioned by the synchronizer, not simulated here.
		set_physics_process(false)
		camera_rig.queue_free()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var aiming := Input.is_action_pressed("aim")
	var speed := AIM_SPEED if aiming else WALK_SPEED
	# The top-down camera never rotates, so screen-up is always world -Z.
	var direction := Vector3(input.x, 0.0, input.y)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()

	var look_direction := _get_aim_direction() if aiming else direction
	if look_direction.length_squared() > 0.001:
		var target_yaw := atan2(-look_direction.x, -look_direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, TURN_SPEED * delta)

	camera_rig.global_position = global_position


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
