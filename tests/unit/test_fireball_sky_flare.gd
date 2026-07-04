class_name TestFireballSkyFlare
extends RefCounted

const FireballProjectileScript := preload("res://scripts/spells/fireball_projectile.gd")
const SkyFlareEffectScript := preload("res://scripts/spells/sky_flare_effect.gd")
const FireballFlightScript := preload("res://scripts/spells/fireball_flight.gd")


func run() -> int:
	var failures := 0
	failures += _test_projectile_delegates_to_flight_rules()
	failures += _test_sky_flare_effect_delegates_to_flight_rules()
	return failures


func _test_projectile_delegates_to_flight_rules() -> int:
	var up := Vector3(0.0, 1.0, 0.0)
	if FireballProjectileScript.is_sky_flare_direction(up) \
			!= FireballFlightScript.is_sky_flare_direction(up):
		push_error("Expected projectile sky-flare check to match flight rules")
		return 1
	return 0


func _test_sky_flare_effect_delegates_to_flight_rules() -> int:
	var steep := Vector3(0.2, 0.8, 0.2)
	if SkyFlareEffectScript.is_sky_flare_direction(steep) \
			!= FireballFlightScript.is_sky_flare_direction(steep):
		push_error("Expected sky flare effect check to match flight rules")
		return 1
	return 0
