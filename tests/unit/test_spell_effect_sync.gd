class_name TestSpellEffectSync
extends RefCounted

const SyncScript := preload("res://scripts/spells/spell_effect_sync.gd")
const FireballSpell := preload("res://resources/spells/fireball.tres")
const HasteSpell := preload("res://resources/spells/haste.tres")
const LumosSpell := preload("res://resources/spells/lumos.tres")


func run() -> int:
	var failures := 0
	failures += _test_all_spells_are_supported()
	failures += _test_build_fireball_params()
	failures += _test_build_haste_params()
	failures += _test_build_light_params()
	failures += _test_unsupported_spell_returns_empty_params()
	failures += _test_apply_haste_from_wire_params()
	failures += _test_apply_light_from_wire_params()
	failures += _test_fireball_params_spawn_projectile()
	return failures


func _make_tracking_player() -> _EffectTrackingPlayer:
	var player := _EffectTrackingPlayer.new()
	var head := Node3D.new()
	head.name = "Head"
	var pivot := Node3D.new()
	pivot.name = "CameraPivot"
	head.add_child(pivot)
	player.add_child(head)
	player.global_transform = Transform3D(Basis.IDENTITY, Vector3(1.0, 2.0, 3.0))
	pivot.global_transform = Transform3D(Basis.IDENTITY, Vector3(1.0, 2.5, 4.0))
	return player


func _test_unsupported_spell_returns_empty_params() -> int:
	var player := _make_player_stub()
	var unknown := SpellDefinition.new()
	unknown.id = "debug"
	unknown.effect_id = "teleport"
	var params := SyncScript.build_params(unknown, player)
	player.queue_free()
	if not params.is_empty():
		push_error("Expected unsupported spell to produce empty sync params")
		return 1
	return 0


func _test_apply_haste_from_wire_params() -> int:
	var player := _make_tracking_player()
	var params := {
		SyncScript.KEY_EFFECT_ID: SyncScript.EFFECT_HASTE,
		SyncScript.KEY_DURATION: 5.0,
		SyncScript.KEY_MULTIPLIER: 1.8,
	}
	SyncScript.apply(player, params)
	player.queue_free()
	if player.speed_boost_calls.size() != 1:
		push_error("Expected synced haste params to apply speed boost")
		return 1
	return 0


func _test_apply_light_from_wire_params() -> int:
	var tree := SceneTree.new()
	var root := Node3D.new()
	tree.root.add_child(root)
	var player := _make_tracking_player()
	root.add_child(player)
	var params := {
		SyncScript.KEY_EFFECT_ID: SyncScript.EFFECT_LIGHT,
		SyncScript.KEY_DURATION: 4.0,
	}
	SyncScript.apply(player, params)
	player.queue_free()
	root.queue_free()
	tree.free()
	if player.light_pulse_calls.size() != 1:
		push_error("Expected synced light params to pulse light")
		return 1
	return 0


func _make_player_stub() -> CharacterBody3D:
	return _make_tracking_player()


func _test_all_spells_are_supported() -> int:
	for spell in [FireballSpell, HasteSpell, LumosSpell]:
		if not SyncScript.is_supported_effect(spell.effect_id):
			push_error("Expected effect '%s' to be supported for sync" % spell.effect_id)
			return 1
	return 0


func _test_build_fireball_params() -> int:
	var tree := SceneTree.new()
	var root := Node3D.new()
	tree.root.add_child(root)
	var player := _make_player_stub()
	root.add_child(player)
	var params := SyncScript.build_params(FireballSpell, player)
	player.queue_free()
	root.queue_free()
	tree.free()
	if str(params.get(SyncScript.KEY_EFFECT_ID, "")) != SyncScript.EFFECT_FIREBALL:
		push_error("Expected fireball effect id in params")
		return 1
	if not params.has(SyncScript.KEY_ORIGIN) or not params.has(SyncScript.KEY_DIRECTION):
		push_error("Expected fireball origin and direction in params")
		return 1
	return 0


func _test_build_haste_params() -> int:
	var player := _make_player_stub()
	var params := SyncScript.build_params(HasteSpell, player)
	player.queue_free()
	if str(params.get(SyncScript.KEY_EFFECT_ID, "")) != SyncScript.EFFECT_HASTE:
		push_error("Expected haste effect id in params")
		return 1
	if float(params.get(SyncScript.KEY_DURATION, 0.0)) <= 0.0:
		push_error("Expected haste duration in params")
		return 1
	return 0


func _test_build_light_params() -> int:
	var player := _make_player_stub()
	var params := SyncScript.build_params(LumosSpell, player)
	player.queue_free()
	if str(params.get(SyncScript.KEY_EFFECT_ID, "")) != SyncScript.EFFECT_LIGHT:
		push_error("Expected light effect id in params")
		return 1
	if float(params.get(SyncScript.KEY_DURATION, 0.0)) <= 0.0:
		push_error("Expected light duration in params")
		return 1
	return 0


func _test_fireball_params_spawn_projectile() -> int:
	var tree := SceneTree.new()
	var root := Node3D.new()
	tree.root.add_child(root)

	var player := _make_player_stub()
	root.add_child(player)

	var params := {
		SyncScript.KEY_EFFECT_ID: SyncScript.EFFECT_FIREBALL,
		SyncScript.KEY_ORIGIN: Vector3(1.0, 2.0, 3.0),
		SyncScript.KEY_DIRECTION: Vector3(0.0, 0.0, -1.0),
	}
	SyncScript.apply(player, params)

	var projectile_count := 0
	for child in root.get_children():
		if child.get_script() == load("res://scripts/spells/fireball_projectile.gd"):
			projectile_count += 1

	player.queue_free()
	root.queue_free()
	tree.free()

	if projectile_count != 1:
		push_error("Expected synced fireball params to spawn one projectile")
		return 1
	return 0


class _EffectTrackingPlayer extends CharacterBody3D:
	var speed_boost_calls: Array[Dictionary] = []
	var light_pulse_calls: Array[float] = []


	func apply_speed_boost(duration: float, multiplier: float) -> void:
		speed_boost_calls.append({
			"duration": duration,
			"multiplier": multiplier,
		})


	func apply_light_pulse(duration: float) -> void:
		light_pulse_calls.append(duration)
