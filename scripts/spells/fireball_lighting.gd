class_name FireballLighting
extends RefCounted

## Shadow-casting lights for fireball VFX.

const WorldVisualLayersScript := preload("res://scripts/world_visual_layers.gd")


static func configure_cast_light(
	light: OmniLight3D,
	energy: float,
	light_range: float,
	color: Color,
	enable_shadows: bool = true
) -> void:
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.35
	light.light_specular = 0.4
	light.light_cull_mask = WorldVisualLayersScript.SCENE_LIGHT_MASK
	light.shadow_caster_mask = WorldVisualLayersScript.WORLD_LIGHT_MASK
	light.shadow_enabled = enable_shadows
	if enable_shadows:
		light.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
		light.shadow_bias = 0.04
		light.shadow_normal_bias = 1.1


static func make_travel_cast_light(sky_flare: bool = false) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = "TravelCastLight"
	if sky_flare:
		configure_cast_light(light, 2.4, 7.5, Color(1.0, 0.58, 0.18), false)
	else:
		configure_cast_light(light, 1.35, 4.8, Color(1.0, 0.5, 0.14), false)
	return light


static func start_travel_glow_pulse(
	owner: Node,
	cast_light: OmniLight3D,
	core_material: StandardMaterial3D,
	sky_flare: bool = false
) -> Tween:
	var peak_energy := 2.8 if sky_flare else 1.75
	var base_energy := 1.6 if sky_flare else 1.05
	var peak_emission := 4.2 if sky_flare else 3.2
	var base_emission := 2.6 if sky_flare else 2.2

	var pulse := owner.create_tween()
	pulse.set_loops()
	pulse.tween_method(
		func(intensity: float) -> void:
			cast_light.light_energy = lerpf(base_energy, peak_energy, intensity)
			core_material.emission_energy_multiplier = lerpf(
				base_emission,
				peak_emission,
				intensity
			),
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
			),
		0.0,
		1.0,
		0.42
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return pulse


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


static func make_signal_beacon_light(energy: float, light_range: float) -> OmniLight3D:
	var beacon := OmniLight3D.new()
	beacon.name = "SignalBeaconLight"
	configure_cast_light(beacon, energy, light_range, Color(1.0, 0.58, 0.18))
	return beacon


static func make_launch_flash_light() -> OmniLight3D:
	var flash := OmniLight3D.new()
	flash.name = "LaunchFlashLight"
	configure_cast_light(flash, 24.0, 22.0, Color(1.0, 0.92, 0.78))
	return flash
