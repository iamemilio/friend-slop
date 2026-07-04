extends RefCounted

const PlayableCharacterScene := preload("res://scenes/characters/playable_character.tscn")
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
	failures += _test_wand_cast_feedback_is_emission_only(tree)
	failures += _test_wand_tip_brightness_tracks_listen_level(tree)
	failures += _test_wand_flame_glow_after_cast(tree)
	return failures


func _make_character(tree: SceneTree) -> PlayableCharacter:
	var player: PlayableCharacter = PlayableCharacterScene.instantiate()
	tree.root.add_child(player)
	player.configure_interaction(null, player.casting_session, null, null)
	return player


func _signal_latch() -> Dictionary:
	return {"hit": false}


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

	var succeeded := _signal_latch()
	session.cast_succeeded.connect(func(_spell, _mode, _validation) -> void:
		succeeded["hit"] = true
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

	for _attempt in 3000:
		session._process(0.016)
		var runner := session.get_node_or_null("SpellValidationRunner") as SpellValidationRunner
		if runner != null:
			runner._process(0.0)
		if session.get_state() == SpellCastingSession.STATE_IDLE:
			break

	_free_character(player)

	if not bool(succeeded["hit"]):
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


func _test_wand_cast_feedback_is_emission_only(tree: SceneTree) -> int:
	var failures := 0
	var wand := PlayerWandScript.new()
	tree.root.add_child(wand)

	var cast_origin := wand.get_node_or_null("CastOrigin") as Marker3D
	if cast_origin == null:
		failures += 1
		push_error("Expected wand cast origin marker at the tip")
	else:
		if cast_origin.get_node_or_null("TipSpotLight") != null:
			failures += 1
			push_error("Expected casting feedback to avoid a world tip spotlight")
		var flashlight := cast_origin.get_node_or_null("FlashlightBeam") as SpotLight3D
		if flashlight == null or flashlight.light_cull_mask != PlayerWandScript.WORLD_LIGHT_CULL_MASK:
			failures += 1
			push_error("Expected wand flashlight to illuminate world geometry only")
		elif flashlight.shadow_caster_mask != PlayerWandScript.WORLD_LIGHT_CULL_MASK:
			failures += 1
			push_error("Expected wand flashlight to ignore player-layer shadow casters")
		elif flashlight.shadow_enabled:
			failures += 1
			push_error("Expected wand flashlight to skip shadows for a soft cone beam")
		elif flashlight.spot_range < 10.0:
			failures += 1
			push_error("Expected wand flashlight cone to reach nearby maze surfaces")
		elif flashlight.spot_angle < deg_to_rad(70.0):
			failures += 1
			push_error("Expected wand flashlight to use a wide cone")
		elif flashlight.light_size <= 0.0:
			failures += 1
			push_error("Expected wand flashlight to use light_size for a soft beam")
		elif cast_origin.get_node_or_null("FlashlightSpill") != null:
			failures += 1
			push_error("Expected wand flashlight to use a single cone, not omni spill")
		else:
			var tip := wand.get_node_or_null("Tip") as MeshInstance3D
			if tip == null or tip.global_position.distance_to(cast_origin.global_position) > 0.08:
				failures += 1
				push_error("Expected wand cast origin to stay at the tip orb")

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


func _test_wand_flame_glow_after_cast(tree: SceneTree) -> int:
	var wand := PlayerWandScript.new()
	tree.root.add_child(wand)
	wand.set_flame_glow_enabled(true)

	var tip := wand.get_node_or_null("Tip") as MeshInstance3D
	if tip == null or not (tip.material_override is StandardMaterial3D):
		wand.queue_free()
		push_error("Expected wand tip material for flame glow")
		return 1

	var mat: StandardMaterial3D = tip.material_override
	if mat.emission_energy_multiplier < 2.0:
		wand.queue_free()
		push_error("Expected flame glow to brighten wand tip emission")
		return 1
	if mat.emission.r < 0.5 or mat.emission.g > 0.2:
		wand.queue_free()
		push_error("Expected flame glow to use a deep red emission color")
		return 1

	wand.queue_free()
	return 0
