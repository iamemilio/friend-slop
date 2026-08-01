class_name RoleLoadout
extends RefCounted

## Role starter kits. Apprentices get APPRENTICE_STARTER_SPELLS.
## Wardens get the union of apprentice starters and WARDEN_STARTER_SPELLS.

const APPRENTICE_STARTER_SPELLS: Array[String] = [
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

const WARDEN_STARTER_SPELLS: Array[String] = [
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
		return _union_spell_ids(APPRENTICE_STARTER_SPELLS, WARDEN_STARTER_SPELLS)
	return APPRENTICE_STARTER_SPELLS.duplicate()


static func _union_spell_ids(a: Array[String], b: Array[String]) -> Array[String]:
	var seen: Dictionary = {}
	var out: Array[String] = []
	for spell_id in a:
		if spell_id.is_empty() or seen.has(spell_id):
			continue
		seen[spell_id] = true
		out.append(spell_id)
	for spell_id in b:
		if spell_id.is_empty() or seen.has(spell_id):
			continue
		seen[spell_id] = true
		out.append(spell_id)
	return out
