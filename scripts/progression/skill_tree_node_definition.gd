class_name SkillTreeNodeDefinition
extends Resource

## One node in a skill tree — spells, stat bumps, and/or passives.

@export var node_id: String = ""
@export var display_name: String = ""
@export var summary: String = ""
@export var tier: int = 0
@export var column: int = 0
@export var prerequisite_ids: Array[String] = []
@export var spell_ids: Array[String] = []
@export var stat_bonuses: Dictionary = {}
@export var passive_descriptions: Array[String] = []


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	return node_id.capitalize()


func has_unlock_content() -> bool:
	return (
		not spell_ids.is_empty()
		or not stat_bonuses.is_empty()
		or not passive_descriptions.is_empty()
	)


func get_reward_summary() -> String:
	if not summary.is_empty():
		return summary
	var parts: PackedStringArray = []
	if not spell_ids.is_empty():
		parts.append("%d spell(s)" % spell_ids.size())
	if not stat_bonuses.is_empty():
		parts.append("%d stat(s)" % stat_bonuses.size())
	if not passive_descriptions.is_empty():
		parts.append("%d passive(s)" % passive_descriptions.size())
	if parts.is_empty():
		return "No rewards yet"
	return ", ".join(parts)


func get_content_items(
	spell_names: Dictionary = {},
	spell_descriptions: Dictionary = {}
) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for spell_id in spell_ids:
		items.append({
			"kind": "spell",
			"label": String(spell_names.get(spell_id, spell_id.capitalize())),
			"description": String(
				spell_descriptions.get(spell_id, "Voice-cast power.")
			),
		})
	for stat_key in stat_bonuses.keys():
		items.append({
			"kind": "stat",
			"label": String(stat_key),
			"description": String(stat_bonuses[stat_key]),
		})
	for passive in passive_descriptions:
		var text := String(passive)
		var parts := text.split(": ", true, 1)
		var label := String(parts[0]) if parts.size() > 1 else "Passive"
		var description := String(parts[1]) if parts.size() > 1 else text
		items.append({
			"kind": "passive",
			"label": label,
			"description": description,
		})
	return items


func get_content_labels(
	spell_names: Dictionary = {},
	spell_descriptions: Dictionary = {}
) -> PackedStringArray:
	var labels: PackedStringArray = []
	for item in get_content_items(spell_names, spell_descriptions):
		labels.append(String(item.get("label", "")))
	return labels
