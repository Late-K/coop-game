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
## Save rooms are havens (SafeRoom): it never walks into one, ignores noises made inside,
## and gives up on anyone who reaches one, wandering back to where it started. Nor does it
## ever go through a doorway, open or shut: a door is always between you and it. Held up at
## one, it soon gives up and goes back. Unless it's hunting someone, it keeps clear of the
## ground either side of a door (DOOR_CLEAR), so nothing waits where you can't see it, and
## it never swipes at someone going through a door that's open to let them through.
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
## Seconds pushing against something (a closed door) before it searches where it stands.
const STUCK_TIME := 1.0
## How far short of a save room's edge it stops (about its body's reach).
const HAVEN_MARGIN := 0.6
## Metres either side of a door's wall it stays out of unless it's hunting someone: you
## step into the next room blind (the rooms past a door are dark), so nothing waits there.
const DOOR_CLEAR := 2.5
## Seconds held up at a doorway while hunting before it gives up and goes back.
const DOOR_GIVE_UP := 1.0

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
## Dormant until woken: lies where it was put, as if dead (it can be finished off like
## that), until something wakes everything with this tag (SectorPower). Empty: awake.
@export var wake_tag := ""

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
## Where it started (its post), to wander back to after giving up on someone.
var _home: Variant = null
## Stopped at a save room's edge or a doorway last frame.
var _at_haven := false
## Seconds it has barely moved while searching (held up by a closed door).
var _stuck_time := 0.0
## Seconds held up at a doorway while hunting.
var _door_time := 0.0
## Lying dormant (see wake_tag): no groan as it "falls", no getting up on its own.
var _sleeping := false

@onready var model: CharacterModel = $Model
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var finish_point: Interactable = $FinishPoint


## Server: a sound at `at` that carries `radius` metres. Enemies that hear it come to look.
## Noises inside a save room don't carry out of it.
static func make_noise(tree: SceneTree, at: Vector3, radius: float) -> void:
	if SafeRoom.covers(tree, at):
		return
	for enemy: Enemy in tree.get_nodes_in_group("enemies"):
		enemy.hear(at, radius)


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	model.look = look
	finish_point.used.connect(_on_finish_used)
	set_physics_process(multiplayer.is_server())
	if not wake_tag.is_empty():
		add_to_group("dormant")
		_sleeping = true
		state = State.DOWNED
		_timer = INF
	_on_state_changed()


## Level re-spawns placed enemies through WorldSpawner: what has to survive the trip.
func get_spawn_data() -> Dictionary:
	return {"wake_tag": wake_tag} if not wake_tag.is_empty() else {}


func apply_spawn_data(data: Dictionary) -> void:
	wake_tag = data.get("wake_tag", "")


## Server: up from dormant, after a moment (each one in its own time).
func wake() -> void:
	if _sleeping and state == State.DOWNED:
		_sleeping = false
		_timer = randf_range(0.4, 1.8)


func _physics_process(delta: float) -> void:
	if _home == null:
		_home = global_position # placed by now (spawned enemies get their transform after _ready)
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
			# Where it's going is past a door: no use waiting at it.
			if _goal != _home and _held_by_door(_goal, delta):
				_give_up()
			# Arrived, or held up at a save room or a closed door: search here.
			elif _walk_to(_goal, delta, 0.7) or _at_haven or _stuck_time > STUCK_TIME:
				_timer += delta
				if _timer > SEARCH_TIME:
					# Searched: back to its post, so none is left loitering at a save room door.
					if _home != null and _goal != _home and global_position.distance_to(_home) > 1.0:
						_give_up()
					else:
						state = State.IDLE
		State.CHASE:
			# Its target went through a door: it can't follow, so it doesn't wait there.
			if _held_by_door(target.global_position if _is_valid_target(target) else _last_seen, delta):
				_give_up()
			else:
				_chase(delta)
		State.STAGGERED:
			velocity.x = _knockback.x
			velocity.z = _knockback.z
			_knockback = _knockback.lerp(Vector3.ZERO, 1.0 - exp(-8.0 * delta))
			_timer -= delta
			if _timer <= 0.0:
				if _is_valid_target(target):
					state = State.CHASE
				else:
					_give_up()
		State.DOWNED:
			_timer -= delta
			if _timer <= 0.0:
				health = max_health
				state = State.IDLE
				print("[enemy] %s got back up" % name)
	_keep_out()
	var before := global_position
	move_and_slide()
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	_stuck_time = _stuck_time + delta if state == State.INVESTIGATE and moved < 0.2 * delta else 0.0


