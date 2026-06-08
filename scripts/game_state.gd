extends Node

## Shared game context for the cursed-wizard snail race.

enum PlayerForm {
	SNAIL,
	HUMAN,
}

const SNAIL_COLORS: Array[Color] = [
	Color(0.92, 0.28, 0.32), # crimson
	Color(0.28, 0.55, 0.95), # azure
	Color(0.35, 0.82, 0.42), # emerald
	Color(0.95, 0.78, 0.22), # gold
	Color(0.72, 0.38, 0.92), # violet
	Color(0.95, 0.48, 0.18), # amber
	Color(0.28, 0.88, 0.86), # teal
	Color(0.95, 0.42, 0.72), # rose
]

var local_player_form: PlayerForm = PlayerForm.SNAIL
var is_multiplayer: bool = false
var run_seed: int = -1
var dev_tome_at_spawn: bool = false
var dev_tome_spell_id: String = "lumos"


func reset_for_new_game() -> void:
	is_multiplayer = false
	local_player_form = PlayerForm.SNAIL
	run_seed = randi()


func prepare_multiplayer_game(seed: int) -> void:
	is_multiplayer = true
	local_player_form = PlayerForm.SNAIL
	run_seed = seed


func get_snail_color(player_index: int) -> Color:
	return SNAIL_COLORS[player_index % SNAIL_COLORS.size()]


func is_snail() -> bool:
	return local_player_form == PlayerForm.SNAIL
