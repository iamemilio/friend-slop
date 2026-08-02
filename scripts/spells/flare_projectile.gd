class_name FlareProjectile
extends Node3D

## Rising signal spark that bursts into a sky flare. Separate from Fireball.

const SPEED := 16.0

const SkyFlareEffectScript := preload("res://scripts/spells/sky_flare_effect.gd")
const FireballParticlesScript := preload("res://scripts/spells/fireball_particles.gd")
const FireballLightingScript := preload("res://scripts/spells/fireball_lighting.gd")
const FireballSmokeTrailScript := preload("res://scripts/spells/fireball_smoke_trail.gd")

var _direction := Vector3.UP
var _elapsed := 0.0
var _travelled := 0.0
var _smoke_trail: CPUParticles3D
var _comet_sparks: CPUParticles3D
var _travel_light: OmniLight3D
var _core_mesh: MeshInstance3D
var _core_material: StandardMaterial3D
var _glow_tween: Tween


static func spawn(parent: Node, origin: Vector3, direction: Vector3) -> Node3D:
	var projectile = new()
	var dir := direction
	if dir.length_squared() < 0.0001:
		dir = Vector3.FORWARD
	else:
		dir = dir.normalized()
	## Travel exactly along cast aim (wand → crosshair); burst wherever it finishes.
	projectile._direction = dir
	parent.add_child(projectile)
	projectile.global_position = origin
	return projectile


func _ready() -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.56
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.45, 0.1)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.35, 0.05)
	material.emission_energy_multiplier = 3.2
	material.roughness = 0.2
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core_material = material
	mesh_instance.material_override = material
	_core_mesh = mesh_instance
	add_child(mesh_instance)

	_travel_light = FireballLightingScript.make_travel_cast_light(true)
	add_child(_travel_light)
	_glow_tween = FireballLightingScript.start_travel_glow_pulse(
		self, _travel_light, _core_material, true
	)

	_smoke_trail = FireballSmokeTrailScript.create_emitter()
	_smoke_trail.position = -_direction * 0.28
	add_child(_smoke_trail)

	_comet_sparks = FireballParticlesScript.make_comet_spark_emitter()
	_comet_sparks.position = -_direction * 0.18
	add_child(_comet_sparks)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var motion: Vector3 = _direction * SPEED * delta
	_travelled += motion.length()
	global_position += motion
	if FireballFlight.should_finish_sky_flare(_elapsed, _travelled):
		_finish()


func _finish() -> void:
	if not is_inside_tree():
		return
	var world_parent := get_parent()
	var impact_pos := global_position
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	if _smoke_trail != null and is_instance_valid(_smoke_trail):
		_smoke_trail.queue_free()
	if _comet_sparks != null and is_instance_valid(_comet_sparks):
		_comet_sparks.queue_free()
	if _core_mesh != null:
		_core_mesh.visible = false
	if _travel_light != null:
		_travel_light.visible = false
	visible = false
	SkyFlareEffectScript.spawn(world_parent, impact_pos)
	queue_free()
