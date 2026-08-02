@tool
class_name WardShield
extends Node3D

## Forward-facing spherical-cap blue shield. Blocks one fireball, then shatters.
## Open scenes/spells/ward.tscn (or ward_workspace.tscn) — select Ward root to edit Dome shape.

const WardMeshBuilderScript := preload("res://scripts/spells/ward_mesh_builder.gd")

const GROUP := "spell_ward"
const DURATION_SEC := 1.0
## Kept for tests / callers that expect a class-level default size.
const RADIUS := 1.35
const SHIELD_BLUE := Color(0.35, 0.65, 1.0, 0.38)
const SHIELD_EDGE := Color(0.55, 0.85, 1.0, 0.72)

@export_group("Dome shape")
@export_range(0.25, 4.0, 0.05, "or_greater") var radius: float = 1.35:
	set(value):
		radius = maxf(value, 0.05)
		_rebuild_geometry()

@export_range(0.1, 0.9, 0.01) var surface_fraction: float = 0.333:
	set(value):
		surface_fraction = clampf(value, 0.05, 0.95)
		_rebuild_geometry()

@export_range(2, 32, 1) var ring_count: int = 10:
	set(value):
		ring_count = maxi(value, 2)
		_rebuild_geometry()

@export_range(3, 64, 1) var segment_count: int = 28:
	set(value):
		segment_count = maxi(value, 3)
		_rebuild_geometry()

var _body: StaticBody3D
var _mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D
var _material: StandardMaterial3D
var _spent := false
var _lifetime := 0.0


static func spawn(parent: Node, origin: Vector3, direction: Vector3) -> Node:
	## Lazy-load avoids circular preload with ward.tscn (which attaches this script).
	var packed: PackedScene = load("res://scenes/spells/ward.tscn") as PackedScene
	var ward: Node = packed.instantiate()
	if parent != null:
		parent.add_child(ward)
	if ward.has_method("setup_cast"):
		ward.call("setup_cast", origin, direction)
	return ward


func _ready() -> void:
	_cache_nodes()
	_rebuild_geometry()
	add_to_group(GROUP)
	if _body != null:
		_body.add_to_group(GROUP)
	if Engine.is_editor_hint():
		set_process(false)
		return
	if _mesh_instance != null and _mesh_instance.material_override is StandardMaterial3D:
		## Duplicate so fade/dissolve does not mutate the shared scene material.
		_material = (_mesh_instance.material_override as StandardMaterial3D).duplicate()
		_mesh_instance.material_override = _material


func _cache_nodes() -> void:
	_mesh_instance = get_node_or_null("Dome") as MeshInstance3D
	_body = get_node_or_null("Body") as StaticBody3D
	if _body != null:
		_collision_shape = _body.get_node_or_null("CollisionShape3D") as CollisionShape3D


func _rebuild_geometry() -> void:
	if not is_inside_tree() and not Engine.is_editor_hint():
		return
	if _mesh_instance == null or _collision_shape == null:
		_cache_nodes()
	if _mesh_instance == null:
		return
	_mesh_instance.mesh = WardMeshBuilderScript.build_mesh(
		radius, surface_fraction, ring_count, segment_count
	)
	if _collision_shape != null:
		_collision_shape.shape = WardMeshBuilderScript.build_collision_shape(
			radius, surface_fraction, ring_count, segment_count
		)


func setup_cast(origin: Vector3, direction: Vector3) -> void:
	var dir := direction
	if dir.length_squared() < 0.0001:
		dir = Vector3.FORWARD
	else:
		dir = dir.normalized()
	## Sit the dome just ahead of the cast point, bulging toward the aim (-Z).
	var pos := origin + dir * (radius * 0.2)
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.95:
		up = Vector3.RIGHT
	global_transform = Transform3D(Basis.looking_at(dir, up), pos)
	_lifetime = 0.0
	_spent = false
	set_process(true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_lifetime += delta
	if _material != null:
		var fade := clampf(1.0 - (_lifetime / DURATION_SEC), 0.0, 1.0)
		_material.albedo_color.a = SHIELD_BLUE.a * fade
		_material.emission = SHIELD_EDGE * (0.35 + 0.4 * fade)
	if _lifetime >= DURATION_SEC and not _spent:
		_dissolve()


func notify_spell_blocked() -> void:
	## One fireball (or similar) spends the ward.
	if _spent:
		return
	_spent = true
	_dissolve()


func _dissolve() -> void:
	_spent = true
	set_process(false)
	if _body != null:
		_body.collision_layer = 0
	var tween := create_tween()
	if _material != null:
		tween.tween_property(_material, "albedo_color:a", 0.0, 0.12)
	tween.tween_callback(queue_free)
