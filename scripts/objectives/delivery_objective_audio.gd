class_name DeliveryObjectiveAudio
extends RefCounted

## Relic ping audio tuning derived from maze dimensions.

const PING_AUDIBLE_COVERAGE := 0.6


static func maze_world_span(maze_width: int, maze_height: int, cell_size: float) -> float:
	if maze_width < 1 or maze_height < 1 or cell_size <= 0.0:
		return 0.0
	var world_width := float(maze_width * 2 + 1) * cell_size
	var world_depth := float(maze_height * 2 + 1) * cell_size
	return maxf(world_width, world_depth)


static func ping_max_distance(maze_width: int, maze_height: int, cell_size: float) -> float:
	return maze_world_span(maze_width, maze_height, cell_size) * PING_AUDIBLE_COVERAGE
