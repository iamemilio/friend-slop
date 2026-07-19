@tool
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
const MazeWallMeshScript := preload("res://scripts/maze_wall_mesh.gd")
const PlayerSpawnLayoutScript := preload("res://scripts/player_spawn_layout.gd")

const SPAWN_ZONE_PREVIEW_NAME := "SpawnZonePreview"

@export var maze_width: int = 15:
	set(value):
		maze_width = maxi(value, 1)
		_on_editor_dims_changed()
@export var maze_height: int = 15:
	set(value):
		maze_height = maxi(value, 1)
		_on_editor_dims_changed()
@export var cell_size: float = 3.0:
	set(value):
		cell_size = maxf(value, 0.1)
		_on_editor_dims_changed()
@export var wall_height: float = 3.0
@export var regenerate_on_ready: bool = true
@export_range(0.0, 1.0, 0.05) var straight_bias: float = 0.4
@export_range(0.0, 0.5, 0.01) var braid_ratio: float = 0.15

var _wall_grid: Array = []
var _exit_triggered: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		_notify_main_editor_preview()
		return
	call_deferred("_deferred_generate")


func _on_editor_dims_changed() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	_notify_main_editor_preview()


func _notify_main_editor_preview() -> void:
	var main := get_parent()
	if main != null and main.has_method("editor_refresh_environment_preview"):
		main.editor_refresh_environment_preview()


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
	if Engine.is_editor_hint():
		_build_spawn_zone_preview()
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


## Convert a world position to a maze room cell (not raw wall-grid coords).
func world_position_to_maze_cell(world_position: Vector3) -> Vector2i:
	var offset := _maze_offset()
	var gx := int(round((world_position.x + offset.x) / cell_size))
	var gy := int(round((world_position.z + offset.z) / cell_size))
	var cell_x := clampi(int(floor(float(gx) / 2.0)), 0, maze_width - 1)
	var cell_y := clampi(int(floor(float(gy) / 2.0)), 0, maze_height - 1)
	return Vector2i(cell_x, cell_y)


func rebuild_spawn_zone_preview_from_slots(slots: Array) -> void:
	## Replace default roster pads with pads matching PlayerSpawnSlot cells.
	if not Engine.is_editor_hint():
		return
	var existing := get_node_or_null(SPAWN_ZONE_PREVIEW_NAME)
	if existing != null:
		remove_child(existing)
		existing.free()
	if slots.is_empty():
		_build_spawn_zone_preview()
		return

	var root := Node3D.new()
	root.name = SPAWN_ZONE_PREVIEW_NAME
	add_child(root)

	var apprentice_i := 0
	var apprentice_colors: Array[Color] = [
		Color(0.2, 0.75, 1.0, 0.55),
		Color(0.15, 0.95, 0.85, 0.55),
		Color(0.35, 0.65, 1.0, 0.55),
	]
	for slot in slots:
		if slot == null or not (slot is PlayerSpawnSlot):
			continue
		var spawn_slot := slot as PlayerSpawnSlot
		var cell: Vector2i = spawn_slot.spawn_cell
		if spawn_slot.role == PlayerSpawnSlot.Role.WARDEN:
			root.add_child(
				_make_spawn_zone_marker(
					cell,
					cell_size * 2.4,
					0.35,
					Color(0.85, 0.25, 0.95, 0.55),
					Color(0.7, 0.15, 0.9),
					"WardenZone"
				)
			)
		else:
			var tint: Color = apprentice_colors[apprentice_i % apprentice_colors.size()]
			root.add_child(
				_make_spawn_zone_marker(
					cell,
					cell_size * 2.2,
					0.28,
					tint,
					Color(tint.r, tint.g, tint.b),
					"ApprenticeZone_%d" % apprentice_i
				)
			)
			apprentice_i += 1


func _clear_maze() -> void:
	# Free immediately so editor rebuilds do not stack duplicate floors/walls.
	while get_child_count() > 0:
		var child := get_child(0)
		remove_child(child)
		child.free()
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
	material.albedo_color = Color(0.18, 0.15, 0.22)
	material.roughness = 0.85
	mesh_instance.material_override = material
	mesh_instance.layers = WorldVisualLayersScript.WORLD
	# Floor only receives shadows; casting causes moiré streaks on the top surface.
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = floor_size
	collision.shape = shape
	collision.position.y = -0.1

	body.add_child(mesh_instance)
	body.add_child(collision)
	add_child(body)


func _build_walls() -> void:
	var wall_size := Vector3(cell_size, wall_height, cell_size)
	var grid_to_world := func(gx: int, gy: int) -> Vector3:
		return _grid_to_world(gx, gy)
	var mesh := MazeWallMeshScript.build(_wall_grid, wall_size, grid_to_world)

	var body := StaticBody3D.new()
	body.name = "Walls"

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.52, 0.46, 0.58)
	material.roughness = 0.7
	mesh_instance.material_override = material
	mesh_instance.layers = WorldVisualLayersScript.WORLD
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	var collision := CollisionShape3D.new()
	var collision_shape := mesh.create_trimesh_shape()
	if collision_shape == null:
		push_error("MazeGenerator: failed to build wall collision shape")
	else:
		collision.shape = collision_shape

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


func _build_spawn_zone_preview() -> void:
	## Editor-only: large role-colored pads at warden center + apprentice corners.
	var roster: Array[Vector2i] = PlayerSpawnLayoutScript.collect_roster_spawn_cells(
		_wall_grid,
		maze_width,
		maze_height
	)
	if roster.is_empty():
		return

	var root := Node3D.new()
	root.name = SPAWN_ZONE_PREVIEW_NAME
	add_child(root)

	# Warden — magenta center pad
	root.add_child(
		_make_spawn_zone_marker(
			roster[0],
			cell_size * 2.4,
			0.35,
			Color(0.85, 0.25, 0.95, 0.55),
			Color(0.7, 0.15, 0.9),
			"WardenZone"
		)
	)

	# Apprentices — cyan corner pads
	var apprentice_colors: Array[Color] = [
		Color(0.2, 0.75, 1.0, 0.55),
		Color(0.15, 0.95, 0.85, 0.55),
		Color(0.35, 0.65, 1.0, 0.55),
	]
	for i in range(1, mini(roster.size(), 4)):
		var tint: Color = apprentice_colors[(i - 1) % apprentice_colors.size()]
		var emission := Color(tint.r, tint.g, tint.b)
		root.add_child(
			_make_spawn_zone_marker(
				roster[i],
				cell_size * 2.2,
				0.28,
				tint,
				emission,
				"ApprenticeZone_%d" % (i - 1)
			)
		)


func _make_spawn_zone_marker(
	cell: Vector2i,
	diameter: float,
	height: float,
	albedo: Color,
	emission: Color,
	marker_name: String
) -> MeshInstance3D:
	var world := _cell_to_world(cell.x, cell.y)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = marker_name
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = diameter * 0.5
	cylinder.bottom_radius = diameter * 0.5
	cylinder.height = height
	mesh_instance.mesh = cylinder
	mesh_instance.position = Vector3(world.x, height * 0.5, world.z)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = albedo
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = 2.0
	mat.disable_fog = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = mat
	return mesh_instance


func _on_exit_body_entered(body: Node3D) -> void:
	if _exit_triggered:
		return
	if not body.is_in_group("player"):
		return
	_exit_triggered = true
	exit_reached.emit(body)
