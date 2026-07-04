class_name FireballParticles
extends RefCounted

## Shared CPUParticles3D builders for fireball VFX.


static func make_burst(
	node_name: String,
	amount: int,
	color: Color,
	velocity_min: float,
	velocity_max: float,
	lifetime: float,
	explosiveness: float,
	gravity: Vector3 = Vector3(0.0, -4.0, 0.0),
	render_preset: String = "spark"
) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = node_name
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = explosiveness
	particles.amount = amount
	particles.lifetime = lifetime
	particles.local_coords = false
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = velocity_min
	particles.initial_velocity_max = velocity_max
	particles.gravity = gravity
	particles.scale_amount_min = 0.04
	particles.scale_amount_max = 0.12
	particles.color = color
	apply_render_setup(particles, render_preset)
	return particles


static func make_drift(
	node_name: String,
	amount: int,
	lifetime: float,
	color: Color,
	direction: Vector3 = Vector3.DOWN,
	spread: float = 35.0
) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = node_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.local_coords = false
	particles.direction = direction
	particles.spread = spread
	particles.initial_velocity_min = 0.4
	particles.initial_velocity_max = 1.4
	particles.gravity = Vector3(0.0, -1.2, 0.0)
	particles.scale_amount_min = 0.03
	particles.scale_amount_max = 0.08
	particles.color = color
	apply_render_setup(particles, "ember")
	return particles


static func make_smoke_trail_emitter() -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "FireballSmokeTrail"
	particles.emitting = true
	particles.amount = 72
	particles.lifetime = 2.0
	particles.lifetime_randomness = 0.25
	particles.explosiveness = 0.0
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.14
	particles.direction = Vector3(0.0, 0.15, 0.0)
	particles.spread = 42.0
	particles.initial_velocity_min = 0.35
	particles.initial_velocity_max = 1.4
	particles.gravity = Vector3(0.0, 0.25, 0.0)
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 0.85
	particles.color = Color(0.72, 0.68, 0.62, 0.82)
	particles.color_ramp = _make_smoke_color_ramp()
	apply_render_setup(particles, "smoke_trail")
	return particles


static func make_comet_spark_emitter() -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "FireballCometSparks"
	particles.emitting = true
	particles.amount = 48
	particles.lifetime = 0.55
	particles.lifetime_randomness = 0.35
	particles.explosiveness = 0.0
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.08
	particles.direction = Vector3.UP
	particles.spread = 28.0
	particles.initial_velocity_min = 0.8
	particles.initial_velocity_max = 2.8
	particles.gravity = Vector3(0.0, -1.5, 0.0)
	particles.scale_amount_min = 0.08
	particles.scale_amount_max = 0.18
	particles.color = Color(1.0, 0.78, 0.35, 0.95)
	apply_render_setup(particles, "spark")
	return particles


static func make_firework_shell(
	node_name: String,
	amount: int,
	color: Color,
	velocity_min: float,
	velocity_max: float
) -> CPUParticles3D:
	var particles := make_burst(
		node_name,
		amount,
		color,
		velocity_min,
		velocity_max,
		1.8,
		1.0,
		Vector3(0.0, -2.4, 0.0),
		"firework"
	)
	particles.lifetime_randomness = 0.2
	particles.scale_amount_min = 0.12
	particles.scale_amount_max = 0.32
	particles.color_ramp = _make_firework_color_ramp(color)
	return particles


static func make_signal_smoke_column() -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "SignalSmokeColumn"
	particles.emitting = true
	particles.amount = 36
	particles.lifetime = 4.5
	particles.lifetime_randomness = 0.2
	particles.explosiveness = 0.0
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.35
	particles.direction = Vector3.UP
	particles.spread = 8.0
	particles.initial_velocity_min = 1.2
	particles.initial_velocity_max = 2.8
	particles.gravity = Vector3(0.0, -0.15, 0.0)
	particles.scale_amount_min = 0.45
	particles.scale_amount_max = 1.1
	particles.color = Color(0.82, 0.78, 0.72, 0.55)
	particles.color_ramp = _make_smoke_color_ramp()
	apply_render_setup(particles, "smoke_trail")
	return particles


