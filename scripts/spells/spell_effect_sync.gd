class_name SpellEffectSync
extends RefCounted

## Generic spell effect params for solo play and multiplayer RPC payloads.

const FireballProjectileScript := preload("res://scripts/spells/fireball_projectile.gd")

const KEY_EFFECT_ID := "effect_id"
const KEY_ORIGIN := "origin"
const KEY_DIRECTION := "direction"
const KEY_DURATION := "duration"
const KEY_MULTIPLIER := "multiplier"

const EFFECT_HASTE := "haste"
const EFFECT_LIGHT := "light"
const EFFECT_FIREBALL := "fireball"

const DEFAULT_LIGHT_DURATION := 20.0
const DEFAULT_HASTE_DURATION := 4.0
const DEFAULT_HASTE_MULTIPLIER := 1.65
const DEFAULT_FIREBALL_CAST_DURATION := 0.0


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
		_:
			return {}
	return params


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
			player.apply_light_pulse(float(params.get(KEY_DURATION, DEFAULT_LIGHT_DURATION)))
			TrailRegistry.reveal_trails(float(params.get(KEY_DURATION, DEFAULT_LIGHT_DURATION)))
		EFFECT_FIREBALL:
			_apply_fireball(player, params)
		_:
			push_warning(
				"SpellEffectSync: unknown effect '%s'" % str(params.get(KEY_EFFECT_ID, ""))
			)


static func is_supported_effect(effect_id: String) -> bool:
	return effect_id in [EFFECT_HASTE, EFFECT_LIGHT, EFFECT_FIREBALL]


static func _fireball_direction(player: CharacterBody3D) -> Vector3:
	if player.has_method("get_wand_cast_direction"):
		return player.call("get_wand_cast_direction")
	var camera_pivot: Node3D = player.get_node_or_null("Head/CameraPivot")
	if camera_pivot != null:
		var basis := camera_pivot.global_transform.basis if camera_pivot.is_inside_tree() \
			else camera_pivot.transform.basis
		var forward := -basis.z.normalized()
		forward.y = clampf(forward.y, -0.25, 0.25)
		return forward.normalized()
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
	var origin: Vector3 = params.get(KEY_ORIGIN, Vector3.ZERO)
	var direction: Vector3 = params.get(KEY_DIRECTION, Vector3.FORWARD)
	if player.has_method("launch_fireball_from_params"):
		player.launch_fireball_from_params(origin, direction)
		return
	var world: Node = player.get_tree().current_scene if player.is_inside_tree() else null
	if world == null:
		world = player.get_parent()
	if world == null:
		return
	FireballProjectileScript.spawn(world, origin, direction)
