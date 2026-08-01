class_name SpellEffectSync
extends RefCounted

## Generic spell effect params for solo play and multiplayer RPC payloads.
## Persistence model: see SpellSyncLane (player_bound / ephemeral / world_object /
## targeted). Ephemeral spawns use SpellEphemeralFx; lasting props use SpellWorldSync.

const FireballProjectileScript := preload("res://scripts/spells/fireball_projectile.gd")
const LightBallOrbScript := preload("res://scripts/spells/light_ball_orb.gd")
const TargetHighlightScript := preload("res://scripts/spells/target_highlight.gd")
const TargetedObjectControlScript := preload("res://scripts/spells/targeted_object_control.gd")
const GameWorldScript := preload("res://scripts/game_world.gd")
const SpellWorldSyncScript := preload("res://scripts/spells/spell_world_sync.gd")
const SpellEphemeralFxScript := preload("res://scripts/spells/spell_ephemeral_fx.gd")
const SpellSyncLaneScript := preload("res://scripts/spells/spell_sync_lane.gd")
const FakeWallScript := preload("res://scripts/headmaster/fake_wall.gd")

const KEY_EFFECT_ID := "effect_id"
const KEY_ORIGIN := "origin"
const KEY_WAND_ORIGIN := "wand_origin"
const KEY_DIRECTION := "direction"
const KEY_DURATION := "duration"
const KEY_MULTIPLIER := "multiplier"
const KEY_TARGET_KIND := "target_kind"

const EFFECT_HASTE := "haste"
const EFFECT_LIGHT := "light"
const EFFECT_FIREBALL := "fireball"
const EFFECT_FLASHLIGHT_TOGGLE := "flashlight_toggle"
const EFFECT_LIGHT_BALL := "light_ball"
const EFFECT_TARGET := "target"
const EFFECT_PULL := "pull"
const EFFECT_FOLLOW := "follow"
const EFFECT_DISPELL := "dispell"
const EFFECT_FAKE_WALL := "fake_wall"

const KEY_GRID_X := "grid_x"
const KEY_GRID_Y := "grid_y"
const KEY_SIZE := "size"
const KEY_SPAWN_ID := "spawn_id"

const DEFAULT_LIGHT_DURATION := 20.0
const DEFAULT_HASTE_DURATION := 4.0
const DEFAULT_HASTE_MULTIPLIER := 1.65
const DEFAULT_FIREBALL_CAST_DURATION := 0.0
const DEFAULT_LIGHT_BALL_DURATION := 30.0
const DEFAULT_TARGET_DURATION := 10.0


static func get_effect_duration_sec(spell: SpellDefinition, params: Dictionary = {}) -> float:
	if spell == null:
		return 0.0
	match spell.effect_id:
		EFFECT_LIGHT:
			return float(params.get(KEY_DURATION, DEFAULT_LIGHT_DURATION))
		EFFECT_HASTE:
			return float(params.get(KEY_DURATION, DEFAULT_HASTE_DURATION))
		EFFECT_FIREBALL:
			return DEFAULT_FIREBALL_CAST_DURATION
		EFFECT_LIGHT_BALL:
			# Orb fades itself — no right-side active-timer chrome.
			return 0.0
		EFFECT_FLASHLIGHT_TOGGLE:
			return 0.0
		EFFECT_TARGET:
			# Highlight fades itself — no right-side active-timer chrome.
			return 0.0
		EFFECT_PULL, EFFECT_FOLLOW, EFFECT_DISPELL:
			return 0.0
		EFFECT_FAKE_WALL:
			return 0.0
		_:
			return 0.0


