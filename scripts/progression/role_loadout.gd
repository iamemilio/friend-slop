class_name RoleLoadout
extends RefCounted

## Fixed starting spells per role — no skill-tree progression.

const APPRENTICE_SPELLS: Array[String] = [
	"show_me",
	"fireball",
	"haste",
	"light",
	"light_ball",
	"target",
	"pull",
	"follow",
	"stop",
]

const WARDEN_SPELLS: Array[String] = [
	"warden_stalk",
	"warden_pounce",
	"warden_mark",
	"warden_whisper",
	"warden_mirror",
	"warden_fade",
	"warden_shift",
	"warden_seal",
	"warden_forge",
]


static func role_label(role: int) -> String:
	if role == GameState.PlayerRole.WARDEN:
		return "Warden"
	return "Apprentice"


static func get_starting_spell_ids(role: int) -> Array[String]:
	if role == GameState.PlayerRole.WARDEN:
		return WARDEN_SPELLS.duplicate()
	return APPRENTICE_SPELLS.duplicate()
