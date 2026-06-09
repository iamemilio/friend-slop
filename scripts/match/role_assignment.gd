class_name RoleAssignment
extends RefCounted

## Validates lobby rosters for asymmetric horror (3 apprentices + 1 warden at max).

const MIN_HORROR_PLAYERS := 3


static func role_label(role: int) -> String:
	match role:
		GameState.PlayerRole.WARDEN:
			return "Warden"
		_:
			return "Apprentice"


static func count_roles(roles: Dictionary) -> Dictionary:
	var apprentices := 0
	var wardens := 0
	for peer_id in roles.keys():
		match int(roles[peer_id]):
			GameState.PlayerRole.WARDEN:
				wardens += 1
			_:
				apprentices += 1
	return {"apprentices": apprentices, "wardens": wardens}


static func validate_horror_roster(peer_ids: Array, roles: Dictionary) -> Error:
	if peer_ids.is_empty():
		return ERR_INVALID_PARAMETER
	for peer_id in peer_ids:
		if not roles.has(peer_id):
			return ERR_INVALID_PARAMETER
	var counts := count_roles(roles)
	if peer_ids.size() < MIN_HORROR_PLAYERS:
		return ERR_INVALID_PARAMETER
	if counts.wardens != 1:
		return ERR_INVALID_PARAMETER
	if counts.apprentices < 2:
		return ERR_INVALID_PARAMETER
	return OK


static func default_roles_for_peers(peer_ids: Array) -> Dictionary:
	var result: Dictionary = {}
	var sorted_ids: Array = peer_ids.duplicate()
	sorted_ids.sort()
	for index in range(sorted_ids.size()):
		var peer_id := int(sorted_ids[index])
		if index == 0:
			result[peer_id] = GameState.PlayerRole.WARDEN
		else:
			result[peer_id] = GameState.PlayerRole.APPRENTICE
	return result
