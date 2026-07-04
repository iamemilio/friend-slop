class_name GuideContent
extends RefCounted

## Pure text assembly for the Tab guide menu — unit-testable without UI nodes.

const SpellDefinitionScript := preload("res://scripts/spells/spell_definition.gd")

const EMPTY_OBJECTIVES := "No active objectives."
const CODEX_EMPTY_LIST_LABEL := "(No spells known yet)"


static func control_hints_text() -> String:
	return (
		"Move — WASD\n"
		+ "Sprint — Shift · Jump — Space\n"
		+ "Camera — C · Interact — F\n"
		+ "Cast — hold LMB, speak, release\n"
		+ "Spell codex — B · Guide — Tab"
	)


static func format_objective_lines(lines: PackedStringArray) -> String:
	if lines.is_empty():
		return EMPTY_OBJECTIVES
	return "\n".join(lines)


static func build_view(objective_lines: PackedStringArray) -> Dictionary:
	return {
		"hints": control_hints_text(),
		"objectives": format_objective_lines(objective_lines),
	}


static func codex_spell_ids(loadout: Node) -> Array[String]:
	if loadout == null or not loadout.has_method("get_known_spell_ids"):
		return []
	return loadout.get_known_spell_ids()


static func codex_row_label(spell: SpellDefinitionScript, spell_id: String) -> String:
	if spell == null:
		return spell_id
	return "%s — \"%s\"" % [spell.display_name, spell.get_incantation_text()]


static func codex_empty_hint() -> String:
	return "Find floating tomes in the maze."


static func codex_list_hint() -> String:
	return "Click a spell to read more — hold [LMB] to cast."


static func build_spell_detail(spell: SpellDefinitionScript) -> Dictionary:
	if spell == null:
		return {"title": "Spell", "body": "No details available."}
	return {
		"title": spell.display_name,
		"body": "\n".join(spell.get_codex_detail_lines()),
	}
