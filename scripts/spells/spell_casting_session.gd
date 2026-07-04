class_name SpellCastingSession
extends Node

signal cast_succeeded(spell: SpellDefinition, mode: String, validation: CastValidationResult)
signal cast_failed(spell: SpellDefinition, reason: String, partial: CastValidationResult)
signal state_changed(state: String, spell: SpellDefinition)
signal listen_level_changed(level: float)
signal listen_coaching_changed(message: String)
signal tome_teaching_changed(active: bool, spell: SpellDefinition)
signal tome_retry_tick(seconds_left: float)

enum Mode { LEARN, CAST }

const ValidationRunnerScript := preload("res://scripts/spells/spell_validation_runner.gd")
const SpellSttConfigScript := preload("res://scripts/spells/spell_stt_config.gd")
const VoiceCaptureWorkerScript := preload("res://scripts/spells/voice_capture_worker.gd")

const STATE_IDLE := "idle"
const STATE_ARMING := "arming"
const STATE_LISTENING := "listening"
const STATE_VALIDATING := "validating"
const STATE_COACHING := "coaching"

const ARMING_SEC := 0.1
const MAX_LISTEN_SEC := 5.0
const TRAILING_SILENCE_SEC := 0.15
const MIN_LISTEN_BEFORE_END_SEC := 0.25
const TOME_RETRY_SEC := 2.0
const MAX_CAPTURE_CHUNKS_PER_FRAME := 8

@export var mic_bus_name: String = "MicCapture"

var _state: String = STATE_IDLE
var _mode: Mode = Mode.CAST
var _spell: SpellDefinition
var _tome_teaching := false
var _tome_spell: SpellDefinition
var _coaching_retry_left: float = 0.0
var _validator: VoiceSpellValidator
var _spell_loadout: Node
var _mic_player: AudioStreamPlayer
var _capture_effect: AudioEffectCapture
var _arming_left: float = 0.0
var _listen_left: float = 0.0
var _listen_elapsed: float = 0.0
var _speech_detected := false
var _silence_after_speech: float = 0.0
var _recorded_samples: PackedFloat32Array = PackedFloat32Array()
var _sample_rate: int = 44100
var _transcript_words: PackedStringArray = PackedStringArray()
var _word_starts_sec: PackedFloat32Array = PackedFloat32Array()
var _validation_runner: SpellValidationRunner
var _free_cast := false
var _free_cast_candidates: Array[SpellDefinition] = []
var _free_cast_debug_lines: PackedStringArray = PackedStringArray()
var _capture_worker: VoiceCaptureWorker


func _ready() -> void:
	_capture_worker = VoiceCaptureWorkerScript.new()
	_ensure_validation_runner()
	if _is_local_simulation():
		_setup_microphone()


func _ensure_validation_runner() -> void:
	if _validation_runner == null:
		_validation_runner = get_node_or_null("SpellValidationRunner") as SpellValidationRunner
	if _validation_runner == null:
		_validation_runner = ValidationRunnerScript.new()
		_validation_runner.name = "SpellValidationRunner"
		add_child(_validation_runner)
	if not _validation_runner.validation_finished.is_connected(_on_validation_runner_finished):
		_validation_runner.validation_finished.connect(_on_validation_runner_finished)


func configure(validator: VoiceSpellValidator, spell_loadout: Node = null) -> void:
	_validator = validator
	_spell_loadout = spell_loadout


func is_free_cast() -> bool:
	return _free_cast


func is_active() -> bool:
	return _state != STATE_IDLE and _state != STATE_COACHING


func is_tome_teaching() -> bool:
	return _tome_teaching


func is_between_attempts() -> bool:
	return _tome_teaching and _state == STATE_COACHING


func is_validating() -> bool:
	return _state == STATE_VALIDATING


func get_state() -> String:
	return _state


func get_tome_spell() -> SpellDefinition:
	return _tome_spell if _tome_teaching else null


func get_active_spell() -> SpellDefinition:
	return _spell if _spell != null else _tome_spell


