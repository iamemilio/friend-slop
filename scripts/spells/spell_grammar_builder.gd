class_name SpellGrammarBuilder
extends RefCounted

## Builds Vosk grammar JSON for a small spell vocabulary.


static func build_json_from_spell_dicts(spell_dicts: Array) -> String:
	var phrases: Array[String] = []
	for item in spell_dicts:
		if item is Dictionary:
			var words: Variant = item.get("incantation_words", [])
			if words is Array:
				phrases.append(" ".join(PackedStringArray(words)))
			elif words is PackedStringArray:
				phrases.append(" ".join(words))
	return build_json(phrases)


static func build_json(phrases: Array) -> String:
	var unique: Array[String] = []
	var seen: Dictionary = {}
	for phrase in phrases:
		var text := str(phrase).strip_edges().to_lower()
		if text.is_empty() or seen.has(text):
			continue
		seen[text] = true
		unique.append(text)
	if unique.is_empty():
		return ""
	unique.append("[unk]")
	return JSON.stringify(unique)
