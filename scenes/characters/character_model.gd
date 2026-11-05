@tool
class_name CharacterModel
extends Node3D
## A player character as a segmented low-poly figure: rigid pieces for head, torso, arms and
## legs on joints, like early PS1 horror. Built and animated in code, so it can be swapped
## for a modelled character later without touching gameplay (which only sets the state
## below and calls the play_* gestures).
##
## Animation is procedural but stepped: poses update POSE_RATE times a second, the way PS1
## games ran their animation at a fraction of the frame rate.
##
## Looks: the Subject is a pale, smooth, too-clean figure that moves with mechanical
## precision and never breathes. The Visitor is bulky cold-weather gear (orange parka, hood,
## backpack) and moves like a person: breathing, heavier steps.
## Enemies: the husk is a wrecked, filthy Subject-like figure with red eyes, hunched,
## reaching, breathing raggedly. The listener is tall, dark and eyeless, a dish where its
## face should be, its head turning slowly as it listens.
##
## Faces -Z (the player's forward). Origin at the feet.

enum Look { SUBJECT, VISITOR, HUSK, LISTENER }
## LIVE follows the gameplay state; the others are fixed poses for set dressing.
enum Pose { LIVE, CORPSE, WAITING }

const POSE_RATE := 15.0
## How fast joints move toward their target pose (per second).
const BLEND_RATE := 14.0
## Metres travelled per full walk cycle (two steps).
const STRIDE := 1.5
const DEATH_TIME := 0.8

@export var look := Look.VISITOR:
	set(value):
		if value == look:
			return
		look = value
		if is_node_ready():
			_build()
@export var pose := Pose.LIVE
## Varies the corpse pose (which way it fell, where the limbs lie).
@export var variation := 0
## Render layers of every piece. Players use their own (Player.VISUAL_LAYER), so cameras
## that must never show them (CCTV) can leave them out.
@export_flags_3d_render var visual_layers := 1:
	set(value):
		visual_layers = value
		for piece in find_children("*", "VisualInstance3D", true, false):
			piece.layers = value

## Set by the owner every frame (the player, on every peer).
var aiming := false
var dead := false

var _rig := Node3D.new()
var _joints := {} # name -> Node3D pivot
var _current := {} # name -> Vector3 rotation (the blended pose)
var _gun: Node3D
var _rig_position := Vector3.ZERO
var _rig_rotation := Vector3.ZERO
var _since_pose := 0.0
var _time := 0.0
var _phase := 0.0
var _speed := 0.0
var _last_position := Vector3.ZERO
var _dead_time := 0.0
var _recoil := 0.0
var _hurt := 0.0
var _gesture := ""
var _gesture_time := 0.0
var _materials := {}


func _ready() -> void:
	_build()
	_last_position = global_position


## A shot fired: the arms kick up.
func play_shot() -> void:
	_recoil = 1.0


## Hit: the body jerks back.
func play_hurt() -> void:
	_hurt = 1.0


## Short arm gestures: "interact" (reach forward), "shove" (both arms thrust) or "attack"
## (an enemy's raised swipe).
func play_gesture(gesture: String) -> void:
	_gesture = gesture
	_gesture_time = 0.0


func _process(delta: float) -> void:
	_time += delta
	var moved := global_position - _last_position
	_last_position = global_position
	if moved.length() > 1.0:
		moved = Vector3.ZERO # a teleport (respawn, cutscene), not a step
	var speed := Vector2(moved.x, moved.z).length() / maxf(delta, 0.0001)
	_speed = lerpf(_speed, minf(speed, 8.0), 1.0 - exp(-10.0 * delta))
	_phase = fmod(_phase + _speed * delta / STRIDE * TAU, TAU)
	_dead_time = _dead_time + delta if dead else 0.0
	_recoil = maxf(_recoil - delta * 6.0, 0.0)
	_hurt = maxf(_hurt - delta * 3.0, 0.0)
	if _gesture:
		_gesture_time += delta
		if _gesture_time > 0.6:
			_gesture = ""
	_since_pose += delta
	if _since_pose >= 1.0 / POSE_RATE:
		_apply_pose(_since_pose)
		_since_pose = 0.0


# --- Posing --------------------------------------------------------------------

