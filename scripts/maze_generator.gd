extends Node3D

## Generates a random maze and builds floor + wall collision geometry.
## Uses iterative recursive-backtracker, optional straight corridors, and loop braiding.

signal maze_ready(
	spawn_position: Vector3,
	exit_position: Vector3,
	spawn_cell: Vector2i,
	exit_cell: Vector2i
)
signal exit_reached(player: Node3D)

const WorldVisualLayersScript := preload("res://scripts/world_visual_layers.gd")

@export var maze_width: int = 15
@export var maze_height: int = 15
@export var cell_size: float = 3.0
@export var wall_height: float = 3.0
@export var regenerate_on_ready: bool = true
@export_range(0.0, 1.0, 0.05) var straight_bias: float = 0.4
@export_range(0.0, 0.5, 0.01) var braid_ratio: float = 0.15

var _wall_grid: Array = []
var _exit_triggered: bool = false


func _ready() -> void:
	call_deferred("_deferred_generate")


func _deferred_generate() -> void:
	if regenerate_on_ready:
		var seed_value: int = GameState.run_seed if GameState.run_seed >= 0 else -1
		generate_maze(seed_value)


func generate_maze(seed_value: int = -1) -> void:
	_clear_maze()
	_exit_triggered = false

	if seed_value >= 0:
		seed(seed_value)
	else:
		randomize()

	_wall_grid = MazeCarver.generate(maze_width, maze_height, -1, {
		"straight_bias": straight_bias,
		"braid_ratio": braid_ratio,
	})
	_build_floor()
	_build_walls()

	var spawn := _cell_to_world(0, 0)
	spawn.y = 0.5
	var exit := _cell_to_world(maze_width - 1, maze_height - 1)
	exit.y = 0.5

	_build_exit_marker(exit)
	maze_ready.emit(spawn, exit, Vector2i(0, 0), Vector2i(maze_width - 1, maze_height - 1))


func get_wall_grid() -> Array:
	return _wall_grid


func cell_to_world(cell_x: int, cell_y: int) -> Vector3:
	var pos := _cell_to_world(cell_x, cell_y)
	pos.y = 1.2
	return pos


func world_to_cell(world_position: Vector3) -> Vector2i:
	var offset := _maze_offset()
	var gx := int(round((world_position.x + offset.x) / cell_size))
	var gy := int(round((world_position.z + offset.z) / cell_size))
	return Vector2i(gx, gy)


func _clear_maze() -> void:
	for child in get_children():
		child.queue_free()
	_wall_grid.clear()


func _grid_to_world(gx: int, gy: int) -> Vector3:
	var offset := _maze_offset()
	return Vector3(gx * cell_size - offset.x, 0.0, gy * cell_size - offset.z)


func _cell_to_world(cell_x: int, cell_y: int) -> Vector3:
	return _grid_to_world(cell_x * 2 + 1, cell_y * 2 + 1)


func _maze_offset() -> Vector3:
	var grid_w := maze_width * 2 + 1
	var grid_h := maze_height * 2 + 1
	return Vector3(grid_w * cell_size * 0.5, 0.0, grid_h * cell_size * 0.5)


func _build_floor() -> void:
	var grid_w := maze_width * 2 + 1
	var grid_h := maze_height * 2 + 1
	var floor_size := Vector3(grid_w * cell_size, 0.2, grid_h * cell_size)

	var body := StaticBody3D.new()
	body.name = "Floor"

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = floor_size
	mesh_instance.mesh = box
	mesh_instance.position.y = -0.1

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.1, 0.16)
	material.roughness = 0.85
	mesh_instance.material_override = material
	mesh_instance.layers = WorldVisualLayersScript.WORLD

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = floor_size
	collision.shape = shape
	collision.position.y = -0.1

	body.add_child(mesh_instance)
	body.add_child(collision)
	add_child(body)