static func build_params(spell: SpellDefinition, player: CharacterBody3D) -> Dictionary:
	if spell == null or player == null:
		return {}
	var params := {KEY_EFFECT_ID: spell.effect_id}
	match spell.effect_id:
		EFFECT_FIREBALL:
			params[KEY_ORIGIN] = _fireball_origin(player)
			params[KEY_DIRECTION] = _fireball_direction(player)
		EFFECT_LIGHT:
			params[KEY_DURATION] = DEFAULT_LIGHT_DURATION
		EFFECT_HASTE:
			params[KEY_DURATION] = DEFAULT_HASTE_DURATION
			params[KEY_MULTIPLIER] = DEFAULT_HASTE_MULTIPLIER
		EFFECT_LIGHT_BALL:
			params[KEY_ORIGIN] = _light_ball_origin(player)
			params[KEY_WAND_ORIGIN] = _fireball_origin(player)
			params[KEY_DURATION] = DEFAULT_LIGHT_BALL_DURATION
			params[KEY_SPAWN_ID] = SpellWorldSyncScript.make_spawn_id(player)
		EFFECT_FLASHLIGHT_TOGGLE:
			pass
		EFFECT_TARGET:
			params[KEY_DURATION] = DEFAULT_TARGET_DURATION
			_append_targetable(params, player)
		EFFECT_PULL:
			_append_looked_at_target(params, player, true)
		EFFECT_FOLLOW:
			_append_looked_at_target(params, player, false)
		EFFECT_DISPELL:
			if not TargetHighlightScript.has_active_highlights(player.get_tree()):
				return {}
			_append_dispell_target(params, player)
		EFFECT_FAKE_WALL:
			# Placement supplies grid/origin/size after interact confirm.
			return {}
		_:
			return {}
	return params


static func _append_targetable(params: Dictionary, player: CharacterBody3D) -> void:
	var target := TargetedObjectControlScript.pick_targetable(player)
	if target == null:
		return
	var desc: Dictionary = TargetedObjectControlScript.describe_target(target)
	if desc.is_empty():
		return
	params[KEY_TARGET_KIND] = str(desc.get("kind", ""))
	params[KEY_ORIGIN] = desc.get("mark", Vector3.ZERO)


static func _append_looked_at_target(
	params: Dictionary,
	player: CharacterBody3D,
	require_los: bool = false
) -> void:
	var target := TargetedObjectControlScript.pick_looked_at(player, require_los)
	if target == null:
		return
	var desc: Dictionary = TargetedObjectControlScript.describe_target(target)
	if desc.is_empty():
		return
	params[KEY_TARGET_KIND] = str(desc.get("kind", ""))
	params[KEY_ORIGIN] = desc.get("mark", Vector3.ZERO)


static func _append_dispell_target(params: Dictionary, player: CharacterBody3D) -> void:
	if player == null or not player.is_inside_tree():
		return
	var tree := player.get_tree()
	## Dispell only acts on an active Target outline — never bare aim.
	var target: Node3D = null
	for anchor in TargetHighlightScript.get_highlighted_anchors(tree):
		if anchor == null:
			continue
		if (
			anchor.is_in_group(SpellWorldSyncScript.KIND_FAKE_WALL)
			or anchor.is_in_group(SpellWorldSyncScript.KIND_LIGHT_BALL)
		):
			target = anchor
			break
	if target == null:
		return
	var desc: Dictionary = TargetedObjectControlScript.describe_target(target)
	if desc.is_empty():
		return
	params[KEY_TARGET_KIND] = str(desc.get("kind", ""))
	params[KEY_ORIGIN] = desc.get("mark", Vector3.ZERO)
	var cell: Variant = target.get("grid_cell")
	if cell is Vector2i:
		params[KEY_GRID_X] = cell.x
		params[KEY_GRID_Y] = cell.y
	var object_id := SpellWorldSyncScript.get_id(target)
	if object_id.is_empty() and cell is Vector2i:
		object_id = SpellWorldSyncScript.make_cell_id(cell)
	if not object_id.is_empty():
		params[KEY_SPAWN_ID] = object_id


