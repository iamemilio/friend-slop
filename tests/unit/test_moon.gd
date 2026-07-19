class_name TestMoon
extends RefCounted

const MoonScene := preload("res://scenes/environment/moon.tscn")


func run() -> int:
	var failures := 0
	failures += _test_shadow_distance_scales_with_maze()
	failures += _test_moon_light_aims_at_maze_center()
	failures += _test_moon_shadow_settings_reduce_artifacts()
	return failures


func _test_shadow_distance_scales_with_maze() -> int:
	var root := Node3D.new()
	var moon: Moon = MoonScene.instantiate()
	root.add_child(moon)
	moon.configure_for_maze(45, 45, 3.0)
	var moon_light: DirectionalLight3D = moon.get_node("MoonLight")
	if moon_light == null:
		root.queue_free()
		push_error("Expected MoonLight node to exist")
		return 1
	if moon_light.directional_shadow_max_distance < 250.0:
		root.queue_free()
		push_error("Expected moon shadow distance to cover large mazes")
		return 1
	if moon.position.y < 120.0:
		root.queue_free()
		push_error("Expected moon to sit high above the maze")
		return 1
	root.queue_free()
	return 0


func _test_moon_light_aims_at_maze_center() -> int:
	var root := Node3D.new()
	var moon: Moon = MoonScene.instantiate()
	root.add_child(moon)
	moon.configure_for_maze(45, 45, 3.0)
	var moon_light: DirectionalLight3D = moon.get_node("MoonLight")
	var light_dir := -moon_light.transform.basis.z
	var to_center := (-moon.position).normalized()
	if light_dir.dot(to_center) < 0.99:
		root.queue_free()
		push_error("Expected moon light to shine from the moon toward maze center")
		return 1
	if moon.position.is_zero_approx():
		root.queue_free()
		push_error("Expected moon to sit off-center so height affects light angle")
		return 1
	root.queue_free()
	return 0


func _test_moon_shadow_settings_reduce_artifacts() -> int:
	var root := Node3D.new()
	var moon: Moon = MoonScene.instantiate()
	root.add_child(moon)
	moon.configure_for_maze(45, 45, 3.0)
	var moon_light: DirectionalLight3D = moon.get_node("MoonLight")
	var issue := ""
	if moon_light.directional_shadow_mode != DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS:
		issue = "Expected moon to use 4-split directional shadows for cloud coverage"
	elif not moon_light.directional_shadow_blend_splits:
		issue = "Expected moon cascade blending enabled for soft cloud shadow transitions"
	elif moon_light.directional_shadow_pancake_size < 10.0:
		issue = "Expected moon shadow pancake enabled for high cloud casters"
	elif moon_light.light_angular_distance > 0.0:
		issue = "Expected moon light angular distance off (no PCSS dither)"
	elif moon_light.shadow_blur > 1.5:
		issue = "Expected moon shadow blur to stay mild"
	elif moon_light.shadow_bias > 0.35:
		issue = "Expected moon shadow bias to stay moderate (avoid peter-panning)"
	elif moon_light.shadow_normal_bias < 1.5:
		issue = "Expected moon normal bias high enough to avoid floor streaking"
	elif moon_light.shadow_normal_bias > 6.0:
		issue = "Expected moon normal bias to stay moderate (avoid peter-panning)"
	elif moon_light.directional_shadow_max_distance < 42.0:
		issue = "Expected moon shadow distance to reach the cloud layer"
	elif moon_light.directional_shadow_max_distance > 420.0:
		issue = "Expected moon shadow distance capped to reduce cascade flicker"
	root.queue_free()
	if not issue.is_empty():
		push_error(issue)
		return 1
	return 0
