class_name TestGameState
extends RefCounted

const GameStateScript := preload("res://scripts/game_state.gd")


func run() -> int:
	var failures := 0
	failures += _test_reset_for_new_game()
	failures += _test_prepare_multiplayer_game()
	failures += _test_get_snail_color_wraps()
	failures += _test_is_snail_tracks_form()
	return failures


func _make_state() -> GameStateScript:
	return GameStateScript.new()


func _test_reset_for_new_game() -> int:
	var state := _make_state()
	state.is_multiplayer = true
	state.local_player_form = GameStateScript.PlayerForm.HUMAN
	state.run_seed = 42

	state.reset_for_new_game()

	if state.is_multiplayer:
		push_error("Expected solo reset to clear is_multiplayer")
		return 1
	if state.local_player_form != GameStateScript.PlayerForm.SNAIL:
		push_error("Expected solo reset to restore snail form")
		return 1
	if state.run_seed < 0:
		push_error("Expected solo reset to assign a run seed")
		return 1
	return 0


func _test_prepare_multiplayer_game() -> int:
	var state := _make_state()
	state.reset_for_new_game()

	state.prepare_multiplayer_game(987654)

	if not state.is_multiplayer:
		push_error("Expected prepare_multiplayer_game to enable multiplayer")
		return 1
	if state.run_seed != 987654:
		push_error("Expected prepare_multiplayer_game to set run_seed")
		return 1
	if state.local_player_form != GameStateScript.PlayerForm.SNAIL:
		push_error("Expected multiplayer start to begin in snail form")
		return 1
	return 0


func _test_get_snail_color_wraps() -> int:
	var state := _make_state()
	var first := state.get_snail_color(0)
	var wrapped := state.get_snail_color(GameStateScript.SNAIL_COLORS.size())
	if first != wrapped:
		push_error("Expected snail color palette to wrap by player index")
		return 1
	return 0


func _test_is_snail_tracks_form() -> int:
	var state := _make_state()
	state.local_player_form = GameStateScript.PlayerForm.SNAIL
	if not state.is_snail():
		push_error("Expected SNAIL form to report is_snail() true")
		return 1
	state.local_player_form = GameStateScript.PlayerForm.HUMAN
	if state.is_snail():
		push_error("Expected HUMAN form to report is_snail() false")
		return 1
	return 0
