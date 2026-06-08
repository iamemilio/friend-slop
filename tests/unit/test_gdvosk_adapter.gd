extends RefCounted

const GdvoskAdapterScript := preload("res://scripts/spells/gdvosk_adapter.gd")


func run() -> int:
	var failures := 0
	failures += _test_extract_words_from_alternatives()
	failures += _test_extract_words_from_result_entries()
	failures += _test_extract_words_from_text_field()
	return failures


func _test_extract_words_from_alternatives() -> int:
	var parsed: Dictionary = GdvoskAdapterScript.extract_words_and_starts({
		"alternatives": [{"confidence": 1.0, "text": "fire ball"}],
	})
	var words: PackedStringArray = parsed.get("words", PackedStringArray())
	if words.size() != 2 or words[0] != "fire" or words[1] != "ball":
		push_error("Expected alternatives text to split into tokens, got: %s" % words)
		return 1
	return 0


func _test_extract_words_from_result_entries() -> int:
	var parsed: Dictionary = GdvoskAdapterScript.extract_words_and_starts({
		"result": [{"word": "fireball", "start": 0.4}],
	})
	var words: PackedStringArray = parsed.get("words", PackedStringArray())
	if words.size() != 1 or words[0] != "fireball":
		push_error("Expected result entry words, got: %s" % words)
		return 1
	return 0


func _test_extract_words_from_text_field() -> int:
	var parsed: Dictionary = GdvoskAdapterScript.extract_words_and_starts({
		"text": "lumos",
	})
	var words: PackedStringArray = parsed.get("words", PackedStringArray())
	if words.size() != 1 or words[0] != "lumos":
		push_error("Expected text field word, got: %s" % words)
		return 1
	return 0