func start(spell: SpellDefinition, mode: Mode) -> void:
	if spell == null:
		TomeDebug.log("CastSession", "start aborted: spell is null")
		return
	if _tome_teaching:
		end_tome_teaching()
	if _state != STATE_IDLE:
		TomeDebug.log(
			"CastSession",
			"start aborted: not idle (state=%s)" % _state
		)
		return
	var mode_name := "LEARN" if mode == Mode.LEARN else "CAST"
	TomeDebug.log(
		"CastSession",
		"start mode=%s spell='%s' mic_player=%s capture=%s"
		% [
			mode_name,
			spell.id,
			_mic_player != null,
			_capture_effect != null,
		]
	)
	_tome_teaching = false
	_tome_spell = null
	_free_cast = false
	_free_cast_candidates = []
	_begin_attempt(spell, mode)


func start_free_cast(candidates: Array[SpellDefinition]) -> void:
	var known_spells := _known_spells_for_player()
	if known_spells.is_empty():
		known_spells = candidates.duplicate()
	if known_spells.is_empty():
		TomeDebug.log("CastSession", "start_free_cast aborted: no candidates")
		return
	if _tome_teaching:
		end_tome_teaching()
	if _state != STATE_IDLE:
		TomeDebug.log(
			"CastSession",
			"start_free_cast aborted: not idle (state=%s)" % _state
		)
		return
	_free_cast = true
	_free_cast_candidates = known_spells
	_mode = Mode.CAST
	_spell = null
	TomeDebug.log(
		"CastSession",
		"start free cast (%d spells known)" % _free_cast_candidates.size()
	)
	_recorded_samples = PackedFloat32Array()
	_transcript_words = PackedStringArray()
	_word_starts_sec = PackedFloat32Array()
	_speech_detected = false
	_silence_after_speech = 0.0
	_listen_elapsed = 0.0
	_coaching_retry_left = 0.0
	_set_state(STATE_ARMING)
	_arming_left = ARMING_SEC


func begin_tome_teaching(spell: SpellDefinition) -> void:
	if spell == null:
		return
	if _tome_teaching and _tome_spell != null and _tome_spell.id == spell.id:
		return
	if _state != STATE_IDLE:
		end_tome_teaching()
	_free_cast = false
	_free_cast_candidates = []
	_tome_teaching = true
	_tome_spell = spell
	_mode = Mode.LEARN
	TomeDebug.log("CastSession", "begin tome teaching for '%s'" % spell.id)
	tome_teaching_changed.emit(true, spell)
	_begin_attempt(spell, Mode.LEARN)


func end_tome_teaching() -> void:
	if not _tome_teaching:
		return
	if _state == STATE_VALIDATING:
		TomeDebug.log("CastSession", "end tome teaching deferred — validation in progress")
		return
	TomeDebug.log("CastSession", "end tome teaching")
	_tome_teaching = false
	_tome_spell = null
	_coaching_retry_left = 0.0
	_abort_validation()
	_stop_mic()
	_spell = null
	_set_state(STATE_IDLE)
	tome_teaching_changed.emit(false, null)


func _begin_attempt(spell: SpellDefinition, mode: Mode) -> void:
	_spell = spell
	_mode = mode
	_recorded_samples = PackedFloat32Array()
	_transcript_words = PackedStringArray()
	_word_starts_sec = PackedFloat32Array()
	_speech_detected = false
	_silence_after_speech = 0.0
	_listen_elapsed = 0.0
	_coaching_retry_left = 0.0
	_set_state(STATE_ARMING)
	_arming_left = ARMING_SEC


func cancel() -> void:
	if _tome_teaching:
		end_tome_teaching()
		return
	if _state == STATE_IDLE:
		return
	_free_cast = false
	_free_cast_candidates = []
	_abort_validation()
	_stop_mic()
	_spell = null
	_set_state(STATE_IDLE)


## End a hold-to-cast wand session (free cast only). Release commits immediately.
func release_wand_hold() -> void:
	if not _free_cast:
		return
	match _state:
		STATE_ARMING:
			cancel()
		STATE_LISTENING:
			_begin_validation()
		_:
			pass


