class_name CloudSystem
extends Node3D

## Deterministic low-poly cloud layer drifting across the horizon.

const CloudStateScript := preload("res://scripts/environment/cloud_state.gd")
const WorldVisualLayersScript := preload("res://scripts/world_visual_layers.gd")

const CLOUD_SALT := "clouds"
const PUFFS_MIN := 4
const PUFFS_MAX := 8
const BASE_CLOUD_RADIUS := 11.0
const MIN_CLOUD_RADIUS := 8.0
const MAX_CLOUD_RADIUS := 32.0
const TRAVEL_SPAN_FACTOR := 2.5
const CLOUD_DENSITY_SCALE := 1.15

@export var cloud_count_base: int = 7
@export var cloud_density_divisor: float = 55.0
@export var cloud_count_max: int = 36
@export var drift_speed_min: float = 2.0
@export var drift_speed_max: float = 7.0
@export var cloud_height_min_ratio: float = 0.45
@export var cloud_height_max_ratio: float = 0.72

var _clouds: Array[CloudState] = []
var _bounds_min: Vector3 = Vector3.ZERO
var _bounds_max: Vector3 = Vector3.ZERO
var _travel_span: float = 0.0
var _match_start_time_msec: int = 0
var _configured: bool = false
var _cloud_holder: Node3D = _create_cloud_holder()


func _create_cloud_holder() -> Node3D:
	var holder := Node3D.new()
	holder.name = "Clouds"
	return holder


func _ready() -> void:
	_ensure_holder_in_tree()


func _ensure_holder_in_tree() -> void:
	if _cloud_holder == null:
		_cloud_holder = _create_cloud_holder()
	if _cloud_holder.get_parent() == null:
		add_child(_cloud_holder)


func configure_for_maze(
	maze_width: int,
	maze_height: int,
	cell_size: float,
	moon_height: float,
	run_seed: int = -1,
	start_time_msec: int = 0
) -> void:
	var grid_w := float(maze_width * 2 + 1)
	var grid_h := float(maze_height * 2 + 1)
	var maze_span := maxf(grid_w, grid_h) * cell_size
	var travel_span := maze_span * TRAVEL_SPAN_FACTOR
	var half := travel_span * 0.5
	var height_min := moon_height * cloud_height_min_ratio
	var height_max := moon_height * cloud_height_max_ratio

	var bounds_min := Vector3(-half, height_min, -half)
	var bounds_max := Vector3(half, height_max, half)
	configure(bounds_min, bounds_max, run_seed, start_time_msec, travel_span)


func configure(
	bounds_min: Vector3,
	bounds_max: Vector3,
	run_seed: int = -1,
	start_time_msec: int = 0,
	travel_span: float = -1.0
) -> void:
	_ensure_holder_in_tree()
	_clear_clouds()
	_bounds_min = bounds_min
	_bounds_max = bounds_max
	_travel_span = travel_span if travel_span > 0.0 else maxf(
		_bounds_max.x - _bounds_min.x,
		_bounds_max.z - _bounds_min.z
	)
	_match_start_time_msec = start_time_msec if start_time_msec > 0 else Time.get_ticks_msec()
	_configured = true

	var cloud_seed := _derive_seed(run_seed)
	seed(cloud_seed)

	var scaled_count := int(
		round((float(cloud_count_base) + _travel_span / cloud_density_divisor) * CLOUD_DENSITY_SCALE)
	)
	var scaled_max := int(round(float(cloud_count_max) * CLOUD_DENSITY_SCALE))
	var cloud_count := mini(scaled_max, scaled_count)

	_clouds = _generate_cloud_states(cloud_count)
	for state in _clouds:
		var mesh := _build_cloud_mesh(state)
		var instance := _create_mesh_instance(mesh)
		instance.name = "Cloud_%d" % state.index
		_cloud_holder.add_child(instance)

	_update_cloud_transforms(_elapsed_seconds())


func get_travel_span() -> float:
	return _travel_span


func get_bounds_min() -> Vector3:
	return _bounds_min


func get_bounds_max() -> Vector3:
	return _bounds_max


func _derive_seed(run_seed: int) -> int:
	return hash("%d:%s" % [run_seed, CLOUD_SALT])


