class_name GdvoskAdapter
extends RefCounted

## gdvosk bridge — STT uses a background worker; one transcribe at a time via mutex.

const ACCEPT_CHUNK_SAMPLES := 8000
const VOSK_SAMPLE_RATE := 16000
const SpellLogScript := preload("res://scripts/spells/spell_log.gd")
const MODEL_SEARCH_PATHS: Array[String] = [
	"res://addons/gdvosk/model",
	"res://models/vosk",
	"user://vosk-model",
]

static var _cached_model: Object
static var _cached_model_path: String = ""
static var _transcribe_mutex: Mutex = Mutex.new()


static func is_available() -> bool:
	return ClassDB.class_exists("VoskRecognizer")


static func prewarm() -> void:
	if not is_available():
		return
	var model_path := find_model_path()
	if model_path.is_empty():
		return
	_get_or_load_model(model_path)


static func prewarm_full(source_sample_rate: int) -> bool:
	if not is_available():
		return false
	var model_path := find_model_path()
	if model_path.is_empty():
		return false
	if _get_or_load_model(model_path) == null:
		return false

	var rate: int = maxi(source_sample_rate, VOSK_SAMPLE_RATE)
	var sample_count: int = maxi(1, int(float(rate) * 0.3))
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	for i in sample_count:
		samples[i] = 0.002 * sin(float(i) * 0.05)

	transcribe_samples(samples, rate)
	return is_model_loaded()


static func is_model_loaded() -> bool:
	return _cached_model != null


static func unload_model() -> void:
	_cached_model = null
	_cached_model_path = ""


static func transcribe_samples(
	samples: PackedFloat32Array,
	sample_rate: int
) -> Dictionary:
	var empty := {"words": PackedStringArray(), "starts": PackedFloat32Array()}
	if samples.is_empty() or sample_rate <= 0 or not is_available():
		return empty

	_transcribe_mutex.lock()
	var result := _transcribe_with_vosk_recognizer(samples, sample_rate)
	_transcribe_mutex.unlock()
	return result


static func find_model_path() -> String:
	for path in MODEL_SEARCH_PATHS:
		if DirAccess.dir_exists_absolute(path):
			return path
	return ""


