class_name Character
extends CharacterBody3D

## 3D character shell: body/head meshes, collision, and tint.
## Inherited by PlayableCharacter (and then Apprentice / Warden).

## Body/head render layer — wand lights use a world-only mask and skip this layer.
const PLAYER_SELF_VISUAL_LAYER := WorldVisualLayers.PLAYER_SELF

const BODY_RADIUS := 0.20
const HEAD_RADIUS := 0.16
const BODY_CENTER_Y := BODY_RADIUS
const HEAD_CENTER_Y := BODY_RADIUS * 2.0 + HEAD_RADIUS
const COLLISION_WALL_PADDING := 0.08
const BODY_COLLISION_RADIUS := BODY_RADIUS + COLLISION_WALL_PADDING

var _character_color: Color = Color.WHITE

@onready var head: Node3D = %Head
@onready var _body_mesh: MeshInstance3D = %Body
@onready var _head_mesh: MeshInstance3D = %HeadMesh
@onready var _body_collision: CollisionShape3D = %CollisionShape3D


func _configure_collision() -> void:
	var body_capsule := CapsuleShape3D.new()
	body_capsule.radius = BODY_COLLISION_RADIUS
	var bottom_y := BODY_CENTER_Y - BODY_RADIUS
	var top_y := HEAD_CENTER_Y + HEAD_RADIUS
	var total_height := top_y - bottom_y
	body_capsule.height = maxf(0.08, total_height - body_capsule.radius * 2.0)
	_body_collision.shape = body_capsule
	_body_collision.position.y = bottom_y + body_capsule.radius + body_capsule.height * 0.5


func _apply_character_color(color: Color) -> void:
	# Lit materials (no constant emission) so moonlight / world lights shade the mesh.
	# Layer PLAYER_SELF: moon uses SCENE_LIGHT_MASK; wand flashlight stays WORLD-only.
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.albedo_color = color
	material.roughness = 0.62
	material.metallic = 0.05
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	_body_mesh.material_override = material
	_body_mesh.layers = PLAYER_SELF_VISUAL_LAYER
	_body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var head_material := material.duplicate() as StandardMaterial3D
	head_material.albedo_color = color.lightened(0.08)
	_head_mesh.material_override = head_material
	_head_mesh.layers = PLAYER_SELF_VISUAL_LAYER
	_head_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func get_snail_color() -> Color:
	return _character_color
