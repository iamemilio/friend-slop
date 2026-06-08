class_name PlayerSpawnLayout
extends RefCounted

const PLAYER_Y := 0.5
const IN_CELL_SPACING := 0.85

static func compute_positions(
	spawn_cell: Vector2i,
	wall_grid: Array,
	maze_width: int,
	maze_height: int,
	cell_to_world: Callable,
	player_count: int
) -> Array[Vector3]:
	if player_count <= 0:
		return []

	var cells := _collect_spawn_cells(
		spawn_cell,
		wall_grid,
		maze_width,
		maze_height,
		player_count
	)
	var positions: Array[Vector3] = []
	var cell_slots: Dictionary = {}

	for player_index in player_count:
		var cell_index := mini(player_index, cells.size() - 1)
		var cell: Vector2i = cells[cell_index]
		var slot: int = cell_slots.get(cell, 0)
		cell_slots[cell] = slot + 1

		var pos: Vector3 = cell_to_world.call(cell.x, cell.y)
		pos.y = PLAYER_Y
		pos += _in_cell_offset(slot, cell_index, cells, player_count)
		positions.append(pos)

	return positions


static func _collect_spawn_cells(
	spawn_cell: Vector2i,
	wall_grid: Array,
	maze_width: int,
	maze_height: int,
	max_cells: int
) -> Array[Vector2i]:
	var reachable := DiscoverableSpawnPlan.collect_reachable_cells(
		wall_grid,
		maze_width,
		maze_height,
		spawn_cell
	)
	if reachable.is_empty():
		return [spawn_cell]

	var ordered: Array[Vector2i] = [spawn_cell]
	var extras: Array[Vector2i] = []
	for cell in reachable:
		if cell == spawn_cell:
			continue
		extras.append(cell)

	extras.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var score_a := _forward_score(a, spawn_cell)
		var score_b := _forward_score(b, spawn_cell)
		if score_a != score_b:
			return score_a < score_b
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y
	)

	for cell in extras:
		if ordered.size() >= max_cells:
			break
		ordered.append(cell)

	return ordered


static func _forward_score(cell: Vector2i, spawn_cell: Vector2i) -> int:
	var delta := cell - spawn_cell
	return absi(delta.x) + absi(delta.y)


static func _in_cell_offset(
	slot: int,
	cell_index: int,
	cells: Array[Vector2i],
	player_count: int
) -> Vector3:
	if player_count == 1:
		return Vector3.ZERO

	if player_count == 2 and cells.size() >= 2:
		if cell_index == 0:
			return Vector3(0.0, 0.0, -0.35)
		return Vector3(0.0, 0.0, 0.35)

	var lane := float(slot) - float(max(player_count - 1, 1)) * 0.5
	return Vector3(lane * IN_CELL_SPACING, 0.0, 0.0)
