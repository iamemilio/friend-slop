class_name DiscoverableSpawnPlan
extends RefCounted

const PLACEMENT_SALT := "discoverables"

const _CARDINAL_DIRS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(0, -1),
]


static func derive_seed(run_seed: int) -> int:
	return hash("%d:%s" % [run_seed, PLACEMENT_SALT])


static func is_walkable_cell(wall_grid: Array, cell: Vector2i) -> bool:
	return _is_cell_passage(wall_grid, cell)


static func collect_reachable_cells(
	wall_grid: Array,
	maze_width: int,
	maze_height: int,
	from_cell: Vector2i
) -> Array[Vector2i]:
	if not _is_cell_passage(wall_grid, from_cell):
		return []

	var dirs: Array[Vector2i] = _CARDINAL_DIRS
	var queue: Array[Vector2i] = [from_cell]
	var visited: Dictionary = {from_cell: true}
	var reachable: Array[Vector2i] = [from_cell]

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for dir in dirs:
			var next: Vector2i = current + dir
			if not _is_in_maze_bounds(next, maze_width, maze_height):
				continue
			if visited.has(next):
				continue
			if not _is_cell_passage(wall_grid, next):
				continue
			if not _are_cells_connected(wall_grid, current, next):
				continue
			visited[next] = true
			reachable.append(next)
			queue.append(next)

	return reachable


static func find_dev_tome_cell(
	wall_grid: Array,
	maze_width: int,
	maze_height: int,
	spawn_cell: Vector2i
) -> Vector2i:
	## Returns a walkable maze cell connected to spawn for dev tome placement.
	for dir in _CARDINAL_DIRS:
		var neighbor: Vector2i = spawn_cell + dir
		if not _is_in_maze_bounds(neighbor, maze_width, maze_height):
			continue
		if not is_walkable_cell(wall_grid, neighbor):
			continue
		if _are_cells_connected(wall_grid, spawn_cell, neighbor):
			return neighbor

	for cell in collect_reachable_cells(wall_grid, maze_width, maze_height, spawn_cell):
		if cell != spawn_cell:
			return cell

	return spawn_cell


static func compute(
	wall_grid: Array,
	maze_width: int,
	maze_height: int,
	spawn_cell: Vector2i,
	exit_cell: Vector2i,
	run_config: DiscoverableRunConfig,
	rng_seed: int
) -> Array[DiscoverablePlacement]:
	var placements: Array[DiscoverablePlacement] = []
	if run_config == null or run_config.entries.is_empty():
		return placements

	var candidates: Array[Vector2i] = _collect_candidates(
		wall_grid,
		maze_width,
		maze_height,
		spawn_cell,
		exit_cell,
		run_config
	)
	if candidates.is_empty():
		return placements

	seed(rng_seed)
	candidates.shuffle()

	var used_cells: Array[Vector2i] = []
	var min_between: int = _max_min_dist_between(run_config)
	var variant_rng: int = rng_seed

	for entry in run_config.entries:
		if entry == null or entry.definition == null or entry.count <= 0:
			continue

		for _i in entry.count:
			var cell: Vector2i = _pick_cell(candidates, used_cells, min_between)
			if cell == Vector2i(-1, -1):
				break
			if not is_walkable_cell(wall_grid, cell):
				continue

			var variant_id: String = _pick_variant(entry, variant_rng)
			variant_rng = hash("%d:%s" % [variant_rng, variant_id])

			var placement: DiscoverablePlacement = DiscoverablePlacement.new(
				entry.definition.id,
				variant_id,
				cell,
				variant_rng
			)
			placements.append(placement)
			used_cells.append(cell)

	return placements


static func _max_min_dist_between(run_config: DiscoverableRunConfig) -> int:
	var max_dist: int = 6
	for entry in run_config.entries:
		if entry != null and entry.definition != null:
			max_dist = maxi(max_dist, entry.definition.min_dist_between)
	return max_dist


static func _collect_candidates(
	wall_grid: Array,
	maze_width: int,
	maze_height: int,
	spawn_cell: Vector2i,
	exit_cell: Vector2i,
	run_config: DiscoverableRunConfig
) -> Array[Vector2i]:
	var min_from_special: int = _max_min_dist_from_special(run_config)
	var candidates: Array[Vector2i] = []
	var reachable_cells: Array[Vector2i] = collect_reachable_cells(
		wall_grid,
		maze_width,
		maze_height,
		spawn_cell
	)

	for cell in reachable_cells:
		if not _is_cell_passage(wall_grid, cell):
			continue
		if cell == spawn_cell or cell == exit_cell:
			continue
		if _manhattan(cell, spawn_cell) < min_from_special:
			continue
		if _manhattan(cell, exit_cell) < min_from_special:
			continue
		candidates.append(cell)

	return candidates


static func _max_min_dist_from_special(run_config: DiscoverableRunConfig) -> int:
	var max_dist: int = 4
	for entry in run_config.entries:
		if entry != null and entry.definition != null:
			max_dist = maxi(max_dist, entry.definition.min_dist_from_special)
	return max_dist


static func _pick_cell(
	candidates: Array[Vector2i],
	used_cells: Array[Vector2i],
	min_between: int
) -> Vector2i:
	for candidate in candidates:
		if _is_far_enough(candidate, used_cells, min_between):
			return candidate
	return Vector2i(-1, -1)


static func _is_far_enough(cell: Vector2i, used_cells: Array[Vector2i], min_between: int) -> bool:
	for used in used_cells:
		if _manhattan(cell, used) < min_between:
			return false
	return true


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _is_in_maze_bounds(cell: Vector2i, maze_width: int, maze_height: int) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < maze_width and cell.y < maze_height


static func _is_cell_passage(wall_grid: Array, cell: Vector2i) -> bool:
	var gx: int = cell.x * 2 + 1
	var gy: int = cell.y * 2 + 1
	if gx >= wall_grid.size() or gy >= wall_grid[gx].size():
		return false
	return wall_grid[gx][gy] == 0


static func _are_cells_connected(wall_grid: Array, a: Vector2i, b: Vector2i) -> bool:
	var dx: int = b.x - a.x
	var dy: int = b.y - a.y
	if absi(dx) + absi(dy) != 1:
		return false

	var wx: int
	var wy: int
	if dx == 1:
		wx = a.x * 2 + 2
		wy = a.y * 2 + 1
	elif dx == -1:
		wx = a.x * 2
		wy = a.y * 2 + 1
	elif dy == 1:
		wx = a.x * 2 + 1
		wy = a.y * 2 + 2
	else:
		wx = a.x * 2 + 1
		wy = a.y * 2

	if wx >= wall_grid.size() or wy >= wall_grid[wx].size():
		return false
	return wall_grid[wx][wy] == 0


static func _pick_variant(entry: DiscoverableSpawnEntry, rng_seed: int) -> String:
	if entry.variant_ids.is_empty():
		return ""
	seed(rng_seed)
	return entry.variant_ids[randi() % entry.variant_ids.size()]
