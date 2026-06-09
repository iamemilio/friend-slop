extends Node3D

const PlayerSpawnLayoutScript := preload("res://scripts/player_spawn_layout.gd")
const SpellEffectSyncScript := preload("res://scripts/spells/spell_effect_sync.gd")

var _game_won: bool = false
var _learn_confirm_pending: bool = false
var _local_player: CharacterBody3D

@onready var maze: Node3D = $MazeGenerator
@onready var players_root: Node3D = $Players
@onready var smoke_trails: SmokeTrailManager = $SmokeTrails
@onready var discoverable_spawner = $DiscoverableSpawner
@onready var spell_registry: SpellRegistry = $SpellRegistry
@onready var game_hud: CanvasLayer = $GameHUD
@onready var voice_validator = $VoiceSpellValidator
@onready var pause_menu = $PauseMenu


func _ready() -> void:
	_apply_voice_settings()
	SettingsManager.settings_applied.connect(_apply_voice_settings)
	maze.maze_ready.connect(_on_maze_ready)
	maze.exit_reached.connect(_on_exit_reached)
	pause_menu.quit_to_menu_requested.connect(_on_quit_to_menu)

	if GameState.is_multiplayer:
		multiplayer.peer_connected.connect(_on_peer_connected)
		var role_name := RoleAssignment.role_label(GameState.get_local_role())
		var phase_name := MatchState.phase_to_string(MatchStateManager.get_phase())
		TomeDebug.log(
			"Main",
			"Match start — role=%s phase=%s seed=%s"
			% [role_name, phase_name, GameState.run_seed]
		)
		MatchStateManager.log_summary()

	TrailRegistry.reset()

	await _ensure_speech_stt_ready()

	NetworkManager.spawn_players(
		players_root,
		_configure_local_player
	)


func _ensure_speech_stt_ready() -> void:
	if SettingsManager.voice_use_stub:
		TomeDebug.log("Main", "Speech STT skipped (Voice Stub enabled)")
		return
	if SpeechSttLoader.is_loading():
		TomeDebug.log("Main", "Waiting for speech model to load...")
		await SpeechSttLoader.loading_finished
	elif not SpeechSttLoader.is_ready():
		SpeechSttLoader.ensure_ready()
	if SpeechSttLoader.is_ready():
		TomeDebug.log("Main", "Speech STT ready")
	else:
		TomeDebug.log("Main", "Speech STT unavailable: %s" % SpeechSttLoader.get_status())


func _apply_voice_settings() -> void:
	voice_validator.use_stub = SettingsManager.voice_use_stub


func _configure_local_player(player: CharacterBody3D) -> void:
	_local_player = player
	_wire_spell_system(player)


func _wire_spell_system(player: CharacterBody3D) -> void:
	var spell_book: SpellBook = player.get_spell_book()
	var casting_session: SpellCastingSession = player.get_casting_session()
	var effect_applier: Node = player.get_effect_applier()

	spell_book.configure(spell_registry.get_all_spells())
	_apply_role_starting_spells(spell_book)
	game_hud.configure(spell_book, casting_session)
	casting_session.configure(voice_validator, spell_book)
	casting_session.add_to_group("casting_session")
	casting_session.state_changed.connect(_on_cast_state_changed)
	casting_session.cast_succeeded.connect(_on_cast_succeeded)
	casting_session.cast_failed.connect(_on_cast_failed)
	casting_session.tome_teaching_changed.connect(_on_tome_teaching_changed)
	player.configure_interaction(spell_book, casting_session, game_hud, effect_applier)


func _apply_role_starting_spells(spell_book: SpellBook) -> void:
	var peer_id := 1
	if GameState.is_multiplayer:
		peer_id = multiplayer.get_unique_id()
	var config := GameState.get_character_config_for_peer(peer_id)
	if GameState.is_multiplayer and config.role != GameState.PlayerRole.WARDEN:
		return
	for spell_id in config.get_starting_spell_ids():
		spell_book.learn(spell_id)