func _apply_pose(step: float) -> void:
	var target := _target_pose()
	var blend := 1.0 - exp(-BLEND_RATE * step)
	if pose != Pose.LIVE or Engine.is_editor_hint():
		blend = 1.0
	for joint: String in _joints:
		var to: Vector3 = target.get(joint, Vector3.ZERO)
		_current[joint] = (_current[joint] as Vector3).lerp(to, blend)
		_joints[joint].rotation = _current[joint]
	_rig_position = _rig_position.lerp(target["rig_position"], blend)
	_rig_rotation = _rig_rotation.lerp(target["rig_rotation"], blend)
	_rig.position = _rig_position
	_rig.rotation = _rig_rotation
	if _gun:
		_gun.visible = aiming and pose == Pose.LIVE and not dead


## The pose for the current state, as joint rotations (radians) plus the rig's placement.
## Arms and legs hang along -Y: +X rotation swings a limb forward; elbows bend with +X,
## knees with -X. On the spine and neck, +X leans back (looks up), -X leans forward.
func _target_pose() -> Dictionary:
	var p := {"rig_position": Vector3.ZERO, "rig_rotation": Vector3.ZERO}
	match pose:
		Pose.CORPSE:
			return _corpse_pose(p)
		Pose.WAITING:
			return _waiting_pose(p)
	if dead:
		return _death_pose(p)

	var machine := look == Look.SUBJECT or look == Look.LISTENER
	var husk := look == Look.HUSK
	var walk := clampf(_speed / 4.0, 0.0, 1.0)
	var swing := sin(_phase)
	# Legs: alternate, the back leg's knee folds as it lifts.
	p["hip_l"] = Vector3(swing * 0.55 * walk, 0, 0)
	p["hip_r"] = Vector3(-swing * 0.55 * walk, 0, 0)
	p["knee_l"] = Vector3(-maxf(0.0, -cos(_phase)) * 0.9 * walk, 0, 0)
	p["knee_r"] = Vector3(-maxf(0.0, cos(_phase)) * 0.9 * walk, 0, 0)
	var bob := absf(cos(_phase)) * (0.02 if machine else 0.045) * walk
	p["rig_position"] = Vector3(0, bob - 0.02 * walk, 0)
	# Torso: the Visitor leans into the walk and breathes; the Subject does neither.
	var breath := 0.0 if machine else (sin(_time * 2.6) * 0.05 if husk else sin(_time * 1.7) * 0.025)
	p["spine"] = Vector3(-0.08 * walk + breath - (0.0 if machine else 0.06), sin(_phase) * 0.05 * walk, 0)
	p["neck"] = Vector3(0.05 * walk - breath, 0, 0)
	# Arms swing against the legs.
	var arm_swing := (0.25 if machine else 0.4) * walk
	p["shoulder_l"] = Vector3(-swing * arm_swing, 0, -0.12)
	p["shoulder_r"] = Vector3(swing * arm_swing, 0, 0.12)
	p["elbow_l"] = Vector3(0.2 + 0.2 * walk, 0, 0)
	p["elbow_r"] = Vector3(0.2 + 0.2 * walk, 0, 0)
	if husk:
		# Hunched, knees bent, arms reaching ahead of it.
		p["spine"] += Vector3(-0.35, 0, 0)
		p["neck"] += Vector3(0.3, 0, 0)
		p["shoulder_l"] = Vector3(0.35 - swing * 0.15 * walk, 0, -0.15)
		p["shoulder_r"] = Vector3(0.35 + swing * 0.15 * walk, 0, 0.15)
		p["hip_l"] += Vector3(0.1, 0, 0)
		p["hip_r"] += Vector3(0.1, 0, 0)
		p["knee_l"] += Vector3(-0.2, 0, 0)
		p["knee_r"] += Vector3(-0.2, 0, 0)
	elif look == Look.LISTENER:
		# Standing still, the dish turns and tilts, searching.
		var listen := 1.0 - walk
		p["neck"] = Vector3(0.1 * sin(_time * 0.9) * listen, 0.5 * sin(_time * 0.6) * listen, 0.3 * sin(_time * 0.7) * listen)

	if aiming:
		# Two-handed: right arm straight at the target, left arm bracing it.
		var kick := _recoil * 0.35
		p["shoulder_r"] = Vector3(PI / 2 + kick, 0.12, 0)
		p["elbow_r"] = Vector3(kick * 0.5, 0, 0)
		p["shoulder_l"] = Vector3(PI / 2 * 0.92 + kick, -0.45, 0)
		p["elbow_l"] = Vector3(0.35, 0, 0)
		p["spine"] = Vector3(-0.05 + kick * 0.15, -0.12, 0)
		p["neck"] = Vector3(0.05, 0.12, 0)
	if _gesture:
		var k := sin(clampf(_gesture_time / 0.6, 0.0, 1.0) * PI)
		if _gesture == "interact":
			p["shoulder_r"] = (p["shoulder_r"] as Vector3).lerp(Vector3(1.15, 0.1, 0), k)
			p["elbow_r"] = (p["elbow_r"] as Vector3).lerp(Vector3(0.3, 0, 0), k)
			p["neck"] = (p["neck"] as Vector3).lerp(Vector3(-0.3, 0, 0), k)
		elif _gesture == "shove":
			for side in ["l", "r"]:
				p["shoulder_" + side] = (p["shoulder_" + side] as Vector3).lerp(Vector3(PI / 2, 0, 0), k)
				p["elbow_" + side] = (p["elbow_" + side] as Vector3).lerp(Vector3.ZERO, k)
			p["spine"] = (p["spine"] as Vector3).lerp(Vector3(-0.3, 0, 0), k)
		elif _gesture == "attack":
			# Both arms rise over the head, then come down in a swipe.
			var g := clampf(_gesture_time / 0.6, 0.0, 1.0)
			var lift := 2.6 * (g / 0.45) if g < 0.45 else lerpf(2.6, 0.3, (g - 0.45) / 0.55)
			for side in ["l", "r"]:
				p["shoulder_" + side] = Vector3(lift, 0, 0)
				p["elbow_" + side] = Vector3(0.4, 0, 0)
			p["spine"] = Vector3(0.15 if g < 0.45 else -0.45, 0, 0)
	if _hurt > 0.0:
		p["spine"] += Vector3(0.4, 0, 0) * _hurt
		p["neck"] += Vector3(0.3, 0, 0) * _hurt
		p["shoulder_l"] += Vector3(-0.3, 0, -0.3) * _hurt
		p["shoulder_r"] += Vector3(-0.3, 0, 0.3) * _hurt
	return p