func _setup_microphone() -> void:
	if _mic_player != null:
		return
	_sample_rate = int(AudioServer.get_mix_rate())
	var bus_idx: int = AudioServer.get_bus_index(mic_bus_name)
	if bus_idx < 0:
		push_warning("SpellCastingSession: mic bus '%s' not found" % mic_bus_name)
		TomeDebug.log("CastSession", "mic setup FAILED: bus '%s' missing" % mic_bus_name)
		return

	for i in AudioServer.get_bus_effect_count(bus_idx):
		var effect: AudioEffect = AudioServer.get_bus_effect(bus_idx, i)
		if effect is AudioEffectCapture:
			_capture_effect = effect
			break

	_mic_player = AudioStreamPlayer.new()
	_mic_player.name = "MicInput"
	_mic_player.bus = mic_bus_name
	_mic_player.stream = AudioStreamMicrophone.new()
	add_child(_mic_player)
	TomeDebug.log(
		"CastSession",
		"mic setup ok bus=%s capture=%s input_device='%s'"
		% [mic_bus_name, _capture_effect != null, AudioServer.get_input_device()]
	)


func _set_state(next: String) -> void:
	_state = next
	TomeDebug.log("CastSession", "state -> %s (spell=%s)" % [
		next,
		_spell.id if _spell != null else "none",
	])
	state_changed.emit(_state, _spell)


func _process(delta: float) -> void:
	if not _is_local_simulation():
		return
	match _state:
		STATE_ARMING:
			_arming_left -= delta
			_emit_arming_coaching()
			if _arming_left <= 0.0:
				_begin_listening()
		STATE_LISTENING:
			_listen_left -= delta
			_listen_elapsed += delta
			_drain_capture_buffer()
			var level: float = _compute_listen_level()
			listen_level_changed.emit(level)
			_update_listen_coaching(level, delta)
			if _listen_left <= 0.0:
				_begin_validation()
		STATE_COACHING:
			_coaching_retry_left -= delta
			tome_retry_tick.emit(_coaching_retry_left)
			if _coaching_retry_left <= 0.0:
				_begin_attempt(_tome_spell, Mode.LEARN)
		_:
			pass


func _begin_listening() -> void:
	SettingsManager.stop_mic_test()
	_ensure_microphone()
	_set_state(STATE_LISTENING)
	_listen_left = MAX_LISTEN_SEC
	_listen_elapsed = 0.0
	_speech_detected = false
	_silence_after_speech = 0.0
	if _capture_effect:
		_capture_effect.clear_buffer()
	if _mic_player:
		_mic_player.play()
		TomeDebug.log("CastSession", "mic player started playing=%s" % _mic_player.playing)
	else:
		TomeDebug.log("CastSession", "mic player missing — no audio capture")
	if _free_cast:
		listen_coaching_changed.emit(_free_cast_coaching_text())
	elif _spell != null:
		listen_coaching_changed.emit(_spell.get_listen_coaching_text())
	if _capture_worker != null:
		_capture_worker.reset()
		_capture_worker.start()


func _stop_mic() -> void:
	if _mic_player and _mic_player.playing:
		_mic_player.stop()
	if _capture_worker != null:
		_capture_worker.stop()


func _drain_capture_buffer() -> void:
	if _capture_effect == null or _capture_worker == null:
		return
	var chunks_processed := 0
	while _capture_effect.can_get_buffer(512) \
			and chunks_processed < MAX_CAPTURE_CHUNKS_PER_FRAME:
		var chunk: PackedVector2Array = _capture_effect.get_buffer(512)
		var mono := PackedFloat32Array()
		mono.resize(chunk.size())
		for i in chunk.size():
			mono[i] = (chunk[i].x + chunk[i].y) * 0.5
		_capture_worker.push_chunk(mono)
		chunks_processed += 1


func _compute_listen_level() -> float:
	if _capture_worker == null:
		return 0.0
	return _capture_worker.get_listen_level()


func _emit_arming_coaching() -> void:
	if _free_cast:
		listen_coaching_changed.emit(_free_cast_coaching_text())
		return
	if _spell == null:
		return
	listen_coaching_changed.emit(_spell.get_listen_coaching_text())


func _update_listen_coaching(level: float, delta: float) -> void:
	var threshold: float = SpellAudioUtils.MIN_SPEECH_RMS
	if _free_cast:
		if level >= threshold:
			_speech_detected = true
			_silence_after_speech = 0.0
			listen_coaching_changed.emit("Good volume — say your spell!")
		elif _speech_detected:
			_silence_after_speech += delta
			listen_coaching_changed.emit("Got it — release to cast.")
		elif level >= threshold * 0.35:
			listen_coaching_changed.emit("Almost — speak a little louder.")
		else:
			listen_coaching_changed.emit(_free_cast_coaching_text())
		return

	if _spell == null:
		return

	if level >= threshold:
		_speech_detected = true
		_silence_after_speech = 0.0
		listen_coaching_changed.emit("Good volume — keep going!")
		return

	if _speech_detected:
		_silence_after_speech += delta
		listen_coaching_changed.emit("Got it — finishing up...")
		if _listen_elapsed >= MIN_LISTEN_BEFORE_END_SEC \
				and _silence_after_speech >= TRAILING_SILENCE_SEC:
			_begin_validation()
		return

	if level >= threshold * 0.35:
		listen_coaching_changed.emit("Almost — speak a little louder.")
	else:
		listen_coaching_changed.emit(_spell.get_listen_coaching_text())


