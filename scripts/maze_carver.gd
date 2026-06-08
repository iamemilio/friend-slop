class_name MazeCarver
extends RefCounted

## Pure maze-carving logic (no scene nodes). Safe for large grids - uses an explicit stack.
##
## Tuning:
## - straight_bias (0-1): prefer continuing in the same direction for longer corridors.
## - braid_ratio (0-0.5): open extra passages to create loops and alternate routes.

const DIRS := [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]


static func generate(
	maze_width: int,
	maze_height: int,
	rng_seed: int = -1,
	options: Variant = null
) -> Array:
	if maze_width < 1 or maze_height < 1:
		push_error("MazeCarver.generate: width and height must be >= 1")
		return []

	if rng_seed >= 0:
		seed(rng_seed)

	var opts: Dictionary = options if options is Dictionary else {}
	var straight_bias: float = opts.get("straight_bias", 0.0)
	var braid_ratio: float = opts.get("braid_ratio", 0.0)

	var grid := _create_wall_grid(maze_width, maze_height)
	carve_iterative(grid, 1, 1, straight_bias)
	add_loops(grid, braid_ratio)
	return grid


static func carve_iterative(
	wall_grid: Array,
	start_x: int,
	start_y: int,
	straight_bias: float = 0.0
) -> void:
	var stack: Array = [{"pos": Vector2i(start_x, start_y), "incoming": Vector2i.ZERO}]
	wall_grid[start_x][start_y] = 0

	while not stack.is_empty():
		var frame: Dictionary = stack[-1]
		var current: Vector2i = frame["pos"]
		var incoming: Vector2i = frame["incoming"]
		var gx := current.x
		var gy := current.y

		var directions := _ordered_directions(incoming, straight_bias)

		var carved := false
		for dir in directions:
			var nx := gx + dir.x * 2
			var ny := gy + dir.y * 2
			if nx <= 0 or nx >= wall_grid.size() - 1:
				continue
			if ny <= 0 or ny >= wall_grid[0].size() - 1:
				continue
			if wall_grid[nx][ny] == 1:
				wall_grid[gx + dir.x][gy + dir.y] = 0
				wall_grid[nx][ny] = 0
				stack.append({"pos": Vector2i(nx, ny), "incoming": dir})
				carved = true
				break

		if not carved:
			stack.pop_back()


static func add_loops(wall_grid: Array, braid_ratio: float) -> void:
	if braid_ratio <= 0.0:
		return

	var candidates := _find_loop_wall_candidates(wall_grid)
	if candidates.is_empty():
		return

	candidates.shuffle()
	var remove_count := int(floor(float(candidates.size()) * braid_ratio))
	remove_count = clampi(remove_count, 0, candidates.size())

	for i in remove_count:
		var wall: Vector2i = candidates[i]
		wall_grid[wall.x][wall.y] = 0


static func count_open_neighbors(wall_grid: Array, gx: int, gy: int) -> int:
	## Counts reachable neighboring maze cells from a passage cell at (gx, gy).
	if wall_grid.is_empty():
		return 0

	var open := 0
	var grid_w: int = wall_grid.size()
	var grid_h: int = wall_grid[0].size()

	for dir in DIRS:
		var passage_x: int = gx + dir.x
		var passage_y: int = gy + dir.y
		var cell_x: int = gx + dir.x * 2
		var cell_y: int = gy + dir.y * 2
		if passage_x <= 0 or passage_x >= grid_w - 1:
			continue
		if passage_y <= 0 or passage_y >= grid_h - 1:
			continue
		if cell_x <= 0 or cell_x >= grid_w - 1:
			continue
		if cell_y <= 0 or cell_y >= grid_h - 1:
			continue
		if wall_grid[passage_x][passage_y] != 0:
			continue
		if wall_grid[cell_x][cell_y] != 0:
			continue
		open += 1
	return open


static func grid_size_for(maze_width: int, maze_height: int) -> Vector2i:
	return Vector2i(maze_width * 2 + 1, maze_height * 2 + 1)


