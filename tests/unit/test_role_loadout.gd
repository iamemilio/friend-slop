class_name TestRoleLoadout
extends RefCounted

const GameStateScript := preload("res://scripts/game_state.gd")
const RoleLoadoutScript := preload("res://scripts/progression/role_loadout.gd")


func run() -> int:
	var failures := 0
	failures += _test_warden_gets_all_powers()
	failures += _test_apprentice_starter_kit()
	failures += _test_role_labels()
	return failures


func _test_warden_gets_all_powers() -> int:
	var spell_ids := RoleLoadoutScript.get_starting_spell_ids(GameStateScript.PlayerRole.WARDEN)
	if spell_ids.size() != RoleLoadoutScript.WARDEN_SPELLS.size():
		push_error("Expected warden loadout to include all warden spells")
		return 1
	if not spell_ids.has("warden_forge"):
		push_error("Expected warden loadout to include warden_forge")
		return 1
	return 0


func _test_apprentice_starter_kit() -> int:
	var spell_ids := RoleLoadoutScript.get_starting_spell_ids(
		GameStateScript.PlayerRole.APPRENTICE
	)
	if spell_ids.size() != RoleLoadoutScript.APPRENTICE_SPELLS.size():
		push_error("Expected apprentice loadout to include all apprentice spells")
		return 1
	if not spell_ids.has("show_me"):
		push_error("Expected apprentice loadout to include show_me")
		return 1
	if not spell_ids.has("light") or not spell_ids.has("light_ball"):
		push_error("Expected apprentice loadout to include light and light_ball")
		return 1
	if not spell_ids.has("target"):
		push_error("Expected apprentice loadout to include target")
		return 1
	if not spell_ids.has("pull") or not spell_ids.has("follow") or not spell_ids.has("stop"):
		push_error("Expected apprentice loadout to include pull, follow, and stop")
		return 1
	return 0


func _test_role_labels() -> int:
	if RoleLoadoutScript.role_label(GameStateScript.PlayerRole.WARDEN) != "Warden":
		push_error("Expected warden role label")
		return 1
	if RoleLoadoutScript.role_label(GameStateScript.PlayerRole.APPRENTICE) != "Apprentice":
		push_error("Expected apprentice role label")
		return 1
	return 0