func _build_walls() -> void:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	for gx in _wall_grid.size():
		for gy in _wall_grid[gx].size():
			if _wall_grid[gx][gy] == 1:
				var center := _grid_to_world(gx, gy)
				center.y = wall_height * 0.5
				_add_box(surface_tool, center, Vector3(cell_size, wall_height, cell_size))

	var mesh := surface_tool.commit()

	var body := StaticBody3D.new()
	body.name = "Walls"

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.28, 0.42)
	material.roughness = 0.7
	mesh_instance.material_override = material
	mesh_instance.layers = WorldVisualLayersScript.WORLD

	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()

	body.add_child(mesh_instance)
	body.add_child(collision)
	add_child(body)


func _build_exit_marker(exit_position: Vector3) -> void:
	var gate_root := Node3D.new()
	gate_root.name = "RestorationGate"
	gate_root.position = exit_position
	add_child(gate_root)

	var marker := MeshInstance3D.new()
	marker.name = "Crystal"

	var crystal := CylinderMesh.new()
	crystal.top_radius = 0.25
	crystal.bottom_radius = 0.45
	crystal.height = 2.4
	marker.mesh = crystal
	marker.position = Vector3(0.0, 1.2, 0.0)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.9, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.25, 0.7, 0.95)
	material.emission_energy_multiplier = 2.5
	material.roughness = 0.1
	material.metallic = 0.15
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.9
	marker.material_override = material
	marker.layers = WorldVisualLayersScript.WORLD
	gate_root.add_child(marker)

	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 0.85, 1.0)
	light.light_energy = 2.0
	light.omni_range = 8.0
	light.position = Vector3(0.0, 2.2, 0.0)
	gate_root.add_child(light)

	var trigger := Area3D.new()
	trigger.name = "ExitTrigger"
	trigger.collision_layer = 0
	trigger.collision_mask = 1
	trigger.monitoring = true
	trigger.monitorable = false
	trigger.body_entered.connect(_on_exit_body_entered)

	var trigger_shape := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.4
	shape.height = 3.0
	trigger_shape.shape = shape
	trigger_shape.position = Vector3(0.0, 1.5, 0.0)
	trigger.add_child(trigger_shape)
	gate_root.add_child(trigger)


func _on_exit_body_entered(body: Node3D) -> void:
	if _exit_triggered:
		return
	if not body.is_in_group("player"):
		return
	_exit_triggered = true
	exit_reached.emit(body)


func _add_box(surface_tool: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var half := size * 0.5
	var corners := [
		center + Vector3(-half.x, -half.y, -half.z),
		center + Vector3(half.x, -half.y, -half.z),
		center + Vector3(half.x, -half.y, half.z),
		center + Vector3(-half.x, -half.y, half.z),
		center + Vector3(-half.x, half.y, -half.z),
		center + Vector3(half.x, half.y, -half.z),
		center + Vector3(half.x, half.y, half.z),
		center + Vector3(-half.x, half.y, half.z),
	]

	_add_quad(surface_tool, corners[4], corners[5], corners[6], corners[7]) # top
	_add_quad(surface_tool, corners[0], corners[2], corners[1], corners[3]) # bottom
	_add_quad(surface_tool, corners[0], corners[1], corners[5], corners[4]) # front
	_add_quad(surface_tool, corners[2], corners[3], corners[7], corners[6]) # back
	_add_quad(surface_tool, corners[1], corners[2], corners[6], corners[5]) # right
	_add_quad(surface_tool, corners[3], corners[0], corners[4], corners[7]) # left


func _add_quad(
	surface_tool: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3
) -> void:
	var normal := (b - a).cross(c - a).normalized()
	surface_tool.set_normal(normal)
	surface_tool.add_vertex(a)
	surface_tool.add_vertex(b)
	surface_tool.add_vertex(c)
	surface_tool.set_normal(normal)
	surface_tool.add_vertex(a)
	surface_tool.add_vertex(c)
	surface_tool.add_vertex(d)
