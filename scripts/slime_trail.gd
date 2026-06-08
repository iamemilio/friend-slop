extends Node

## Leaves colored slime streaks on the ground while the snail is moving and grounded.

const MIN_SPEED := 0.15
const MIN_SEGMENT_LENGTH := 0.08
const STREAK_WIDTH := 0.42
const SLIME_LIFETIME := 50.0
const GROUND_Y := 0.012
const SlimeStreakSegmentScript := preload("res://scripts/slime_streak_segment.gd")

var snail_color: Color = Color.WHITE
var _trail_container: Node3D
var _player: CharacterBody3D
var _last_ground_position: Vector3
var _was_on_floor: bool = false
var _ready_to_drop: bool = false

var _streak_mesh: ArrayMesh


func setup(player: CharacterBody3D, color: Color, trail_container: Node3D) -> void:
	_player = player
	snail_color = color
	_trail_container = trail_container
	_last_ground_position = player.global_position
	_streak_mesh = _build_streak_mesh()
	_ready_to_drop = true


func _physics_process(_delta: float) -> void:
	if not _ready_to_drop or _player == null or _trail_container == null:
		return

	if not _player.is_on_floor():
		_was_on_floor = false
		return

	var current_position := _player.global_position

	if not _was_on_floor:
		_last_ground_position = current_position
		_was_on_floor = true
		return

	var horizontal_speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	if horizontal_speed < MIN_SPEED:
		_last_ground_position = current_position
		return

	var from := Vector3(_last_ground_position.x, 0.0, _last_ground_position.z)
	var to := Vector3(current_position.x, 0.0, current_position.z)
	var segment_vector := to - from
	var segment_length := segment_vector.length()
	if segment_length < MIN_SEGMENT_LENGTH:
		return

	_spawn_streak(from, to, segment_vector / segment_length, segment_length)
	_last_ground_position = current_position


func _spawn_streak(from: Vector3, to: Vector3, direction: Vector3, length: float) -> void:
	var segment := MeshInstance3D.new()
	segment.name = "SlimeStreak"
	segment.mesh = _streak_mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(snail_color.r, snail_color.g, snail_color.b, 0.82)
	material.emission_enabled = true
	material.emission = snail_color * 0.4
	material.emission_energy_multiplier = 1.4
	material.roughness = 0.04
	material.metallic = 0.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.clearcoat_enabled = true
	material.clearcoat = 0.85
	material.clearcoat_roughness = 0.08
	segment.material_override = material

	var midpoint := (from + to) * 0.5
	segment.global_position = Vector3(midpoint.x, GROUND_Y, midpoint.z)
	segment.scale = Vector3(STREAK_WIDTH, 1.0, length)
	segment.rotation.y = atan2(direction.x, direction.z)

	segment.set_script(SlimeStreakSegmentScript)
	segment.call("begin_fade", SLIME_LIFETIME)

	_trail_container.add_child(segment)


func _build_streak_mesh() -> ArrayMesh:
	# Unit-length streak along local Z with tapered edges for a gooey smear shape.
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_width := 0.5
	var taper := 0.55
	var y := 0.0

	var back_left := Vector3(-half_width * taper, y, -0.5)
	var back_right := Vector3(half_width * taper, y, -0.5)
	var front_left := Vector3(-half_width, y, 0.5)
	var front_right := Vector3(half_width, y, 0.5)
	var center_left := Vector3(-half_width * 0.92, y, 0.0)
	var center_right := Vector3(half_width * 0.92, y, 0.0)

	_add_quad(surface_tool, back_left, back_right, center_right, center_left)
	_add_quad(surface_tool, center_left, center_right, front_right, front_left)

	var mesh := surface_tool.commit()
	return mesh


func _add_quad(
	surface_tool: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3
) -> void:
	var normal := Vector3.UP
	surface_tool.set_normal(normal)
	surface_tool.set_uv(Vector2(0.0, 0.0))
	surface_tool.add_vertex(a)
	surface_tool.set_uv(Vector2(1.0, 0.0))
	surface_tool.add_vertex(b)
	surface_tool.set_uv(Vector2(1.0, 1.0))
	surface_tool.add_vertex(c)
	surface_tool.set_normal(normal)
	surface_tool.set_uv(Vector2(0.0, 0.0))
	surface_tool.add_vertex(a)
	surface_tool.set_uv(Vector2(1.0, 1.0))
	surface_tool.add_vertex(c)
	surface_tool.set_uv(Vector2(0.0, 1.0))
	surface_tool.add_vertex(d)
