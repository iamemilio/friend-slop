class_name PlayerWand
extends Node3D

## Slim hand-held wand with tip spotlight and cast / fizzle feedback.

const WORLD_LIGHT_CULL_MASK := 1

const TIP_SPOT_ARMED_ENERGY := 0.8
const TIP_SPOT_LISTEN_MAX_BOOST := 11.0
const TIP_SPOT_RANGE := 8.0
const TIP_SPOT_ANGLE_DEG := 42.0
const TIP_SPOT_LISTEN_ANGLE_BOOST_DEG := 14.0
const TIP_IDLE_ENERGY := 0.0
const TIP_EMISSION_ARMED := 0.4
const TIP_EMISSION_LISTEN_MAX := 10.0
const TIP_SCALE_LISTEN_BOOST := 0.38
const LISTEN_LEVEL_REFERENCE := 0.08
const LISTEN_PEAK_DECAY := 0.68
const LISTEN_VISUAL_CURVE := 0.62
const SHAFT_LENGTH := 0.28
const SHAFT_TOP_RADIUS := 0.007
const SHAFT_BOTTOM_RADIUS := 0.010
const TIP_RADIUS := 0.012
const SPELL_LIGHT_ENERGY := 3.2
const SPELL_LIGHT_RANGE := 9.0
const SPELL_LIGHT_ANGLE_DEG := 55.0

var _shaft_mesh: MeshInstance3D
var _tip_mesh: MeshInstance3D
var _tip_spot: SpotLight3D
var _spell_cast_light: SpotLight3D
var _spell_light_tween: Tween
var _cast_origin: Marker3D
var _fizzle_particles: CPUParticles3D
var _success_particles: CPUParticles3D
var _armed := false
var _listen_level: float = 0.0
var _listen_peak: float = 0.0


func _ready() -> void:
	_build_wand_meshes()
	_build_particles()
	set_armed(false)


func set_armed(active: bool) -> void:
	_armed = active
	if not active:
		_listen_level = 0.0
		_listen_peak = 0.0
	_refresh_tip_light()


func set_listen_level(level: float) -> void:
	var normalized := clampf(level / LISTEN_LEVEL_REFERENCE, 0.0, 1.0)
	_listen_peak = maxf(_listen_peak * LISTEN_PEAK_DECAY, normalized)
	_listen_level = _listen_peak
	_refresh_tip_light()


func get_cast_origin() -> Vector3:
	return _cast_origin.global_position if _cast_origin != null else global_position


func get_cast_direction() -> Vector3:
	return -global_transform.basis.z.normalized()


func play_cast_success(spell: SpellDefinition = null, keep_armed: bool = false) -> void:
	if not keep_armed:
		set_armed(false)
	_emit_burst(_success_particles, _success_color_for_spell(spell))
	_pulse_tip(Color(1.0, 0.98, 0.92), 0.35)


func play_fizzle(keep_armed: bool = false) -> void:
	if not keep_armed:
		set_armed(false)
	_emit_burst(_fizzle_particles, Color(0.55, 0.5, 0.65))
	_pulse_tip(Color(0.65, 0.55, 0.75), 0.2)


func play_spell_light(duration: float) -> void:
	if _spell_cast_light == null:
		return
	if _spell_light_tween != null and _spell_light_tween.is_valid():
		_spell_light_tween.kill()
	_spell_cast_light.visible = true
	_spell_cast_light.light_energy = SPELL_LIGHT_ENERGY
	_set_tip_emission(Color(0.95, 0.85, 0.45), 2.6)
	_spell_light_tween = create_tween()
	_spell_light_tween.tween_property(_spell_cast_light, "light_energy", 0.0, duration)
	_spell_light_tween.tween_callback(_finish_spell_light)


func _build_wand_meshes() -> void:
	var tip_offset := _tip_local_position()

	_shaft_mesh = MeshInstance3D.new()
	_shaft_mesh.name = "Shaft"
	var shaft := CylinderMesh.new()
	shaft.top_radius = SHAFT_TOP_RADIUS
	shaft.bottom_radius = SHAFT_BOTTOM_RADIUS
	shaft.height = SHAFT_LENGTH
	_shaft_mesh.mesh = shaft
	_shaft_mesh.position = tip_offset * 0.5
	_shaft_mesh.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var shaft_mat := StandardMaterial3D.new()
	shaft_mat.albedo_color = Color(0.18, 0.12, 0.1)
	shaft_mat.roughness = 0.55
	shaft_mat.metallic = 0.35
	_shaft_mesh.material_override = shaft_mat
	add_child(_shaft_mesh)

	_tip_mesh = MeshInstance3D.new()
	_tip_mesh.name = "Tip"
	var tip := SphereMesh.new()
	tip.radius = TIP_RADIUS
	tip.height = TIP_RADIUS * 2.0
	_tip_mesh.mesh = tip
	_tip_mesh.position = tip_offset
	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color(0.85, 0.88, 0.95)
	tip_mat.emission_enabled = true
	tip_mat.emission = Color.WHITE
	tip_mat.emission_energy_multiplier = 0.0
	tip_mat.roughness = 0.15
	tip_mat.metallic = 0.2
	_tip_mesh.material_override = tip_mat
	add_child(_tip_mesh)

	_cast_origin = Marker3D.new()
	_cast_origin.name = "CastOrigin"
	_cast_origin.position = tip_offset + Vector3(0.0, 0.0, -0.025)
	add_child(_cast_origin)

	_tip_spot = SpotLight3D.new()
	_tip_spot.name = "TipSpotLight"
	_tip_spot.position = Vector3.ZERO
	_tip_spot.spot_range = TIP_SPOT_RANGE
	_tip_spot.spot_angle = deg_to_rad(TIP_SPOT_ANGLE_DEG)
	_tip_spot.spot_attenuation = 1.15
	_tip_spot.light_color = Color(0.95, 0.92, 1.0)
	_configure_world_light(_tip_spot)
	_cast_origin.add_child(_tip_spot)

	_spell_cast_light = SpotLight3D.new()
	_spell_cast_light.name = "SpellCastLight"
	_spell_cast_light.position = Vector3.ZERO
	_spell_cast_light.spot_range = SPELL_LIGHT_RANGE
	_spell_cast_light.spot_angle = deg_to_rad(SPELL_LIGHT_ANGLE_DEG)
	_spell_cast_light.light_color = Color(0.95, 0.85, 0.45)
	_spell_cast_light.light_energy = 0.0
	_spell_cast_light.visible = false
	_configure_world_light(_spell_cast_light)
	_cast_origin.add_child(_spell_cast_light)


