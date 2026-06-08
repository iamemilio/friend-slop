class_name TestSpellCastMultiplayer
extends RefCounted

const SyncScript := preload("res://scripts/spells/spell_effect_sync.gd")
const FireballSpell := preload("res://resources/spells/fireball.tres")


func run(tree: SceneTree) -> int:
	var failures := 0
	failures += _test_execute_spell_cast_forwards_to_main(tree)
	failures += _test_wire_params_are_dictionary_safe()
	return failures


func _test_execute_spell_cast_forwards_to_main(tree: SceneTree) -> int:
	var prev_scene := tree.current_scene
	var fake_main := _RecordingMain.new()
	tree.root.add_child(fake_main)
	tree.current_scene = fake_main

	var params := {
		SyncScript.KEY_EFFECT_ID: SyncScript.EFFECT_FIREBALL,
		SyncScript.KEY_ORIGIN: Vector3(1.0, 2.0, 3.0),
		SyncScript.KEY_DIRECTION: Vector3(0.0, 0.0, -1.0),
	}
	NetworkManager._execute_spell_cast(2, FireballSpell.id, params)

	fake_main.queue_free()
	tree.current_scene = prev_scene

	if fake_main.received_casts.size() != 1:
		push_error("Expected NetworkManager._execute_spell_cast to forward to main")
		return 1
	var received: Dictionary = fake_main.received_casts[0]
	if int(received.get("peer_id", -1)) != 2:
		push_error("Expected forwarded caster peer id to match RPC payload")
		return 1
	if str(received.get("spell_id", "")) != FireballSpell.id:
		push_error("Expected forwarded spell id to match RPC payload")
		return 1
	if str(received.get("params", {}).get(SyncScript.KEY_EFFECT_ID, "")) != SyncScript.EFFECT_FIREBALL:
		push_error("Expected forwarded params to include fireball effect id")
		return 1
	return 0


func _test_wire_params_are_dictionary_safe() -> int:
	var player := CharacterBody3D.new()
	var params := SyncScript.build_params(FireballSpell, player)
	player.free()

	for key in params.keys():
		var value: Variant = params[key]
		if value is Dictionary or value is Array:
			push_error("Expected wire params to stay flat, found nested value for '%s'" % key)
			return 1
		if value is Object and not (value is Vector3):
			push_error("Expected wire params to avoid Resource/Object values for '%s'" % key)
			return 1
	return 0


class _RecordingMain extends Node:
	var received_casts: Array[Dictionary] = []


	func apply_synced_spell_cast(
		caster_peer_id: int,
		spell_id: String,
		params: Dictionary
	) -> void:
		received_casts.append({
			"peer_id": caster_peer_id,
			"spell_id": spell_id,
			"params": params.duplicate(true),
		})