static func pack_for_network(params: Dictionary) -> Dictionary:
	var local := normalize_params(params)
	if local.is_empty():
		return {}
	var wire := {KEY_EFFECT_ID: str(local.get(KEY_EFFECT_ID, ""))}
	match str(wire[KEY_EFFECT_ID]):
		EFFECT_FIREBALL:
			var origin := coerce_vector3(local.get(KEY_ORIGIN, Vector3.ZERO))
			var direction := coerce_vector3(local.get(KEY_DIRECTION, Vector3.FORWARD))
			SpellEphemeralFxScript.pack_ray(wire, origin, direction)
		EFFECT_HASTE:
			wire[KEY_DURATION] = float(local.get(KEY_DURATION, DEFAULT_HASTE_DURATION))
			wire[KEY_MULTIPLIER] = float(local.get(KEY_MULTIPLIER, DEFAULT_HASTE_MULTIPLIER))
		EFFECT_LIGHT:
			wire[KEY_DURATION] = float(local.get(KEY_DURATION, DEFAULT_LIGHT_DURATION))
		EFFECT_TARGET:
			wire[KEY_DURATION] = float(local.get(KEY_DURATION, DEFAULT_TARGET_DURATION))
			wire[KEY_TARGET_KIND] = str(local.get(KEY_TARGET_KIND, ""))
			var mark := coerce_vector3(local.get(KEY_ORIGIN, Vector3.ZERO))
			wire["origin_x"] = mark.x
			wire["origin_y"] = mark.y
			wire["origin_z"] = mark.z
		EFFECT_PULL, EFFECT_FOLLOW:
			wire[KEY_TARGET_KIND] = str(local.get(KEY_TARGET_KIND, ""))
			var mark := coerce_vector3(local.get(KEY_ORIGIN, Vector3.ZERO))
			wire["origin_x"] = mark.x
			wire["origin_y"] = mark.y
			wire["origin_z"] = mark.z
		EFFECT_DISPELL:
			wire[KEY_TARGET_KIND] = str(local.get(KEY_TARGET_KIND, ""))
			var mark := coerce_vector3(local.get(KEY_ORIGIN, Vector3.ZERO))
			wire["origin_x"] = mark.x
			wire["origin_y"] = mark.y
			wire["origin_z"] = mark.z
			wire[KEY_GRID_X] = int(local.get(KEY_GRID_X, -1))
			wire[KEY_GRID_Y] = int(local.get(KEY_GRID_Y, -1))
			wire[KEY_SPAWN_ID] = str(local.get(KEY_SPAWN_ID, ""))
		EFFECT_LIGHT_BALL:
			var origin := coerce_vector3(local.get(KEY_ORIGIN, Vector3.ZERO))
			var wand_origin := coerce_vector3(local.get(KEY_WAND_ORIGIN, Vector3.ZERO))
			wire["origin_x"] = origin.x
			wire["origin_y"] = origin.y
			wire["origin_z"] = origin.z
			wire["wand_x"] = wand_origin.x
			wire["wand_y"] = wand_origin.y
			wire["wand_z"] = wand_origin.z
			wire[KEY_DURATION] = float(local.get(KEY_DURATION, DEFAULT_LIGHT_BALL_DURATION))
			wire[KEY_SPAWN_ID] = str(local.get(KEY_SPAWN_ID, ""))
		EFFECT_FLASHLIGHT_TOGGLE:
			pass
		EFFECT_FAKE_WALL:
			var origin := coerce_vector3(local.get(KEY_ORIGIN, Vector3.ZERO))
			var size := coerce_vector3(local.get(KEY_SIZE, Vector3(3.0, 3.0, 3.0)))
			wire[KEY_GRID_X] = int(local.get(KEY_GRID_X, -1))
			wire[KEY_GRID_Y] = int(local.get(KEY_GRID_Y, -1))
			wire["origin_x"] = origin.x
			wire["origin_y"] = origin.y
			wire["origin_z"] = origin.z
			wire["size_x"] = size.x
			wire["size_y"] = size.y
			wire["size_z"] = size.z
		_:
			return {}
	return wire