## Knees give, then the body drops back onto the floor and stays there.
func _death_pose(p: Dictionary) -> Dictionary:
	var buckle := clampf(_dead_time / (DEATH_TIME * 0.4), 0.0, 1.0)
	var fall := clampf((_dead_time - DEATH_TIME * 0.4) / (DEATH_TIME * 0.6), 0.0, 1.0)
	fall = fall * fall
	p["hip_l"] = Vector3(0.9 * buckle * (1.0 - fall), 0, 0)
	p["hip_r"] = Vector3(0.7 * buckle * (1.0 - fall) + 0.3 * fall, 0, 0)
	p["knee_l"] = Vector3(-1.4 * buckle * (1.0 - fall), 0, 0)
	p["knee_r"] = Vector3(-1.2 * buckle * (1.0 - fall) - 0.5 * fall, 0, 0)
	p["spine"] = Vector3(-0.3 * buckle * (1.0 - fall), 0, 0)
	p["neck"] = Vector3(-0.5 * buckle + 0.9 * fall, 0.4 * fall, 0)
	p["shoulder_l"] = Vector3(0.3 * buckle, 0, -0.2 - 1.0 * fall)
	p["shoulder_r"] = Vector3(0.3 * buckle, 0, 0.2 + 0.7 * fall)
	p["elbow_l"] = Vector3(0.4 * fall, 0, 0)
	p["elbow_r"] = Vector3(0.9 * fall, 0, 0)
	p["rig_position"] = Vector3(0, -0.45 * buckle * (1.0 - fall) + 0.12 * fall, 0)
	p["rig_rotation"] = Vector3(PI / 2 * fall, 0, 0) # backward, face up
	return p


