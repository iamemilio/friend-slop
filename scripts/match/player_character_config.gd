class_name PlayerCharacterConfig
extends RefCounted

## Lobby character setup payload (synced per peer before match start).

var role: int = GameState.PlayerRole.APPRENTICE
var binding: Binding = Binding.create_default()


static func create_default(
	for_role: int = GameState.PlayerRole.APPRENTICE
) -> PlayerCharacterConfig:
	var config := PlayerCharacterConfig.new()
	config.role = for_role
	config.binding = Binding.create_for_role(for_role)
	return config


static func from_dict(data: Dictionary) -> PlayerCharacterConfig:
	var config := PlayerCharacterConfig.new()
	config.role = int(data.get("role", GameState.PlayerRole.APPRENTICE))
	if data.has("binding") and data.get("binding") is Dictionary:
		config.binding = Binding.from_dict(data.get("binding"))
	else:
		config.binding = Binding.from_dict(_legacy_binding_payload(data, config.role))
	return config


func to_dict() -> Dictionary:
	return {
		"role": role,
		"binding": binding.to_dict(),
	}


func summary() -> String:
	return binding.summary()


func get_skill_tree() -> SkillTree:
	return binding.build_skill_tree()


func get_starting_spell_ids() -> Array[String]:
	return get_skill_tree().get_starting_spell_ids()


static func _legacy_binding_payload(data: Dictionary, for_role: int) -> Dictionary:
	if data.has("warden_focus_index") and for_role == GameState.PlayerRole.WARDEN:
		var tree := Binding.DEFAULT_WARDEN_TREE
		var index := _clamp_index(int(data.get("warden_focus_index", 0)), tree.starting_node_ids.size())
		return {
			"tree_id": tree.tree_id,
			"starting_node_id": tree.starting_node_ids[index],
		}
	if not data.has("survivor_binding_index"):
		return {}
	var tree := Binding.DEFAULT_FIREMAGE_TREE
	var index := int(data.get("survivor_binding_index", 0))
	if index < 0 or index >= tree.starting_node_ids.size():
		index = 0
	return {
		"tree_id": tree.tree_id,
		"starting_node_id": tree.starting_node_ids[index],
	}


static func _clamp_index(value: int, option_count: int) -> int:
	if option_count <= 0:
		return 0
	return clampi(value, 0, option_count - 1)
