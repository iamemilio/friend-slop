class_name TestSpellEffectSync
extends RefCounted

const SyncScript := preload("res://scripts/spells/spell_effect_sync.gd")
const FireballProjectileScript := preload("res://scripts/spells/fireball_projectile.gd")
const FireballSpell := preload("res://resources/spells/fireball.tres")
const HasteSpell := preload("res://resources/spells/haste.tres")
const ShowMeSpell := preload("res://resources/spells/show_me.tres")
const LightSpell := preload("res://resources/spells/light.tres")
const LightBallSpell := preload("res://resources/spells/light_ball.tres")


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
	failures += _test_fireball_network_round_trip()
	failures += _test_fireball_wire_params_spawn_projectile()
	failures += _test_apply_flashlight_toggle()
	failures += _test_build_light_ball_params()
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
	var player := _make_tracking_player()
	var params := {
		SyncScript.KEY_EFFECT_ID: SyncScript.EFFECT_LIGHT,
		SyncScript.KEY_DURATION: 4.0,
	}
	SyncScript.apply(player, params)
	player.queue_free()
	return 0


func _make_player_stub() -> CharacterBody3D:
	return _make_tracking_player()


func _test_all_spells_are_supported() -> int:
	for spell in [FireballSpell, HasteSpell, ShowMeSpell, LightSpell, LightBallSpell]:
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
	var params := SyncScript.build_params(ShowMeSpell, player)
	player.queue_free()
	if str(params.get(SyncScript.KEY_EFFECT_ID, "")) != SyncScript.EFFECT_LIGHT:
		push_error("Expected light effect id in params")
		return 1
	if float(params.get(SyncScript.KEY_DURATION, 0.0)) != SyncScript.DEFAULT_LIGHT_DURATION:
		push_error("Expected show_me light duration to match DEFAULT_LIGHT_DURATION")
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
		if child.get_script() == FireballProjectileScript:
			projectile_count += 1

	player.queue_free()
	root.queue_free()
	tree.free()

	if projectile_count != 1:
		push_error("Expected synced fireball params to spawn one projectile")
		return 1
	return 0


func _test_fireball_network_round_trip() -> int:
	var params := {
		SyncScript.KEY_EFFECT_ID: SyncScript.EFFECT_FIREBALL,
		SyncScript.KEY_ORIGIN: Vector3(1.0, 2.0, 3.0),
		SyncScript.KEY_DIRECTION: Vector3(0.0, 0.5, -1.0),
	}
	var wire := SyncScript.pack_for_network(params)
	var restored := SyncScript.unpack_from_network(wire)
	var origin: Vector3 = restored.get(SyncScript.KEY_ORIGIN, Vector3.ZERO)
	var direction: Vector3 = restored.get(SyncScript.KEY_DIRECTION, Vector3.ZERO)
	if not origin.is_equal_approx(Vector3(1.0, 2.0, 3.0)):
		push_error("Expected fireball origin to round-trip through network params")
		return 1
	if not direction.is_equal_approx(Vector3(0.0, 0.5, -1.0).normalized()):
		push_error("Expected fireball direction to round-trip through network params")
		return 1
	return 0


func _test_fireball_wire_params_spawn_projectile() -> int:
	var tree := SceneTree.new()
	var root := Node3D.new()
	tree.root.add_child(root)

	var player := _make_player_stub()
	root.add_child(player)

	var wire := SyncScript.pack_for_network({
		SyncScript.KEY_EFFECT_ID: SyncScript.EFFECT_FIREBALL,
		SyncScript.KEY_ORIGIN: Vector3(4.0, 5.0, 6.0),
		SyncScript.KEY_DIRECTION: Vector3(1.0, 0.0, 0.0),
	})
	SyncScript.apply(player, SyncScript.resolve_network_params(FireballSpell, player, wire))

	var projectile_count := 0
	for child in root.get_children():
		if child.get_script() == FireballProjectileScript:
			projectile_count += 1

	player.queue_free()
	root.queue_free()
	tree.free()

	if projectile_count != 1:
		push_error("Expected wire-format fireball params to spawn one projectile")
		return 1
	return 0


func _test_apply_flashlight_toggle() -> int:
	var player := _make_tracking_player()
	SyncScript.apply(player, {SyncScript.KEY_EFFECT_ID: SyncScript.EFFECT_FLASHLIGHT_TOGGLE})
	if player.toggle_calls != 1 or not player.flashlight_on:
		player.queue_free()
		push_error("Expected flashlight_toggle to turn wand beam on")
		return 1
	SyncScript.apply(player, {SyncScript.KEY_EFFECT_ID: SyncScript.EFFECT_FLASHLIGHT_TOGGLE})
	if player.toggle_calls != 2 or player.flashlight_on:
		player.queue_free()
		push_error("Expected second flashlight_toggle to turn wand beam off")
		return 1
	var params := SyncScript.build_params(LightSpell, player)
	player.queue_free()
	if str(params.get(SyncScript.KEY_EFFECT_ID, "")) != SyncScript.EFFECT_FLASHLIGHT_TOGGLE:
		push_error("Expected light to build flashlight_toggle params")
		return 1
	return 0


func _test_build_light_ball_params() -> int:
	var player := _make_player_stub()
	var params := SyncScript.build_params(LightBallSpell, player)
	player.queue_free()
	if str(params.get(SyncScript.KEY_EFFECT_ID, "")) != SyncScript.EFFECT_LIGHT_BALL:
		push_error("Expected light_ball effect id in params")
		return 1
	if not params.has(SyncScript.KEY_ORIGIN):
		push_error("Expected light_ball origin in params")
		return 1
	if not params.has(SyncScript.KEY_WAND_ORIGIN):
		push_error("Expected light_ball wand_origin in params")
		return 1
	if float(params.get(SyncScript.KEY_DURATION, 0.0)) != SyncScript.DEFAULT_LIGHT_BALL_DURATION:
		push_error("Expected light_ball duration to be 30 seconds")
		return 1
	return 0


class _EffectTrackingPlayer extends CharacterBody3D:
	var speed_boost_calls: Array[Dictionary] = []
	var toggle_calls := 0
	var flashlight_on := false


	func apply_speed_boost(duration: float, multiplier: float) -> void:
		speed_boost_calls.append({
			"duration": duration,
			"multiplier": multiplier,
		})


	func is_flashlight_enabled() -> bool:
		return flashlight_on


	func set_flashlight_enabled(active: bool) -> void:
		flashlight_on = active


	func toggle_flashlight() -> void:
		toggle_calls += 1
		flashlight_on = not flashlight_on
