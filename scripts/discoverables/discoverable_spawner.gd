class_name DiscoverableSpawner
extends Node3D

## Instantiates discoverables from a spawn plan after maze generation.

@export var run_config: DiscoverableRunConfig

var _definition_by_id: Dictionary = {}


func _ready() -> void:
	_build_definition_lookup()


func _build_definition_lookup() -> void:
	_definition_by_id.clear()
	if run_config == null:
		return
	for entry in run_config.entries:
		if entry != null and entry.definition != null:
			_definition_by_id[entry.definition.id] = entry.definition


func clear_spawned() -> void:
	for child in get_children():
		child.queue_free()


func spawn_from_plan(
	placements: Array[DiscoverablePlacement],
	cell_to_world: Callable,
	wall_grid: Array = []
) -> void:
	clear_spawned()
	for placement in placements:
		_spawn_one(placement, cell_to_world, wall_grid)


func _spawn_one(
	placement: DiscoverablePlacement,
	cell_to_world: Callable,
	wall_grid: Array = []
) -> void:
	if not wall_grid.is_empty():
		if not DiscoverableSpawnPlan.is_walkable_cell(wall_grid, placement.cell):
			push_warning(
				"DiscoverableSpawner: skipping '%s' at non-walkable cell %s"
				% [placement.definition_id, placement.cell]
			)
			return

	var definition: DiscoverableDefinition = _definition_by_id.get(placement.definition_id)
	if definition == null or definition.scene == null:
		push_warning("DiscoverableSpawner: unknown definition '%s'" % placement.definition_id)
		return

	var instance: Node = definition.scene.instantiate()
	add_child(instance)

	var world_pos: Vector3 = cell_to_world.call(placement.cell.x, placement.cell.y)
	world_pos.y = 1.2
	if instance is Node3D:
		instance.global_position = world_pos

	if instance.has_method("initialize"):
		instance.initialize(placement, definition)
	TomeDebug.log(
		"Spawner",
		"spawned %s variant='%s' cell=%s"
		% [placement.definition_id, placement.variant_id, placement.cell]
	)
