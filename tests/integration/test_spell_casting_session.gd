class_name TestSpellCastingSession
extends RefCounted

## Integration tests for SpellCastingSession state machine (stub mode, no real mic).
## Requires a SceneTree so nodes can be added; drives _process directly.

const FireballSpell := preload("res://resources/spells/fireball.tres")
const WorkerScript := preload("res://scripts/spells/spell_validation_worker.gd")
const SpellSttConfigScript := preload("res://scripts/spells/spell_stt_config.gd")


func run(tree: SceneTree) -> int:
	var failures := 0
	failures += _test_stub_tome_teaching_completes(tree)
	failures += _test_validation_runs_async_without_blocking_first_poll(tree)
	failures += _test_offline_session_runs_process(tree)
	failures += _test_non_stub_fails_before_validation_when_stt_unavailable(tree)
	failures += _test_cast_fireball_stub_succeeds(tree)
	failures += _test_cast_fireball_heard_transcript_succeeds(tree)
	failures += _test_cast_fireball_wrong_words_fails(tree)
	return failures


func _pump_session_frame(session: SpellCastingSession) -> void:
	session._process(0.016)
	var runner := session.get_node_or_null("SpellValidationRunner") as SpellValidationRunner
	if runner != null:
		runner._process(0.0)


func _drive_listen_and_validate(
	session: SpellCastingSession,
	transcript_words: PackedStringArray = PackedStringArray()
) -> void:
	session._process(0.51)
	session._recorded_samples = _loud_samples(0.5)
	session._sample_rate = 48000
	if not transcript_words.is_empty():
		session._transcript_words = transcript_words
	session._begin_validation()
	for _attempt in 300:
		if session.get_state() != SpellCastingSession.STATE_VALIDATING:
			break
		_pump_session_frame(session)


func _loud_samples(duration_sec: float, sample_rate: int = 48000) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	for _i in int(sample_rate * duration_sec):
		samples.append(0.04)
	return samples


func _make_session(tree: SceneTree) -> SpellCastingSession:
	var cast_session_script := load("res://scripts/spells/spell_casting_session.gd") as GDScript
	var player := CharacterBody3D.new()
	var session: SpellCastingSession = cast_session_script.new()
	player.add_child(session)
	tree.root.add_child(player)
	return session


func _free_session(session: SpellCastingSession) -> void:
	var player := session.get_parent()
	if player != null:
		player.queue_free()


func _test_stub_tome_teaching_completes(tree: SceneTree) -> int:
	var session := _make_session(tree)
	var validator := VoiceSpellValidator.new()
	validator.use_stub = true
	session.configure(validator, null)

	var succeeded := false
	session.cast_succeeded.connect(func(_spell, _mode, _validation) -> void:
		succeeded = true
	)

	session.begin_tome_teaching(FireballSpell)
	session._process(0.51)
	session._recorded_samples = _loud_samples(0.5)
	session._sample_rate = 48000
	session._begin_validation()
	for _attempt in 300:
		if session.get_state() != SpellCastingSession.STATE_VALIDATING:
			break
		_pump_session_frame(session)

	_free_session(session)

	if not succeeded:
		push_error("Expected stub tome teaching cast to emit cast_succeeded")
		return 1
	return 0


func _test_validation_runs_async_without_blocking_first_poll(tree: SceneTree) -> int:
	WorkerScript.test_delay_sec = 0.08
	var session := _make_session(tree)
	var validator := VoiceSpellValidator.new()
	validator.use_stub = true
	session.configure(validator, null)

	var succeeded := false
	session.cast_succeeded.connect(func(_spell, _mode, _validation) -> void:
		succeeded = true
	)

	session.begin_tome_teaching(FireballSpell)
	session._process(0.51)
	session._recorded_samples = _loud_samples(0.5)
	session._sample_rate = 48000
	session._begin_validation()

	if session.get_state() != SpellCastingSession.STATE_VALIDATING:
		WorkerScript.test_delay_sec = 0.0
		_free_session(session)
		push_error("Expected validating state after _begin_validation")
		return 1

	session._process(0.0)
	var runner := session.get_node_or_null("SpellValidationRunner") as SpellValidationRunner
	if runner != null:
		runner._process(0.0)
	if succeeded:
		WorkerScript.test_delay_sec = 0.0
		_free_session(session)
		push_error("Expected first poll not to finish validation while worker is delayed")
		return 1
	if session.get_state() != SpellCastingSession.STATE_VALIDATING:
		WorkerScript.test_delay_sec = 0.0
		_free_session(session)
		push_error("Expected session to remain validating on first poll")
		return 1

	for _attempt in 300:
		if session.get_state() != SpellCastingSession.STATE_VALIDATING:
			break
		_pump_session_frame(session)

	WorkerScript.test_delay_sec = 0.0
	_free_session(session)

	if not succeeded:
		push_error("Expected async validation to eventually emit cast_succeeded")
		return 1
	return 0


