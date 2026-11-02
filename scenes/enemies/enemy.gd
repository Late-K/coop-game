class_name Enemy
extends CharacterBody3D
## Server-controlled enemy. The host runs all AI and damage; clients only see the
## synced position/rotation/state.
##
## Shot down, it collapses and gets back up after a while, unless a player walks
## over and finishes it (interact while it is down). That costs time and nerve.
## Movement is direct steering with line of sight; pathfinding comes later.

enum State { IDLE, CHASE, DOWNED }

const MAX_HEALTH := 30
const MOVE_SPEED := 2.2
const DETECT_RANGE := 7.0
const LOSE_RANGE := 12.0
const ATTACK_RANGE := 1.3
const ATTACK_DAMAGE := 20
const ATTACK_COOLDOWN := 1.2
const REVIVE_TIME := 15.0
const TURN_SPEED := 6.0
const ENEMY_LAYER := 2 # physics layer 2, "enemy"
const SIGHT_MASK := 1 # only the world blocks sight

## Synced to clients; drives the visuals on every peer.
var state := State.IDLE:
	set(value):
		if value == state:
			return
		state = value
		if is_node_ready():
			_apply_state_visuals()

var health := MAX_HEALTH
var target: Player = null
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _attack_timer := 0.0
var _revive_timer := 0.0

@onready var body: Node3D = $Body
@onready var finish_point: Interactable = $FinishPoint


func _ready() -> void:
	finish_point.used.connect(_on_finish_used)
	set_physics_process(multiplayer.is_server())
	_apply_state_visuals()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	velocity.x = 0.0
	velocity.z = 0.0
	_attack_timer = maxf(_attack_timer - delta, 0.0)

	match state:
		State.IDLE:
			target = _find_target()
			if target:
				state = State.CHASE
		State.CHASE:
			_chase(delta)
		State.DOWNED:
			_revive_timer -= delta
			if _revive_timer <= 0.0:
				health = MAX_HEALTH
				state = State.IDLE
				print("[enemy] %s got back up" % name)
	move_and_slide()


## Server only.
func take_damage(amount: int, attacker: Player) -> void:
	if state == State.DOWNED:
		return
	health -= amount
	if state == State.IDLE and attacker:
		target = attacker
		state = State.CHASE
	if health <= 0:
		state = State.DOWNED
		_revive_timer = REVIVE_TIME
		print("[enemy] %s is down" % name)


func _chase(delta: float) -> void:
	if not _is_valid_target(target):
		target = null
		state = State.IDLE
		return
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance > LOSE_RANGE:
		target = null
		state = State.IDLE
		return
	if distance > ATTACK_RANGE:
		var direction := to_target / distance
		velocity.x = direction.x * MOVE_SPEED
		velocity.z = direction.z * MOVE_SPEED
	elif _attack_timer == 0.0:
		_attack_timer = ATTACK_COOLDOWN
		target.take_damage.rpc_id(target.get_multiplayer_authority(), ATTACK_DAMAGE)
	if distance > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-to_target.x, -to_target.z), TURN_SPEED * delta)


func _find_target() -> Player:
	var nearest: Player = null
	var nearest_distance := DETECT_RANGE
	for player: Player in get_tree().get_nodes_in_group("players"):
		var distance := global_position.distance_to(player.global_position)
		if _is_valid_target(player) and distance < nearest_distance and _can_see(player):
			nearest = player
			nearest_distance = distance
	return nearest


func _is_valid_target(player: Player) -> bool:
	return is_instance_valid(player) and player.health > 0


func _can_see(player: Player) -> bool:
	var eye := global_position + Vector3.UP * 1.5
	var query := PhysicsRayQueryParameters3D.create(eye, player.global_position + Vector3.UP * 1.2, SIGHT_MASK)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _apply_state_visuals() -> void:
	var downed := state == State.DOWNED
	# Lying down: players walk over it and shots pass through, but it can be finished.
	body.rotation.x = -PI / 2.0 if downed else 0.0
	body.position.y = 0.35 if downed else 0.0
	collision_layer = 0 if downed else ENEMY_LAYER
	finish_point.set_deferred("monitorable", downed)


func _on_finish_used(_player: Player) -> void:
	_request_finish.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _request_finish() -> void:
	if multiplayer.is_server() and state == State.DOWNED:
		print("[enemy] %s finished off" % name)
		queue_free() # WorldSpawner despawns it on the other peer
