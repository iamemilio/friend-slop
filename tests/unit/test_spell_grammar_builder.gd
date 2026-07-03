extends RefCounted

const SpellGrammarBuilderScript := preload("res://scripts/spells/spell_grammar_builder.gd")


func run() -> int:
	var failures := 0
	failures += _test_build_json_empty()
	failures += _test_build_json_phrases_and_unk()
	failures += _test_build_json_dedupes()
	failures += _test_build_json_from_spell_dicts()
	return failures


func _test_build_json_empty() -> int:
	var json := SpellGrammarBuilderScript.build_json([])
	if json != "":
		push_error("Expected empty grammar for no phrases, got: %s" % json)
		return 1
	return 0


func _test_build_json_phrases_and_unk() -> int:
	var parsed: Variant = JSON.parse_string(
		SpellGrammarBuilderScript.build_json(["show me", "speed up"])
	)
	if not parsed is Array:
		push_error("Expected grammar JSON array")
		return 1
	var phrases: Array = parsed
	if phrases.size() != 3:
		push_error("Expected 2 phrases plus [unk], got: %s" % phrases)
		return 1
	if phrases[0] != "show me" or phrases[1] != "speed up" or phrases[2] != "[unk]":
		push_error("Unexpected grammar phrases: %s" % phrases)
		return 1
	return 0


func _test_build_json_dedupes() -> int:
	var parsed: Variant = JSON.parse_string(
		SpellGrammarBuilderScript.build_json(["Show Me", "show me"])
	)
	var phrases: Array = parsed
	if phrases.size() != 2:
		push_error("Expected deduped phrase plus [unk], got: %s" % phrases)
		return 1
	return 0


func _test_build_json_from_spell_dicts() -> int:
	var spells: Array = [
		{"incantation_words": ["fireball"]},
		{"incantation_words": ["show", "me"]},
	]
	var parsed: Variant = JSON.parse_string(
		SpellGrammarBuilderScript.build_json_from_spell_dicts(spells)
	)
	var phrases: Array = parsed
	if phrases.size() != 3:
		push_error("Expected spell dict phrases plus [unk], got: %s" % phrases)
		return 1
	if phrases[0] != "fireball" or phrases[1] != "show me":
		push_error("Unexpected spell dict grammar: %s" % phrases)
		return 1
	return 0
