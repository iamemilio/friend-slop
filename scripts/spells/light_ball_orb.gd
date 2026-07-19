class_name LightBallOrb
extends Node3D

## Stationary glowing orb that illuminates the maze, then fades out.

const WorldVisualLayersScript := preload("res://scripts/world_visual_layers.gd")

const DEFAULT_DURATION_SEC := 30.0
const ORB_RADIUS := 0.28
const LIGHT_RANGE := 14.0
const LIGHT_ENERGY := 4.2
const PLACE_FORWARD := 2.4
const PLACE_HEIGHT := 1.15


var _duration_sec := DEFAULT_DURATION_SEC
var _omni: OmniLight3D
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _tween: Tween


static func spawn(
	parent: Node,
	world_position: Vector3,
	duration_sec: float = DEFAULT_DURATION_SEC
) -> LightBallOrb:
	var orb := LightBallOrb.new()
	orb._duration_sec = maxf(duration_sec, 0.5)
	parent.add_child(orb)
	orb.global_position = world_position
	return orb


static func spawn_ahead_of_player(
	player: CharacterBody3D,
	duration_sec: float = DEFAULT_DURATION_SEC
) -> LightBallOrb:
	if player == null or not player.is_inside_tree():
		return null
	var world: Node = player.get_tree().current_scene
	if world == null:
		world = player.get_parent()
	if world == null:
		return null
	var origin := player.global_position
	var forward := -player.global_transform.basis.z
	if player.has_method("get_wand_cast_origin"):
		origin = player.call("get_wand_cast_origin")
	if player.has_method("get_wand_cast_direction"):
		forward = player.call("get_wand_cast_direction")
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = -player.global_transform.basis.z
		forward.y = 0.0
	forward = forward.normalized()
	var pos := origin + forward * PLACE_FORWARD
	pos.y = player.global_position.y + PLACE_HEIGHT
	return spawn(world, pos, duration_sec)


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = ORB_RADIUS
	sphere.height = ORB_RADIUS * 2.0
	_mesh.mesh = sphere
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = Color(1.0, 0.96, 0.82, 0.92)
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.94, 0.7)
	_mat.emission_energy_multiplier = 3.5
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.layers = WorldVisualLayersScript.WORLD
	add_child(_mesh)

	_omni = OmniLight3D.new()
	_omni.light_color = Color(1.0, 0.95, 0.8)
	_omni.light_energy = LIGHT_ENERGY
	_omni.omni_range = LIGHT_RANGE
	_omni.omni_attenuation = 1.15
	_omni.shadow_enabled = false
	_omni.light_cull_mask = WorldVisualLayersScript.SCENE_LIGHT_MASK
	add_child(_omni)

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_omni, "light_energy", 0.0, _duration_sec).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN)
	_tween.tween_property(_mat, "emission_energy_multiplier", 0.0, _duration_sec).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN)
	_tween.tween_property(_mat, "albedo_color:a", 0.0, _duration_sec).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(queue_free)
