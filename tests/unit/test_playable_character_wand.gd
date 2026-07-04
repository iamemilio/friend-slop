extends RefCounted

const PlayableCharacterScript := preload("res://scripts/characters/playable_character.gd")
const PlayerWandScript := preload("res://scripts/player/player_wand.gd")
const SpellCastingSessionScript := preload("res://scripts/spells/spell_casting_session.gd")
const DeliveryObjectiveScript := preload("res://scripts/objectives/delivery_objective.gd")
const StateScript := preload("res://scripts/objectives/delivery_objective_state.gd")
const FireballSpell := preload("res://resources/spells/fireball.tres")


func run(tree: SceneTree) -> int:
	var failures := 0
	failures += _test_release_ignored_without_press(tree)
	failures += _test_release_commits_while_holding(tree)
	failures += _test_free_cast_blocked_while_carrying_relic(tree)
	failures += _test_wand_glow_uses_tip_spotlight_and_world_light_mask(tree)
	failures += _test_wand_tip_brightness_tracks_listen_level(tree)
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


func _test_free_cast_blocked_while_carrying_relic(tree: SceneTree) -> int:
	var player := _make_character(tree)
	var session := player._casting_session
	var objective := DeliveryObjectiveScript.new()
	objective.state = StateScript.new()
	objective.state.phase = StateScript.Phase.CARRIED
	objective.state.carrier = player
	objective.add_to_group("delivery_objective")
	tree.root.add_child(objective)

	player._on_wand_button_pressed()

	objective.queue_free()
	_free_character(player)

	if session.get_state() != SpellCastingSession.STATE_IDLE:
		push_error("Expected wand cast to stay idle while carrying relic")
		return 1
	return 0


func _test_wand_glow_uses_tip_spotlight_and_world_light_mask(tree: SceneTree) -> int:
	var failures := 0
	var wand := PlayerWandScript.new()
	tree.root.add_child(wand)

	var cast_origin := wand.get_node_or_null("CastOrigin") as Marker3D
	if cast_origin == null:
		failures += 1
		push_error("Expected wand cast origin marker at the tip")
	else:
		var tip_spot := cast_origin.get_node_or_null("TipSpotLight") as SpotLight3D
		if tip_spot == null or tip_spot.light_cull_mask != PlayerWandScript.WORLD_LIGHT_CULL_MASK:
			failures += 1
			push_error("Expected wand tip spotlight to illuminate world geometry only")
		elif tip_spot.shadow_caster_mask != PlayerWandScript.WORLD_LIGHT_CULL_MASK:
			failures += 1
			push_error("Expected wand tip spotlight to ignore player-layer shadow casters")
		elif not tip_spot.shadow_enabled:
			failures += 1
			push_error("Expected wand tip spotlight to cast shadows")
		else:
			wand.set_armed(true)
			if tip_spot.spot_range < 6.0:
				failures += 1
				push_error("Expected wand tip spotlight to reach nearby maze surfaces")
			var tip := wand.get_node_or_null("Tip") as MeshInstance3D
			if tip == null or tip.global_position.distance_to(cast_origin.global_position) > 0.08:
				failures += 1
				push_error("Expected wand light origin to stay at the tip orb")

	wand.queue_free()
	return failures


func _test_wand_tip_brightness_tracks_listen_level(tree: SceneTree) -> int:
	var wand := PlayerWandScript.new()
	tree.root.add_child(wand)
	wand.set_armed(true)

	var tip := wand.get_node_or_null("Tip") as MeshInstance3D
	if tip == null or not (tip.material_override is StandardMaterial3D):
		wand.queue_free()
		push_error("Expected wand tip material for listen-level brightness")
		return 1

	wand.set_listen_level(0.0)
	var quiet_mat: StandardMaterial3D = tip.material_override
	var quiet_emission := quiet_mat.emission_energy_multiplier

	wand.set_listen_level(PlayerWandScript.LISTEN_LEVEL_REFERENCE)
	var loud_mat: StandardMaterial3D = tip.material_override
	var loud_emission := loud_mat.emission_energy_multiplier

	if loud_emission <= quiet_emission + 2.0:
		wand.queue_free()
		push_error(
			"Expected wand tip to brighten with mic level (quiet=%.2f loud=%.2f)"
			% [quiet_emission, loud_emission]
		)
		return 1
	if tip.scale.x <= 1.01:
		wand.queue_free()
		push_error("Expected wand tip to swell slightly at full listen level")
		return 1

	wand.queue_free()
	return 0
