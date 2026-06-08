class_name SpellBook
extends Node

signal spell_learned(spell_id: String)
signal spell_cast(spell_id: String)

var _known: Dictionary = {}
var _spell_defs: Dictionary = {}


func configure(spell_defs: Array[SpellDefinition]) -> void:
	_spell_defs.clear()
	for spell in spell_defs:
		if spell != null:
			_spell_defs[spell.id] = spell


func reset() -> void:
	_known.clear()


func knows(spell_id: String) -> bool:
	return _known.has(spell_id)


func learn(spell_id: String) -> void:
	if knows(spell_id):
		return
	_known[spell_id] = {"learned_at": Time.get_ticks_msec()}
	spell_learned.emit(spell_id)


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


func has_known_spells() -> bool:
	return not _known.is_empty()


func get_spell_definition(spell_id: String) -> SpellDefinition:
	return _spell_defs.get(spell_id)


func can_cast(spell_id: String) -> bool:
	if not knows(spell_id):
		return false
	return cooldown_remaining(spell_id) <= 0.0


func mark_cast(spell_id: String) -> void:
	if not _known.has(spell_id):
		_known[spell_id] = {}
	_known[spell_id]["last_cast_time"] = Time.get_ticks_msec() / 1000.0
	spell_cast.emit(spell_id)


func cooldown_remaining(spell_id: String) -> float:
	if not _known.has(spell_id):
		return 0.0
	var spell: SpellDefinition = _spell_defs.get(spell_id)
	if spell == null:
		return 0.0
	var last_cast: float = _known[spell_id].get("last_cast_time", -999.0)
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - last_cast
	return maxf(0.0, spell.cooldown_sec - elapsed)
