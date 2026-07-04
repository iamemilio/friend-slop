class_name CharacterSpellLoadout
extends Node

## Per-character set of known spells. Casting is gated by voice recognition, not cooldowns.

signal spell_learned(spell_id: String)
signal spell_unlearned(spell_id: String)
signal loadout_changed()

var _spell_defs: Dictionary = {}
var _known: Dictionary = {}


func configure(spells: Array[SpellDefinition]) -> void:
	_spell_defs.clear()
	for spell in spells:
		if spell != null:
			_spell_defs[spell.id] = spell


func reset() -> void:
	_known.clear()
	loadout_changed.emit()


func knows(spell_id: String) -> bool:
	return _known.has(spell_id)


func has_known_spells() -> bool:
	return not _known.is_empty()


func learn_spell(spell_id: String, _source: String = "") -> bool:
	if spell_id.is_empty() or not _spell_defs.has(spell_id):
		return false
	if knows(spell_id):
		return false
	_known[spell_id] = {"learned_at": Time.get_ticks_msec()}
	spell_learned.emit(spell_id)
	loadout_changed.emit()
	return true


func unlearn_spell(spell_id: String) -> void:
	if not knows(spell_id):
		return
	_known.erase(spell_id)
	spell_unlearned.emit(spell_id)
	loadout_changed.emit()


func get_known_spell_ids() -> Array[String]:
	var ids: Array[String] = []
	for spell_id in _known.keys():
		ids.append(spell_id)
	ids.sort()
	return ids


func get_known_spells() -> Array[SpellDefinition]:
	var spells: Array[SpellDefinition] = []
	for spell_id in get_known_spell_ids():
		var spell: SpellDefinition = get_spell_definition(spell_id)
		if spell != null:
			spells.append(spell)
	return spells


func get_spell_definition(spell_id: String) -> SpellDefinition:
	return _spell_defs.get(spell_id)
