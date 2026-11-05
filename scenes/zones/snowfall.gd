class_name Snowfall
extends GPUParticles3D
## Driving snow around the local player in a blizzard (EnvironmentZone.snowfall): flakes
## blown hard sideways through a box around them, thick enough to hide what the fog doesn't.
## The player moves it along and switches `emitting`; only the local player has one.

const BOX := Vector3(14, 6, 14)


func _init() -> void:
	amount = 2200
	lifetime = 1.6
	preprocess = 1.6
	emitting = false
	local_coords = false
	visibility_aabb = AABB(-BOX, BOX * 2.0)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = BOX / 2.0
	process.direction = Vector3(1, -0.4, 0.3)
	process.spread = 12.0
	process.initial_velocity_min = 7.0
	process.initial_velocity_max = 12.0
	process.gravity = Vector3(2, -3, 0.5)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 1.5
	process.scale_min = 0.6
	process.scale_max = 1.4
	process_material = process
	var flake := QuadMesh.new()
	flake.size = Vector2(0.05, 0.05)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_color = Color(0.95, 0.97, 1.0, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.set_meta("retro_skip", true)
	flake.material = material
	draw_pass_1 = flake