func _test_cast_fireball_stub_succeeds(tree: SceneTree) -> int:
	var session := _make_session(tree)
	var validator := VoiceSpellValidator.new()
	validator.use_stub = true
	session.configure(validator, null)

	var cast_spell: SpellDefinition = null
	var cast_mode := ""
	var validation: CastValidationResult = null
	session.cast_succeeded.connect(
		func(spell: SpellDefinition, mode: String, result: CastValidationResult) -> void:
			cast_spell = spell
			cast_mode = mode
			validation = result
	)

	session.start(FireballSpell, SpellCastingSession.Mode.CAST)
	_drive_listen_and_validate(session)
	_free_session(session)

	if cast_spell == null or cast_spell.id != "fireball":
		push_error("Expected stub cast to succeed with fireball spell")
		return 1
	if cast_mode != "cast":
		push_error("Expected cast mode 'cast', got: %s" % cast_mode)
		return 1
	if validation == null or not validation.passed:
		push_error("Expected successful fireball validation")
		return 1
	if validation.heard_text != "fireball":
		push_error("Expected heard incantation 'fireball', got: %s" % validation.heard_text)
		return 1
	return 0


func _test_cast_fireball_heard_transcript_succeeds(tree: SceneTree) -> int:
	if not SpellSttConfigScript.get_runtime_issue().is_empty():
		return 0

	var session := _make_session(tree)
	var validator := VoiceSpellValidator.new()
	validator.use_stub = false
	session.configure(validator, null)

	var cast_spell: SpellDefinition = null
	var validation: CastValidationResult = null
	session.cast_succeeded.connect(
		func(spell: SpellDefinition, _mode: String, result: CastValidationResult) -> void:
			cast_spell = spell
			validation = result
	)

	session.start(FireballSpell, SpellCastingSession.Mode.CAST)
	_drive_listen_and_validate(session, PackedStringArray(["fireball"]))
	_free_session(session)

	if cast_spell == null or cast_spell.id != "fireball":
		push_error("Expected non-stub cast with 'fireball' transcript to succeed")
		return 1
	if validation == null or not validation.passed:
		push_error(
			"Expected fireball validation to pass, reason: %s"
			% (validation.failure_reason if validation != null else "null")
		)
		return 1
	if validation.heard_text != "fireball":
		push_error("Expected heard text 'fireball', got: %s" % validation.heard_text)
		return 1
	return 0


func _test_cast_fireball_wrong_words_fails(tree: SceneTree) -> int:
	if not SpellSttConfigScript.get_runtime_issue().is_empty():
		return 0

	var session := _make_session(tree)
	var validator := VoiceSpellValidator.new()
	validator.use_stub = false
	session.configure(validator, null)

	var failed := false
	var fail_reason := ""
	session.cast_failed.connect(func(_spell, reason, _partial) -> void:
		failed = true
		fail_reason = reason
	)

	session.start(FireballSpell, SpellCastingSession.Mode.CAST)
	_drive_listen_and_validate(session, PackedStringArray(["show", "me"]))
	_free_session(session)

	if not failed:
		push_error("Expected fireball cast to fail when incantation was 'show me'")
		return 1
	if fail_reason.is_empty():
		push_error("Expected a failure reason for wrong incantation")
		return 1
	return 0


func _test_offline_session_runs_process(tree: SceneTree) -> int:
	var session := _make_session(tree)
	var validator := VoiceSpellValidator.new()
	validator.use_stub = true
	session.configure(validator, null)

	var prev_peer: MultiplayerPeer = tree.multiplayer.multiplayer_peer
	tree.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	session.begin_tome_teaching(FireballSpell)
	var state_before := session.get_state()
	session._process(0.51)
	var state_after := session.get_state()

	tree.multiplayer.multiplayer_peer = prev_peer
	_free_session(session)

	if state_before != "arming":
		push_error("Expected arming state at tome teaching start")
		return 1
	if state_after != "listening":
		push_error(
			"Expected offline cast session to advance to listening, got: %s"
			% state_after
		)
		return 1
	return 0


func _test_non_stub_fails_before_validation_when_stt_unavailable(tree: SceneTree) -> int:
	var runtime_issue := SpellSttConfigScript.get_runtime_issue()
	if runtime_issue.is_empty():
		return 0

	var session := _make_session(tree)
	var validator := VoiceSpellValidator.new()
	validator.use_stub = false
	session.configure(validator, null)

	var fail_reason := ""
	session.cast_failed.connect(func(_spell, reason, _partial) -> void:
		fail_reason = reason
	)

	session.begin_tome_teaching(FireballSpell)
	session._process(0.51)
	session._recorded_samples = _loud_samples(0.5)
	session._sample_rate = 48000
	session._begin_validation()

	var state := session.get_state()
	_free_session(session)

	if fail_reason != runtime_issue:
		push_error(
			"Expected cast to fail at STT preflight with runtime issue, got: %s"
			% fail_reason
		)
		return 1
	if state != "idle":
		push_error(
			"Expected idle state after STT preflight failure, got: %s" % state
		)
		return 1
	return 0
