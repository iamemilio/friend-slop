class_name TestInputPrompt
extends RefCounted

const InputPromptScript := preload("res://scripts/ui/input_prompt.gd")
const DeliveryObjectiveScript := preload("res://scripts/objectives/delivery_objective.gd")
const StateScript := preload("res://scripts/objectives/delivery_objective_state.gd")


func run() -> int:
	var failures := 0
	failures += _test_interact_action_label_uses_input_map()
	failures += _test_with_action_formats_prompt()
	failures += _test_relic_pickup_prompt_in_range()
	failures += _test_drop_preserves_world_position()
	return failures


func _test_interact_action_label_uses_input_map() -> int:
	if InputMap.has_action("interact"):
		var label := InputPromptScript.action_label("interact")
		if label.is_empty() or label == "?":
			push_error("Expected interact action to resolve to a display label")
			return 1
		if label.contains("Physical"):
			push_error("Expected interact label to omit physical key suffix, got: %s" % label)
			return 1
		return 0
	var prompt := InputPromptScript.with_action("missing_action", "Pick it up?", "F")
	if prompt != "Pick it up? [F]":
		push_error("Expected missing action to use fallback label, got: %s" % prompt)
		return 1
	return 0


func _test_with_action_formats_prompt() -> int:
	var prompt := InputPromptScript.with_action("interact", "Drop it", "F")
	if prompt != "Drop it [F]":
		push_error("Expected action prompt to append bracketed key, got: %s" % prompt)
		return 1
	return 0


func _test_relic_pickup_prompt_in_range() -> int:
	var objective := DeliveryObjectiveScript.new()
	objective.state = StateScript.new()
	objective.state.phase = StateScript.Phase.SEEK_ITEM
	var player := Node3D.new()
	player.add_to_group("player")
	player.global_position = Vector3.ZERO
	objective.set("_item_world_pos", Vector3(1.0, 0.0, 0.0))

	var prompt := objective.get_interaction_prompt(player)
	if prompt.is_empty():
		player.free()
		objective.free()
		push_error("Expected relic pickup prompt when player is in range")
		return 1
	if not prompt.contains("Pick it up?"):
		player.free()
		objective.free()
		push_error("Expected relic pickup prompt text, got: %s" % prompt)
		return 1
	if not "[" in prompt and not "]" in prompt:
		player.free()
		objective.free()
		push_error("Expected relic pickup prompt to include key binding brackets")
		return 1

	player.global_position = Vector3(10.0, 0.0, 0.0)
	if not objective.get_interaction_prompt(player).is_empty():
		player.free()
		objective.free()
		push_error("Expected no relic prompt when player is out of range")
		return 1

	player.free()
	objective.free()
	return 0


func _test_drop_preserves_world_position() -> int:
	var objective := DeliveryObjectiveScript.new()
	objective.state = StateScript.new()
	objective.state.phase = StateScript.Phase.CARRIED
	var player := Node3D.new()
	player.global_position = Vector3(8.0, 0.5, -2.0)
	objective.state.carrier = player
	objective.set("_item_world_pos", Vector3(0.0, 1.1, 0.0))
	var item_root := Node3D.new()
	item_root.global_position = Vector3(8.5, 1.4, -1.5)
	objective.set("_item_root", item_root)

	if not objective._try_interact_local(player):
		player.free()
		objective.free()
		item_root.free()
		push_error("Expected local relic drop to succeed")
		return 1

	var dropped: Vector3 = objective.get("_item_world_pos")
	var expected := Vector3(8.5, 1.1, -1.5)
	if not dropped.is_equal_approx(expected):
		player.free()
		objective.free()
		item_root.free()
		push_error("Expected dropped relic to remain at drop location, got %s" % str(dropped))
		return 1

	player.free()
	objective.free()
	item_root.free()
	return 0