static func apply_render_setup(particles: CPUParticles3D, preset: String) -> void:
	var quad := QuadMesh.new()
	match preset:
		"smoke_trail":
			quad.size = Vector2(0.55, 0.55)
		"firework":
			quad.size = Vector2(0.24, 0.24)
		"ember":
			quad.size = Vector2(0.12, 0.12)
		_:
			quad.size = Vector2(0.16, 0.16)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	match preset:
		"smoke_trail":
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		"firework", "ember":
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_:
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

	particles.mesh = quad
	particles.material_override = mat
	particles.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))


static func make_explosion_core_burst() -> CPUParticles3D:
	var particles := make_burst(
		"ExplosionCore",
		88,
		Color(1.0, 0.96, 0.82, 1.0),
		10.0,
		24.0,
		0.48,
		1.0,
		Vector3(0.0, -3.5, 0.0),
		"firework"
	)
	particles.scale_amount_min = 0.16
	particles.scale_amount_max = 0.42
	particles.color_ramp = _make_explosion_flash_ramp()
	return particles


static func make_explosion_fire_burst() -> CPUParticles3D:
	var particles := make_burst(
		"ExplosionFire",
		64,
		Color(1.0, 0.58, 0.12, 1.0),
		5.5,
		14.0,
		0.78,
		0.98,
		Vector3(0.0, -5.0, 0.0),
		"firework"
	)
	particles.scale_amount_min = 0.1
	particles.scale_amount_max = 0.28
	particles.color_ramp = _make_explosion_fire_ramp()
	return particles


static func make_explosion_smoke_burst() -> CPUParticles3D:
	var particles := make_burst(
		"ExplosionSmoke",
		36,
		Color(0.42, 0.38, 0.34, 0.82),
		1.8,
		5.5,
		1.15,
		0.82,
		Vector3(0.0, 2.8, 0.0),
		"smoke_trail"
	)
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 0.95
	particles.color_ramp = _make_smoke_color_ramp()
	return particles


static func make_explosion_ember_linger() -> CPUParticles3D:
	var particles := make_drift(
		"ExplosionEmbers",
		40,
		1.35,
		Color(1.0, 0.62, 0.18, 0.95),
		Vector3.UP,
		120.0
	)
	particles.one_shot = true
	particles.explosiveness = 0.88
	particles.initial_velocity_min = 1.4
	particles.initial_velocity_max = 4.8
	particles.gravity = Vector3(0.0, -4.5, 0.0)
	particles.scale_amount_min = 0.06
	particles.scale_amount_max = 0.16
	return particles


static func explosion_cleanup_delay_sec() -> float:
	return 1.45


static func _make_explosion_flash_ramp() -> Gradient:
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 0.95, 1.0))
	gradient.add_point(0.1, Color(1.0, 0.92, 0.35, 1.0))
	gradient.add_point(0.35, Color(1.0, 0.45, 0.08, 0.85))
	gradient.add_point(1.0, Color(0.45, 0.12, 0.02, 0.0))
	return gradient


static func _make_explosion_fire_ramp() -> Gradient:
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.88, 0.42, 1.0))
	gradient.add_point(0.25, Color(1.0, 0.48, 0.08, 0.9))
	gradient.add_point(1.0, Color(0.35, 0.08, 0.02, 0.0))
	return gradient


static func smoke_trail_fade_delay_sec(
	particle_lifetime: float,
	padding_sec: float = 0.35
) -> float:
	return particle_lifetime + padding_sec


static func _make_smoke_color_ramp() -> Gradient:
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(0.95, 0.72, 0.38, 0.85))
	gradient.add_point(0.25, Color(0.62, 0.58, 0.54, 0.72))
	gradient.add_point(1.0, Color(0.35, 0.33, 0.3, 0.0))
	return gradient


static func _make_firework_color_ramp(base_color: Color) -> Gradient:
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.98, 0.92, 1.0))
	gradient.add_point(0.15, base_color)
	gradient.add_point(0.65, base_color.lightened(0.15))
	gradient.add_point(1.0, Color(base_color.r, base_color.g, base_color.b, 0.0))
	return gradient