static func unpack_from_network(wire: Dictionary) -> Dictionary:
	if wire.is_empty():
		return {}
	var effect_id := str(wire.get(KEY_EFFECT_ID, ""))
	var params := {KEY_EFFECT_ID: effect_id}
	match effect_id:
		EFFECT_FIREBALL:
			var ray := SpellEphemeralFxScript.unpack_ray(wire)
			params[KEY_ORIGIN] = ray[SpellEphemeralFxScript.KEY_ORIGIN]
			params[KEY_DIRECTION] = ray[SpellEphemeralFxScript.KEY_DIRECTION]
		EFFECT_HASTE:
			params[KEY_DURATION] = float(wire.get(KEY_DURATION, DEFAULT_HASTE_DURATION))
			params[KEY_MULTIPLIER] = float(wire.get(KEY_MULTIPLIER, DEFAULT_HASTE_MULTIPLIER))
		EFFECT_LIGHT:
			params[KEY_DURATION] = float(wire.get(KEY_DURATION, DEFAULT_LIGHT_DURATION))
		EFFECT_TARGET:
			params[KEY_DURATION] = float(wire.get(KEY_DURATION, DEFAULT_TARGET_DURATION))
			params[KEY_TARGET_KIND] = str(wire.get(KEY_TARGET_KIND, ""))
			params[KEY_ORIGIN] = Vector3(
				float(wire.get("origin_x", 0.0)),
				float(wire.get("origin_y", 0.0)),
				float(wire.get("origin_z", 0.0))
			)
		EFFECT_PULL, EFFECT_FOLLOW:
			params[KEY_TARGET_KIND] = str(wire.get(KEY_TARGET_KIND, ""))
			params[KEY_ORIGIN] = Vector3(
				float(wire.get("origin_x", 0.0)),
				float(wire.get("origin_y", 0.0)),
				float(wire.get("origin_z", 0.0))
			)
		EFFECT_DISPELL:
			params[KEY_TARGET_KIND] = str(wire.get(KEY_TARGET_KIND, ""))
			params[KEY_ORIGIN] = Vector3(
				float(wire.get("origin_x", 0.0)),
				float(wire.get("origin_y", 0.0)),
				float(wire.get("origin_z", 0.0))
			)
			params[KEY_GRID_X] = int(wire.get(KEY_GRID_X, -1))
			params[KEY_GRID_Y] = int(wire.get(KEY_GRID_Y, -1))
			params[KEY_SPAWN_ID] = str(wire.get(KEY_SPAWN_ID, ""))
		EFFECT_LIGHT_BALL:
			params[KEY_ORIGIN] = Vector3(
				float(wire.get("origin_x", 0.0)),
				float(wire.get("origin_y", 0.0)),
				float(wire.get("origin_z", 0.0))
			)
			params[KEY_WAND_ORIGIN] = Vector3(
				float(wire.get("wand_x", 0.0)),
				float(wire.get("wand_y", 0.0)),
				float(wire.get("wand_z", 0.0))
			)
			params[KEY_DURATION] = float(wire.get(KEY_DURATION, DEFAULT_LIGHT_BALL_DURATION))
			params[KEY_SPAWN_ID] = str(wire.get(KEY_SPAWN_ID, ""))
		EFFECT_FLASHLIGHT_TOGGLE:
			pass
		EFFECT_FAKE_WALL:
			params[KEY_GRID_X] = int(wire.get(KEY_GRID_X, -1))
			params[KEY_GRID_Y] = int(wire.get(KEY_GRID_Y, -1))
			params[KEY_ORIGIN] = Vector3(
				float(wire.get("origin_x", 0.0)),
				float(wire.get("origin_y", 0.0)),
				float(wire.get("origin_z", 0.0))
			)
			params[KEY_SIZE] = Vector3(
				float(wire.get("size_x", 3.0)),
				float(wire.get("size_y", 3.0)),
				float(wire.get("size_z", 3.0))
			)
		_:
			return {}
	return params


static func normalize_params(params: Dictionary) -> Dictionary:
	if params.is_empty():
		return {}
	if is_network_format(params):
		return unpack_from_network(params)
	return params.duplicate(true)


static func is_network_format(params: Dictionary) -> bool:
	var effect_id := str(params.get(KEY_EFFECT_ID, ""))
	if effect_id == EFFECT_FIREBALL and SpellEphemeralFxScript.is_ray_wire(params):
		return true
	if effect_id == EFFECT_LIGHT_BALL and params.has("origin_x") and not params.has(KEY_ORIGIN):
		return true
	if (
		(
			effect_id == EFFECT_PULL
			or effect_id == EFFECT_FOLLOW
			or effect_id == EFFECT_TARGET
			or effect_id == EFFECT_DISPELL
		)
		and params.has("origin_x")
		and not params.has(KEY_ORIGIN)
	):
		return true
	if (
		effect_id == EFFECT_FAKE_WALL
		and params.has("origin_x")
		and not params.has(KEY_ORIGIN)
	):
		return true
	return false


