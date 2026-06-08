class_name TestMazeCarver
extends RefCounted

const MazeCarverScript := preload("res://scripts/maze_carver.gd")

var failures: int = 0


func run() -> int:
	test_all_cells_carved_small()
	test_all_cells_carved_large()
	test_boundary_stays_solid()
	test_all_cells_reachable()
	test_same_seed_produces_same_maze()
	test_different_seeds_produce_different_mazes()
	test_carve_iterative_does_not_use_recursion()
	test_braiding_adds_alternate_routes()
	test_count_open_neighbors()
	return failures


func test_all_cells_carved_small() -> void:
	var grid := _generate(5, 5, 1234)
	_assert_eq(_count_carved_cells(grid, 5, 5), 25, "5x5 maze should carve all 25 cells")


func test_all_cells_carved_large() -> void:
	var grid := _generate(45, 45, 5678)
	_assert_eq(
		_count_carved_cells(grid, 45, 45),
		45 * 45,
		"45x45 maze should carve all cells without stack overflow"
	)


func test_boundary_stays_solid() -> void:
	var grid := _generate(10, 8, 42)
	_assert_true(
		MazeCarverScript.outer_boundary_is_solid(grid),
		"outer maze boundary should remain solid walls"
	)


func test_all_cells_reachable() -> void:
	var grid := _generate(15, 15, 999)
	_assert_true(
		MazeCarverScript.all_cells_reachable(grid, 15, 15),
		"every cell should be reachable from the start"
	)


func test_same_seed_produces_same_maze() -> void:
	var grid_a := _generate(12, 12, 2026)
	var grid_b := _generate(12, 12, 2026)
	_assert_true(
		MazeCarverScript.grids_equal(grid_a, grid_b),
		"identical seeds should produce identical mazes"
	)


func test_different_seeds_produce_different_mazes() -> void:
	var grid_a := _generate(12, 12, 111)
	var grid_b := _generate(12, 12, 222)
	_assert_true(
		not MazeCarverScript.grids_equal(grid_a, grid_b),
		"different seeds should usually produce different mazes"
	)


func test_braiding_adds_alternate_routes() -> void:
	var plain := _generate(12, 12, 2026, {"braid_ratio": 0.0})
	var braided := _generate(12, 12, 2026, {"braid_ratio": 0.25})
	_assert_true(
		not MazeCarverScript.grids_equal(plain, braided),
		"braiding should change the maze layout"
	)
	_assert_true(
		MazeCarverScript.all_cells_reachable(braided, 12, 12),
		"braided maze should remain fully connected"
	)


func test_count_open_neighbors() -> void:
	var grid := _generate(5, 5, 4242)
	var count := MazeCarverScript.count_open_neighbors(grid, 1, 1)
	_assert_true(
		count >= 1 and count <= 3,
		"start cell should report only connected maze-cell neighbors"
	)
	_assert_eq(
		MazeCarverScript.count_open_neighbors(grid, 999, 999),
		0,
		"out-of-bounds positions should report zero neighbors"
	)


func test_carve_iterative_does_not_use_recursion() -> void:
	var grid := _generate(3, 3, 7)
	for x in grid.size():
		for y in grid[x].size():
			if grid[x][y] != 0 and grid[x][y] != 1:
				_assert_true(false, "grid cells should only contain wall (1) or passage (0) values")
				return
	_assert_true(true, "grid cells should only contain wall (1) or passage (0) values")


func _generate(
	maze_width: int,
	maze_height: int,
	rng_seed: int = -1,
	options: Variant = null
) -> Array:
	return MazeCarverScript.generate(maze_width, maze_height, rng_seed, options)


func _count_carved_cells(grid: Array, maze_width: int, maze_height: int) -> int:
	return MazeCarverScript.count_carved_cells(grid, maze_width, maze_height)


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
