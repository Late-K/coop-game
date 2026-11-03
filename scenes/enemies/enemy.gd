class_name Enemy
extends CharacterBody3D
## Server-controlled enemy. The host runs all AI and damage; clients only see the synced
## position, rotation and state, and animate the model from them.
##
## Senses (set per scene): sight (a cone, blocked by walls), hearing (noises: footsteps,
## gunshots, see make_noise) and, for special enemies, radios: any player whose radio is
## switched on, on any station, within `radio_range`, even through walls. A noise sends it
## to look; a player it can sense, it hunts along the level's navigation map.
##
## Shot down, it collapses and gets back up after a while, unless a player walks over and
## finishes it (interact while it is down). A shove staggers it for a moment.
##
## enemy.tscn is the husk (sight and hearing); listener.tscn is blind and tracks radios.

enum State { IDLE, INVESTIGATE, CHASE, STAGGERED, DOWNED }

const ATTACK_RANGE := 1.3
const ATTACK_COOLDOWN := 1.2
## The swipe lands this long after it starts (the model's attack gesture).
const ATTACK_WINDUP := 0.3
const TURN_SPEED := 6.0
const ENEMY_LAYER := 2 # physics layer 2, "enemy"
const SIGHT_MASK := 1 # only the world blocks sight
## Seconds a chasing enemy keeps hunting after losing all sense of its target.
const LOSE_TIME := 4.0
## Seconds it lingers where a noise was before giving up.
const SEARCH_TIME := 3.0
const STAGGER_TIME := 1.0
const SENSE_INTERVAL := 0.25

@export var look := CharacterModel.Look.HUSK
@export var max_health := 30
@export var move_speed := 2.2
@export var attack_damage := 20
@export var revive_time := 15.0
## How far it sees, in metres (0: blind), and how wide (degrees).
@export var sight_range := 9.0
@export var sight_angle := 140.0
## Multiplies how far noises carry to it (0: deaf).
@export var hearing := 1.0
## Tracks players whose radio is on, within this range (0: doesn't).
@export var radio_range := 0.0

## Synced to clients; drives the model on every peer.
var state := State.IDLE:
	set(value):
		if value == state:
			return
		state = value
		if is_node_ready():
			_on_state_changed()

var health := 0
var target: Player = null
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _goal := Vector3.ZERO
## Where the target was the last time it was seen or heard.
var _last_seen := Vector3.ZERO
var _attack_timer := 0.0
var _growl_timer := 0.0
var _timer := 0.0
var _lost_time := 0.0
var _sense_timer := 0.0
var _knockback := Vector3.ZERO

@onready var model: CharacterModel = $Model
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var finish_point: Interactable = $FinishPoint


## Server: a sound at `at` that carries `radius` metres. Enemies that hear it come to look.
static func make_noise(tree: SceneTree, at: Vector3, radius: float) -> void:
	for enemy: Enemy in tree.get_nodes_in_group("enemies"):
		enemy.hear(at, radius)


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	model.look = look
	finish_point.used.connect(_on_finish_used)
	set_physics_process(multiplayer.is_server())
	_on_state_changed()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	velocity.x = 0.0
	velocity.z = 0.0
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_sense_timer -= delta
	if _sense_timer <= 0.0 and state in [State.IDLE, State.INVESTIGATE, State.CHASE]:
		_sense_timer = SENSE_INTERVAL
		_sense()

	match state:
		State.INVESTIGATE:
			if _walk_to(_goal, delta, 0.7):
				_timer += delta
				if _timer > SEARCH_TIME:
					state = State.IDLE
		State.CHASE:
			_chase(delta)
		State.STAGGERED:
			velocity.x = _knockback.x
			velocity.z = _knockback.z
			_knockback = _knockback.lerp(Vector3.ZERO, 1.0 - exp(-8.0 * delta))
			_timer -= delta
			if _timer <= 0.0:
				state = State.CHASE if _is_valid_target(target) else State.IDLE
		State.DOWNED:
			_timer -= delta
			if _timer <= 0.0:
				health = max_health
				state = State.IDLE
				print("[enemy] %s got back up" % name)
	move_and_slide()


# --- Senses (server) -------------------------------------------------------------

## Sight and radios: the nearest player it can sense becomes the target.
func _sense() -> void:
	var sensed: Player = null
	var nearest := INF
	for player: Player in get_tree().get_nodes_in_group("players"):
		if not _is_valid_target(player):
			continue
		var distance := global_position.distance_to(player.global_position)
		if distance < nearest and (_can_see(player, distance) or _can_hear_radio(player, distance)):
			sensed = player
			nearest = distance
	if sensed:
		target = sensed
		_last_seen = sensed.global_position
		_lost_time = 0.0
		state = State.CHASE


## A noise: come and look, unless already hunting someone.
func hear(at: Vector3, radius: float) -> void:
	if hearing <= 0.0 or state in [State.CHASE, State.STAGGERED, State.DOWNED]:
		return
	if global_position.distance_to(at) <= radius * hearing:
		_goal = at
		_timer = 0.0
		state = State.INVESTIGATE