func _on_peer_connected(peer_id: int) -> void:
	NetworkManager.spawn_player_for_peer(
		peer_id,
		players_root,
		_configure_local_player
	)


func _on_quit_to_menu() -> void:
	SettingsManager.stop_mic_test()
	NetworkManager.disconnect_session()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _on_maze_ready(
	_spawn_position: Vector3,
	_exit_position: Vector3,
	spawn_cell: Vector2i,
	exit_cell: Vector2i
) -> void:
	var players: Array[CharacterBody3D] = []
	for child in players_root.get_children():
		if child is CharacterBody3D:
			players.append(child)
	players.sort_custom(func(a: CharacterBody3D, b: CharacterBody3D) -> bool:
		return a.player_index < b.player_index
	)

	var spawn_positions: Array[Vector3] = PlayerSpawnLayoutScript.compute_positions(
		spawn_cell,
		maze.get_wall_grid(),
		maze.maze_width,
		maze.maze_height,
		Callable(maze, "cell_to_world"),
		players.size()
	) as Array[Vector3]
	for i in players.size():
		var player := players[i]
		player.global_position = spawn_positions[i]
		player.velocity = Vector3.ZERO

	if discoverable_spawner.run_config == null:
		return

	var placement_seed: int = DiscoverableSpawnPlan.derive_seed(GameState.run_seed)
	var wall_grid: Array = maze.get_wall_grid()
	var placements: Array[DiscoverablePlacement] = DiscoverableSpawnPlan.compute(
		wall_grid,
		maze.maze_width,
		maze.maze_height,
		spawn_cell,
		exit_cell,
		discoverable_spawner.run_config,
		placement_seed
	)
	discoverable_spawner.spawn_from_plan(
		placements,
		Callable(maze, "cell_to_world"),
		wall_grid
	)


func _get_casting_session() -> SpellCastingSession:
	if _local_player == null:
		return null
	return _local_player.get_casting_session()


func _get_spell_book() -> SpellBook:
	if _local_player == null:
		return null
	return _local_player.get_spell_book()


func _get_effect_applier() -> Node:
	if _local_player == null:
		return null
	return _local_player.get_effect_applier()


func apply_synced_spell_cast(
	caster_peer_id: int,
	spell_id: String,
	params: Dictionary
) -> void:
	var player := players_root.get_node_or_null(str(caster_peer_id)) as CharacterBody3D
	if player == null:
		TomeDebug.log(
			"Main",
			"synced spell cast skipped: player %d not found" % caster_peer_id
		)
		return
	var spell := spell_registry.get_spell(spell_id)
	if spell == null:
		TomeDebug.log("Main", "synced spell cast skipped: unknown spell '%s'" % spell_id)
		return
	var applier := player.get_effect_applier() as SpellEffectApplier
	if applier == null:
		return
	TomeDebug.log(
		"Main",
		"synced spell cast peer=%d spell='%s' effect='%s'"
		% [caster_peer_id, spell_id, spell.effect_id]
	)
	applier.apply_synced_cast(player, spell, params)


func _on_cast_state_changed(state: String, spell: SpellDefinition) -> void:
	var casting_session := _get_casting_session()
	if casting_session == null:
		return
	if state == SpellCastingSession.STATE_IDLE:
		if _learn_confirm_pending or casting_session.is_tome_teaching():
			return
		game_hud.hide_casting()
		return
	if casting_session.is_free_cast() and not casting_session.is_tome_teaching():
		return
	game_hud.show_casting_state(
		state,
		spell,
		casting_session.is_tome_teaching(),
		casting_session.is_free_cast()
	)


func _on_tome_teaching_changed(active: bool, _spell: SpellDefinition) -> void:
	if not active and not _learn_confirm_pending:
		game_hud.hide_casting()