func _build_particles() -> void:
	_fizzle_particles = _make_burst_particles("FizzleParticles", Color(0.55, 0.5, 0.65))
	_success_particles = _make_burst_particles("SuccessParticles", Color(1.0, 0.92, 0.75))
	add_child(_fizzle_particles)
	add_child(_success_particles)


func _make_burst_particles(node_name: String, color: Color) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = node_name
	particles.position = _tip_local_position()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = 16
	particles.lifetime = 0.4
	particles.local_coords = true
	particles.direction = Vector3(0.0, 0.0, -1.0)
	particles.spread = 35.0
	particles.initial_velocity_min = 0.6
	particles.initial_velocity_max = 1.6
	particles.gravity = Vector3(0.0, -2.0, 0.0)
	particles.scale_amount_min = 0.025
	particles.scale_amount_max = 0.06
	particles.color = color
	return particles


func _refresh_tip_light() -> void:
	var energy := TIP_IDLE_ENERGY
	var emission := 0.0
	var spot_angle := TIP_SPOT_ANGLE_DEG
	var visual := 0.0
	if _armed:
		visual = _listen_visual_strength(_listen_level)
		energy = TIP_SPOT_ARMED_ENERGY + visual * TIP_SPOT_LISTEN_MAX_BOOST
		emission = TIP_EMISSION_ARMED + visual * TIP_EMISSION_LISTEN_MAX
		spot_angle = TIP_SPOT_ANGLE_DEG + visual * TIP_SPOT_LISTEN_ANGLE_BOOST_DEG
	_tip_spot.light_energy = energy
	_tip_spot.spot_angle = deg_to_rad(spot_angle)
	_tip_spot.light_color = Color(0.92, 0.94, 1.0).lerp(Color(1.0, 0.96, 0.82), visual)
	_apply_tip_visual(visual, emission)


static func _listen_visual_strength(listen_level: float) -> float:
	return pow(clampf(listen_level, 0.0, 1.0), LISTEN_VISUAL_CURVE)


func _apply_tip_visual(visual: float, emission: float) -> void:
	if _tip_mesh.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = _tip_mesh.material_override
		var dim := Color(0.72, 0.76, 0.88)
		var bright := Color(1.0, 0.98, 0.92)
		mat.albedo_color = dim.lerp(bright, visual)
		var glow := Color(0.82, 0.88, 1.0).lerp(Color(1.0, 0.94, 0.78), visual)
		mat.emission = glow
		mat.emission_energy_multiplier = emission
	_tip_mesh.scale = Vector3.ONE * (1.0 + visual * TIP_SCALE_LISTEN_BOOST)


func _pulse_tip(color: Color, duration: float) -> void:
	_set_tip_emission(color, 2.0)
	var tween := create_tween()
	tween.tween_property(_tip_spot, "light_energy", 0.0, duration)


func _emit_burst(particles: CPUParticles3D, color: Color) -> void:
	if particles == null:
		return
	particles.color = color
	particles.position = _tip_local_position()
	particles.restart()
	particles.emitting = true


func _finish_spell_light() -> void:
	if _spell_cast_light != null:
		_spell_cast_light.visible = false
	_refresh_tip_light()


func _configure_world_light(light: Light3D) -> void:
	light.light_cull_mask = WORLD_LIGHT_CULL_MASK
	light.shadow_enabled = true
	light.shadow_bias = 0.04
	light.shadow_normal_bias = 1.0


func _set_tip_emission(color: Color, energy: float) -> void:
	if _tip_mesh.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = _tip_mesh.material_override
		mat.emission = color
		mat.emission_energy_multiplier = energy


func _tip_local_position() -> Vector3:
	return Vector3(0.0, 0.0, -SHAFT_LENGTH)


func _success_color_for_spell(spell: SpellDefinition) -> Color:
	if spell == null:
		return Color(1.0, 0.95, 0.85)
	match spell.effect_id:
		"fireball":
			return Color(1.0, 0.55, 0.15)
		"light":
			return Color(1.0, 0.92, 0.55)
		"haste":
			return Color(0.55, 0.82, 1.0)
		_:
			return Color(1.0, 0.95, 0.85)
