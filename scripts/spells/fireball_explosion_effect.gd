class_name FireballExplosionEffect
extends Node3D

## Impact burst when a fireball hits geometry.

const FireballParticlesScript := preload("res://scripts/spells/fireball_particles.gd")
const FireballLightingScript := preload("res://scripts/spells/fireball_lighting.gd")


static func spawn(parent: Node, world_position: Vector3) -> FireballExplosionEffect:
	var effect := FireballExplosionEffect.new()
	parent.add_child(effect)
	effect.global_position = world_position
	effect._play()
	return effect


func _play() -> void:
	var flash := FireballLightingScript.make_explosion_flash_light()
	add_child(flash)

	var glow := FireballLightingScript.make_explosion_glow_light()
	add_child(glow)

	_emit_particles(FireballParticlesScript.make_explosion_core_burst())
	_emit_particles(FireballParticlesScript.make_explosion_fire_burst())
	_emit_particles(FireballParticlesScript.make_explosion_smoke_burst())
	_emit_particles(FireballParticlesScript.make_explosion_ember_linger())

	var shockwave := _build_shockwave()
	add_child(shockwave)

	var flash_tween := create_tween()
	flash_tween.set_parallel(true)
	flash_tween.tween_property(flash, "light_energy", 0.0, 0.14)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	flash_tween.tween_property(flash, "omni_range", 26.0, 0.06)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	flash_tween.tween_property(glow, "light_energy", 0.0, 0.9)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flash_tween.tween_property(shockwave, "scale", Vector3.ONE * 6.0, 0.42)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	var shock_mat := shockwave.material_override as StandardMaterial3D
	if shock_mat != null:
		flash_tween.tween_method(
			func(intensity: float) -> void:
				shock_mat.albedo_color.a = intensity * 0.42
				shock_mat.emission_energy_multiplier = intensity * 3.5,
			1.0,
			0.0,
			0.42
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var cleanup := create_tween()
	cleanup.tween_interval(FireballParticlesScript.explosion_cleanup_delay_sec())
	cleanup.tween_callback(queue_free)


func _emit_particles(particles: CPUParticles3D) -> void:
	add_child(particles)
	particles.emitting = true
	particles.restart()


func _build_shockwave() -> MeshInstance3D:
	var shockwave := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.4
	mesh.height = 0.8
	shockwave.mesh = mesh
	shockwave.scale = Vector3.ONE * 0.12
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.72, 0.22, 0.42)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.1)
	mat.emission_energy_multiplier = 3.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shockwave.material_override = mat
	return shockwave
