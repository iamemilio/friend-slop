extends RefCounted

const SpellCastValidatorScript := preload("res://scripts/spells/spell_cast_validator.gd")
const CastValidationResultScript := preload("res://scripts/spells/cast_validation_result.gd")
const SpellDefinitionScript := preload("res://scripts/spells/spell_definition.gd")


func run() -> int:
	var failures := 0
	failures += _test_requires_transcript_for_targeted_cast()
	failures += _test_rejects_wrong_words_with_loud_audio()
	failures += _test_passes_matching_words_and_audio()
	failures += _test_stub_bypasses_checks()
	failures += _test_free_cast_rejects_without_transcript()
	failures += _test_free_cast_picks_matching_spell()
	failures += _test_stub_free_cast_single_selected_spell()
	return failures


func _make_spell(id: String, words: Array[String]) -> SpellDefinitionScript:
	var spell := SpellDefinitionScript.new()
	spell.id = id
	spell.incantation_words = PackedStringArray(words)
	spell.require_rhythm = false
	return spell


func _loud_samples(duration_sec: float, sample_rate: int = 44100) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	for _i in int(sample_rate * duration_sec):
		samples.append(0.04)
	return samples


func _test_requires_transcript_for_targeted_cast() -> int:
	var lumos := _make_spell("lumos", ["lumos"])
	var result := SpellCastValidatorScript.validate(
		lumos,
		_loud_samples(0.5),
		44100,
		PackedStringArray(),
		PackedFloat32Array(),
		false
	)
	if result.passed:
		push_error("Expected targeted cast without transcript to fail")
		return 1
	if not result.failure_reason.contains("speech recognition"):
		push_error("Expected speech recognition failure reason")
		return 1
	return 0


func _test_rejects_wrong_words_with_loud_audio() -> int:
	var fireball := _make_spell("fireball", ["fireball"])
	var result := SpellCastValidatorScript.validate(
		fireball,
		_loud_samples(0.5),
		44100,
		PackedStringArray(["lumos"]),
		PackedFloat32Array(),
		false
	)
	if result.passed:
		push_error("Expected wrong incantation to fail even with loud audio")
		return 1
	if result.words_ok:
		push_error("Expected words_ok to be false for wrong incantation")
		return 1
	return 0


func _test_passes_matching_words_and_audio() -> int:
	var lumos := _make_spell("lumos", ["lumos"])
	var result := SpellCastValidatorScript.validate(
		lumos,
		_loud_samples(0.5),
		44100,
		PackedStringArray(["lumos"]),
		PackedFloat32Array(),
		false
	)
	if not result.passed:
		push_error(
			"Expected matching words and audio to pass, got: %s"
			% result.failure_reason
		)
		return 1
	return 0


func _test_stub_bypasses_checks() -> int:
	var lumos := _make_spell("lumos", ["lumos"])
	var result := SpellCastValidatorScript.validate(
		lumos,
		PackedFloat32Array(),
		44100,
		PackedStringArray(),
		PackedFloat32Array(),
		true
	)
	if not result.passed:
		push_error("Expected stub mode to bypass validation for dev tome testing")
		return 1
	return 0


func _test_free_cast_rejects_without_transcript() -> int:
	var fireball := _make_spell("fireball", ["fireball"])
	var match: Dictionary = SpellCastValidatorScript.resolve_free_cast(
		[fireball],
		_loud_samples(0.3),
		44100,
		PackedStringArray(),
		PackedFloat32Array(),
		false
	)
	if match.get("spell") != null:
		push_error("Expected free cast without transcript to fail")
		return 1
	return 0


func _test_free_cast_picks_matching_spell() -> int:
	var lumos := _make_spell("lumos", ["lumos"])
	var fireball := _make_spell("fireball", ["fireball"])
	var match: Dictionary = SpellCastValidatorScript.resolve_free_cast(
		[lumos, fireball],
		_loud_samples(0.3),
		44100,
		PackedStringArray(["lumos"]),
		PackedFloat32Array(),
		false
	)
	var spell := match.get("spell") as SpellDefinitionScript
	if spell == null or spell.id != "lumos":
		push_error("Expected free cast to pick lumos when transcript matches")
		return 1
	return 0


func _test_stub_free_cast_single_selected_spell() -> int:
	var fireball := _make_spell("fireball", ["fireball"])
	var match: Dictionary = SpellCastValidatorScript.resolve_free_cast(
		[fireball],
		_loud_samples(0.3),
		44100,
		PackedStringArray(),
		PackedFloat32Array(),
		true
	)
	var spell := match.get("spell") as SpellDefinitionScript
	if spell == null or spell.id != "fireball":
		push_error("Expected stub free cast to work with one selected spell")
		return 1
	return 0
