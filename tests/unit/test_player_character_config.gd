class_name TestPlayerCharacterConfig
extends RefCounted

const GameStateScript := preload("res://scripts/game_state.gd")
const PlayerCharacterConfigScript := preload("res://scripts/match/player_character_config.gd")
const RoleLoadoutScript := preload("res://scripts/progression/role_loadout.gd")


func run() -> int:
	var failures := 0
	failures += _test_default_apprentice_summary()
	failures += _test_default_warden_summary()
	failures += _test_dict_round_trip()
	failures += _test_warden_starting_spells()
	failures += _test_apprentice_starting_spells()
	return failures


func _test_default_apprentice_summary() -> int:
	var config := PlayerCharacterConfigScript.create_default(GameStateScript.PlayerRole.APPRENTICE)
	if config.role != GameStateScript.PlayerRole.APPRENTICE:
		push_error("Expected default apprentice role")
		return 1
	if config.summary() != "Apprentice":
		push_error("Expected apprentice summary to show role label")
		return 1
	return 0


func _test_default_warden_summary() -> int:
	var config := PlayerCharacterConfigScript.create_default(GameStateScript.PlayerRole.WARDEN)
	if config.summary() != "Warden":
		push_error("Expected warden summary to show role label")
		return 1
	return 0


func _test_dict_round_trip() -> int:
	var original := PlayerCharacterConfigScript.create_default(GameStateScript.PlayerRole.WARDEN)
	var restored := PlayerCharacterConfigScript.from_dict(original.to_dict())
	if restored.role != GameStateScript.PlayerRole.WARDEN:
		push_error("Expected character config round-trip to preserve role")
		return 1
	return 0


func _test_warden_starting_spells() -> int:
	var config := PlayerCharacterConfigScript.create_default(GameStateScript.PlayerRole.WARDEN)
	var spell_ids := config.get_starting_spell_ids()
	if spell_ids.size() != 9:
		push_error("Expected warden config to expose nine starting spells")
		return 1
	if not spell_ids.has("warden_forge"):
		push_error("Expected warden loadout to include warden_forge")
		return 1
	return 0


func _test_apprentice_starting_spells() -> int:
	var config := PlayerCharacterConfigScript.create_default(GameStateScript.PlayerRole.APPRENTICE)
	var spell_ids := config.get_starting_spell_ids()
	if spell_ids.size() != RoleLoadoutScript.APPRENTICE_SPELLS.size():
		push_error("Expected apprentice config to expose all apprentice starting spells")
		return 1
	if not spell_ids.has("fireball") or not spell_ids.has("light"):
		push_error("Expected apprentice loadout to include fireball and light")
		return 1
	return 0
