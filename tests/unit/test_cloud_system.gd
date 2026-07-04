class_name TestCloudSystem
extends RefCounted

const CloudSystemScript := preload("res://scripts/environment/cloud_system.gd")
const CloudStateScript := preload("res://scripts/environment/cloud_state.gd")

var failures: int = 0


func run() -> int:
	test_deterministic_positions()
	test_count_scales_with_span()
	test_horizon_travel_span()
	test_clouds_cast_shadows()
	test_clouds_spawn_within_bounds()
	test_wrap_around()
	test_horizon_arc()
	return failures


func test_deterministic_positions() -> void:
	var bounds_min := Vector3(-100.0, 80.0, -100.0)
	var bounds_max := Vector3(100.0, 120.0, 100.0)
	var seed_value := 4242

	var system_a := _make_system(bounds_min, bounds_max, seed_value)
	var system_b := _make_system(bounds_min, bounds_max, seed_value)

	_assert_eq(
		system_a.get_cloud_count(),
		system_b.get_cloud_count(),
		"same seed should produce same cloud count"
	)

	var elapsed := 12.34
	for i in system_a.get_cloud_count():
		var state_a: CloudState = system_a.get_cloud_state(i)
		var state_b: CloudState = system_b.get_cloud_state(i)
		var pos_a := state_a.position_at(elapsed, bounds_min, bounds_max)
		var pos_b := state_b.position_at(elapsed, bounds_min, bounds_max)
		_assert_eq(pos_a, pos_b, "same seed should produce same cloud positions")

	_free_system(system_a)
	_free_system(system_b)


func test_count_scales_with_span() -> void:
	var small := _make_system(
		Vector3(-50.0, 80.0, -50.0), Vector3(50.0, 120.0, 50.0), 1234
	)
	var large := _make_system(
		Vector3(-300.0, 80.0, -300.0), Vector3(300.0, 120.0, 300.0), 1234
	)

	_assert_true(
		large.get_cloud_count() > small.get_cloud_count(),
		"larger bounds should produce more clouds"
	)

	_free_system(small)
	_free_system(large)


func test_horizon_travel_span() -> void:
	var root := Node3D.new()
	var system: CloudSystem = CloudSystemScript.new()
	root.add_child(system)
	system.configure_for_maze(45, 45, 3.0, 200.0, 1234, 1000)

	var maze_span := 91.0 * 3.0
	var expected_span := maze_span * CloudSystemScript.TRAVEL_SPAN_FACTOR
	_assert_true(
		is_equal_approx(system.get_travel_span(), expected_span),
		"cloud travel span should be at least 2.5x maze span"
	)
	var bounds_size := system.get_bounds_max().x - system.get_bounds_min().x
	_assert_true(
		bounds_size >= expected_span - 0.01,
		"cloud bounds should cover the full travel span"
	)

	root.queue_free()


func test_clouds_cast_shadows() -> void:
	var system := _make_system(
		Vector3(-100.0, 80.0, -100.0), Vector3(100.0, 120.0, 100.0), 999
	)
	var holder := system.get_node("Clouds")
	_assert_true(holder.get_child_count() > 0, "cloud holder should have children")

	for child in holder.get_children():
		var mesh: MeshInstance3D = child as MeshInstance3D
		_assert_true(mesh != null, "cloud child should be MeshInstance3D")
		_assert_true(
			mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
			"cloud mesh should cast shadows on the maze"
		)

	_free_system(system)


func test_clouds_spawn_within_bounds() -> void:
	var bounds_min := Vector3(-120.0, 90.0, -120.0)
	var bounds_max := Vector3(120.0, 150.0, 120.0)
	var system := _make_system(bounds_min, bounds_max, 5555)

	for i in system.get_cloud_count():
		var state: CloudState = system.get_cloud_state(i)
		var pos := state.position_at(0.0, bounds_min, bounds_max)
		_assert_true(
			pos.x >= bounds_min.x and pos.x <= bounds_max.x,
			"cloud x position should be within bounds"
		)
		_assert_true(
			pos.y >= bounds_min.y and pos.y <= bounds_max.y,
			"cloud y position should be within bounds"
		)
		_assert_true(
			pos.z >= bounds_min.z and pos.z <= bounds_max.z,
			"cloud z position should be within bounds"
		)

	_free_system(system)


func test_wrap_around() -> void:
	var state := CloudStateScript.new()
	state.base_position = Vector3(0.0, 100.0, 0.0)
	state.velocity = Vector3(10.0, 0.0, 0.0)
	state.arc_amplitude = 0.0

	var bounds_min := Vector3(-50.0, 90.0, -50.0)
	var bounds_max := Vector3(50.0, 110.0, 50.0)

	var pos_before := state.position_at(4.0, bounds_min, bounds_max)
	var pos_after := state.position_at(14.0, bounds_min, bounds_max)

	_assert_true(
		pos_after.x < bounds_max.x,
		"cloud should wrap back into bounds"
	)
	_assert_true(
		pos_after.x >= bounds_min.x,
		"wrapped cloud should remain inside bounds"
	)
	_assert_eq(
		pos_before.x,
		pos_after.x,
		"positions should repeat after one full wrap cycle"
	)


func test_horizon_arc() -> void:
	var state := CloudStateScript.new()
	state.base_position = Vector3(0.0, 100.0, 0.0)
	state.velocity = Vector3(4.0, 0.0, 0.0)
	state.arc_amplitude = 6.0
	state.arc_wavelength = 40.0
	state.arc_phase = 0.0

	var bounds_min := Vector3(-200.0, 80.0, -200.0)
	var bounds_max := Vector3(200.0, 140.0, 200.0)

	var flat_y := state.position_at(0.0, bounds_min, bounds_max).y
	var arced_y := state.position_at(2.5, bounds_min, bounds_max).y
	_assert_true(
		not is_equal_approx(flat_y, arced_y),
		"clouds should follow a slight vertical arc while drifting"
	)


func _make_system(bounds_min: Vector3, bounds_max: Vector3, seed_value: int) -> CloudSystem:
	var root := Node3D.new()
	var system: CloudSystem = CloudSystemScript.new()
	root.add_child(system)
	system.configure(bounds_min, bounds_max, seed_value, Time.get_ticks_msec())
	return system


func _free_system(system: CloudSystem) -> void:
	if system != null and system.get_parent() != null:
		system.get_parent().queue_free()


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: %s" % message)
	else:
		failures += 1
		push_error("  FAIL: %s" % message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		print("  PASS: %s" % message)
	else:
		failures += 1
		push_error("  FAIL: %s (expected %s, got %s)" % [message, expected, actual])
