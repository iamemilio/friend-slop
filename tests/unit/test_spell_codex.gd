class_name TestSpellCodex
extends RefCounted

const SpellDefinitionScript := preload("res://scripts/spells/spell_definition.gd")


func run() -> int:
	var failures := 0
	failures += _test_fireball_codex_omits_flare()
	failures += _test_show_me_codex_mentions_trails()
	failures += _test_codex_omits_cooldown()
	return failures


func _make_spell(effect_id: String, words: Array[String]) -> SpellDefinitionScript:
	var spell := SpellDefinitionScript.new()
	spell.id = effect_id
	spell.display_name = effect_id
	spell.incantation_words = PackedStringArray(words)
	spell.effect_id = effect_id
	spell.cooldown_sec = 8.0
	return spell


func _test_fireball_codex_omits_flare() -> int:
	var spell := _make_spell("fireball", ["fireball"])
	var detail := spell.get_codex_effect_detail()
	if not detail.contains("explode"):
		push_error("Expected fireball codex to mention impact explosion")
		return 1
	if detail.contains("flare"):
		push_error("Expected fireball codex to omit signal flare text")
		return 1
	return 0


func _test_show_me_codex_mentions_trails() -> int:
	var spell := _make_spell("light", ["show", "me"])
	var detail := spell.get_codex_effect_detail()
	if not detail.contains("smoke trails"):
		push_error("Expected show-me codex to mention smoke trails")
		return 1
	return 0


func _test_codex_omits_cooldown() -> int:
	var spell := _make_spell("fireball", ["fireball"])
	var lines := spell.get_codex_detail_lines()
	for line in lines:
		if str(line).to_lower().contains("cooldown"):
			push_error("Expected codex detail lines to omit cooldown mentions")
			return 1
	return 0