## A body left behind. Lying on its back (even variation) or face down (odd), limbs placed
## a little differently each time.
func _corpse_pose(p: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = variation * 7919 + 17
	var face_down := variation % 2 == 1
	p["hip_l"] = Vector3(rng.randf_range(-0.1, 0.4), 0, rng.randf_range(-0.2, 0.0))
	p["hip_r"] = Vector3(rng.randf_range(0.0, 0.6), 0, rng.randf_range(0.0, 0.25))
	p["knee_l"] = Vector3(-rng.randf_range(0.0, 0.6), 0, 0)
	p["knee_r"] = Vector3(-rng.randf_range(0.2, 1.2), 0, 0)
	p["spine"] = Vector3(0, rng.randf_range(-0.2, 0.2), 0)
	p["neck"] = Vector3(rng.randf_range(0.2, 0.6) * (-1.0 if face_down else 1.0), rng.randf_range(-0.9, 0.9), 0)
	p["shoulder_l"] = Vector3(rng.randf_range(-0.3, 0.6), 0, -rng.randf_range(0.3, 1.4))
	p["shoulder_r"] = Vector3(rng.randf_range(-0.3, 0.6), 0, rng.randf_range(0.3, 1.4))
	p["elbow_l"] = Vector3(rng.randf_range(0.0, 1.2), 0, 0)
	p["elbow_r"] = Vector3(rng.randf_range(0.0, 1.2), 0, 0)
	p["rig_position"] = Vector3(0, 0.12, 0)
	p["rig_rotation"] = Vector3(-PI / 2 if face_down else PI / 2, 0, 0)
	return p


## Sitting on the floor, knees up, arms on the knees, head down: waiting for someone.
func _waiting_pose(p: Dictionary) -> Dictionary:
	p["hip_l"] = Vector3(2.2, 0, -0.12)
	p["hip_r"] = Vector3(2.2, 0, 0.12)
	p["knee_l"] = Vector3(-2.6, 0, 0)
	p["knee_r"] = Vector3(-2.6, 0, 0)
	p["spine"] = Vector3(-0.1, 0, 0)
	p["neck"] = Vector3(-0.55, 0, 0)
	p["shoulder_l"] = Vector3(0.9, 0, -0.1)
	p["shoulder_r"] = Vector3(0.9, 0, 0.1)
	p["elbow_l"] = Vector3(0.9, 0, 0)
	p["elbow_r"] = Vector3(0.9, 0, 0)
	p["rig_position"] = Vector3(0, -0.8, 0)
	return p


# --- Building ------------------------------------------------------------------

## Builds the figure for `look`: joints first, then the pieces hung on them.
func _build() -> void:
	for child in _rig.get_children():
		child.free()
	_gun = null
	if _rig.get_parent() == null:
		add_child(_rig)
	_joints.clear()
	_current.clear()
	var subject := look == Look.SUBJECT
	var visitor := look == Look.VISITOR
	# suit, skin, dark, trousers, bulk
	var palette: Array = {
		Look.SUBJECT: [Color(0.8, 0.82, 0.84), Color(0.86, 0.87, 0.88), Color(0.32, 0.34, 0.36), Color(0.72, 0.74, 0.76), 1.0],
		Look.VISITOR: [Color(0.9, 0.48, 0.22), Color(0.62, 0.48, 0.4), Color(0.14, 0.15, 0.17), Color(0.22, 0.25, 0.3), 1.18],
		Look.HUSK: [Color(0.44, 0.41, 0.38), Color(0.5, 0.47, 0.45), Color(0.22, 0.11, 0.1), Color(0.36, 0.33, 0.31), 0.95],
		Look.LISTENER: [Color(0.13, 0.13, 0.15), Color(0.2, 0.2, 0.23), Color(0.06, 0.06, 0.07), Color(0.11, 0.11, 0.13), 0.9],
	}[look]
	var suit := _material(palette[0])
	var skin := _material(palette[1])
	var dark := _material(palette[2])
	var trousers := _material(palette[3])
	var bulk: float = palette[4] # the Visitor's layers of clothing, the listener's thinness
	_rig.scale = Vector3.ONE * (1.15 if look == Look.LISTENER else 1.0)

	var hips := _joint("hips", _rig, Vector3(0, 0.92, 0))
	_piece(hips, Vector3(0.34 * bulk, 0.18, 0.21 * bulk), Vector3(0, 0.02, 0), trousers)
	var spine := _joint("spine", hips, Vector3(0, 0.1, 0))
	_piece(spine, Vector3(0.42 * bulk, 0.48, 0.24 * bulk), Vector3(0, 0.24, 0), suit)
	var neck := _joint("neck", spine, Vector3(0, 0.5, 0))
	if look != Look.LISTENER:
		_piece(neck, Vector3(0.21, 0.24, 0.23), Vector3(0, 0.14, 0), skin)
	if subject:
		# A seam at the waist and a faint light at the nape: what it is, if you look.
		_piece(spine, Vector3(0.43, 0.03, 0.25), Vector3(0, 0.02, 0), dark)
		_piece(neck, Vector3(0.06, 0.04, 0.01), Vector3(0, 0.08, 0.12), _glow(Color(0.45, 0.95, 0.82)))
	elif look == Look.HUSK:
		# The same seam as the Subject, the nape light dead, stains, and red eyes.
		_piece(spine, Vector3(0.41, 0.03, 0.24), Vector3(0, 0.02, 0), dark)
		_piece(spine, Vector3(0.22, 0.2, 0.01), Vector3(0.06, 0.3, -0.125), dark)
		_piece(spine, Vector3(0.12, 0.14, 0.01), Vector3(-0.1, 0.12, 0.125), dark)
		_piece(neck, Vector3(0.16, 0.035, 0.01), Vector3(0, 0.17, -0.12), _glow(Color(1.0, 0.2, 0.1)))
	elif look == Look.LISTENER:
		# No face: a narrow head carrying a dish, and an antenna with a slow red light.
		_piece(neck, Vector3(0.14, 0.3, 0.16), Vector3(0, 0.15, 0), skin)
		_piece(neck, Vector3(0.44, 0.38, 0.03), Vector3(0, 0.22, -0.1), dark)
		_piece(neck, Vector3(0.3, 0.26, 0.02), Vector3(0, 0.22, -0.12), suit)
		_piece(neck, Vector3(0.02, 0.36, 0.02), Vector3(0.12, 0.48, 0.02), dark)
		_piece(neck, Vector3(0.04, 0.04, 0.04), Vector3(0.12, 0.67, 0.02), _glow(Color(1.0, 0.15, 0.1)))
	else:
		# Hood up with a fur ruff, face in shadow, a backpack.
		_piece(neck, Vector3(0.3, 0.32, 0.31), Vector3(0, 0.15, 0.03), suit)
		_piece(neck, Vector3(0.32, 0.08, 0.06), Vector3(0, 0.12, -0.13), _material(Color(0.72, 0.68, 0.62)))
		_piece(neck, Vector3(0.18, 0.16, 0.02), Vector3(0, 0.14, -0.14), dark)
		_piece(spine, Vector3(0.36, 0.42, 0.18), Vector3(0, 0.26, 0.23), _material(Color(0.24, 0.26, 0.2)))
		_piece(spine, Vector3(0.44 * bulk, 0.05, 0.25 * bulk), Vector3(0, 0.03, 0), dark)

	for side in [-1, 1]:
		var s := "l" if side < 0 else "r"
		var shoulder := _joint("shoulder_" + s, spine, Vector3(0.25 * side * bulk, 0.42, 0))
		_piece(shoulder, Vector3(0.1 * bulk, 0.3, 0.1 * bulk), Vector3(0, -0.14, 0), suit)
		var elbow := _joint("elbow_" + s, shoulder, Vector3(0, -0.29, 0))
		# Enemies' forearms are longer than a person's.
		var forearm := 0.27 if subject or visitor else 0.36
		_piece(elbow, Vector3(0.09 * bulk, forearm, 0.09 * bulk), Vector3(0, -forearm / 2.0, 0), suit)
		_piece(elbow, Vector3(0.08, 0.09, 0.09), Vector3(0, -forearm - 0.03, 0), skin if not visitor else dark)
		if s == "r" and (subject or visitor):
			# The pistol, shown only while aiming.
			_gun = Node3D.new()
			_gun.name = "Gun"
			_gun.position = Vector3(0, -0.32, -0.04)
			elbow.add_child(_gun)
			_piece(_gun, Vector3(0.05, 0.2, 0.1), Vector3(0, -0.05, -0.03), dark)
		var hip := _joint("hip_" + s, hips, Vector3(0.1 * side, -0.02, 0))
		_piece(hip, Vector3(0.14 * bulk, 0.44, 0.15 * bulk), Vector3(0, -0.21, 0), trousers)
		var knee := _joint("knee_" + s, hip, Vector3(0, -0.44, 0))
		_piece(knee, Vector3(0.12 * bulk, 0.42, 0.13 * bulk), Vector3(0, -0.2, 0), dark if visitor else trousers)
		_piece(knee, Vector3(0.12 * bulk, 0.08, 0.25), Vector3(0, -0.42, -0.05), dark)
	for joint: String in _joints:
		_current[joint] = Vector3.ZERO
	_apply_pose(1.0)


func _joint(joint_name: String, parent: Node3D, at: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.name = joint_name.to_pascal_case()
	joint.position = at
	parent.add_child(joint)
	_joints[joint_name] = joint
	return joint


func _piece(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	var piece := MeshInstance3D.new()
	piece.mesh = box
	piece.position = at
	piece.material_override = material
	piece.layers = visual_layers
	parent.add_child(piece)


func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.9
		_materials[color] = material
	return _materials[color]


func _glow(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	return material
