class_name SpellEffectSync
extends RefCounted

## Generic spell effect params for solo play and multiplayer RPC payloads.

const FireballProjectileScript := preload("res://scripts/spells/fireball_projectile.gd")
const LightBallOrbScript := preload("res://scripts/spells/light_ball_orb.gd")

const KEY_EFFECT_ID := "effect_id"
const KEY_ORIGIN := "origin"
const KEY_WAND_ORIGIN := "wand_origin"
const KEY_DIRECTION := "direction"
const KEY_DURATION := "duration"
const KEY_MULTIPLIER := "multiplier"

const EFFECT_HASTE := "haste"
const EFFECT_LIGHT := "light"
const EFFECT_FIREBALL := "fireball"
const EFFECT_FLASHLIGHT_TOGGLE := "flashlight_toggle"
const EFFECT_LIGHT_BALL := "light_ball"

const DEFAULT_LIGHT_DURATION := 20.0
const DEFAULT_HASTE_DURATION := 4.0
const DEFAULT_HASTE_MULTIPLIER := 1.65
const DEFAULT_FIREBALL_CAST_DURATION := 0.0
const DEFAULT_LIGHT_BALL_DURATION := 30.0


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
			return float(params.get(KEY_DURATION, DEFAULT_LIGHT_BALL_DURATION))
		EFFECT_FLASHLIGHT_TOGGLE:
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
		EFFECT_FLASHLIGHT_TOGGLE:
			pass
		_:
			return {}
	return params


static func pack_for_network(params: Dictionary) -> Dictionary:
	var local := normalize_params(params)
	if local.is_empty():
		return {}
	var wire := {KEY_EFFECT_ID: str(local.get(KEY_EFFECT_ID, ""))}
	match str(wire[KEY_EFFECT_ID]):
		EFFECT_FIREBALL:
			var origin := coerce_vector3(local.get(KEY_ORIGIN, Vector3.ZERO))
			var direction := coerce_vector3(local.get(KEY_DIRECTION, Vector3.FORWARD))
			wire["origin_x"] = origin.x
			wire["origin_y"] = origin.y
			wire["origin_z"] = origin.z
			wire["dir_x"] = direction.x
			wire["dir_y"] = direction.y
			wire["dir_z"] = direction.z
		EFFECT_HASTE:
			wire[KEY_DURATION] = float(local.get(KEY_DURATION, DEFAULT_HASTE_DURATION))
			wire[KEY_MULTIPLIER] = float(local.get(KEY_MULTIPLIER, DEFAULT_HASTE_MULTIPLIER))
		EFFECT_LIGHT:
			wire[KEY_DURATION] = float(local.get(KEY_DURATION, DEFAULT_LIGHT_DURATION))
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
		EFFECT_FLASHLIGHT_TOGGLE:
			pass
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
			params[KEY_ORIGIN] = Vector3(
				float(wire.get("origin_x", 0.0)),
				float(wire.get("origin_y", 0.0)),
				float(wire.get("origin_z", 0.0))
			)
			params[KEY_DIRECTION] = Vector3(
				float(wire.get("dir_x", 0.0)),
				float(wire.get("dir_y", 0.0)),
				float(wire.get("dir_z", 0.0))
			).normalized()
		EFFECT_HASTE:
			params[KEY_DURATION] = float(wire.get(KEY_DURATION, DEFAULT_HASTE_DURATION))
			params[KEY_MULTIPLIER] = float(wire.get(KEY_MULTIPLIER, DEFAULT_HASTE_MULTIPLIER))
		EFFECT_LIGHT:
			params[KEY_DURATION] = float(wire.get(KEY_DURATION, DEFAULT_LIGHT_DURATION))
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
		EFFECT_FLASHLIGHT_TOGGLE:
			pass
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
	if effect_id == EFFECT_FIREBALL and params.has("origin_x") and params.has("dir_x"):
		return true
	if effect_id == EFFECT_LIGHT_BALL and params.has("origin_x") and not params.has(KEY_ORIGIN):
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

static func is_supported_effect(effect_id: String) -> bool:
	return effect_id in [
		EFFECT_HASTE,
		EFFECT_LIGHT,
		EFFECT_FIREBALL,
		EFFECT_FLASHLIGHT_TOGGLE,
		EFFECT_LIGHT_BALL,
	]


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
	if direction.length_squared() <= 0.01:
		return
	var world: Node = player.get_tree().current_scene if player.is_inside_tree() else null
	if world == null:
		world = player.get_parent()
	if world == null:
		return
	FireballProjectileScript.spawn(world, origin, direction.normalized())


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
	var world: Node = player.get_tree().current_scene if player.is_inside_tree() else null
	if world == null:
		world = player.get_parent()
	if world == null:
		return
	LightBallOrbScript.spawn_cast(
		world,
		wand_origin,
		target,
		float(params.get(KEY_DURATION, DEFAULT_LIGHT_BALL_DURATION))
	)


static func _fireball_origin_plausible(params: Dictionary, player: CharacterBody3D) -> bool:
	var origin := coerce_vector3(params.get(KEY_ORIGIN, Vector3.ZERO))
	return player.global_position.distance_squared_to(origin) <= 9.0