func _free_cast_coaching_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for spell in _known_spells_for_player():
		if spell != null:
			parts.append('"%s"' % spell.get_incantation_text())
	if parts.is_empty():
		return "Say a spell you've learned."
	return "Say any learned incantation: " + ", ".join(parts)


func _known_spells_for_player() -> Array[SpellDefinition]:
	if _spell_loadout != null and _spell_loadout.has_method("get_known_spells"):
		var known: Array = _spell_loadout.get_known_spells()
		var spells: Array[SpellDefinition] = []
		for spell in known:
			if spell is SpellDefinition:
				spells.append(spell)
		return spells
	return _free_cast_candidates.duplicate()


func _grammar_spells_for_player(
	known_spells: Array[SpellDefinition] = []
) -> Array[SpellDefinition]:
	var spells: Array[SpellDefinition] = []
	var seen: Dictionary = {}
	var source := known_spells
	if source.is_empty():
		source = _known_spells_for_player()
	for spell in source:
		if spell == null or seen.has(spell.id):
			continue
		seen[spell.id] = true
		spells.append(spell)
	# Tome / targeted casts may include a spell not yet in the loadout.
	if _spell != null and not seen.has(_spell.id):
		spells.append(_spell)
	return spells


func _begin_validation() -> void:
	if _state != STATE_LISTENING:
		return
	_set_state(STATE_VALIDATING)
	_drain_capture_buffer()
	_stop_mic()
	var worker_samples := PackedFloat32Array()
	if _capture_worker != null:
		worker_samples = _capture_worker.take_samples()
	if worker_samples.size() > _recorded_samples.size():
		_recorded_samples = worker_samples
	TomeDebug.log(
		"CastSession",
		"validating samples=%d sample_rate=%d stub=%s"
		% [
			_recorded_samples.size(),
			_sample_rate,
			str(_validator.use_stub) if _validator != null else "no_validator",
		]
	)

	if _validator == null:
		_finish_fail("Voice validator not configured")
		return

	if _transcript_words.is_empty() and _validator.use_stub:
		_inject_stub_transcript_for_candidates()
	if not SpeechSttLoader.ensure_ready():
		TomeDebug.log(
			"CastSession",
			"speech STT not ready: %s"
			% SpeechSttLoader.get_status()
		)
	if _try_fail_missing_stt():
		return

	_ensure_validation_runner()
	var mode := "free_cast" if _free_cast else "targeted"
	var known_spells := _known_spells_for_player()
	if _free_cast:
		_free_cast_candidates = known_spells
	var grammar_spells := _grammar_spells_for_player(known_spells)
	if not _validation_runner.start(
		mode,
		_recorded_samples,
		_sample_rate,
		_validator.use_stub,
		_spell,
		_free_cast_candidates,
		_transcript_words,
		_word_starts_sec,
		grammar_spells
	):
		_finish_fail("Could not start spell validation")
		return
	TomeDebug.log(
		"CastSession",
		"validation started (mode=%s known=%d grammar=%d)"
		% [mode, known_spells.size(), grammar_spells.size()]
	)


