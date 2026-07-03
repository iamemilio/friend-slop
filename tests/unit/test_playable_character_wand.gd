extends RefCounted

const PlayableCharacterScript := preload("res://scripts/characters/playable_character.gd")
const SpellCastingSessionScript := preload("res://scripts/spells/spell_casting_session.gd")
const FireballSpell := preload("res://resources/spells/fireball.tres")


func run(tree: SceneTree) -> int:
	var failures := 0
	failures += _test_release_ignored_without_press(tree)
	failures += _test_release_commits_while_holding(tree)
	return failures


func _make_character(tree: SceneTree) -> PlayableCharacter:
	var player := PlayableCharacterScript.new()
	var session: SpellCastingSession = SpellCastingSessionScript.new()
	session.name = "SpellCastingSession"
	player.add_child(session)
	tree.root.add_child(player)
	player.configure_interaction(null, session, null, null)
	return player


func _free_character(player: PlayableCharacter) -> void:
	player.queue_free()


func _test_release_ignored_without_press(tree: SceneTree) -> int:
	var player := _make_character(tree)
	var session := player._casting_session
	var validator := VoiceSpellValidator.new()
	validator.use_stub = true
	session.configure(validator)
	session.start_free_cast([FireballSpell])
	for _i in 30:
		if session.get_state() == SpellCastingSession.STATE_LISTENING:
			break
		session._process(0.016)

	player._on_wand_button_released()

	if session.get_state() != SpellCastingSession.STATE_LISTENING:
		_free_character(player)
		push_error("Expected release without prior press to leave session listening")
		return 1

	_free_character(player)
	return 0


func _test_release_commits_while_holding(tree: SceneTree) -> int:
	var player := _make_character(tree)
	var session := player._casting_session
	var validator := VoiceSpellValidator.new()
	validator.use_stub = true
	session.configure(validator)

	var succeeded := false
	session.cast_succeeded.connect(func(_spell, _mode, _validation) -> void:
		succeeded = true
	)

	player._on_wand_button_pressed()
	for _i in 30:
		if session.get_state() == SpellCastingSession.STATE_LISTENING:
			break
		session._process(0.016)
	session._recorded_samples = PackedFloat32Array()
	for _i in 24000:
		session._recorded_samples.append(0.04)
	session._sample_rate = 48000
	player._on_wand_button_released()

	for _attempt in 300:
		if session.get_state() != SpellCastingSession.STATE_VALIDATING:
			break
		session._process(0.016)
		var runner := session.get_node_or_null("SpellValidationRunner") as SpellValidationRunner
		if runner != null:
			runner._process(0.0)

	_free_character(player)

	if not succeeded:
		push_error("Expected press-hold-release to commit a free cast")
		return 1
	return 0