func _can_see(player: Player, distance: float) -> bool:
	if sight_range <= 0.0 or distance > sight_range:
		return false
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > 0.5 and rad_to_deg((-global_basis.z).angle_to(to_player.normalized())) > sight_angle / 2.0:
		return false
	var eye := global_position + Vector3.UP * 1.5
	var query := PhysicsRayQueryParameters3D.create(eye, player.global_position + Vector3.UP * 1.2, SIGHT_MASK)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _can_hear_radio(player: Player, distance: float) -> bool:
	return radio_range > 0.0 and player.radio_on and distance <= radio_range


# --- Moving and fighting (server) -------------------------------------------------

func _chase(delta: float) -> void:
	if not _is_valid_target(target):
		target = null
		state = State.IDLE
		return
	var distance := global_position.distance_to(target.global_position)
	# Still sensed? (_sense refreshes this while it can see or hear them.)
	_lost_time += delta
	if _lost_time > LOSE_TIME:
		# Lost them: go and look where they were last sensed.
		_goal = _last_seen
		_timer = 0.0
		target = null
		state = State.INVESTIGATE
		return
	if distance > ATTACK_RANGE:
		_walk_to(target.global_position, delta, ATTACK_RANGE * 0.8)
	else:
		_face(target.global_position, delta)
		if _attack_timer == 0.0:
			_attack_timer = ATTACK_COOLDOWN
			_play_attack.rpc()
			get_tree().create_timer(ATTACK_WINDUP).timeout.connect(_land_attack)


## Lands only if the target is still in reach (and nothing stopped the swipe).
func _land_attack() -> void:
	if state == State.CHASE and _is_valid_target(target) \
			and global_position.distance_to(target.global_position) <= ATTACK_RANGE + 0.3:
		target.take_damage.rpc_id(target.get_multiplayer_authority(), attack_damage)


## Follows the navigation map toward `to`; true once within `near` of it. Without a map
## (still baking, or none) it walks straight there.
func _walk_to(to: Vector3, delta: float, near: float) -> bool:
	var flat := Vector3(to.x - global_position.x, 0, to.z - global_position.z)
	if flat.length() <= near:
		return true
	agent.target_position = to
	var next := agent.get_next_path_position()
	var step := Vector3(next.x - global_position.x, 0, next.z - global_position.z)
	if step.length() < 0.05:
		step = flat # no path (yet): straight line
	var direction := step.normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	_face(global_position + direction, delta)
	return false


func _face(point: Vector3, delta: float) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), TURN_SPEED * delta)


func _is_valid_target(player: Player) -> bool:
	return is_instance_valid(player) and player.health > 0


## Server only. Shot: it turns on whoever shot it.
func take_damage(amount: int, attacker: Player) -> void:
	if state == State.DOWNED:
		return
	health -= amount
	_play_hit.rpc()
	if attacker and state != State.STAGGERED:
		target = attacker
		_last_seen = attacker.global_position
		_lost_time = 0.0
		state = State.CHASE
	if health <= 0:
		_timer = revive_time
		state = State.DOWNED
		print("[enemy] %s is down" % name)


## Server only. A player's shove: pushed back along `direction`, staggered, no damage.
func shove(direction: Vector3) -> void:
	if state == State.DOWNED:
		return
	_knockback = Vector3(direction.x, 0, direction.z).normalized() * 5.0
	_timer = STAGGER_TIME
	_attack_timer = ATTACK_COOLDOWN
	state = State.STAGGERED


# --- Every peer: model and sound -------------------------------------------------------

func _process(delta: float) -> void:
	model.dead = state == State.DOWNED
	if state != State.CHASE:
		return
	_growl_timer -= delta
	if _growl_timer <= 0.0:
		_growl_timer = randf_range(2.5, 5.0)
		Sound.play_at("enemy_growl", global_position, 0.0, 25.0, 0.05, 0.75 if look == CharacterModel.Look.LISTENER else 1.0)


func _on_state_changed() -> void:
	var downed := state == State.DOWNED
	# Lying down: players walk over it and shots pass through, but it can be finished.
	collision_layer = 0 if downed else ENEMY_LAYER
	finish_point.set_deferred("monitorable", downed)
	match state:
		State.CHASE:
			_growl_timer = 0.0 # growl right away when it notices someone
		State.STAGGERED:
			model.play_hurt()
		State.DOWNED:
			# A lower, slower groan as it collapses.
			Sound.play_at("enemy_growl", global_position, -2.0, 25.0, 0.0, 0.6)


@rpc("authority", "call_local", "unreliable")
func _play_hit() -> void:
	Sound.play_at("enemy_hit", global_position + Vector3.UP, 0.0, 30.0)
	model.play_hurt()


@rpc("authority", "call_local", "unreliable")
func _play_attack() -> void:
	model.play_gesture("attack")


func _on_finish_used(_player: Player) -> void:
	_request_finish.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _request_finish() -> void:
	if multiplayer.is_server() and state == State.DOWNED:
		print("[enemy] %s finished off" % name)
		queue_free() # WorldSpawner despawns it on the other peer
