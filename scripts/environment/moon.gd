@tool
class_name Moon
extends Node3D

## Physical moon above the maze; moonlight is a child DirectionalLight3D.
##
## DirectionalLight3D ignores position — only its -Z axis sets ray direction. We place
## the moon off-center and aim the light at the maze origin so the beam matches the
## moon mesh. Taller moon (same horizontal offset) = steeper light = shorter shadows.

const MIN_HEIGHT := 120.0
const HEIGHT_FACTOR := 0.95
const MIN_GROUND_RADIUS := 72.0
const GROUND_RADIUS_FACTOR := 0.18
const MOON_AZIMUTH_DEG := 38.0

@onready var moon_light: DirectionalLight3D = $MoonLight


func _get_moon_light() -> DirectionalLight3D:
	if moon_light != null:
		return moon_light
	return get_node_or_null("MoonLight") as DirectionalLight3D


func _ready() -> void:
	if Engine.is_editor_hint():
		# Main / MazeGenerator drive configure_for_maze for editor preview.
		return
	_place_moon_for_span(MIN_HEIGHT / HEIGHT_FACTOR)
	_configure_moon_light()


func _place_moon_for_span(span: float) -> void:
	var height := maxf(span * HEIGHT_FACTOR, MIN_HEIGHT)
	var ground_radius := maxf(span * GROUND_RADIUS_FACTOR, MIN_GROUND_RADIUS)
	var azimuth := deg_to_rad(MOON_AZIMUTH_DEG)
	position = Vector3(
		ground_radius * sin(azimuth),
		height,
		ground_radius * cos(azimuth)
	)
	_aim_light_at_maze_center()


func _aim_light_at_maze_center() -> void:
	var light := _get_moon_light()
	if light == null:
		return
	var to_center := -position
	if to_center.is_zero_approx():
		return
	if is_inside_tree():
		light.look_at(Vector3.ZERO, Vector3.UP)
	else:
		light.basis = Basis.looking_at(to_center, Vector3.UP)


func _configure_moon_light() -> void:
	var light := _get_moon_light()
	if light == null:
		return
	# Light + shadow both WORLD and PLAYER_SELF so characters receive moonlight shading.
	light.light_cull_mask = WorldVisualLayers.SCENE_LIGHT_MASK
	light.shadow_caster_mask = WorldVisualLayers.SCENE_LIGHT_MASK
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	light.directional_shadow_blend_splits = true
	# Near-biased splits: player-in-maze POV needs stable floor coverage first.
	light.directional_shadow_split_1 = 0.18
	light.directional_shadow_split_2 = 0.42
	light.directional_shadow_split_3 = 0.72
	# Pancake restores depth precision for high cloud → floor rays (0 caused swim/flicker).
	light.directional_shadow_pancake_size = 28.0
	light.directional_shadow_fade_start = 0.85
	light.light_angular_distance = 0.0
	light.shadow_blur = 0.6
	# Hard enough for moonlight, soft enough to hide cascade micro-jitter.
	light.shadow_bias = 0.12
	light.shadow_normal_bias = 2.2


func configure_for_maze(
	maze_width: int,
	maze_height: int,
	cell_size: float,
	cloud_field_size: Vector3 = Vector3.ZERO
) -> void:
	var span_x := float(maze_width * 2 + 1) * cell_size
	var span_z := float(maze_height * 2 + 1) * cell_size
	var span := maxf(span_x, span_z)
	_place_moon_for_span(span)
	_configure_moon_light()
	var light := _get_moon_light()
	if light == null:
		return
	light.shadow_enabled = true
	# Reach overhead clouds above the playable maze — not the full 1500-unit field edge.
	# Oversized max_distance is a common cause of DirectionalLight shadow flicker.
	var cloud_ceiling := maxf(cell_size * 52.0, 140.0)
	if cloud_field_size.y > 0.0:
		cloud_ceiling = maxf(cloud_ceiling, cloud_field_size.y + 40.0)
	var shadow_distance := maxf(span * 1.25, cloud_ceiling + span * 0.55)
	light.directional_shadow_max_distance = clampf(shadow_distance, 280.0, 400.0)
	light.directional_shadow_split_1 = 0.18
	light.directional_shadow_split_2 = 0.42
	light.directional_shadow_split_3 = 0.72