func _generate_cloud_states(count: int) -> Array[CloudState]:
	var states: Array[CloudState] = []
	var size := _bounds_max - _bounds_min
	var drift_angle := randf() * TAU
	var drift_speed := drift_speed_min + randf() * (drift_speed_max - drift_speed_min)
	var shared_velocity := Vector3(
		cos(drift_angle) * drift_speed,
		0.0,
		sin(drift_angle) * drift_speed
	)

	for i in count:
		var state := CloudStateScript.new()
		state.index = i
		state.base_position = Vector3(
			_bounds_min.x + randf() * size.x,
			_bounds_min.y + randf() * size.y,
			_bounds_min.z + randf() * size.z
		)
		state.velocity = shared_velocity

		var radius_scale := 0.75 + randf() * 0.85
		state.radius = clampf(BASE_CLOUD_RADIUS * radius_scale, MIN_CLOUD_RADIUS, MAX_CLOUD_RADIUS)
		state.puff_seed = hash("%d:%d:%s" % [i, state.base_position.x, CLOUD_SALT])
		state.arc_amplitude = state.radius * (0.12 + randf() * 0.18)
		state.arc_wavelength = _travel_span * (0.35 + randf() * 0.25)
		state.arc_phase = randf() * TAU
		states.append(state)

	return states


func _build_cloud_mesh(state: CloudState) -> ArrayMesh:
	seed(state.puff_seed)
	var puff_count := PUFFS_MIN + (randi() % (PUFFS_MAX - PUFFS_MIN + 1))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for _i in puff_count:
		var offset := Vector3(
			(randf() - 0.5) * state.radius * 1.6,
			(randf() - 0.5) * state.radius * 0.4,
			(randf() - 0.5) * state.radius * 1.6
		)
		var puff_size := Vector3(
			state.radius * (0.55 + randf() * 0.55),
			state.radius * (0.28 + randf() * 0.38),
			state.radius * (0.55 + randf() * 0.55)
		)
		_append_box(st, offset, puff_size)

	st.generate_normals()
	return st.commit()


func _create_mesh_instance(mesh: ArrayMesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _cloud_material()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	instance.layers = WorldVisualLayersScript.WORLD
	return instance


func _cloud_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.84, 0.87, 0.91, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.25, 0.28, 0.32)
	material.emission_energy_multiplier = 0.6
	material.roughness = 1.0
	return material


func _append_box(st: SurfaceTool, offset: Vector3, size: Vector3) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5

	var v := [
		Vector3(-hx, -hy, -hz) + offset, Vector3(hx, -hy, -hz) + offset,
		Vector3(hx, hy, -hz) + offset, Vector3(-hx, hy, -hz) + offset,
		Vector3(-hx, -hy, hz) + offset, Vector3(hx, -hy, hz) + offset,
		Vector3(hx, hy, hz) + offset, Vector3(-hx, hy, hz) + offset,
	]

	## Front
	st.add_vertex(v[4]); st.add_vertex(v[5]); st.add_vertex(v[6])
	st.add_vertex(v[4]); st.add_vertex(v[6]); st.add_vertex(v[7])
	## Back
	st.add_vertex(v[2]); st.add_vertex(v[1]); st.add_vertex(v[0])
	st.add_vertex(v[3]); st.add_vertex(v[2]); st.add_vertex(v[0])
	## Top
	st.add_vertex(v[3]); st.add_vertex(v[7]); st.add_vertex(v[6])
	st.add_vertex(v[3]); st.add_vertex(v[6]); st.add_vertex(v[2])
	## Bottom
	st.add_vertex(v[4]); st.add_vertex(v[0]); st.add_vertex(v[1])
	st.add_vertex(v[4]); st.add_vertex(v[1]); st.add_vertex(v[5])
	## Right
	st.add_vertex(v[1]); st.add_vertex(v[2]); st.add_vertex(v[6])
	st.add_vertex(v[1]); st.add_vertex(v[6]); st.add_vertex(v[5])
	## Left
	st.add_vertex(v[4]); st.add_vertex(v[7]); st.add_vertex(v[3])
	st.add_vertex(v[4]); st.add_vertex(v[3]); st.add_vertex(v[0])


func _process(_delta: float) -> void:
	if not _configured:
		return
	_update_cloud_transforms(_elapsed_seconds())


func _elapsed_seconds() -> float:
	if _match_start_time_msec == 0:
		return 0.0
	return (Time.get_ticks_msec() - _match_start_time_msec) / 1000.0


func _update_cloud_transforms(elapsed_sec: float) -> void:
	var children := _cloud_holder.get_children()
	for i in _clouds.size():
		if i >= children.size():
			break
		var state: CloudState = _clouds[i]
		var instance: MeshInstance3D = children[i]
		instance.position = state.position_at(elapsed_sec, _bounds_min, _bounds_max)


func _clear_clouds() -> void:
	_clouds.clear()
	if _cloud_holder == null:
		return
	for child in _cloud_holder.get_children():
		child.queue_free()


func get_cloud_count() -> int:
	return _clouds.size()


func get_cloud_state(index: int) -> CloudState:
	if index < 0 or index >= _clouds.size():
		return null
	return _clouds[index]
