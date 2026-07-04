class_name FireballProjectile
extends Area3D

## Forward-moving fireball; upward casts burst into a sky flare signal.

const SPEED := 16.0

const SkyFlareEffectScript := preload("res://scripts/spells/sky_flare_effect.gd")
const FireballExplosionEffectScript := preload("res://scripts/spells/fireball_explosion_effect.gd")
const FireballSmokeTrailScript := preload("res://scripts/spells/fireball_smoke_trail.gd")
const FireballParticlesScript := preload("res://scripts/spells/fireball_particles.gd")
const FireballLightingScript := preload("res://scripts/spells/fireball_lighting.gd")

var _direction := Vector3.FORWARD
var _elapsed := 0.0
var _sky_flare_mode := false
var _travelled := 0.0
var _smoke_trail: CPUParticles3D
var _comet_sparks: CPUParticles3D
var _hit_shape: SphereShape3D
var _travel_light: OmniLight3D
var _core_material: StandardMaterial3D
var _core_mesh: MeshInstance3D
var _glow_tween: Tween


static func spawn(parent: Node, origin: Vector3, direction: Vector3) -> FireballProjectile:
	var projectile := FireballProjectile.new()
	projectile._direction = direction.normalized()
	projectile._sky_flare_mode = FireballFlight.is_sky_flare_direction(projectile._direction)
	parent.add_child(projectile)
	projectile.global_position = origin
	return projectile


static func is_sky_flare_direction(direction: Vector3) -> bool:
	return FireballFlight.is_sky_flare_direction(direction)


func _ready() -> void:
	monitoring = not _sky_flare_mode
	monitorable = false
	collision_layer = 0
	collision_mask = 1 if not _sky_flare_mode else 0

	var shape := SphereShape3D.new()
	shape.radius = FireballFlight.HIT_RADIUS
	_hit_shape = shape
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = FireballFlight.VISUAL_RADIUS if not _sky_flare_mode else 0.28
	mesh.height = mesh.radius * 2.0
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.45, 0.1)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.35, 0.05)
	material.emission_energy_multiplier = 2.4 if not _sky_flare_mode else 3.2
	material.roughness = 0.2
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core_material = material
	mesh_instance.material_override = material
	_core_mesh = mesh_instance
	add_child(mesh_instance)

	_travel_light = FireballLightingScript.make_travel_cast_light(_sky_flare_mode)
	add_child(_travel_light)

	_glow_tween = FireballLightingScript.start_travel_glow_pulse(
		self,
		_travel_light,
		_core_material,
		_sky_flare_mode
	)

	_smoke_trail = FireballSmokeTrailScript.create_emitter()
	_smoke_trail.position = -_direction * 0.28
	add_child(_smoke_trail)

	if _sky_flare_mode:
		_comet_sparks = FireballParticlesScript.make_comet_spark_emitter()
		_comet_sparks.position = -_direction * 0.18
		add_child(_comet_sparks)

	if not _sky_flare_mode:
		body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _sky_flare_mode:
		_process_sky_flare(delta)
		return

	if FireballFlight.should_finish_normal(_elapsed):
		_finish(false)
		return

	var motion: Vector3 = _direction * SPEED * delta
	if _cast_motion_hit(motion):
		return
	global_position += motion


func _cast_motion_hit(motion: Vector3) -> bool:
	if _hit_shape == null:
		return false
	var space_state := get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _hit_shape
	params.transform = global_transform
	params.motion = motion
	params.exclude = [get_rid()]
	params.collision_mask = collision_mask
	var contact := space_state.cast_motion(params)
	var safe_fraction: float = contact[0]
	if safe_fraction >= 1.0:
		return false
	global_position += motion * safe_fraction
	_finish(false)
	return true


func _process_sky_flare(delta: float) -> void:
	var motion: Vector3 = _direction * SPEED * delta
	_travelled += motion.length()
	global_position += motion

	if FireballFlight.should_finish_sky_flare(_elapsed, _travelled):
		_finish(true)


func _finish(sky_flare: bool) -> void:
	if not is_inside_tree():
		return
	var world_parent := get_parent()
	var impact_pos := global_position
	_clear_projectile_visuals()
	if sky_flare:
		SkyFlareEffectScript.spawn(world_parent, impact_pos)
	else:
		FireballExplosionEffectScript.spawn(world_parent, impact_pos)
	queue_free()


func _clear_projectile_visuals() -> void:
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
		_glow_tween = null
	if _smoke_trail != null and is_instance_valid(_smoke_trail):
		_smoke_trail.queue_free()
		_smoke_trail = null
	if _comet_sparks != null and is_instance_valid(_comet_sparks):
		_comet_sparks.queue_free()
		_comet_sparks = null
	if _core_mesh != null and is_instance_valid(_core_mesh):
		_core_mesh.visible = false
	if _travel_light != null and is_instance_valid(_travel_light):
		_travel_light.visible = false
		_travel_light.light_energy = 0.0
	visible = false


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		return
	_finish(false)
