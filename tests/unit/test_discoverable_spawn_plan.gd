class_name TestDiscoverableSpawnPlan
extends RefCounted

const MazeCarverScript := preload("res://scripts/maze_carver.gd")
const DiscoverableSpawnPlanScript := preload(
	"res://scripts/discoverables/discoverable_spawn_plan.gd"
)
const DiscoverableDefinitionScript := preload(
	"res://scripts/discoverables/discoverable_definition.gd"
)
const DiscoverableSpawnEntryScript := preload(
	"res://scripts/discoverables/discoverable_spawn_entry.gd"
)
const DiscoverableRunConfigScript := preload(
	"res://scripts/discoverables/discoverable_run_config.gd"
)

var failures: int = 0


func run() -> int:
	test_deterministic_placements()
	test_respects_spawn_exit_exclusion()
	test_no_overlapping_placements()
	test_large_maze()
	test_all_placements_are_on_walkable_paths()
	return failures


func test_deterministic_placements() -> void:
	var grid := MazeCarverScript.generate(10, 10, 4242, {})
	var config := _make_config("tome", 3, ["show_me", "haste", "shield"])
	var a := DiscoverableSpawnPlanScript.compute(
		grid, 10, 10, Vector2i(0, 0), Vector2i(9, 9), config, 999
	)
	var b := DiscoverableSpawnPlanScript.compute(
		grid, 10, 10, Vector2i(0, 0), Vector2i(9, 9), config, 999
	)
	_assert_eq(a.size(), b.size(), "same seed should produce same placement count")
	for i in a.size():
		_assert_eq(a[i].cell, b[i].cell, "same seed should produce same cells")
		_assert_eq(a[i].variant_id, b[i].variant_id, "same seed should produce same variants")


func test_respects_spawn_exit_exclusion() -> void:
	var grid := MazeCarverScript.generate(8, 8, 111, {})
	var config := _make_config("tome", 5, ["show_me"])
	var placements := DiscoverableSpawnPlanScript.compute(
		grid, 8, 8, Vector2i(0, 0), Vector2i(7, 7), config, 555
	)
	for placement in placements:
		_assert_true(
			placement.cell != Vector2i(0, 0) and placement.cell != Vector2i(7, 7),
			"placements should avoid spawn and exit cells"
		)
		var dist_spawn: int = absi(placement.cell.x) + absi(placement.cell.y)
		var dist_exit: int = absi(placement.cell.x - 7) + absi(placement.cell.y - 7)
		_assert_true(
			dist_spawn >= 4 and dist_exit >= 4,
			"placements should stay away from spawn and exit"
		)


func test_no_overlapping_placements() -> void:
	var grid := MazeCarverScript.generate(15, 15, 777, {})
	var config := _make_config("tome", 4, ["a", "b", "c", "d"])
	var placements := DiscoverableSpawnPlanScript.compute(
		grid, 15, 15, Vector2i(0, 0), Vector2i(14, 14), config, 888
	)
	for i in placements.size():
		for j in range(i + 1, placements.size()):
			var dist: int = absi(placements[i].cell.x - placements[j].cell.x)
			dist += absi(placements[i].cell.y - placements[j].cell.y)
			_assert_true(dist >= 6, "placements should respect min_dist_between")


func test_large_maze() -> void:
	var grid := MazeCarverScript.generate(45, 45, 5678, {})
	var config := _make_config("tome", 3, ["show_me", "haste", "shield"])
	var placements := DiscoverableSpawnPlanScript.compute(
		grid, 45, 45, Vector2i(0, 0), Vector2i(44, 44), config, 12345
	)
	_assert_eq(placements.size(), 3, "45x45 maze should place requested discoverable count")


func test_all_placements_are_on_walkable_paths() -> void:
	var config := _make_config("tome", 3, ["show_me", "haste", "shield"])
	for maze_seed in [42, 111, 4242, 5678, 9999]:
		var grid := MazeCarverScript.generate(45, 45, maze_seed, {})
		var spawn := Vector2i(0, 0)
		var exit := Vector2i(44, 44)
		var placements := DiscoverableSpawnPlanScript.compute(
			grid, 45, 45, spawn, exit, config, maze_seed
		)
		for placement in placements:
			_assert_true(
				DiscoverableSpawnPlanScript.is_walkable_cell(grid, placement.cell),
				"placement should be on a walkable cell for seed %d" % maze_seed
			)
			_assert_true(
				_is_reachable_from_spawn(grid, 45, 45, spawn, placement.cell),
				"placement should be reachable from spawn for seed %d" % maze_seed
			)


func _is_reachable_from_spawn(
	grid: Array,
	maze_width: int,
	maze_height: int,
	spawn: Vector2i,
	target: Vector2i
) -> bool:
	var reachable := DiscoverableSpawnPlanScript.collect_reachable_cells(
		grid, maze_width, maze_height, spawn
	)
	return target in reachable


func _make_config(def_id: String, count: int, variants: Array) -> DiscoverableRunConfig:
	var definition := DiscoverableDefinitionScript.new()
	definition.id = def_id
	definition.display_name = "Tome"
	definition.min_dist_from_special = 4
	definition.min_dist_between = 6

	var entry := DiscoverableSpawnEntryScript.new()
	entry.definition = definition
	entry.count = count
	entry.variant_ids = PackedStringArray(variants)

	var config := DiscoverableRunConfigScript.new()
	config.entries = [entry]
	return config


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
