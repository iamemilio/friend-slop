extends RefCounted

const LoadoutScript := preload("res://scripts/spells/character_spell_loadout.gd")
const SpellDefinitionScript := preload("res://scripts/spells/spell_definition.gd")


func run() -> int:
	var failures := 0
	failures += _test_unknown_spell_not_known()
	failures += _test_learn_and_query()
	failures += _test_learn_unknown_fails()
	failures += _test_unlearn()
	return failures


func _make_loadout() -> LoadoutScript:
	var loadout := LoadoutScript.new()
	var show_me := SpellDefinitionScript.new()
	show_me.id = "show_me"
	show_me.display_name = "Show Me"
	loadout.configure([show_me])
	return loadout


func _test_unknown_spell_not_known() -> int:
	var loadout := _make_loadout()
	if loadout.knows("show_me"):
		push_error("Expected unknown spell to be absent from loadout")
		return 1
	return 0


func _test_learn_and_query() -> int:
	var loadout := _make_loadout()
	if not loadout.learn_spell("show_me", "test"):
		push_error("Expected learn_spell to succeed")
		return 1
	if not loadout.knows("show_me"):
		push_error("Expected spell to be known after learn")
		return 1
	var spells := loadout.get_known_spells()
	if spells.size() != 1 or spells[0].id != "show_me":
		push_error("Expected get_known_spells to return learned spell")
		return 1
	return 0


func _test_learn_unknown_fails() -> int:
	var loadout := _make_loadout()
	if loadout.learn_spell("missing"):
		push_error("Expected learn_spell to fail for unknown id")
		return 1
	return 0


func _test_unlearn() -> int:
	var loadout := _make_loadout()
	loadout.learn_spell("show_me")
	loadout.unlearn_spell("show_me")
	if loadout.knows("show_me"):
		push_error("Expected spell to be removed after unlearn")
		return 1
	return 0