static func count_carved_cells(wall_grid: Array, maze_width: int, maze_height: int) -> int:
	var carved := 0
	for cell_y in maze_height:
		for cell_x in maze_width:
			var gx := cell_x * 2 + 1
			var gy := cell_y * 2 + 1
			if wall_grid[gx][gy] == 0:
				carved += 1
	return carved


static func outer_boundary_is_solid(wall_grid: Array) -> bool:
	if wall_grid.is_empty():
		return false

	var grid_w: int = wall_grid.size()
	var grid_h: int = wall_grid[0].size()

	for x in grid_w:
		if wall_grid[x][0] != 1 or wall_grid[x][grid_h - 1] != 1:
			return false

	for y in grid_h:
		if wall_grid[0][y] != 1 or wall_grid[grid_w - 1][y] != 1:
			return false

	return true


static func all_cells_reachable(wall_grid: Array, maze_width: int, maze_height: int) -> bool:
	var start := Vector2i(1, 1)
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	visited[_cell_key(start.x, start.y)] = true
	var reachable := 0

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		reachable += 1

		for dir in DIRS:
			var passage := Vector2i(current.x + dir.x, current.y + dir.y)
			var next_cell := Vector2i(current.x + dir.x * 2, current.y + dir.y * 2)
			if not _is_cell_in_maze(next_cell.x, next_cell.y, maze_width, maze_height):
				continue
			if wall_grid[passage.x][passage.y] != 0:
				continue
			if wall_grid[next_cell.x][next_cell.y] != 0:
				continue

			var key := _cell_key(next_cell.x, next_cell.y)
			if visited.has(key):
				continue
			visited[key] = true
			queue.append(next_cell)

	return reachable == maze_width * maze_height


static func grids_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false

	for x in a.size():
		if a[x].size() != b[x].size():
			return false
		for y in a[x].size():
			if a[x][y] != b[x][y]:
				return false

	return true


static func _ordered_directions(incoming: Vector2i, straight_bias: float) -> Array[Vector2i]:
	var directions: Array[Vector2i] = []
	for dir in DIRS:
		directions.append(dir)
	directions.shuffle()

	if incoming != Vector2i.ZERO and randf() < straight_bias:
		for i in directions.size():
			if directions[i] == incoming:
				var chosen: Vector2i = directions[i]
				directions.remove_at(i)
				directions.insert(0, chosen)
				break

	return directions


static func _find_loop_wall_candidates(wall_grid: Array) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	if wall_grid.is_empty():
		return candidates

	var grid_w: int = wall_grid.size()
	var grid_h: int = wall_grid[0].size()

	for gx in range(1, grid_w - 1):
		for gy in range(1, grid_h - 1):
			if wall_grid[gx][gy] != 1:
				continue

			var horizontal_passage: bool = (
				wall_grid[gx - 1][gy] == 0 and wall_grid[gx + 1][gy] == 0
			)
			var vertical_passage: bool = (
				wall_grid[gx][gy - 1] == 0 and wall_grid[gx][gy + 1] == 0
			)
			if horizontal_passage or vertical_passage:
				candidates.append(Vector2i(gx, gy))

	return candidates


static func _create_wall_grid(maze_width: int, maze_height: int) -> Array:
	var size := grid_size_for(maze_width, maze_height)
	var grid_w: int = size.x
	var grid_h: int = size.y

	var grid: Array = []
	grid.resize(grid_w)
	for x in grid_w:
		grid[x] = []
		grid[x].resize(grid_h)
		for y in grid_h:
			grid[x][y] = 1

	return grid


static func _is_cell_in_maze(gx: int, gy: int, maze_width: int, maze_height: int) -> bool:
	var cell_x: int = (gx - 1) >> 1
	var cell_y: int = (gy - 1) >> 1
	return cell_x >= 0 and cell_y >= 0 and cell_x < maze_width and cell_y < maze_height


static func _cell_key(gx: int, gy: int) -> String:
	return "%d,%d" % [gx, gy]
