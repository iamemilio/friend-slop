class_name TestRoleLoadout
extends RefCounted

const GameStateScript := preload("res://scripts/game_state.gd")
const RoleLoadoutScript := preload("res://scripts/progression/role_loadout.gd")


func run() -> int:
	var failures := 0
	failures += _test_warden_gets_union_of_starters()
	failures += _test_apprentice_starter_kit()
	failures += _test_role_labels()
	return failures


func _test_warden_gets_union_of_starters() -> int:
	var spell_ids := RoleLoadoutScript.get_starting_spell_ids(GameStateScript.PlayerRole.WARDEN)
	var expected_size := (
		RoleLoadoutScript.APPRENTICE_STARTER_SPELLS.size()
		+ RoleLoadoutScript.WARDEN_STARTER_SPELLS.size()
	)
	var missing := (
		spell_ids.size() != expected_size
		or not spell_ids.has("warden_forge")
		or not spell_ids.has("show_me")
		or not spell_ids.has("fireball")
	)
	if missing:
		push_error("Expected warden loadout to be union of apprentice and warden starters")
		return 1
	return 0


func _test_apprentice_starter_kit() -> int:
	var spell_ids := RoleLoadoutScript.get_starting_spell_ids(
		GameStateScript.PlayerRole.APPRENTICE
	)
	var expected := RoleLoadoutScript.APPRENTICE_STARTER_SPELLS
	var missing_required := (
		not spell_ids.has("show_me")
		or not spell_ids.has("light")
		or not spell_ids.has("light_ball")
		or not spell_ids.has("target")
		or not spell_ids.has("pull")
		or not spell_ids.has("follow")
		or not spell_ids.has("stop")
	)
	var has_warden_spell := false
	for warden_id in RoleLoadoutScript.WARDEN_STARTER_SPELLS:
		if spell_ids.has(warden_id):
			has_warden_spell = true
			break
	if spell_ids.size() != expected.size() or missing_required or has_warden_spell:
		push_error("Expected apprentice loadout to match apprentice starter kit only")
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
