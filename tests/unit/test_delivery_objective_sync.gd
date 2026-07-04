class_name TestDeliveryObjectiveSync
extends RefCounted

const SyncScript := preload("res://scripts/objectives/delivery_objective_sync.gd")

const INTERACT_RANGE_SQ := 2.5 * 2.5


func run() -> int:
	var failures := 0
	failures += _test_snapshot_round_trip()
	failures += _test_host_pickup_and_deliver()
	failures += _test_host_drop_restores_seek()
	failures += _test_resolve_interact_action()
	return failures


func _test_snapshot_round_trip() -> int:
	var pos := Vector3(12.0, 1.1, -4.0)
	var packed := SyncScript.pack_snapshot(
		SyncScript.Phase.CARRIED,
		2,
		pos
	)
	var unpacked := SyncScript.unpack_snapshot(packed)
	if int(unpacked.get("phase", -1)) != SyncScript.Phase.CARRIED:
		push_error("Expected carried phase in unpacked snapshot")
		return 1
	if int(unpacked.get("carrier_peer_id", -1)) != 2:
		push_error("Expected carrier peer id in unpacked snapshot")
		return 1
	var restored: Vector3 = unpacked.get("item_world_pos", Vector3.ZERO)
	if not restored.is_equal_approx(pos):
		push_error("Expected item world position to round-trip through snapshot")
		return 1
	return 0


func _test_host_pickup_and_deliver() -> int:
	var item_pos := Vector3(0.0, 1.1, 0.0)
	var turn_in_pos := Vector3(6.0, 1.1, 0.0)
	var pickup := SyncScript.apply_host_action(
		SyncScript.Action.PICKUP,
		SyncScript.Phase.SEEK_ITEM,
		-1,
		2,
		Vector3.ZERO,
		item_pos,
		turn_in_pos,
		25.0,
		1.1
	)
	if pickup.is_empty() or int(pickup.get("phase", -1)) != SyncScript.Phase.CARRIED:
		push_error("Expected host pickup to enter carried phase")
		return 1
	var deliver := SyncScript.apply_host_action(
		SyncScript.Action.DELIVER,
		int(pickup.get("phase", -1)),
		int(pickup.get("carrier_peer_id", -1)),
		2,
		turn_in_pos,
		item_pos,
		turn_in_pos,
		25.0,
		1.1
	)
	if deliver.is_empty() or int(deliver.get("phase", -1)) != SyncScript.Phase.COMPLETE:
		push_error("Expected host deliver to complete objective")
		return 1
	return 0


func _test_host_drop_restores_seek() -> int:
	var item_pos := Vector3(0.0, 1.1, 0.0)
	var drop_pos := Vector3(3.0, 0.0, 1.0)
	var drop := SyncScript.apply_host_action(
		SyncScript.Action.DROP,
		SyncScript.Phase.CARRIED,
		2,
		2,
		drop_pos,
		item_pos,
		Vector3(9.0, 1.1, 0.0),
		25.0,
		1.1
	)
	if drop.is_empty() or int(drop.get("phase", -1)) != SyncScript.Phase.SEEK_ITEM:
		push_error("Expected host drop to restore seek phase")
		return 1
	var restored: Vector3 = drop.get("item_world_pos", Vector3.ZERO)
	if not is_equal_approx(restored.y, 1.1):
		push_error("Expected dropped relic to snap to float height")
		return 1
	return 0


func _test_resolve_interact_action() -> int:
	var item_pos := Vector3.ZERO
	var turn_in_pos := Vector3(2.0, 1.1, 0.0)
	var pickup_action := SyncScript.resolve_interact_action(
		SyncScript.Phase.SEEK_ITEM,
		-1,
		2,
		Vector3.ZERO,
		item_pos,
		turn_in_pos,
		INTERACT_RANGE_SQ
	)
	if pickup_action != SyncScript.Action.PICKUP:
		push_error("Expected resolve to return pickup near relic")
		return 1
	var drop_action := SyncScript.resolve_interact_action(
		SyncScript.Phase.CARRIED,
		2,
		2,
		Vector3(5.0, 0.0, 0.0),
		item_pos,
		turn_in_pos,
		INTERACT_RANGE_SQ
	)
	if drop_action != SyncScript.Action.DROP:
		push_error("Expected resolve to return drop while carrying away from turn-in")
		return 1
	return 0
