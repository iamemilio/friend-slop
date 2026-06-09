class_name SkillTreeDefinition
extends Resource

## Base data-driven skill tree shared by role-specific subclasses.

@export var tree_id: String = ""
@export var display_name: String = ""
@export var starting_node_ids: Array[String] = []
@export var node_labels: Dictionary = {}
@export var nodes: Array[SkillTreeNodeDefinition] = []


func get_role_kind() -> String:
	return "base"


func allows_multiple_unlocks_per_node() -> bool:
	return false


func get_node(node_id: String) -> SkillTreeNodeDefinition:
	for node in nodes:
		if node != null and node.node_id == node_id:
			return node
	return null


func get_node_label(node_id: String) -> String:
	var node := get_node(node_id)
	if node != null:
		return node.get_display_name()
	if node_labels.has(node_id):
		return String(node_labels[node_id])
	return node_id.capitalize()


func is_valid_starting_node(node_id: String) -> bool:
	return starting_node_ids.has(node_id)


func get_default_starting_node_id() -> String:
	if starting_node_ids.is_empty():
		return ""
	return starting_node_ids[0]


func get_max_tier() -> int:
	var max_tier := 0
	for node in nodes:
		if node != null:
			max_tier = maxi(max_tier, node.tier)
	return max_tier


func get_layout_columns() -> int:
	var max_column := 0
	for node in nodes:
		if node != null:
			max_column = maxi(max_column, node.column)
	return maxi(1, max_column + 1)


func get_nodes_at_tier(tier: int) -> Array[SkillTreeNodeDefinition]:
	var tier_nodes: Array[SkillTreeNodeDefinition] = []
	for node in nodes:
		if node != null and node.tier == tier:
			tier_nodes.append(node)
	tier_nodes.sort_custom(func(a: SkillTreeNodeDefinition, b: SkillTreeNodeDefinition) -> bool:
		return a.column < b.column
	)
	return tier_nodes


func get_unlock_ids_for_node(_node_id: String) -> Array[String]:
	return []


func get_starting_unlock_ids(node_id: String) -> Array[String]:
	return get_unlock_ids_for_node(node_id)


func get_starting_spell_ids(node_id: String) -> Array[String]:
	return get_starting_unlock_ids(node_id)


func build_node_detail_text(
	node_id: String,
	spell_display_names: Dictionary = {}
) -> String:
	var node := get_node(node_id)
	if node == null:
		return "Unknown node."
	var lines: PackedStringArray = []
	lines.append("[b]%s[/b]" % node.get_display_name())
	if not node.summary.is_empty():
		lines.append(node.summary)
	if is_valid_starting_node(node_id):
		lines.append("[i]Starting kit — pick this branch to begin here.[/i]")
	elif not node.prerequisite_ids.is_empty():
		var prereq_labels: PackedStringArray = []
		for prereq_id in node.prerequisite_ids:
			prereq_labels.append(get_node_label(prereq_id))
		lines.append("Requires: %s" % ", ".join(prereq_labels))
	else:
		lines.append("[i]Future unlock on this branch.[/i]")
	if not node.spell_ids.is_empty():
		var spell_lines: PackedStringArray = []
		for spell_id in node.spell_ids:
			var label := String(spell_display_names.get(spell_id, spell_id.capitalize()))
			spell_lines.append("• %s" % label)
		lines.append("[b]Spells[/b]\n" + "\n".join(spell_lines))
	if not node.stat_bonuses.is_empty():
		var stat_lines: PackedStringArray = []
		for stat_key in node.stat_bonuses.keys():
			var stat_name := String(stat_key).capitalize()
			var stat_value := String(node.stat_bonuses[stat_key])
			stat_lines.append("• %s: %s" % [stat_name, stat_value])
		lines.append("[b]Stats[/b]\n" + "\n".join(stat_lines))
	if not node.passive_descriptions.is_empty():
		var passive_lines: PackedStringArray = []
		for passive in node.passive_descriptions:
			passive_lines.append("• %s" % passive)
		lines.append("[b]Passives[/b]\n" + "\n".join(passive_lines))
	return "\n\n".join(lines)
