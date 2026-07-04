class_name PlayerCharacterConfig
extends RefCounted

## Lobby character setup payload (synced per peer before match start).

var role: int = GameState.PlayerRole.APPRENTICE


static func create_default(
	for_role: int = GameState.PlayerRole.APPRENTICE
) -> PlayerCharacterConfig:
	var config := PlayerCharacterConfig.new()
	config.role = for_role
	return config


static func from_dict(data: Dictionary) -> PlayerCharacterConfig:
	var config := PlayerCharacterConfig.new()
	config.role = int(data.get("role", GameState.PlayerRole.APPRENTICE))
	return config


func to_dict() -> Dictionary:
	return {"role": role}


func summary() -> String:
	return RoleLoadout.role_label(role)


func get_starting_spell_ids() -> Array[String]:
	return RoleLoadout.get_starting_spell_ids(role)