static func resolve_network_params(
	spell: SpellDefinition,
	player: CharacterBody3D,
	wire_or_local: Dictionary
) -> Dictionary:
	var params := normalize_params(wire_or_local)
	if spell == null or params.is_empty():
		return {}
	if str(params.get(KEY_EFFECT_ID, "")) != spell.effect_id:
		params[KEY_EFFECT_ID] = spell.effect_id
	if spell.effect_id == EFFECT_DISPELL and player != null:
		## Require an active Target outline; refill destroy id if the wire omitted it.
		if not TargetHighlightScript.has_active_highlights(player.get_tree()):
			return {}
		var has_wall := int(params.get(KEY_GRID_X, -1)) >= 0
		var has_kind := not str(params.get(KEY_TARGET_KIND, "")).is_empty()
		if not has_wall and not has_kind:
			_append_dispell_target(params, player)
	if spell.effect_id != EFFECT_FIREBALL:
		return params
	if not is_valid_fireball_params(params):
		if player == null:
			return {}
		return build_params(spell, player)
	if player != null and not _fireball_origin_plausible(params, player):
		return build_params(spell, player)
	return params


static func is_valid_fireball_params(params: Dictionary) -> bool:
	if str(params.get(KEY_EFFECT_ID, "")) != EFFECT_FIREBALL:
		return false
	var direction := coerce_vector3(params.get(KEY_DIRECTION, Vector3.ZERO))
	return direction.length_squared() > 0.01


static func coerce_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Dictionary:
		return Vector3(
			float(value.get("x", 0.0)),
			float(value.get("y", 0.0)),
			float(value.get("z", 0.0))
		)
	return Vector3.ZERO


static func apply(player: CharacterBody3D, params: Dictionary) -> void:
	if player == null or params.is_empty():
		return
	match str(params.get(KEY_EFFECT_ID, "")):
		EFFECT_HASTE:
			player.apply_speed_boost(
				float(params.get(KEY_DURATION, DEFAULT_HASTE_DURATION)),
				float(params.get(KEY_MULTIPLIER, DEFAULT_HASTE_MULTIPLIER))
			)
		EFFECT_LIGHT:
			_reveal_trails(float(params.get(KEY_DURATION, DEFAULT_LIGHT_DURATION)))
		EFFECT_FIREBALL:
			_apply_fireball(player, params)
		EFFECT_FLASHLIGHT_TOGGLE:
			_toggle_flashlight(player)
		EFFECT_LIGHT_BALL:
			_apply_light_ball(player, params)
		EFFECT_TARGET:
			_apply_target(player, params)
		EFFECT_PULL:
			_apply_pull(player, params)
		EFFECT_FOLLOW:
			_apply_follow(player, params)
		EFFECT_DISPELL:
			_apply_dispell(player, params)
		EFFECT_FAKE_WALL:
			_apply_fake_wall(player, params)
		_:
			push_warning(
				"SpellEffectSync: unknown effect '%s'" % str(params.get(KEY_EFFECT_ID, ""))
			)



static func _reveal_trails(duration_sec: float) -> void:
	var tree := Engine.get_main_loop()
	if tree == null:
		return
	var registry: Node = tree.root.get_node_or_null("TrailRegistry")
	if registry != null and registry.has_method("reveal_trails"):
		registry.reveal_trails(duration_sec)


static func _apply_target(player: CharacterBody3D, params: Dictionary) -> void:
	if player == null or not player.is_inside_tree():
		return
	var duration := float(params.get(KEY_DURATION, DEFAULT_TARGET_DURATION))
	var target := _resolve_targeted_object(player, params, false)
	if target == null:
		target = TargetedObjectControlScript.pick_targetable(player)
	if target == null:
		return
	TargetHighlightScript.apply_single(player.get_tree(), target, duration)


