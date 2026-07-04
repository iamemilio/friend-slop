class_name TestObjectivePlacement
extends RefCounted

const MazeCarverScript := preload("res://scripts/maze_carver.gd")
const ObjectivePlacementScript := preload("res://scripts/objectives/objective_placement.gd")


func run() -> int:
	var failures := 0
	failures += _test_plans_distinct_cells()
	failures += _test_deterministic_for_seed()
	failures += _test_near_spawn_places_relic_at_start()
	return failures


func _test_plans_distinct_cells() -> int:
	var grid := MazeCarverScript.generate(15, 15, 1234, {})
	var plan := ObjectivePlacementScript.plan(
		grid,
		15,
		15,
		Vector2i(0, 0),
		5678
	)
	if plan.is_empty():
		push_error("Expected objective placement on a valid maze")
		return 1
	var item_cell: Vector2i = plan.get("item_cell")
	var turn_in_cell: Vector2i = plan.get("turn_in_cell")
	if item_cell == turn_in_cell:
		push_error("Expected item and turn-in cells to differ")
		return 1
	if not DiscoverableSpawnPlan.is_walkable_cell(grid, item_cell):
		push_error("Expected item cell to be walkable")
		return 1
	if not DiscoverableSpawnPlan.is_walkable_cell(grid, turn_in_cell):
		push_error("Expected turn-in cell to be walkable")
		return 1
	return 0


func _test_deterministic_for_seed() -> int:
	var grid := MazeCarverScript.generate(15, 15, 999, {})
	var a := ObjectivePlacementScript.plan(grid, 15, 15, Vector2i(0, 0), 42)
	var b := ObjectivePlacementScript.plan(grid, 15, 15, Vector2i(0, 0), 42)
	if a.get("item_cell") != b.get("item_cell"):
		push_error("Expected objective placement to be deterministic for a seed")
		return 1
	if a.get("turn_in_cell") != b.get("turn_in_cell"):
		push_error("Expected turn-in placement to be deterministic for a seed")
		return 1
	return 0


func _test_near_spawn_places_relic_at_start() -> int:
	var grid := MazeCarverScript.generate(15, 15, 4321, {})
	var spawn_cell := Vector2i(0, 0)
	var plan := ObjectivePlacementScript.plan(
		grid,
		15,
		15,
		spawn_cell,
		999,
		true
	)
	if plan.is_empty():
		push_error("Expected near-spawn objective placement on a valid maze")
		return 1
	if plan.get("item_cell") != spawn_cell:
		push_error("Expected dev near-spawn mode to place relic at spawn cell")
		return 1
	var turn_in_cell: Vector2i = plan.get("turn_in_cell")
	if turn_in_cell == spawn_cell:
		push_error("Expected turn-in cell to differ from spawn cell")
		return 1
	return 0