func _apply_validation_payload(payload: Dictionary) -> bool:
	var parsed := SpellValidationCodec.parse_worker_response(payload)
	if not bool(parsed.get("ok", false)):
		var error_text := str(parsed.get("error", "Validation failed"))
		TomeDebug.log("CastSession", "validation FAILED: %s" % error_text)
		_finish_fail(error_text)
		return false

	var transcript_words: PackedStringArray = parsed.get(
		"transcript_words", PackedStringArray()
	)
	if not transcript_words.is_empty():
		_transcript_words = transcript_words
		_word_starts_sec = parsed.get("word_starts_sec", PackedFloat32Array())
		TomeDebug.log("CastSession", 'stt transcript="%s"' % " ".join(_transcript_words))

	var spell_id := str(parsed.get("spell_id", ""))
	if not spell_id.is_empty() and _free_cast:
		for candidate in _free_cast_candidates:
			if candidate != null and candidate.id == spell_id:
				_spell = candidate
				break

	_free_cast_debug_lines = parsed.get("debug_lines", PackedStringArray())
	var result: CastValidationResult = parsed.get("result")
	if result == null:
		_finish_fail("Validation failed unexpectedly")
		return false

	_log_free_cast_debug()
	_log_validation_speech(result)
	if result.passed:
		TomeDebug.log("CastSession", "validation PASSED")
		_finish_success(result)
	else:
		TomeDebug.log("CastSession", "validation FAILED: %s" % result.failure_reason)
		_finish_fail(result.failure_reason, result)
	return true


func _on_validation_runner_finished(_payload: Dictionary) -> void:
	if _state != STATE_VALIDATING:
		return
	_apply_validation_payload(_payload)


func _abort_validation() -> void:
	_ensure_validation_runner()
	_validation_runner.abort()


func _finish_success(validation: CastValidationResult = null) -> void:
	var mode_name: String = "learn" if _mode == Mode.LEARN else "cast"
	var finished_spell := _spell
	var was_tome := _tome_teaching
	if was_tome:
		_tome_teaching = false
		_tome_spell = null
	cast_succeeded.emit(finished_spell, mode_name, validation)
	_spell = null
	_free_cast = false
	_free_cast_candidates = []
	_set_state(STATE_IDLE)
	if was_tome:
		tome_teaching_changed.emit(false, null)


func _finish_fail(reason: String, partial: CastValidationResult = null) -> void:
	var failed_spell := _spell
	if _tome_teaching and _tome_spell != null:
		cast_failed.emit(failed_spell, reason, partial)
		_spell = _tome_spell
		_coaching_retry_left = TOME_RETRY_SEC
		_set_state(STATE_COACHING)
		return
	cast_failed.emit(failed_spell, reason, partial)
	_spell = null
	_free_cast = false
	_free_cast_candidates = []
	_set_state(STATE_IDLE)


func _try_fail_missing_stt() -> bool:
	if _validator.use_stub:
		return false
	var issue := SpellSttConfigScript.get_runtime_issue()
	if issue.is_empty():
		return false
	var partial := CastValidationResult.fail(issue)
	if _spell != null:
		partial.incantation_text = _spell.get_incantation_text()
	elif _tome_spell != null:
		partial.incantation_text = _tome_spell.get_incantation_text()
	CastValidationResult.apply_transcript(partial, _transcript_words)
	TomeDebug.log("CastSession", "validation FAILED: %s" % issue)
	_finish_fail(issue, partial)
	return true


func _inject_stub_transcript_for_candidates() -> void:
	if _free_cast:
		if _free_cast_candidates.size() == 1 and _free_cast_candidates[0] != null:
			_transcript_words = _free_cast_candidates[0].incantation_words.duplicate()
			TomeDebug.log(
				"CastSession",
				'stub transcript="%s"' % " ".join(_transcript_words)
			)
		return
	if _spell != null:
		_transcript_words = _spell.incantation_words.duplicate()
		TomeDebug.log(
			"CastSession",
			'stub transcript="%s"' % " ".join(_transcript_words)
		)


func _log_free_cast_debug() -> void:
	if _free_cast_debug_lines.is_empty():
		return
	for line in _free_cast_debug_lines:
		TomeDebug.log("FreeCastMatch", line)
	_free_cast_debug_lines = PackedStringArray()


func _log_validation_speech(result: CastValidationResult) -> void:
	if result == null:
		return
	if result.heard_text.is_empty() and result.incantation_text.is_empty():
		return
	TomeDebug.log("CastSession", "%s (passed=%s)" % [result.get_speech_match_line(), result.passed])


func _is_local_simulation() -> bool:
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer is OfflineMultiplayerPeer:
		return true
	var player_node: Node = get_parent()
	if player_node != null:
		return player_node.is_multiplayer_authority()
	return is_multiplayer_authority()


func _ensure_microphone() -> void:
	if not _is_local_simulation():
		return
	if _mic_player != null and _capture_effect != null:
		return
	_setup_microphone()
