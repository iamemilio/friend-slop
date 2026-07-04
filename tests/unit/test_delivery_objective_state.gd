class_name TestDeliveryObjectiveState
extends RefCounted

const StateScript := preload("res://scripts/objectives/delivery_objective_state.gd")


func run() -> int:
	var failures := 0
	failures += _test_pickup_and_deliver()
	failures += _test_drop_restores_seek()
	return failures


func _test_pickup_and_deliver() -> int:
	var state := StateScript.new()
	var player := Node.new()
	player.name = "Player"
	if not state.try_pickup(player, Vector3.ZERO, Vector3.ZERO, 4.0):
		push_error("Expected pickup in range to succeed")
		return 1
	if state.phase != StateScript.Phase.CARRIED:
		push_error("Expected carried phase after pickup")
		return 1
	if not state.try_deliver(player, Vector3.ZERO, Vector3.ZERO, 4.0):
		push_error("Expected deliver in range to succeed")
		return 1
	if state.phase != StateScript.Phase.COMPLETE:
		push_error("Expected complete phase after delivery")
		return 1
	player.free()
	return 0


func _test_drop_restores_seek() -> int:
	var state := StateScript.new()
	var player := Node.new()
	state.try_pickup(player, Vector3.ZERO, Vector3.ZERO, 4.0)
	if not state.try_drop(player, Vector3(3, 0, 0)):
		push_error("Expected drop while carrying to succeed")
		return 1
	if state.phase != StateScript.Phase.SEEK_ITEM:
		push_error("Expected seek phase after drop")
		return 1
	player.free()
	return 0
