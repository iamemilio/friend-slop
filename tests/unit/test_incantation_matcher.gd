extends RefCounted

const IncantationMatcherScript := preload("res://scripts/spells/incantation_matcher.gd")
const SpellDefinitionScript := preload("res://scripts/spells/spell_definition.gd")


func run() -> int:
	var failures := 0
	failures += _test_exact_match_show_me()
	failures += _test_exact_match_multi_word()
	failures += _test_rejects_wrong_word()
	failures += _test_fuzzy_match_typo()
	failures += _test_heard_text_contains_incantation()
	failures += _test_compound_single_word_fireball()
	failures += _test_light_on_and_off_phrases()
	return failures


func _make_spell(id: String, words: Array[String]) -> SpellDefinitionScript:
	var spell := SpellDefinitionScript.new()
	spell.id = id
	spell.incantation_words = PackedStringArray(words)
	return spell


func _test_exact_match_show_me() -> int:
	var show_me := _make_spell("show_me", ["show", "me"])
	if not IncantationMatcherScript.matches(PackedStringArray(["show", "me"]), show_me):
		push_error("Expected exact match for show me")
		return 1
	return 0


func _test_exact_match_multi_word() -> int:
	var haste := _make_spell("haste", ["speed", "up"])
	if not IncantationMatcherScript.matches(
		PackedStringArray(["speed", "up"]), haste
	):
		push_error("Expected exact match for speed up")
		return 1
	return 0


func _test_rejects_wrong_word() -> int:
	var fireball := _make_spell("fireball", ["fireball"])
	if IncantationMatcherScript.matches(PackedStringArray(["show", "me"]), fireball):
		push_error("Expected show me to not match fireball")
		return 1
	return 0


func _test_fuzzy_match_typo() -> int:
	var show_me := _make_spell("show_me", ["show", "me"])
	if not IncantationMatcherScript.matches(PackedStringArray(["sho", "me"]), show_me):
		push_error("Expected fuzzy match for sho me -> show me")
		return 1
	return 0


func _test_heard_text_contains_incantation() -> int:
	var haste := _make_spell("haste", ["speed", "up"])
	if not IncantationMatcherScript.matches(
		PackedStringArray(["well", "speed", "up", "now"]), haste
	):
		push_error("Expected phrase containing speed up to match haste")
		return 1
	return 0


func _test_compound_single_word_fireball() -> int:
	var fireball := _make_spell("fireball", ["fireball"])
	if not IncantationMatcherScript.matches(
		PackedStringArray(["fire", "ball"]), fireball
	):
		push_error("Expected 'fire ball' transcript to match fireball")
		return 1
	return 0


func _test_light_on_and_off_phrases() -> int:
	var light_on := _make_spell("light_on", ["light", "on"])
	var light_off := _make_spell("light_off", ["light", "off"])
	if not IncantationMatcherScript.matches(PackedStringArray(["light", "on"]), light_on):
		push_error("Expected exact match for light on")
		return 1
	if not IncantationMatcherScript.matches(PackedStringArray(["light", "off"]), light_off):
		push_error("Expected exact match for light off")
		return 1
	if IncantationMatcherScript.matches(PackedStringArray(["light", "on"]), light_off):
		push_error("Expected light on to not match light off")
		return 1
	return 0
