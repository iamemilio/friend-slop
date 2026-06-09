extends SceneTree

## Headless test entry point.
## Run: godot --headless --path . --script res://tests/run_tests.gd

const TestMazeCarver := preload("res://tests/unit/test_maze_carver.gd")
const TestDiscoverableSpawnPlan := preload("res://tests/unit/test_discoverable_spawn_plan.gd")
const TestVoiceSpellValidator := preload("res://tests/unit/test_voice_spell_validator.gd")
const TestIncantationMatcher := preload("res://tests/unit/test_incantation_matcher.gd")
const TestSpellCastValidator := preload("res://tests/unit/test_spell_cast_validator.gd")
const TestSpellBook := preload("res://tests/unit/test_spell_book.gd")
const TestGdvoskAdapter := preload("res://tests/unit/test_gdvosk_adapter.gd")
const TestSpellValidationCodec := preload("res://tests/unit/test_spell_validation_codec.gd")
const TestGameState := preload("res://tests/unit/test_game_state.gd")
const TestMultiplayerTransport := preload("res://tests/unit/test_multiplayer_transport.gd")
const TestSteamTransport := preload("res://tests/unit/test_steam_transport.gd")
const TestNetworkManager := preload("res://tests/unit/test_network_manager.gd")
const TestPlayerSpawnLayout := preload("res://tests/unit/test_player_spawn_layout.gd")
const TestSpellValidationRunner := preload("res://tests/unit/test_spell_validation_runner.gd")
const TestSpellValidationAsync := preload("res://tests/unit/test_spell_validation_async.gd")
const TestSpellPipeline := preload("res://tests/unit/test_spell_pipeline.gd")
const TestSpellEffectSync := preload("res://tests/unit/test_spell_effect_sync.gd")
const TestSpellCastingSession := preload("res://tests/integration/test_spell_casting_session.gd")
const TestGdvoskExtensionConfig := preload("res://tests/unit/test_gdvosk_extension_config.gd")
const TestSpellSttConfig := preload("res://tests/unit/test_spell_stt_config.gd")
const TestGdvoskRuntime := preload("res://tests/integration/test_gdvosk_runtime.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("Running FriendSlop unit tests...")
	var failures := 0

	var maze_suite := TestMazeCarver.new()
	failures += maze_suite.run()

	var discoverable_suite := TestDiscoverableSpawnPlan.new()
	failures += discoverable_suite.run()

	var voice_suite := TestVoiceSpellValidator.new()
	failures += voice_suite.run()

	var matcher_suite := TestIncantationMatcher.new()
	failures += matcher_suite.run()

	var cast_validator_suite := TestSpellCastValidator.new()
	failures += cast_validator_suite.run()

	var spell_book_suite := TestSpellBook.new()
	failures += spell_book_suite.run()

	var gdvosk_suite := TestGdvoskAdapter.new()
	failures += gdvosk_suite.run()

	var codec_suite := TestSpellValidationCodec.new()
	failures += codec_suite.run()

	var game_state_suite := TestGameState.new()
	failures += game_state_suite.run()

	var transport_suite := TestMultiplayerTransport.new()
	failures += transport_suite.run()

	var steam_transport_suite := TestSteamTransport.new()
	failures += steam_transport_suite.run()

	var network_manager_suite := TestNetworkManager.new()
	failures += network_manager_suite.run()

	var player_spawn_layout_suite := TestPlayerSpawnLayout.new()
	failures += player_spawn_layout_suite.run()

	var spell_validation_runner_suite := TestSpellValidationRunner.new()
	failures += spell_validation_runner_suite.run(self)

	var spell_validation_async_suite := TestSpellValidationAsync.new()
	failures += spell_validation_async_suite.run(self)

	var spell_pipeline_suite := TestSpellPipeline.new()
	failures += spell_pipeline_suite.run(self)

	var spell_effect_sync_suite := TestSpellEffectSync.new()
	failures += spell_effect_sync_suite.run()

	var spell_casting_session_suite := TestSpellCastingSession.new()
	failures += spell_casting_session_suite.run(self)

	var gdvosk_extension_config_suite := TestGdvoskExtensionConfig.new()
	failures += gdvosk_extension_config_suite.run()

	var spell_stt_config_suite := TestSpellSttConfig.new()
	failures += spell_stt_config_suite.run()

	var gdvosk_runtime_suite := TestGdvoskRuntime.new()
	failures += gdvosk_runtime_suite.run()

	if failures == 0:
		print("All tests passed.")
		_finish(0)
	else:
		push_error("%d test(s) failed." % failures)
		_finish(1)


func _finish(exit_code: int) -> void:
	quit(exit_code)
