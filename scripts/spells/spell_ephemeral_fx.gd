class_name SpellEphemeralFx
extends RefCounted

## Fire-and-forget spell visuals (SpellSyncLane.EPHEMERAL).
## Spawn from cast-wire pose on every peer; play out locally; do not assign
## spawn_id or use SpellWorldSync events.

const GameWorldScript := preload("res://scripts/game_world.gd")

const BUCKET_PROJECTILES := "SpellProjectiles"

const KEY_ORIGIN := "origin"
const KEY_DIRECTION := "direction"


static func resolve_parent(
	player: Node,
	bucket_name: String = BUCKET_PROJECTILES
) -> Node:
	if player == null:
		return null
	var world: Node = null
	if player.is_inside_tree():
		world = GameWorldScript.find_match_root(player.get_tree())
	if world == null:
		world = player.get_parent()
	if world == null:
		return null
	if bucket_name.is_empty():
		return world
	var bucket := world.get_node_or_null(bucket_name)
	if bucket != null:
		return bucket
	bucket = Node3D.new()
	bucket.name = bucket_name
	world.add_child(bucket)
	return bucket


static func pack_ray(
	wire: Dictionary,
	origin: Vector3,
	direction: Vector3
) -> void:
	wire["origin_x"] = origin.x
	wire["origin_y"] = origin.y
	wire["origin_z"] = origin.z
	wire["dir_x"] = direction.x
	wire["dir_y"] = direction.y
	wire["dir_z"] = direction.z


static func unpack_ray(wire: Dictionary) -> Dictionary:
	var direction := Vector3(
		float(wire.get("dir_x", 0.0)),
		float(wire.get("dir_y", 0.0)),
		float(wire.get("dir_z", 0.0))
	)
	if direction.length_squared() > 0.0001:
		direction = direction.normalized()
	return {
		KEY_ORIGIN: Vector3(
			float(wire.get("origin_x", 0.0)),
			float(wire.get("origin_y", 0.0)),
			float(wire.get("origin_z", 0.0))
		),
		KEY_DIRECTION: direction,
	}


static func is_ray_wire(params: Dictionary) -> bool:
	return params.has("origin_x") and params.has("dir_x") and not params.has(KEY_ORIGIN)


static func spawn_at(
	player: Node,
	origin: Vector3,
	direction: Vector3,
	spawner: Callable,
	bucket_name: String = BUCKET_PROJECTILES
) -> Variant:
	## spawner(parent, origin, direction) → spawned Node (or null).
	if spawner.is_null():
		return null
	var parent := resolve_parent(player, bucket_name)
	if parent == null:
		return null
	if direction.length_squared() <= 0.01:
		return null
	return spawner.call(parent, origin, direction.normalized())
