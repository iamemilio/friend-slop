class_name TestSpellEffectApplier
extends RefCounted

const ApplierScript := preload("res://scripts/spells/spell_effect_applier.gd")
const SyncScript := preload("res://scripts/spells/spell_effect_sync.gd")
const FireballSpell := preload("res://resources/spells/fireball.tres")
const HasteSpell := preload("res://resources/spells/haste.tres")
const LumosSpell := preload("res://resources/spells/lumos.tres")


func run(tree: SceneTree) -> int:
	var failures := 0
	failures += _test_solo_cast_applies_haste(tree)
	failures += _test_apply_synced_cast_uses_wire_params(tree)
	failures += _test_apply_synced_cast_rebuilds_empty_params(tree)
	failures += _test_apply_synced_spell_cast_on_peer_all_spells(tree)
	failures += _test_apply_synced_spell_cast_on_peer_rejects_missing_player(tree)
	failures += _test_apply_synced_spell_cast_on_peer_rejects_unknown_spell(tree)
	return failures


func _make_registry() -> SpellRegistry:
	var registry := SpellRegistry.new()
	registry.spells = [FireballSpell, HasteSpell, LumosSpell]
	return registry


func _make_tracking_player() -> _EffectTrackingPlayer:
	return _EffectTrackingPlayer.new()


func _attach_applier(player: CharacterBody3D, tree: SceneTree) -> SpellEffectApplier:
	var applier := ApplierScript.new()
	player.add_child(applier)
	tree.root.add_child(player)
	return applier


func _test_solo_cast_applies_haste(tree: SceneTree) -> int:
	var prev_multiplayer := GameState.is_multiplayer
	GameState.is_multiplayer = false

	var player := _make_tracking_player()
	var applier := _attach_applier(player, tree)
	applier.cast_spell(player, HasteSpell)

	GameState.is_multiplayer = prev_multiplayer
	player.queue_free()

	if player.speed_boost_calls.size() != 1:
		push_error("Expected solo cast_spell to apply haste locally")
		return 1
	var call: Dictionary = player.speed_boost_calls[0]
	if float(call.get("duration", 0.0)) <= 0.0 or float(call.get("multiplier", 0.0)) <= 1.0:
		push_error("Expected solo haste cast to pass duration and multiplier")
		return 1
	return 0


func _test_apply_synced_cast_uses_wire_params(tree: SceneTree) -> int:
	var player := _make_tracking_player()
	var applier := _attach_applier(player, tree)
	var wire_params := {
		SyncScript.KEY_EFFECT_ID: SyncScript.EFFECT_HASTE,
		SyncScript.KEY_DURATION: 9.0,
		SyncScript.KEY_MULTIPLIER: 2.5,
	}
	applier.apply_synced_cast(player, HasteSpell, wire_params)
	player.queue_free()

	if player.speed_boost_calls.size() != 1:
		push_error("Expected apply_synced_cast to apply wire params")
		return 1
	var call: Dictionary = player.speed_boost_calls[0]
	if not is_equal_approx(float(call.get("duration", 0.0)), 9.0):
		push_error("Expected synced haste to honor wire duration")
		return 1
	if not is_equal_approx(float(call.get("multiplier", 0.0)), 2.5):
		push_error("Expected synced haste to honor wire multiplier")
		return 1
	return 0


func _test_apply_synced_cast_rebuilds_empty_params(tree: SceneTree) -> int:
	var player := _make_tracking_player()
	var applier := _attach_applier(player, tree)
	applier.apply_synced_cast(player, LumosSpell, {})
	player.queue_free()

	if player.light_pulse_calls.size() != 1:
		push_error("Expected apply_synced_cast to rebuild lumos params when empty")
		return 1
	if float(player.light_pulse_calls[0]) <= 0.0:
		push_error("Expected rebuilt lumos params to include duration")
		return 1
	return 0


func _test_apply_synced_spell_cast_on_peer_all_spells(tree: SceneTree) -> int:
	var registry := _make_registry()
	var players_root := Node3D.new()
	tree.root.add_child(players_root)
	var peer_ids := {
		FireballSpell.id: 11,
		HasteSpell.id: 12,
		LumosSpell.id: 13,
	}

	for spell in [FireballSpell, HasteSpell, LumosSpell]:
		var peer_id: int = peer_ids[spell.id]
		var player := _make_tracking_player()
		player.name = str(peer_id)
		var applier := ApplierScript.new()
		player.add_child(applier)
		players_root.add_child(player)

		var params := SyncScript.build_params(spell, player)
		var applied := ApplierScript.apply_synced_spell_cast_on_peer(
			players_root,
			registry,
			peer_id,
			spell.id,
			params
		)
		if not applied:
			push_error("Expected synced cast to apply spell '%s'" % spell.id)
			players_root.queue_free()
			return 1

		match spell.effect_id:
			SyncScript.EFFECT_FIREBALL:
				if player.fireball_calls.size() != 1:
					push_error("Expected synced fireball cast to launch projectile")
					players_root.queue_free()
					return 1
			SyncScript.EFFECT_HASTE:
				if player.speed_boost_calls.size() != 1:
					push_error("Expected synced haste cast to boost speed")
					players_root.queue_free()
					return 1
			SyncScript.EFFECT_LIGHT:
				if player.light_pulse_calls.size() != 1:
					push_error("Expected synced lumos cast to pulse light")
					players_root.queue_free()
					return 1

	players_root.queue_free()
	return 0


func _test_apply_synced_spell_cast_on_peer_rejects_missing_player(tree: SceneTree) -> int:
	var registry := _make_registry()
	var players_root := Node3D.new()
	tree.root.add_child(players_root)

	var applied := ApplierScript.apply_synced_spell_cast_on_peer(
		players_root,
		registry,
		404,
		"haste",
		{SyncScript.KEY_EFFECT_ID: SyncScript.EFFECT_HASTE}
	)
	players_root.queue_free()

	if applied:
		push_error("Expected synced cast to fail when caster player is missing")
		return 1
	return 0


func _test_apply_synced_spell_cast_on_peer_rejects_unknown_spell(tree: SceneTree) -> int:
	var registry := _make_registry()
	var players_root := Node3D.new()
	tree.root.add_child(players_root)
	var player := _make_tracking_player()
	player.name = "5"
	var applier := ApplierScript.new()
	player.add_child(applier)
	players_root.add_child(player)

	var applied := ApplierScript.apply_synced_spell_cast_on_peer(
		players_root,
		registry,
		5,
		"unknown_spell",
		{SyncScript.KEY_EFFECT_ID: SyncScript.EFFECT_HASTE}
	)
	players_root.queue_free()

	if applied:
		push_error("Expected synced cast to fail for unknown spell id")
		return 1
	return 0


class _EffectTrackingPlayer extends CharacterBody3D:
	var speed_boost_calls: Array[Dictionary] = []
	var light_pulse_calls: Array[float] = []
	var fireball_calls: Array[Dictionary] = []


	func apply_speed_boost(duration: float, multiplier: float) -> void:
		speed_boost_calls.append({
			"duration": duration,
			"multiplier": multiplier,
		})


	func apply_light_pulse(duration: float) -> void:
		light_pulse_calls.append(duration)


	func launch_fireball_from_params(origin: Vector3, direction: Vector3) -> void:
		fireball_calls.append({
			"origin": origin,
			"direction": direction,
		})
