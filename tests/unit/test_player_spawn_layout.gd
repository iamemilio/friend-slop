class_name TestPlayerSpawnLayout
extends RefCounted

const PlayerSpawnLayoutScript := preload("res://scripts/player_spawn_layout.gd")


func run() -> int:
	var failures := 0
	failures += _test_single_player_uses_spawn_center()
	failures += _test_two_players_are_separated()
	failures += _test_three_players_use_distinct_positions()
	return failures


func _test_single_player_uses_spawn_center() -> int:
	var wall_grid := _open_grid(3, 3)
	var positions := PlayerSpawnLayoutScript.compute_positions(
		Vector2i(0, 0),
		wall_grid,
		3,
		3,
		Callable(self, "_cell_to_world"),
		1
	)
	if positions.size() != 1:
		push_error("Expected one spawn position for solo player")
		return 1
	if positions[0] != Vector3(0.0, PlayerSpawnLayoutScript.PLAYER_Y, 0.0):
		push_error("Expected solo player at spawn center")
		return 1
	return 0


func _test_two_players_are_separated() -> int:
	var wall_grid := _open_grid(3, 3)
	var positions := PlayerSpawnLayoutScript.compute_positions(
		Vector2i(0, 0),
		wall_grid,
		3,
		3,
		Callable(self, "_cell_to_world"),
		2
	)
	if positions.size() != 2:
		push_error("Expected two spawn positions")
		return 1
	if positions[0].distance_to(positions[1]) < 0.5:
		push_error("Expected two-player spawns to be separated")
		return 1
	return 0


func _test_three_players_use_distinct_positions() -> int:
	var wall_grid := _open_grid(3, 3)
	var positions := PlayerSpawnLayoutScript.compute_positions(
		Vector2i(0, 0),
		wall_grid,
		3,
		3,
		Callable(self, "_cell_to_world"),
		3
	)
	if positions.size() != 3:
		push_error("Expected three spawn positions")
		return 1

	var seen: Dictionary = {}
	for pos in positions:
		var key := "%.2f,%.2f,%.2f" % [pos.x, pos.y, pos.z]
		if seen.has(key):
			push_error("Expected three-player spawns to be unique")
			return 1
		seen[key] = true
	return 0


func _cell_to_world(cell_x: int, cell_y: int) -> Vector3:
	return Vector3(float(cell_x) * 3.0, 0.0, float(cell_y) * 3.0)


func _open_grid(maze_width: int, maze_height: int) -> Array:
	var grid_w := maze_width * 2 + 1
	var grid_h := maze_height * 2 + 1
	var grid: Array = []
	for gx in grid_w:
		var column: Array = []
		for gy in grid_h:
			var is_passage_x := gx % 2 == 1
			var is_passage_y := gy % 2 == 1
			column.append(0 if is_passage_x and is_passage_y else 1)
		grid.append(column)
	return grid
