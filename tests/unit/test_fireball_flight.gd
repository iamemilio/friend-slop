class_name TestFireballFlight
extends RefCounted

const FireballFlightScript := preload("res://scripts/spells/fireball_flight.gd")
const FireballParticlesScript := preload("res://scripts/spells/fireball_particles.gd")


func run() -> int:
	var failures := 0
	failures += _test_sky_flare_direction_threshold()
	failures += _test_normal_lifetime()
	failures += _test_sky_flare_finish_conditions()
	failures += _test_smoke_trail_fade_delay()
	failures += _test_burst_particle_defaults()
	failures += _test_hit_radius_matches_visual()
	return failures


func _test_sky_flare_direction_threshold() -> int:
	if not FireballFlightScript.is_sky_flare_direction(Vector3(0.2, 0.8, 0.2)):
		push_error("Expected steep upward fireball to count as sky flare")
		return 1
	if FireballFlightScript.is_sky_flare_direction(Vector3(1.0, 0.1, 0.0)):
		push_error("Expected horizontal fireball to stay a normal projectile")
		return 1
	if not FireballFlightScript.is_sky_flare_direction(Vector3(0.0, 1.0, 0.0)):
		push_error("Expected straight-up fireball to count as sky flare")
		return 1
	return 0


func _test_normal_lifetime() -> int:
	if not FireballFlightScript.should_finish_normal(FireballFlightScript.MAX_LIFETIME):
		push_error("Expected normal fireball to finish at max lifetime")
		return 1
	if FireballFlightScript.should_finish_normal(FireballFlightScript.MAX_LIFETIME - 0.1):
		push_error("Expected normal fireball to keep flying before max lifetime")
		return 1
	return 0


func _test_sky_flare_finish_conditions() -> int:
	if not FireballFlightScript.should_finish_sky_flare(
		FireballFlightScript.SKY_FLARE_MAX_RISE_SEC,
		0.0
	):
		push_error("Expected sky flare to finish when max rise time reached")
		return 1
	if not FireballFlightScript.should_finish_sky_flare(
		0.1,
		FireballFlightScript.SKY_FLARE_TRAVEL_DIST
	):
		push_error("Expected sky flare to finish when travel distance reached")
		return 1
	if FireballFlightScript.should_finish_sky_flare(0.1, 1.0):
		push_error("Expected sky flare to keep rising before limits")
		return 1
	return 0


func _test_smoke_trail_fade_delay() -> int:
	var delay := FireballParticlesScript.smoke_trail_fade_delay_sec(2.0)
	if not is_equal_approx(delay, 2.35):
		push_error("Expected smoke trail fade delay to include padding")
		return 1
	return 0


func _test_burst_particle_defaults() -> int:
	var burst := FireballParticlesScript.make_burst(
		"TestBurst",
		32,
		Color.WHITE,
		2.0,
		8.0,
		0.5,
		0.9
	)
	if burst.amount != 32:
		push_error("Expected burst particle amount to match request")
		return 1
	if not burst.one_shot:
		push_error("Expected burst particles to be one-shot")
		return 1
	if burst.local_coords:
		push_error("Expected burst particles to use world coordinates")
		return 1
	if burst.mesh == null:
		push_error("Expected burst particles to assign a render mesh")
		return 1
	if burst.material_override == null:
		push_error("Expected burst particles to assign a material")
		return 1
	return 0


func _test_hit_radius_matches_visual() -> int:
	if FireballFlightScript.HIT_RADIUS >= FireballFlightScript.VISUAL_RADIUS:
		push_error("Expected fireball hit radius to stay inside the visible orb")
		return 1
	if FireballFlightScript.HIT_RADIUS <= 0.0:
		push_error("Expected fireball hit radius to stay positive")
		return 1
	return 0
