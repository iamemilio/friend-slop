class_name FireballProjectile
extends Area3D

## Forward-moving fireball; upward casts burst into a sky flare signal.

const SPEED := 16.0

const SkyFlareEffectScript := preload("res://scripts/spells/sky_flare_effect.gd")
const FireballExplosionEffectScript := preload("res://scripts/spells/fireball_explosion_effect.gd")
const FireballSmokeTrailScript := preload("res://scripts/spells/fireball_smoke_trail.gd")
const FireballParticlesScript := preload("res://scripts/spells/fireball_particles.gd")

var _direction := Vector3.FORWARD
var _elapsed := 0.0
var _sky_flare_mode := false
var _travelled := 0.0
var _smoke_trail: CPUParticles3D
var _comet_sparks: CPUParticles3D
var _hit_shape: SphereShape3D


static func spawn(parent: Node, origin: Vector3, direction: Vector3) -> FireballProjectile:
	var projectile := FireballProjectile.new()
	projectile._direction = direction.normalized()
	projectile._sky_flare_mode = FireballFlight.is_sky_flare_direction(projectile._direction)
	projectile.global_position = origin
	parent.add_child(projectile)
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
	material.emission_energy_multiplier = 3.0 if not _sky_flare_mode else 4.5
	material.roughness = 0.2
	mesh_instance.material_override = material
	add_child(mesh_instance)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.15)
	light.light_energy = 2.0 if not _sky_flare_mode else 3.5
	light.omni_range = 5.0 if not _sky_flare_mode else 8.0
	add_child(light)

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
	FireballSmokeTrailScript.release_emitter(_smoke_trail, world_parent)
	_smoke_trail = null
	if _comet_sparks != null and is_instance_valid(_comet_sparks):
		FireballSmokeTrailScript.release_emitter(_comet_sparks, world_parent)
		_comet_sparks = null
	if sky_flare:
		SkyFlareEffectScript.spawn(world_parent, impact_pos)
	else:
		FireballExplosionEffectScript.spawn(world_parent, impact_pos)
	queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		return
	_finish(false)