## Never into a save room, never through a doorway (and, unless hunting, never near one):
## a step toward one stops with its body short of it. One already inside (placed there by
## mistake, or chasing someone) can still walk out.
func _keep_out() -> void:
	var heading := Vector3(velocity.x, 0.0, velocity.z)
	if heading.length() <= 0.01:
		_at_haven = false
		return
	var ahead := global_position + heading.normalized() * HAVEN_MARGIN
	# Hunting, it closes right up to a doorway: whoever stands in one is in reach.
	var hunting := state == State.CHASE
	var clear := 0.0 if hunting else DOOR_CLEAR
	var to_door := global_position + heading.normalized() * (0.25 if hunting else HAVEN_MARGIN)
	_at_haven = (SafeRoom.covers(get_tree(), ahead) and not SafeRoom.covers(get_tree(), global_position)) \
			or (_in_doorway(to_door, clear) and not _in_doorway(global_position, clear))
	if _at_haven:
		velocity.x = 0.0
		velocity.z = 0.0
		_knockback = Vector3.ZERO


## Inside a door's opening (its wall cell, the door's width), or within `clear` metres of
## it either side.
func _in_doorway(at: Vector3, clear := 0.0) -> bool:
	for door: Door in get_tree().get_nodes_in_group("doors"):
		var local := door.global_transform.affine_inverse() * at
		if absf(local.x) < 0.75 + clear and absf(local.z) < Kit.DOOR_WIDTH / 2.0 + 0.2 and absf(local.y) < 2.0:
			return true
	return false


## Close by a door with `to` on its far side (not in the doorway itself, where it can be
## reached): counts up how long, and true once that's DOOR_GIVE_UP seconds.
func _held_by_door(to: Vector3, delta: float) -> bool:
	var across := false
	for door: Door in get_tree().get_nodes_in_group("doors"):
		var me := door.global_transform.affine_inverse() * global_position
		var there := door.global_transform.affine_inverse() * to
		if absf(me.x) > 0.75 + DOOR_CLEAR or absf(me.z) > Kit.DOOR_WIDTH / 2.0 + 1.0 or absf(me.y) > 2.0 \
				or absf(there.x) < 0.75 or signf(me.x) == signf(there.x):
			continue
		var z_at := lerpf(me.z, there.z, me.x / (me.x - there.x)) # where the line meets the wall
		if absf(z_at) < Kit.DOOR_WIDTH / 2.0 + 0.5:
			across = true
			break
	_door_time = _door_time + delta if across else 0.0
	if _door_time > DOOR_GIVE_UP:
		_door_time = 0.0
		return true
	return false


## Going through a door just opened by hand (Door.letting_through): in its doorway or just
## past it. The walk through is out of their hands.
static func passing_door(tree: SceneTree, at: Vector3) -> bool:
	for door: Door in tree.get_nodes_in_group("doors"):
		if not door.letting_through():
			continue
		var local := door.global_transform.affine_inverse() * at
		if absf(local.x) < 0.75 + DOOR_CLEAR and absf(local.z) < Kit.DOOR_WIDTH / 2.0 + 0.5 and absf(local.y) < 4.0:
			return true
	return false


## Lost its target (or they reached a save room): wander back to where it started.
func _give_up() -> void:
	target = null
	_goal = _home if _home != null else global_position
	_timer = 0.0
	state = State.INVESTIGATE


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
		_give_up()
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
		if _attack_timer == 0.0 and not passing_door(get_tree(), target.global_position):
			_attack_timer = ATTACK_COOLDOWN
			_play_attack.rpc()
			get_tree().create_timer(ATTACK_WINDUP).timeout.connect(_land_attack)


## Lands only if the target is still in reach (and nothing stopped the swipe).
func _land_attack() -> void:
	if state == State.CHASE and _is_valid_target(target) \
			and global_position.distance_to(target.global_position) <= ATTACK_RANGE + 0.3 \
			and not passing_door(get_tree(), target.global_position):
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
	# The mesh floats above the floor, so the agent can sit on a waypoint without counting
	# it reached (it measures height too): skip waypoints already underfoot.
	if step.length() < 0.3:
		var path := agent.get_current_navigation_path()
		for i in range(agent.get_current_navigation_path_index(), path.size()):
			var ahead := Vector3(path[i].x - global_position.x, 0, path[i].z - global_position.z)
			if ahead.length() >= 0.3:
				step = ahead
				break
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


## Alive, out in the open and still in the level: nobody in a save room (or gone down a
## way out) can be hunted, seen or heard.
func _is_valid_target(player: Player) -> bool:
	return is_instance_valid(player) and player.health > 0 and not player.gone_down \
			and not SafeRoom.covers(get_tree(), player.global_position)


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
			# A lower, slower groan as it collapses (not for one lying dormant).
			if not _sleeping:
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