func _on_cast_succeeded(
	spell: SpellDefinition,
	mode: String,
	validation: CastValidationResult = null
) -> void:
	var spell_book := _get_spell_book()
	var casting_session := _get_casting_session()
	var effect_applier := _get_effect_applier()
	if spell_book == null or casting_session == null or effect_applier == null:
		return

	TomeDebug.log(
		"Main",
		"cast_succeeded mode=%s spell='%s'"
		% [mode, spell.id if spell != null else ""]
	)
	if validation != null and (
		not validation.heard_text.is_empty() or not validation.incantation_text.is_empty()
	):
		TomeDebug.log("Main", validation.get_speech_match_line())
	if mode == "learn":
		_learn_confirm_pending = true
		spell_book.learn(spell.id)
		_consume_tome_for_spell(spell.id)
		game_hud.show_spell_learned(spell, validation)
		await get_tree().create_timer(3.5).timeout
		_learn_confirm_pending = false
		game_hud.hide_casting()
	else:
		var params := SpellEffectSyncScript.build_params(spell, _local_player)
		var effect_duration := SpellEffectSyncScript.get_effect_duration_sec(spell, params)
		effect_applier.cast_spell(_local_player, spell)
		spell_book.begin_active_effect(spell.id, effect_duration)
		if effect_duration > 0.0:
			game_hud.show_spell_active(spell.id, effect_duration)
		if casting_session.is_free_cast():
			return
		game_hud.show_cast_success(spell, validation)
		await get_tree().create_timer(2.0).timeout
		game_hud.hide_casting()


func _on_cast_failed(
	_spell: SpellDefinition,
	reason: String,
	partial: CastValidationResult
) -> void:
	var spell_book := _get_spell_book()
	var casting_session := _get_casting_session()
	if spell_book == null or casting_session == null:
		return

	TomeDebug.log(
		"Main",
		"cast_failed spell='%s' reason='%s'"
		% [_spell.id if _spell != null else "", reason]
	)
	if partial != null and (
		not partial.heard_text.is_empty() or not partial.incantation_text.is_empty()
	):
		TomeDebug.log("Main", partial.get_speech_match_line())
	var from_tome: bool = casting_session.is_tome_teaching()
	var free_cast: bool = casting_session.is_free_cast()
	if not free_cast:
		if partial != null:
			game_hud.show_cast_feedback(partial, from_tome)
		else:
			game_hud.show_cast_feedback(CastValidationResult.fail(reason), from_tome)
	if not from_tome and _spell != null:
		var active_left: float = spell_book.effect_active_remaining(_spell.id)
		if active_left > 0.0:
			game_hud.show_cooldown_blocked(_spell, active_left, true)
		elif spell_book.cooldown_remaining(_spell.id) > 0.0:
			game_hud.show_cooldown_blocked(_spell, spell_book.cooldown_remaining(_spell.id))
	if from_tome:
		return
	if free_cast:
		return
	await get_tree().create_timer(3.0).timeout
	game_hud.hide_casting()


func _consume_tome_for_spell(spell_id: String) -> void:
	for child in discoverable_spawner.get_children():
		if child.has_method("get_spell"):
			var tome_spell: SpellDefinition = child.get_spell()
			if tome_spell != null and tome_spell.id == spell_id:
				if child.has_method("consume_with_vfx"):
					child.consume_with_vfx()
				else:
					child.queue_free()
				return


func _on_exit_reached(player: Node3D) -> void:
	if _game_won:
		return
	if GameState.is_multiplayer:
		if player.is_multiplayer_authority():
			_report_race_won.rpc_id(1, multiplayer.get_unique_id())
		return
	_trigger_victory()


@rpc("any_peer", "call_local", "reliable")
func _report_race_won(winner_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_broadcast_victory.rpc(winner_peer_id)


@rpc("authority", "call_local", "reliable")
func _broadcast_victory(winner_peer_id: int) -> void:
	if _game_won:
		return
	_game_won = true
	if winner_peer_id == multiplayer.get_unique_id():
		GameState.local_player_form = GameState.PlayerForm.HUMAN
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://scenes/victory.tscn")


func _trigger_victory() -> void:
	_game_won = true
	GameState.local_player_form = GameState.PlayerForm.HUMAN
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/victory.tscn")
