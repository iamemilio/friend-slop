class_name TestTrailRegistry
extends RefCounted

const TrailRegistryScript := preload("res://scripts/trails/trail_registry.gd")
const TrailSampleScript := preload("res://scripts/trails/trail_sample.gd")


func run() -> int:
	var failures := 0
	failures += _test_sample_round_trip()
	failures += _test_host_stores_and_prunes()
	failures += _test_reveal_window()
	return failures


func _test_sample_round_trip() -> int:
	var sample := TrailSampleScript.make(3, 4.5, -2.0, 9000)
	if TrailSampleScript.seq(sample) != 3:
		push_error("Expected sample seq to round-trip")
		return 1
	var pos := TrailSampleScript.position(sample)
	if not is_equal_approx(pos.x, 4.5) or not is_equal_approx(pos.y, -2.0):
		push_error("Expected sample position to round-trip")
		return 1
	return 0


func _test_host_stores_and_prunes() -> int:
	var registry: Node = TrailRegistryScript.new()
	registry._host_accept_sample(1, 0, 0.0, 0.0)
	registry._host_accept_sample(1, 1, 1.0, 0.0)
	var samples: Array = registry.get_samples_for_peer(1)
	if samples.size() != 2:
		push_error("Expected two stored trail samples")
		registry.free()
		return 1
	registry._host_accept_sample(1, 1, 2.0, 0.0)
	samples = registry.get_samples_for_peer(1)
	if samples.size() != 2:
		push_error("Expected duplicate seq to be ignored")
		registry.free()
		return 1
	registry.free()
	return 0


func _test_reveal_window() -> int:
	var registry: Node = TrailRegistryScript.new()
	if registry.is_revealed():
		push_error("Expected trails to start hidden")
		registry.free()
		return 1
	registry.reveal_trails(1.0)
	if not registry.is_revealed():
		push_error("Expected reveal_trails to expose trails")
		registry.free()
		return 1
	registry.free()
	return 0
