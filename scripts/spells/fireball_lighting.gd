class_name FireballLighting
extends RefCounted

## Shadow-casting omni lights and emissive halos for fireball VFX.


static func configure_cast_light(
	light: OmniLight3D,
	energy: float,
	range: float,
	color: Color,
	enable_shadows: bool = true
) -> void:
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range
	light.omni_attenuation = 1.35
	light.light_specular = 0.4
	light.shadow_enabled = enable_shadows
	if enable_shadows:
		light.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
		light.shadow_bias = 0.04
		light.shadow_normal_bias = 1.1


static func make_travel_cast_light(sky_flare: bool = false) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = "TravelCastLight"
	if sky_flare:
		configure_cast_light(light, 2.4, 7.5, Color(1.0, 0.58, 0.18))
	else:
		configure_cast_light(light, 1.35, 4.8, Color(1.0, 0.5, 0.14))
	return light


static func make_travel_halo_mesh() -> MeshInstance3D:
	var halo := MeshInstance3D.new()
	halo.name = "TravelHalo"
	var mesh := SphereMesh.new()
	mesh.radius = FireballFlight.VISUAL_RADIUS * 2.15
	mesh.height = mesh.radius * 2.0
	halo.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.55, 0.12, 0.14)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.42, 0.08)
	material.emission_energy_multiplier = 1.6
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	halo.material_override = material
	return halo


static func start_travel_glow_pulse(
	owner: Node,
	cast_light: OmniLight3D,
	core_material: StandardMaterial3D,
	halo: MeshInstance3D,
	sky_flare: bool = false
) -> void:
	var peak_energy := 2.8 if sky_flare else 1.75
	var base_energy := 1.6 if sky_flare else 1.05
	var peak_emission := 4.2 if sky_flare else 3.2
	var base_emission := 2.6 if sky_flare else 2.2
	var halo_mat := halo.material_override as StandardMaterial3D if halo != null else null

	var pulse := owner.create_tween()
	pulse.set_loops()
	pulse.tween_method(
		func(intensity: float) -> void:
			cast_light.light_energy = lerpf(base_energy, peak_energy, intensity)
			core_material.emission_energy_multiplier = lerpf(
				base_emission,
				peak_emission,
				intensity
			)
			if halo_mat != null:
				halo_mat.emission_energy_multiplier = lerpf(1.2, 2.0, intensity),
		0.0,
		1.0,
		0.42
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_method(
		func(intensity: float) -> void:
			cast_light.light_energy = lerpf(peak_energy, base_energy, intensity)
			core_material.emission_energy_multiplier = lerpf(
				peak_emission,
				base_emission,
				intensity
			)
			if halo_mat != null:
				halo_mat.emission_energy_multiplier = lerpf(2.0, 1.2, intensity),
		0.0,
		1.0,
		0.42
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


static func make_explosion_flash_light() -> OmniLight3D:
	var flash := OmniLight3D.new()
	flash.name = "ExplosionFlashLight"
	configure_cast_light(flash, 34.0, 18.0, Color(1.0, 0.9, 0.62))
	return flash


static func make_explosion_glow_light() -> OmniLight3D:
	var glow := OmniLight3D.new()
	glow.name = "ExplosionGlowLight"
	configure_cast_light(glow, 18.0, 14.0, Color(1.0, 0.42, 0.1))
	return glow


static func make_signal_beacon_light(energy: float, range: float) -> OmniLight3D:
	var beacon := OmniLight3D.new()
	beacon.name = "SignalBeaconLight"
	configure_cast_light(beacon, energy, range, Color(1.0, 0.58, 0.18))
	return beacon


static func make_launch_flash_light() -> OmniLight3D:
	var flash := OmniLight3D.new()
	flash.name = "LaunchFlashLight"
	configure_cast_light(flash, 24.0, 22.0, Color(1.0, 0.92, 0.78))
	return flash
