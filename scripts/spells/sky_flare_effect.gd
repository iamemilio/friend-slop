class_name SkyFlareEffect
extends Node3D

## Firework-style signal burst from an upward fireball cast.

const DEFAULT_DURATION_SEC := 18.0
const LIGHT_RANGE := 110.0
const LIGHT_PEAK_ENERGY := 14.0

const FireballParticlesScript := preload("res://scripts/spells/fireball_particles.gd")

const _SHELL_COLORS: Array[Color] = [
	Color(1.0, 0.82, 0.28),
	Color(1.0, 0.42, 0.12),
	Color(1.0, 0.95, 0.72),
	Color(0.95, 0.28, 0.48),
	Color(0.45, 0.82, 1.0),
	Color(0.55, 1.0, 0.55),
]


static func spawn(
	parent: Node,
	world_position: Vector3,
	duration_sec: float = DEFAULT_DURATION_SEC
) -> SkyFlareEffect:
	var flare := SkyFlareEffect.new()
	flare.global_position = world_position
	parent.add_child(flare)
	flare._begin(duration_sec)
	return flare


static func is_sky_flare_direction(direction: Vector3) -> bool:
	return FireballFlight.is_sky_flare_direction(direction)


func _begin(duration_sec: float) -> void:
	_play_launch_flash()
	_play_firework_sequence()
	_play_signal_beacon(duration_sec)


func _play_launch_flash() -> void:
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.92, 0.78)
	flash.light_energy = 24.0
	flash.omni_range = 28.0
	flash.shadow_enabled = false
	add_child(flash)

	var burst := FireballParticlesScript.make_burst(
		"LaunchFlash",
		36,
		Color(1.0, 0.95, 0.82, 1.0),
		6.0,
		14.0,
		0.35,
		1.0,
		Vector3(0.0, -1.5, 0.0),
		"firework"
	)
	burst.scale_amount_min = 0.18
	burst.scale_amount_max = 0.42
	add_child(burst)
	burst.emitting = true
	burst.restart()

	var flash_tween := create_tween()
	flash_tween.tween_property(flash, "light_energy", 0.0, 0.22)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	flash_tween.tween_callback(flash.queue_free)


func _play_firework_sequence() -> void:
	_spawn_shell_burst(0.0, 1.0, 120, 10.0, 22.0)
	_spawn_shell_burst(0.1, 0.75, 72, 8.0, 16.0)
	_spawn_shell_burst(0.22, 0.55, 56, 6.0, 13.0)
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(0.38).timeout.connect(
		func() -> void: _spawn_shell_burst(0.0, 0.4, 40, 4.0, 10.0)
	)
	tree.create_timer(0.55).timeout.connect(_spawn_crackle_ring)


func _spawn_shell_burst(
	delay_sec: float,
	_scale: float,
	amount: int,
	velocity_min: float,
	velocity_max: float
) -> void:
	var color := _SHELL_COLORS[randi() % _SHELL_COLORS.size()]
	var pop := FireballParticlesScript.make_firework_shell(
		"FireworkShell",
		amount,
		color,
		velocity_min * _scale,
		velocity_max * _scale
	)
	add_child(pop)
	if delay_sec <= 0.0:
		pop.emitting = true
		pop.restart()
		return
	pop.emitting = false
	get_tree().create_timer(delay_sec).timeout.connect(func() -> void:
		if is_instance_valid(pop):
			pop.emitting = true
			pop.restart()
	)


func _spawn_crackle_ring() -> void:
	for i in 6:
		var angle := (TAU / 6.0) * float(i)
		var offset := Vector3(cos(angle), 0.15, sin(angle)) * 1.4
		var spark := FireballParticlesScript.make_burst(
			"CrackleSpark",
			12,
			_SHELL_COLORS[i % _SHELL_COLORS.size()],
			2.5,
			5.5,
			0.9,
			0.85,
			Vector3(0.0, -2.0, 0.0),
			"spark"
		)
		spark.position = offset
		spark.scale_amount_min = 0.1
		spark.scale_amount_max = 0.2
		add_child(spark)
		spark.emitting = true
		spark.restart()

	var embers := FireballParticlesScript.make_drift(
		"FallingEmbers",
		64,
		3.8,
		Color(1.0, 0.72, 0.28, 0.9),
		Vector3(0.0, -0.35, 0.0),
		55.0
	)
	embers.initial_velocity_min = 0.6
	embers.initial_velocity_max = 2.2
	embers.gravity = Vector3(0.0, -1.8, 0.0)
	embers.scale_amount_min = 0.06
	embers.scale_amount_max = 0.14
	add_child(embers)
	embers.emitting = true


func _play_signal_beacon(duration_sec: float) -> void:
	var beacon := OmniLight3D.new()
	beacon.light_color = Color(1.0, 0.58, 0.18)
	beacon.light_energy = LIGHT_PEAK_ENERGY
	beacon.omni_range = LIGHT_RANGE
	beacon.shadow_enabled = false
	add_child(beacon)

	var smoke := FireballParticlesScript.make_signal_smoke_column()
	add_child(smoke)
	smoke.emitting = true

	var pillar := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.08
	mesh.bottom_radius = 0.35
	mesh.height = 14.0
	pillar.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.62, 0.18, 0.18)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.08)
	mat.emission_energy_multiplier = 1.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pillar.material_override = mat
	pillar.position = Vector3(0.0, 7.0, 0.0)
	add_child(pillar)

	var pulse_tween := create_tween()
	pulse_tween.set_loops(int(maxf(1.0, duration_sec / 1.6)))
	pulse_tween.tween_property(beacon, "light_energy", LIGHT_PEAK_ENERGY * 0.35, 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(beacon, "light_energy", LIGHT_PEAK_ENERGY, 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var fade_tween := create_tween()
	fade_tween.tween_interval(maxf(0.0, duration_sec - 2.5))
	fade_tween.set_parallel(true)
	fade_tween.tween_property(beacon, "light_energy", 0.0, 2.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade_tween.tween_property(pillar, "scale", Vector3.ONE * 0.4, 2.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade_tween.tween_callback(func() -> void: smoke.emitting = false)
	fade_tween.chain().tween_callback(queue_free)
