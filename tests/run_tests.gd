extends SceneTree

## Headless test entry point.
## Run: godot --headless --path . --script res://tests/run_tests.gd
## Offline only — no live Steam client or Steamworks session required.

const TestEnvScript := preload("res://scripts/test/test_env.gd")

const TEST_SUITES: Array[String] = [
	"res://tests/unit/test_maze_carver.gd",
	"res://tests/unit/test_maze_wall_mesh.gd",
	"res://tests/unit/test_discoverable_spawn_plan.gd",
	"res://tests/unit/test_voice_spell_validator.gd",
	"res://tests/unit/test_incantation_matcher.gd",
	"res://tests/unit/test_spell_grammar_builder.gd",
	"res://tests/unit/test_spell_cast_validator.gd",
	"res://tests/unit/test_character_spell_loadout.gd",
	"res://tests/unit/test_gdvosk_adapter.gd",
	"res://tests/unit/test_spell_validation_codec.gd",
	"res://tests/unit/test_game_state.gd",
	"res://tests/unit/test_multiplayer_transport.gd",
	"res://tests/unit/test_steam_transport.gd",
	"res://tests/unit/test_network_manager.gd",
	"res://tests/unit/test_match_state.gd",
	"res://tests/unit/test_role_assignment.gd",
	"res://tests/unit/test_player_character_config.gd",
	"res://tests/unit/test_role_loadout.gd",
	"res://tests/unit/test_objective_placement.gd",
	"res://tests/unit/test_delivery_objective_state.gd",
	"res://tests/unit/test_delivery_objective_audio.gd",
	"res://tests/unit/test_delivery_objective_sync.gd",
	"res://tests/unit/test_input_prompt.gd",
	"res://tests/unit/test_moon.gd",
	"res://tests/unit/test_cloud_system.gd",
	"res://tests/unit/test_trail_registry.gd",
	"res://tests/unit/test_player_spawn_layout.gd",
	"res://tests/unit/test_spell_log.gd",
	"res://tests/unit/test_spell_effect_sync.gd",
	"res://tests/unit/test_guide_content.gd",
	"res://tests/unit/test_spell_codex.gd",
	"res://tests/unit/test_voice_capture_worker.gd",
	"res://tests/unit/test_gdvosk_extension_config.gd",
	"res://tests/unit/test_spell_stt_config.gd",
	"res://tests/integration/test_gdvosk_runtime.gd",
]

const TREE_TEST_SUITES: Array[String] = [
	"res://tests/unit/test_spell_validation_runner.gd",
	"res://tests/unit/test_spell_validation_async.gd",
	"res://tests/unit/test_spell_pipeline.gd",
	"res://tests/unit/test_fireball_sky_flare.gd",
	"res://tests/unit/test_fireball_flight.gd",
	"res://tests/integration/test_spell_casting_session.gd",
	"res://tests/unit/test_playable_character_wand.gd",
]


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	await process_frame
	var multiplayer_api := root.get_multiplayer()
	if multiplayer_api.multiplayer_peer == null:
		multiplayer_api.multiplayer_peer = OfflineMultiplayerPeer.new()
	print("Running FriendSlop unit tests (offline — no Steam required)...")
	if not _assert_steam_offline():
		_finish(1)
		return
	if not _assert_autoloads_ready():
		_finish(1)
		return

	var failures := 0
	for path in TEST_SUITES:
		failures += _run_suite(path)
	for path in TREE_TEST_SUITES:
		failures += _run_suite(path, true)

	if failures == 0:
		print("All tests passed.")
		_finish(0)
	else:
		push_error("%d test(s) failed." % failures)
		_finish(1)


func _run_suite(path: String, needs_tree: bool = false) -> int:
	var script: GDScript = load(path) as GDScript
	if script == null:
		push_error("Failed to load test suite: %s" % path)
		return 1
	var suite: Object = script.new()
	if not suite.has_method("run"):
		push_error("Test suite missing run(): %s" % path)
		return 1
	if needs_tree:
		return suite.call("run", self)
	return suite.call("run")


func _assert_autoloads_ready() -> bool:
	if get_root().get_node_or_null("GameState") == null:
		push_error(
			"Autoloads are not ready. Close other Godot instances for this project "
			+ "and re-run tests."
		)
		return false
	return true


func _finish(exit_code: int) -> void:
	_prepare_exit()
	quit(exit_code)


func _prepare_exit() -> void:
	for child in root.get_children():
		if child is SpellValidationRunner:
			(child as SpellValidationRunner).shutdown()
		elif child is CharacterBody3D:
			child.free()
	var steam_service := get_root().get_node_or_null("SteamService")
	if steam_service != null and steam_service.has_method("shutdown"):
		steam_service.shutdown()
	SpellValidationWorker.force_stt_in_tests = false
	GdvoskAdapter.unload_model()


func _assert_steam_offline() -> bool:
	if not TestEnvScript.is_active():
		return true
	var steam_service := get_root().get_node_or_null("SteamService")
	if steam_service == null:
		return true
	if steam_service.get("initialized"):
		push_error("Unit tests must not initialize Steam (check FRIEND_SLOP_TEST=1)")
		return false
	return true
