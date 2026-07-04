class_name ObjectivePlacement
extends RefCounted

const PLACEMENT_SALT := "delivery_objective"
const MIN_ITEM_DISTANCE_CELLS := 6
const MIN_TURN_IN_DISTANCE_CELLS := 10


static func derive_seed(run_seed: int) -> int:
	return hash("%d:%s" % [run_seed, PLACEMENT_SALT])


static func plan(
	wall_grid: Array,
	maze_width: int,
	maze_height: int,
	spawn_cell: Vector2i,
	run_seed: int
) -> Dictionary:
	var reachable := DiscoverableSpawnPlan.collect_reachable_cells(
		wall_grid,
		maze_width,
		maze_height,
		spawn_cell
	)
	if reachable.size() < 2:
		return {}

	var rng := RandomNumberGenerator.new()
	rng.seed = derive_seed(run_seed)

	var item_candidates: Array[Vector2i] = []
	for cell in reachable:
		if cell.distance_to(spawn_cell) >= MIN_ITEM_DISTANCE_CELLS:
			item_candidates.append(cell)
	if item_candidates.is_empty():
		item_candidates = reachable.duplicate()

	var item_cell: Vector2i = item_candidates[rng.randi_range(0, item_candidates.size() - 1)]

	var turn_in_candidates: Array[Vector2i] = []
	for cell in reachable:
		if cell == item_cell:
			continue
		if cell.distance_to(spawn_cell) >= MIN_TURN_IN_DISTANCE_CELLS:
			turn_in_candidates.append(cell)
	if turn_in_candidates.is_empty():
		for cell in reachable:
			if cell != item_cell:
				turn_in_candidates.append(cell)
	if turn_in_candidates.is_empty():
		return {}

	var turn_in_cell: Vector2i = turn_in_candidates[
		rng.randi_range(0, turn_in_candidates.size() - 1)
	]
	return {
		"item_cell": item_cell,
		"turn_in_cell": turn_in_cell,
	}