static func parse_result_json(json_text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(json_text)
	if parsed is Dictionary:
		return parsed
	return {}


static func extract_words_and_starts(result: Dictionary) -> Dictionary:
	var words: PackedStringArray = PackedStringArray()
	var starts: PackedFloat32Array = PackedFloat32Array()

	if result.has("result"):
		for entry in result["result"]:
			if entry is Dictionary:
				words.append(str(entry.get("word", "")).strip_edges())
				starts.append(float(entry.get("start", 0.0)))

	if words.is_empty() and result.has("alternatives"):
		for alt in result["alternatives"]:
			if alt is Dictionary:
				_append_text_tokens(words, str(alt.get("text", "")))
				if not words.is_empty():
					break

	if words.is_empty() and result.has("text"):
		_append_text_tokens(words, str(result["text"]))

	return {"words": words, "starts": starts}


static func _transcribe_with_vosk_recognizer(
	samples: PackedFloat32Array,
	sample_rate: int
) -> Dictionary:
	var empty := {"words": PackedStringArray(), "starts": PackedFloat32Array()}
	var model_path := find_model_path()
	if model_path.is_empty():
		return empty

	var model: Object = _get_or_load_model(model_path)
	if model == null:
		push_warning("GdvoskAdapter: failed to load Vosk model at %s" % model_path)
		return empty

	var result_dict := _transcribe_at_rate(model, samples, sample_rate)
	if not _result_has_words(result_dict) and sample_rate != VOSK_SAMPLE_RATE:
		var vosk_samples: PackedFloat32Array = _resample_for_vosk(
			samples, sample_rate, VOSK_SAMPLE_RATE
		)
		result_dict = _transcribe_at_rate(model, vosk_samples, VOSK_SAMPLE_RATE)

	if not _result_has_words(result_dict):
		SpellLogScript.debug(
			"Gdvosk",
			"no final result (samples=%d rate=%d)"
			% [samples.size(), sample_rate]
		)
		return empty

	var parsed := extract_words_and_starts(result_dict)
	var words: PackedStringArray = parsed.get("words", PackedStringArray())
	if words.is_empty():
		SpellLogScript.debug("Gdvosk", "empty transcript; raw=%s" % str(result_dict))
	return parsed


static func _transcribe_at_rate(
	model: Object,
	samples: PackedFloat32Array,
	rate: int
) -> Dictionary:
	if samples.is_empty() or rate <= 0:
		return {}

	var recognizer: Object = ClassDB.instantiate("VoskRecognizer")
	if recognizer == null:
		return {}

	if recognizer.has_method("setup"):
		var setup_error: int = recognizer.call("setup", model, rate, null)
		if setup_error != OK:
			push_warning("GdvoskAdapter: VoskRecognizer.setup failed (%s)" % setup_error)
			return {}

	_feed_samples(recognizer, samples)
	_flush_recognizer(recognizer, rate)
	return _read_final_result(recognizer)


static func _flush_recognizer(recognizer: Object, sample_rate: int) -> void:
	if recognizer == null or not recognizer.has_method("accept_samples"):
		return
	var silence_count: int = maxi(1, int(float(sample_rate) * 0.15))
	var silence := PackedVector2Array()
	silence.resize(silence_count)
	recognizer.call("accept_samples", silence)


static func _get_or_load_model(model_path: String) -> Object:
	_transcribe_mutex.lock()
	if _cached_model != null and _cached_model_path == model_path:
		var cached: Object = _cached_model
		_transcribe_mutex.unlock()
		return cached
	_cached_model = _create_vosk_model(model_path)
	_cached_model_path = model_path if _cached_model != null else ""
	var loaded: Object = _cached_model
	_transcribe_mutex.unlock()
	return loaded


static func _create_vosk_model(model_path: String) -> Object:
	if not ClassDB.class_exists("VoskModel"):
		return null
	var model: Object = ClassDB.instantiate("VoskModel")
	if model == null:
		return null
	if model.has_method("load"):
		var load_path := model_path
		if load_path.begins_with("res://") or load_path.begins_with("user://"):
			load_path = ProjectSettings.globalize_path(load_path)
		var load_error: int = model.call("load", load_path)
		if load_error == OK:
			return model
		push_warning("GdvoskAdapter: VoskModel.load failed (%s) for %s" % [load_error, load_path])
	return null


static func _resample_for_vosk(
	samples: PackedFloat32Array,
	source_rate: int,
	target_rate: int
) -> PackedFloat32Array:
	if source_rate <= 0 or target_rate <= 0 or samples.is_empty():
		return samples
	if source_rate == target_rate:
		return samples

	var ratio: float = float(source_rate) / float(target_rate)
	var out_size: int = maxi(1, int(float(samples.size()) / ratio))
	var out := PackedFloat32Array()
	out.resize(out_size)
	for i in out_size:
		var src_index: float = float(i) * ratio
		var left: int = int(floor(src_index))
		var right: int = mini(left + 1, samples.size() - 1)
		var frac: float = src_index - float(left)
		out[i] = lerpf(samples[left], samples[right], frac)
	return out


static func _feed_samples(recognizer: Object, samples: PackedFloat32Array) -> void:
	if samples.is_empty() or recognizer == null:
		return
	if recognizer.has_method("accept_samples"):
		var index := 0
		while index < samples.size():
			var end: int = mini(index + ACCEPT_CHUNK_SAMPLES, samples.size())
			var chunk := _mono_to_stereo_samples(samples.slice(index, end))
			recognizer.call("accept_samples", chunk)
			index = end
		return
	if recognizer.has_method("accept_waveform"):
		recognizer.call("accept_waveform", samples)


static func _mono_to_stereo_samples(samples: PackedFloat32Array) -> PackedVector2Array:
	var stereo := PackedVector2Array()
	stereo.resize(samples.size())
	for i in samples.size():
		var sample: float = samples[i]
		stereo[i] = Vector2(sample, sample)
	return stereo


static func _read_final_result(recognizer: Object) -> Dictionary:
	if recognizer == null:
		return {}
	if recognizer.has_method("get_final_result"):
		var final := _coerce_result_dictionary(recognizer.call("get_final_result"))
		if _result_has_words(final):
			return final
	if recognizer.has_method("get_partial_result"):
		var partial := _coerce_result_dictionary(recognizer.call("get_partial_result"))
		if _result_has_words(partial):
			return partial
	if recognizer.has_method("get_result"):
		var result := _coerce_result_dictionary(recognizer.call("get_result"))
		if _result_has_words(result):
			return result
	return {}


static func _result_has_words(result: Dictionary) -> bool:
	if result.is_empty():
		return false
	var parsed := extract_words_and_starts(result)
	var words: PackedStringArray = parsed.get("words", PackedStringArray())
	return not words.is_empty()


static func _coerce_result_dictionary(raw: Variant) -> Dictionary:
	if raw is Dictionary:
		return raw
	if raw is String:
		return parse_result_json(str(raw))
	return {}


static func _append_text_tokens(words: PackedStringArray, text: String) -> void:
	for token in text.split(" ", false):
		var cleaned := token.strip_edges()
		if not cleaned.is_empty():
			words.append(cleaned)