static func _apply_pull(player: CharacterBody3D, params: Dictionary) -> void:
	var target := _resolve_targeted_object(player, params, true)
	if target == null:
		return
	TargetedObjectControlScript.pull_object(player, target)


static func _apply_follow(player: CharacterBody3D, params: Dictionary) -> void:
	var target := _resolve_targeted_object(player, params, false)
	if target == null:
		return
	TargetedObjectControlScript.start_follow(player, target)


static func _apply_dispell(player: CharacterBody3D, params: Dictionary) -> void:
	var scene_tree: SceneTree = null
	if player != null and player.is_inside_tree():
		scene_tree = player.get_tree()
	else:
		var loop := Engine.get_main_loop()
		if loop is SceneTree:
			scene_tree = loop as SceneTree
	if scene_tree == null:
		return
	var mark := coerce_vector3(params.get(KEY_ORIGIN, Vector3.ZERO))
	var kind := str(params.get(KEY_TARGET_KIND, ""))
	var object_id := str(params.get(KEY_SPAWN_ID, ""))
	var cell := Vector2i(int(params.get(KEY_GRID_X, -1)), int(params.get(KEY_GRID_Y, -1)))
	if object_id.is_empty() and cell.x >= 0:
		object_id = SpellWorldSyncScript.make_cell_id(cell)
		if kind.is_empty():
			kind = SpellWorldSyncScript.KIND_FAKE_WALL
	var destroyed := false
	if not kind.is_empty() or not object_id.is_empty():
		var resolved := SpellWorldSyncScript.resolve(scene_tree, kind, object_id, mark)
		if resolved != null and resolved.has_method("destroy_from_spell"):
			resolved.call("destroy_from_spell", true)
			destroyed = true
	if not destroyed:
		## Fallback when the cast wire has no target: remove highlighted
		## dispellable objects and broadcast so peers still clear them.
		_dispell_highlighted_objects(scene_tree)
	TargetedObjectControlScript.stop_all(scene_tree)


static func _dispell_highlighted_objects(tree: SceneTree) -> void:
	if tree == null:
		return
	for anchor in TargetHighlightScript.get_highlighted_anchors(tree):
		if anchor == null:
			continue
		if (
			anchor.is_in_group(SpellWorldSyncScript.KIND_FAKE_WALL)
			or anchor.is_in_group(SpellWorldSyncScript.KIND_LIGHT_BALL)
		):
			if anchor.has_method("destroy_from_spell"):
				anchor.call("destroy_from_spell", false)


static func _resolve_targeted_object(
	player: CharacterBody3D,
	params: Dictionary,
	require_los: bool = false
) -> Node3D:
	if player == null or not player.is_inside_tree():
		return null
	var kind := str(params.get(KEY_TARGET_KIND, ""))
	if kind.is_empty():
		return TargetedObjectControlScript.pick_looked_at(player, require_los)
	var mark := coerce_vector3(params.get(KEY_ORIGIN, Vector3.ZERO))
	var resolved := TargetedObjectControlScript.resolve_target(
		player.get_tree(), kind, mark
	)
	if (
		require_los
		and resolved != null
		and not TargetedObjectControlScript.has_clear_line_of_sight(player, resolved)
	):
		return null
	return resolved


static func is_supported_effect(effect_id: String) -> bool:
	return SpellSyncLaneScript.is_known(effect_id)


static func sync_lane_for(effect_id: String) -> String:
	return SpellSyncLaneScript.for_effect(effect_id)


static func _fireball_direction(player: CharacterBody3D) -> Vector3:
	if player.has_method("get_wand_cast_direction"):
		return player.call("get_wand_cast_direction")
	var camera_pivot: Node3D = player.get_node_or_null("Head/CameraPivot")
	if camera_pivot != null:
		var basis := camera_pivot.global_transform.basis if camera_pivot.is_inside_tree() \
			else camera_pivot.transform.basis
		return (-basis.z).normalized()
	return -player.transform.basis.z.normalized()


