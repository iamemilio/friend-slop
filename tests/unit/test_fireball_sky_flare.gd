class_name TestFireballSkyFlare
extends RefCounted

const FireballProjectileScript := preload("res://scripts/spells/fireball_projectile.gd")
const SkyFlareEffectScript := preload("res://scripts/spells/sky_flare_effect.gd")
const FireballFlightScript := preload("res://scripts/spells/fireball_flight.gd")


func run(tree: SceneTree) -> int:
	var failures := 0
	failures += _test_projectile_delegates_to_flight_rules()
	failures += _test_sky_flare_effect_delegates_to_flight_rules()
	failures += _test_sky_flare_spawn_sets_global_position(tree)
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


func _test_sky_flare_spawn_sets_global_position(tree: SceneTree) -> int:
	var world := Node3D.new()
	world.position = Vector3(-4.0, 0.0, 2.0)
	tree.root.add_child(world)

	var burst_pos := Vector3(1.0, 20.0, 3.0)
	var flare := SkyFlareEffectScript.spawn(world, burst_pos, 0.1)
	if not flare.is_inside_tree():
		push_error("Expected spawned sky flare to enter the scene tree")
		world.queue_free()
		return 1
	if not flare.global_position.is_equal_approx(burst_pos):
		push_error(
			"Expected sky flare at global %s, got %s"
			% [burst_pos, flare.global_position]
		)
		world.queue_free()
		return 1

	world.queue_free()
	return 0
