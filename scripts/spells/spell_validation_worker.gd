class_name SpellValidationWorker
extends RefCounted

## Thread-safe spell validation entry point. Only plain data crosses thread boundaries.

const CodecScript := preload("res://scripts/spells/spell_validation_codec.gd")
const GdvoskAdapterScript := preload("res://scripts/spells/gdvosk_adapter.gd")
const SpellCastValidatorScript := preload("res://scripts/spells/spell_cast_validator.gd")
const SpellLogScript := preload("res://scripts/spells/spell_log.gd")

## Test hook: artificial delay inside the worker thread.
static var test_delay_sec: float = 0.0
static var last_ran_on_main_thread: bool = true


static func run(work: Dictionary) -> Dictionary:
	last_ran_on_main_thread = Thread.is_main_thread()
	if test_delay_sec > 0.0:
		OS.delay_usec(int(test_delay_sec * 1_000_000.0))

	var transcript_words := CodecScript.packed_strings_from_array(
		work.get("transcript_words", [])
	)
	var word_starts_sec := CodecScript.packed_floats_from_array(
		work.get("word_starts_sec", [])
	)
	var use_stub: bool = bool(work.get("use_stub", false))
	var samples: PackedFloat32Array = work.get("trimmed", PackedFloat32Array())
	var raw_samples: PackedFloat32Array = work.get("samples", PackedFloat32Array())
	var sample_rate: int = int(work.get("sample_rate", 0))

	if transcript_words.is_empty() and not use_stub:
		var stt := _transcribe_for_validation(raw_samples, samples, sample_rate)
		var words: Variant = stt.get("words")
		var starts: Variant = stt.get("starts")
		if words is PackedStringArray:
			transcript_words = words
		if starts is PackedFloat32Array:
			word_starts_sec = starts
		if transcript_words.is_empty():
			SpellLogScript.debug(
				"CastSession",
				"stt returned no words (samples=%d trimmed=%d rate=%d model_loaded=%s)"
				% [
					raw_samples.size(),
					samples.size(),
					sample_rate,
					str(GdvoskAdapterScript.is_model_loaded()),
				]
			)
		else:
			SpellLogScript.debug(
				"CastSession",
				'stt transcript="%s"' % " ".join(transcript_words)
			)

	if str(work.get("mode", "")) == "free_cast":
		return _build_free_cast_response(
			work.get("candidates", []),
			samples,
			sample_rate,
			use_stub,
			transcript_words,
			word_starts_sec
		)

	return _build_targeted_response(
		work.get("spell", {}),
		samples,
		sample_rate,
		use_stub,
		transcript_words,
		word_starts_sec
	)


static func _transcribe_for_validation(
	samples: PackedFloat32Array,
	trimmed: PackedFloat32Array,
	sample_rate: int
) -> Dictionary:
	var stt := GdvoskAdapterScript.transcribe_samples(samples, sample_rate)
	var words: Variant = stt.get("words")
	if words is PackedStringArray and not words.is_empty():
		return stt
	if trimmed.is_empty() or trimmed.size() == samples.size():
		return stt
	return GdvoskAdapterScript.transcribe_samples(trimmed, sample_rate)


static func _build_targeted_response(
	spell_data: Dictionary,
	samples: PackedFloat32Array,
	sample_rate: int,
	use_stub: bool,
	transcript_words: PackedStringArray,
	word_starts_sec: PackedFloat32Array
) -> Dictionary:
	if spell_data.is_empty():
		return {"ok": false, "error": "No spell in request"}

	var result := SpellCastValidatorScript.validate_spell_dict(
		spell_data, samples, sample_rate, transcript_words, word_starts_sec, use_stub
	)
	return _success_payload(
		str(spell_data.get("id", "")),
		result,
		transcript_words,
		word_starts_sec
	)


static func _build_free_cast_response(
	candidate_data: Array,
	samples: PackedFloat32Array,
	sample_rate: int,
	use_stub: bool,
	transcript_words: PackedStringArray,
	word_starts_sec: PackedFloat32Array
) -> Dictionary:
	var match: Dictionary = SpellCastValidatorScript.resolve_free_cast_dict(
		candidate_data,
		samples,
		sample_rate,
		transcript_words,
		word_starts_sec,
		use_stub
	)
	var matched: Variant = match.get("spell")
	var result: CastValidationResult = match.get("result")
	var debug_lines: PackedStringArray = match.get("debug_lines", PackedStringArray())
	var spell_id := ""
	if matched is Dictionary:
		spell_id = str(matched.get("id", ""))
	return _success_payload(
		spell_id,
		result,
		transcript_words,
		word_starts_sec,
		CodecScript.array_from_strings(debug_lines)
	)


static func _success_payload(
	spell_id: String,
	result: CastValidationResult,
	transcript_words: PackedStringArray,
	word_starts_sec: PackedFloat32Array,
	debug_lines: Array = []
) -> Dictionary:
	return {
		"ok": true,
		"spell_id": spell_id,
		"result": CodecScript.result_to_dict(result),
		"transcript_words": CodecScript.array_from_strings(transcript_words),
		"word_starts_sec": CodecScript.array_from_floats(word_starts_sec),
		"debug_lines": debug_lines,
	}