static func _fireball_origin(player: CharacterBody3D) -> Vector3:
	if player.has_method("get_wand_cast_origin"):
		return player.call("get_wand_cast_origin")
	var head: Node3D = player.get_node_or_null("Head")
	var forward := _fireball_direction(player)
	if head != null:
		var head_origin := head.global_position if head.is_inside_tree() else head.position
		return head_origin + forward * 0.6 + Vector3(0.0, 0.1, 0.0)
	var player_origin := player.global_position if player.is_inside_tree() else player.position
	return player_origin + forward * 0.6 + Vector3(0.0, 0.1, 0.0)


static func _apply_fireball(player: CharacterBody3D, params: Dictionary) -> void:
	var origin := coerce_vector3(params.get(KEY_ORIGIN, Vector3.ZERO))
	var direction := coerce_vector3(params.get(KEY_DIRECTION, Vector3.FORWARD))
	SpellEphemeralFxScript.spawn_at(
		player,
		origin,
		direction,
		Callable(FireballProjectileScript, "spawn")
	)


static func _apply_fake_wall(player: CharacterBody3D, params: Dictionary) -> void:
	if player == null or not player.is_inside_tree():
		return
	var cell := Vector2i(int(params.get(KEY_GRID_X, -1)), int(params.get(KEY_GRID_Y, -1)))
	if cell.x < 0 or cell.y < 0:
		return
	var cell_id := SpellWorldSyncScript.make_cell_id(cell)
	if SpellWorldSyncScript.find(
		player.get_tree(), SpellWorldSyncScript.KIND_FAKE_WALL, cell_id
	) != null:
		return
	var origin := coerce_vector3(params.get(KEY_ORIGIN, Vector3.ZERO))
	var size := coerce_vector3(params.get(KEY_SIZE, Vector3(3.0, 3.0, 3.0)))
	if size.length_squared() < 0.01:
		size = Vector3(3.0, 3.0, 3.0)
	var world: Node = GameWorldScript.find_match_root(player.get_tree())
	if world == null:
		world = player.get_parent()
	if world == null:
		return
	var bucket := SpellWorldSyncScript.ensure_bucket(
		world, SpellWorldSyncScript.BUCKET_FAKE_WALLS
	)
	FakeWallScript.spawn(bucket, origin, size, cell)


static func _toggle_flashlight(player: CharacterBody3D) -> void:
	if player.has_method("toggle_flashlight"):
		player.call("toggle_flashlight")
		return
	if not player.has_method("set_flashlight_enabled"):
		return
	var active := false
	if player.has_method("is_flashlight_enabled"):
		active = bool(player.call("is_flashlight_enabled"))
	player.call("set_flashlight_enabled", not active)


static func _light_ball_origin(player: CharacterBody3D) -> Vector3:
	return LightBallOrbScript.resolve_placement(player)


static func _apply_light_ball(player: CharacterBody3D, params: Dictionary) -> void:
	var target := coerce_vector3(params.get(KEY_ORIGIN, Vector3.ZERO))
	if target == Vector3.ZERO:
		target = _light_ball_origin(player)
	var wand_origin := coerce_vector3(params.get(KEY_WAND_ORIGIN, Vector3.ZERO))
	if wand_origin == Vector3.ZERO:
		wand_origin = _fireball_origin(player)
	var world: Node = null
	if player.is_inside_tree():
		world = GameWorldScript.find_match_root(player.get_tree())
	if world == null:
		world = player.get_parent()
	if world == null:
		return
	var bucket := SpellWorldSyncScript.ensure_bucket(
		world, SpellWorldSyncScript.BUCKET_LIGHT_BALLS
	)
	var orb_spawn_id := str(params.get(KEY_SPAWN_ID, ""))
	if orb_spawn_id.is_empty():
		orb_spawn_id = SpellWorldSyncScript.make_spawn_id(player)
	LightBallOrbScript.spawn_cast(
		bucket,
		wand_origin,
		target,
		float(params.get(KEY_DURATION, DEFAULT_LIGHT_BALL_DURATION)),
		orb_spawn_id
	)


static func _fireball_origin_plausible(params: Dictionary, player: CharacterBody3D) -> bool:
	var origin := coerce_vector3(params.get(KEY_ORIGIN, Vector3.ZERO))
	return player.global_position.distance_squared_to(origin) <= 9.0
