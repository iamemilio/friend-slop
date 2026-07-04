extends SceneTree

## Headless test entry point.
## Run: godot --headless --path . --script res://tests/run_tests.gd
## Offline only — no live Steam client or Steamworks session required.

const TestEnvScript := preload("res://scripts/test/test_env.gd")

const TestMazeCarverScript := preload("res://tests/unit/test_maze_carver.gd")
const TestDiscoverableSpawnPlanScript := preload("res://tests/unit/test_discoverable_spawn_plan.gd")
const TestVoiceSpellValidator := preload("res://tests/unit/test_voice_spell_validator.gd")
const TestIncantationMatcher := preload("res://tests/unit/test_incantation_matcher.gd")
const TestSpellGrammarBuilder := preload("res://tests/unit/test_spell_grammar_builder.gd")
const TestSpellCastValidator := preload("res://tests/unit/test_spell_cast_validator.gd")
const TestCharacterSpellLoadout := preload("res://tests/unit/test_character_spell_loadout.gd")
const TestGdvoskAdapter := preload("res://tests/unit/test_gdvosk_adapter.gd")
const TestSpellValidationCodec := preload("res://tests/unit/test_spell_validation_codec.gd")
const TestGameStateScript := preload("res://tests/unit/test_game_state.gd")
const TestMultiplayerTransportScript := preload("res://tests/unit/test_multiplayer_transport.gd")
const TestSteamTransportScript := preload("res://tests/unit/test_steam_transport.gd")
const TestNetworkManagerScript := preload("res://tests/unit/test_network_manager.gd")
const TestMatchStateScript := preload("res://tests/unit/test_match_state.gd")
const TestRoleAssignmentScript := preload("res://tests/unit/test_role_assignment.gd")
const TestPlayerCharacterConfigScript := preload("res://tests/unit/test_player_character_config.gd")
const TestRoleLoadoutScript := preload("res://tests/unit/test_role_loadout.gd")
const TestObjectivePlacementScript := preload("res://tests/unit/test_objective_placement.gd")
const TestDeliveryObjectiveStateScript := preload(
	"res://tests/unit/test_delivery_objective_state.gd"
)
const TestDeliveryObjectiveAudioScript := preload(
	"res://tests/unit/test_delivery_objective_audio.gd"
)
const TestDeliveryObjectiveSyncScript := preload("res://tests/unit/test_delivery_objective_sync.gd")
const TestTrailRegistryScript := preload("res://tests/unit/test_trail_registry.gd")
const TestPlayerSpawnLayoutScript := preload("res://tests/unit/test_player_spawn_layout.gd")
const TestSpellValidationRunnerScript := preload("res://tests/unit/test_spell_validation_runner.gd")
const TestSpellValidationAsyncScript := preload("res://tests/unit/test_spell_validation_async.gd")
const TestSpellPipelineScript := preload("res://tests/unit/test_spell_pipeline.gd")
const TestFireballSkyFlareScript := preload("res://tests/unit/test_fireball_sky_flare.gd")
const TestFireballFlightScript := preload("res://tests/unit/test_fireball_flight.gd")
const TestSpellEffectSyncScript := preload("res://tests/unit/test_spell_effect_sync.gd")
const TestGuideContentScript := preload("res://tests/unit/test_guide_content.gd")
const TestSpellCodexScript := preload("res://tests/unit/test_spell_codex.gd")
const TestSpellCastingSessionScript := preload(
	"res://tests/integration/test_spell_casting_session.gd"
)
const TestPlayableCharacterWand := preload("res://tests/unit/test_playable_character_wand.gd")
const TestVoiceCaptureWorker := preload("res://tests/unit/test_voice_capture_worker.gd")
const TestGdvoskExtensionConfigScript := preload("res://tests/unit/test_gdvosk_extension_config.gd")
const TestSpellSttConfigScript := preload("res://tests/unit/test_spell_stt_config.gd")
const TestGdvoskRuntimeScript := preload("res://tests/integration/test_gdvosk_runtime.gd")


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("Running FriendSlop unit tests (offline — no Steam required)...")
	if not _assert_steam_offline():
		_finish(1)
		return
	var failures := 0

	var maze_suite := TestMazeCarverScript.new()
	failures += maze_suite.run()

	var discoverable_suite := TestDiscoverableSpawnPlanScript.new()
	failures += discoverable_suite.run()

	var voice_suite := TestVoiceSpellValidator.new()
	failures += voice_suite.run()

	var matcher_suite := TestIncantationMatcher.new()
	failures += matcher_suite.run()

	var grammar_suite := TestSpellGrammarBuilder.new()
	failures += grammar_suite.run()

	var cast_validator_suite := TestSpellCastValidator.new()
	failures += cast_validator_suite.run()

	var loadout_suite := TestCharacterSpellLoadout.new()
	failures += loadout_suite.run()

	var gdvosk_suite := TestGdvoskAdapter.new()
	failures += gdvosk_suite.run()

	var codec_suite := TestSpellValidationCodec.new()
	failures += codec_suite.run()

	var game_state_suite := TestGameStateScript.new()
	failures += game_state_suite.run()

	var transport_suite := TestMultiplayerTransportScript.new()
	failures += transport_suite.run()

	var steam_transport_suite := TestSteamTransportScript.new()
	failures += steam_transport_suite.run()

	var network_manager_suite := TestNetworkManagerScript.new()
	failures += network_manager_suite.run()

	var match_state_suite := TestMatchStateScript.new()
	failures += match_state_suite.run()

	var role_assignment_suite := TestRoleAssignmentScript.new()
	failures += role_assignment_suite.run()

	var player_character_config_suite := TestPlayerCharacterConfigScript.new()
	failures += player_character_config_suite.run()

	var role_loadout_suite := TestRoleLoadoutScript.new()
	failures += role_loadout_suite.run()

	var objective_placement_suite := TestObjectivePlacementScript.new()
	failures += objective_placement_suite.run()

	var delivery_objective_state_suite := TestDeliveryObjectiveStateScript.new()
	failures += delivery_objective_state_suite.run()

	var delivery_objective_audio_suite := TestDeliveryObjectiveAudioScript.new()
	failures += delivery_objective_audio_suite.run()

	var delivery_objective_sync_suite := TestDeliveryObjectiveSyncScript.new()
	failures += delivery_objective_sync_suite.run()

	var trail_registry_suite := TestTrailRegistryScript.new()
	failures += trail_registry_suite.run()

	var player_spawn_layout_suite := TestPlayerSpawnLayoutScript.new()
	failures += player_spawn_layout_suite.run()

	var spell_validation_runner_suite := TestSpellValidationRunnerScript.new()
	failures += spell_validation_runner_suite.run(self)

	var spell_validation_async_suite := TestSpellValidationAsyncScript.new()
	failures += spell_validation_async_suite.run(self)

	var spell_pipeline_suite := TestSpellPipelineScript.new()
	failures += spell_pipeline_suite.run(self)

	var spell_effect_sync_suite := TestSpellEffectSyncScript.new()
	failures += spell_effect_sync_suite.run()

	var fireball_sky_flare_suite := TestFireballSkyFlareScript.new()
	failures += fireball_sky_flare_suite.run()

	var fireball_flight_suite := TestFireballFlightScript.new()
	failures += fireball_flight_suite.run()

	var guide_content_suite := TestGuideContentScript.new()
	failures += guide_content_suite.run()

	var spell_codex_suite := TestSpellCodexScript.new()
	failures += spell_codex_suite.run()

	var spell_casting_session_suite := TestSpellCastingSessionScript.new()
	failures += spell_casting_session_suite.run(self)

	var wand_input_suite := TestPlayableCharacterWand.new()
	failures += wand_input_suite.run(self)

	var voice_capture_suite := TestVoiceCaptureWorker.new()
	failures += voice_capture_suite.run()

	var gdvosk_extension_config_suite := TestGdvoskExtensionConfigScript.new()
	failures += gdvosk_extension_config_suite.run()

	var spell_stt_config_suite := TestSpellSttConfigScript.new()
	failures += spell_stt_config_suite.run()

	var gdvosk_runtime_suite := TestGdvoskRuntimeScript.new()
	failures += gdvosk_runtime_suite.run()

	if failures == 0:
		print("All tests passed.")
		_finish(0)
	else:
		push_error("%d test(s) failed." % failures)
		_finish(1)


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
