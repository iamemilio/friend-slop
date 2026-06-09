class_name TestPlayerCharacterConfig
extends RefCounted

const GameStateScript := preload("res://scripts/game_state.gd")
const PlayerCharacterConfigScript := preload("res://scripts/match/player_character_config.gd")


func run() -> int:
	var failures := 0
	failures += _test_default_apprentice_summary()
	failures += _test_default_warden_summary()
	failures += _test_dict_round_trip()
	failures += _test_skill_tree_from_config()
	failures += _test_warden_starting_spells()
	return failures


func _test_default_apprentice_summary() -> int:
	var config := PlayerCharacterConfigScript.create_default(GameStateScript.PlayerRole.APPRENTICE)
	if config.role != GameStateScript.PlayerRole.APPRENTICE:
		push_error("Expected default apprentice role")
		return 1
	if not config.summary().contains("Firemage"):
		push_error("Expected apprentice summary to include Firemage binding")
		return 1
	return 0


func _test_default_warden_summary() -> int:
	var config := PlayerCharacterConfigScript.create_default(GameStateScript.PlayerRole.WARDEN)
	config.role = GameStateScript.PlayerRole.WARDEN
	if not config.summary().contains("Warden"):
		push_error("Expected warden summary to include Warden skill tree")
		return 1
	if not config.summary().contains("Hunter"):
		push_error("Expected warden default starting position in summary")
		return 1
	return 0


func _test_dict_round_trip() -> int:
	var original := PlayerCharacterConfigScript.create_default(GameStateScript.PlayerRole.APPRENTICE)
	original.binding.starting_node_id = "haste"
	var restored := PlayerCharacterConfigScript.from_dict(original.to_dict())
	if restored.binding.starting_node_id != "haste":
		push_error("Expected character config round-trip to preserve binding")
		return 1
	return 0


func _test_skill_tree_from_config() -> int:
	var config := PlayerCharacterConfigScript.create_default(GameStateScript.PlayerRole.APPRENTICE)
	config.binding.starting_node_id = "fireball"
	var tree := config.get_skill_tree()
	if not tree.knows_node("fireball"):
		push_error("Expected config to produce a skill tree with its starting node")
		return 1
	return 0


func _test_warden_starting_spells() -> int:
	var config := PlayerCharacterConfigScript.create_default(GameStateScript.PlayerRole.WARDEN)
	config.binding.starting_node_id = "architect"
	var spell_ids := config.get_starting_spell_ids()
	if spell_ids.size() != 3:
		push_error("Expected warden config to expose three starting spells")
		return 1
	if not spell_ids.has("warden_forge"):
		push_error("Expected architect starting position to include warden_forge")
		return 1
	return 0
