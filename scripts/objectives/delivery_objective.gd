class_name DeliveryObjective
extends Node3D

## Find the noisy relic and bring it to the turn-in shrine (solo-first).

signal phase_changed(phase: int)
signal completed

const InputPromptScript := preload("res://scripts/ui/input_prompt.gd")
const WorldVisualLayersScript := preload("res://scripts/world_visual_layers.gd")
const INTERACT_RANGE := 2.5
const INTERACT_RANGE_SQ := INTERACT_RANGE * INTERACT_RANGE
const PING_INTERVAL_SEC := 3.5
const FLOAT_HEIGHT := 1.1
const BOB_SPEED := 2.2
const BOB_AMPLITUDE := 0.12
const CARRY_OFFSET := Vector3(0.35, -0.15, -0.55)

var state: DeliveryObjectiveState = DeliveryObjectiveState.new()

var _maze: Node3D
var _cell_to_world: Callable
var _item_root: Node3D
var _item_mesh: MeshInstance3D
var _item_audio: AudioStreamPlayer3D
var _turn_in_root: Node3D
var _turn_in_mesh: MeshInstance3D
var _item_world_pos: Vector3 = Vector3.ZERO
var _turn_in_pos: Vector3 = Vector3.ZERO
var _carrier_peer_id: int = -1
var _ping_timer: float = 0.0
var _bob_time: float = 0.0
var _item_cell: Vector2i = Vector2i(-1, -1)
var _turn_in_cell: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	add_to_group("delivery_objective")


func setup(
	maze: Node3D,
	spawn_cell: Vector2i,
	cell_to_world: Callable
) -> void:
	if state.phase == DeliveryObjectiveState.Phase.COMPLETE:
		return
	if GameState.is_multiplayer:
		set_multiplayer_authority(1)
	_maze = maze
	_cell_to_world = cell_to_world
	var plan := ObjectivePlacement.plan(
		maze.get_wall_grid(),
		maze.maze_width,
		maze.maze_height,
		spawn_cell,
		GameState.run_seed,
		SettingsManager.dev_spawn_relic_near_spawn
	)
	if plan.is_empty():
		TomeDebug.log("DeliveryObjective", "Could not plan objective cells")
		return

	_item_cell = plan.get("item_cell")
	_turn_in_cell = plan.get("turn_in_cell")
	_item_world_pos = _cell_center(_item_cell)
	_turn_in_pos = _cell_center(_turn_in_cell)
	_build_visuals()
	_apply_visuals_for_phase()
	TomeDebug.log(
		"DeliveryObjective",
		"Spawned item=%s turn_in=%s"
		% [str(_item_cell), str(_turn_in_cell)]
	)
	phase_changed.emit(state.phase)


func get_interaction_prompt(player: Node) -> String:
	match state.phase:
		DeliveryObjectiveState.Phase.SEEK_ITEM:
			if _is_near(player.global_position, _item_world_pos):
				return InputPromptScript.with_action("interact", "Pick it up?")
		DeliveryObjectiveState.Phase.CARRIED:
			if state.carrier == player:
				if _is_near(player.global_position, _turn_in_pos):
					return InputPromptScript.with_action("interact", "Leave it?")
				return InputPromptScript.with_action("interact", "Drop it")
	return ""


func is_carrier(player: Node) -> bool:
	return (
		state.phase == DeliveryObjectiveState.Phase.CARRIED
		and state.carrier == player
	)


func try_interact(player: Node) -> bool:
	if not player.is_in_group("player"):
		return false
	if GameState.is_multiplayer:
		return _try_interact_multiplayer(player)
	return _try_interact_local(player)


func get_status_lines() -> PackedStringArray:
	return state.get_status_lines()


func _process(delta: float) -> void:
	_bob_time += delta
	if state.phase == DeliveryObjectiveState.Phase.SEEK_ITEM:
		_update_world_bob()

	if state.phase == DeliveryObjectiveState.Phase.COMPLETE:
		return
	if GameState.is_multiplayer and not multiplayer.is_server():
		return

	_ping_timer += delta
	if _ping_timer >= PING_INTERVAL_SEC:
		_ping_timer = 0.0
		if GameState.is_multiplayer:
			if MatchStateManager.allows_gameplay_actions():
				NetworkManager.relay_delivery_objective(
					DeliveryObjectiveSync.NetworkOp.BROADCAST_PING
				)
		else:
			_play_ping()


func _play_ping() -> void:
	if _item_audio != null and is_instance_valid(_item_audio):
		_item_audio.play()
	if _item_mesh != null:
		var tween := create_tween()
		tween.tween_property(_item_mesh, "scale", Vector3.ONE * 1.25, 0.08)
		tween.tween_property(_item_mesh, "scale", Vector3.ONE, 0.12)


func _try_interact_local(player: Node) -> bool:
	match state.phase:
		DeliveryObjectiveState.Phase.SEEK_ITEM:
			if state.try_pickup(player, player.global_position, _item_world_pos, INTERACT_RANGE_SQ):
				_carrier_peer_id = _peer_id_for_player(player)
				_stop_caster_spells(player)
				_apply_visuals_for_phase()
				phase_changed.emit(state.phase)
				return true
		DeliveryObjectiveState.Phase.CARRIED:
			if state.carrier != player:
				return false
			if _is_near(player.global_position, _turn_in_pos):
				if state.try_deliver(
					player,
					player.global_position,
					_turn_in_pos,
					INTERACT_RANGE_SQ
				):
					_carrier_peer_id = -1
					_apply_visuals_for_phase()
					completed.emit()
					phase_changed.emit(state.phase)
					return true
			elif state.try_drop(player, player.global_position):
				_carrier_peer_id = -1
				_item_world_pos = _drop_world_position(player)
				_apply_visuals_for_phase()
				phase_changed.emit(state.phase)
				return true
	return false


func _try_interact_multiplayer(player: Node) -> bool:
	if not MatchStateManager.allows_gameplay_actions():
		return false
	if not player.is_multiplayer_authority():
		return false
	var actor_peer_id := _peer_id_for_player(player)
	var action := DeliveryObjectiveSync.resolve_interact_action(
		state.phase,
		_carrier_peer_id,
		actor_peer_id,
		player.global_position,
		_item_world_pos,
		_turn_in_pos,
		INTERACT_RANGE_SQ
	)
	if action < 0:
		return false
	if multiplayer.is_server():
		return _host_apply_action(actor_peer_id, action, player.global_position)
	NetworkManager.relay_delivery_objective(
		DeliveryObjectiveSync.NetworkOp.REQUEST_INTERACT,
		action
	)
	return false


func _host_apply_action(actor_peer_id: int, action: int, _client_pos: Vector3) -> bool:
	var player := _find_player(actor_peer_id)
	if player == null:
		return false
	var player_pos := player.global_position
	if action == DeliveryObjectiveSync.Action.DROP:
		player_pos = _drop_world_position(player)
	var result := DeliveryObjectiveSync.apply_host_action(
		action,
		state.phase,
		_carrier_peer_id,
		actor_peer_id,
		player_pos,
		_item_world_pos,
		_turn_in_pos,
		INTERACT_RANGE_SQ,
		FLOAT_HEIGHT
	)
	if result.is_empty():
		return false
	NetworkManager.relay_delivery_objective(
		DeliveryObjectiveSync.NetworkOp.BROADCAST_STATE,
		DeliveryObjectiveSync.pack_snapshot(
			int(result.get("phase", state.phase)),
			int(result.get("carrier_peer_id", -1)),
			result.get("item_world_pos", _item_world_pos)
		)
	)
	return true


func apply_network_op(op: int, payload: Variant = null) -> void:
	match op:
		DeliveryObjectiveSync.NetworkOp.REQUEST_INTERACT:
			var interact := payload as Array
			_host_apply_action(int(interact[0]), int(interact[1]), Vector3.ZERO)
		DeliveryObjectiveSync.NetworkOp.BROADCAST_STATE:
			_apply_synced_state(DeliveryObjectiveSync.unpack_snapshot(payload as Dictionary))
		DeliveryObjectiveSync.NetworkOp.BROADCAST_PING:
			_play_ping()


func _apply_synced_state(result: Dictionary) -> void:
	var previous_phase := state.phase
	var previous_carrier := state.carrier
	var new_phase: int = int(result.get("phase", state.phase))
	_carrier_peer_id = int(result.get("carrier_peer_id", -1))
	_item_world_pos = result.get("item_world_pos", _item_world_pos)
	state.phase = new_phase as DeliveryObjectiveState.Phase
	state.carrier = _find_player(_carrier_peer_id) if _carrier_peer_id > 0 else null
	if (
		state.phase == DeliveryObjectiveState.Phase.CARRIED
		and state.carrier != null
		and (previous_phase != DeliveryObjectiveState.Phase.CARRIED or state.carrier != previous_carrier)
	):
		_stop_caster_spells(state.carrier)
	_apply_visuals_for_phase()
	if previous_phase != state.phase:
		if state.phase == DeliveryObjectiveState.Phase.COMPLETE:
			completed.emit()
		phase_changed.emit(state.phase)


func _apply_visuals_for_phase() -> void:
	if _item_root == null:
		return
	match state.phase:
		DeliveryObjectiveState.Phase.SEEK_ITEM:
			if _item_root.get_parent() != self:
				_item_root.reparent(self)
			_item_root.scale = Vector3.ONE
			_sync_item_transform()
		DeliveryObjectiveState.Phase.CARRIED:
			if state.carrier != null:
				_attach_to_carrier(state.carrier as Node3D)
		DeliveryObjectiveState.Phase.COMPLETE:
			_detach_item_to_turn_in()


func _peer_id_for_player(player: Node) -> int:
	return int(player.get_multiplayer_authority())


func _find_player(peer_id: int) -> Node3D:
	if peer_id <= 0:
		return null
	for node in get_tree().get_nodes_in_group("player"):
		if node is Node3D and int(node.get_multiplayer_authority()) == peer_id:
			return node as Node3D
	return null


func _cell_center(cell: Vector2i) -> Vector3:
	var pos: Vector3 = _cell_to_world.call(cell.x, cell.y)
	pos.y = FLOAT_HEIGHT
	return pos


func _ping_max_distance() -> float:
	if _maze == null:
		return 0.0
	return DeliveryObjectiveAudio.ping_max_distance(
		int(_maze.get("maze_width")),
		int(_maze.get("maze_height")),
		float(_maze.get("cell_size"))
	)


func _is_near(a: Vector3, b: Vector3) -> bool:
	return a.distance_squared_to(b) <= INTERACT_RANGE_SQ


func _drop_world_position(player: Node) -> Vector3:
	if _item_root != null and is_instance_valid(_item_root):
		var pos := _item_root.global_position
		pos.y = FLOAT_HEIGHT
		return pos
	if player is Node3D:
		var pos := (player as Node3D).global_position
		pos.y = FLOAT_HEIGHT
		return pos
	return _item_world_pos


func _build_visuals() -> void:
	if _item_root == null:
		_item_root = Node3D.new()
		_item_root.name = "RelicItem"
		add_child(_item_root)

		var item_shape := SphereMesh.new()
		item_shape.radius = 0.28
		item_shape.height = 0.56
		_item_mesh = MeshInstance3D.new()
		_item_mesh.mesh = item_shape
		var item_mat := StandardMaterial3D.new()
		item_mat.albedo_color = Color(0.95, 0.78, 0.22)
		item_mat.emission_enabled = true
		item_mat.emission = Color(0.95, 0.65, 0.15) * 0.8
		_item_mesh.material_override = item_mat
		_item_mesh.layers = WorldVisualLayersScript.WORLD
		_item_root.add_child(_item_mesh)

		_item_audio = AudioStreamPlayer3D.new()
		_item_audio.stream = PlaceholderPingAudio.create_stream()
		_item_audio.max_distance = _ping_max_distance()
		_item_audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		_item_root.add_child(_item_audio)

	if _turn_in_root == null:
		_turn_in_root = Node3D.new()
		_turn_in_root.name = "TurnInShrine"
		add_child(_turn_in_root)
		_turn_in_root.global_position = _turn_in_pos

		var pillar := CylinderMesh.new()
		pillar.top_radius = 0.35
		pillar.bottom_radius = 0.45
		pillar.height = 2.0
		_turn_in_mesh = MeshInstance3D.new()
		_turn_in_mesh.mesh = pillar
		_turn_in_mesh.position.y = pillar.height * 0.5
		var shrine_mat := StandardMaterial3D.new()
		shrine_mat.albedo_color = Color(0.35, 0.82, 0.42)
		shrine_mat.emission_enabled = true
		shrine_mat.emission = Color(0.25, 0.65, 0.35) * 0.5
		_turn_in_mesh.material_override = shrine_mat
		_turn_in_mesh.layers = WorldVisualLayersScript.WORLD
		_turn_in_root.add_child(_turn_in_mesh)

		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.55
		torus.outer_radius = 0.75
		ring.mesh = torus
		ring.position.y = 0.08
		ring.rotation.x = PI * 0.5
		var ring_mat := StandardMaterial3D.new()
		ring_mat.albedo_color = Color(0.45, 0.95, 0.55)
		ring_mat.emission_enabled = true
		ring_mat.emission = Color(0.35, 0.85, 0.45) * 0.35
		ring.material_override = ring_mat
		_turn_in_root.add_child(ring)


func _sync_item_transform() -> void:
	if _item_root == null:
		return
	_item_root.global_position = _item_world_pos


func _update_world_bob() -> void:
	if _item_root == null:
		return
	var pos := _item_world_pos
	pos.y += sin(_bob_time * BOB_SPEED) * BOB_AMPLITUDE
	_item_root.global_position = pos


func _attach_to_carrier(player: Node3D) -> void:
	if _item_root == null or player == null:
		return
	var anchor := player.get_node_or_null("Head") as Node3D
	if anchor == null:
		anchor = player
	if _item_root.get_parent() != anchor:
		_item_root.reparent(anchor)
	_item_root.position = CARRY_OFFSET
	_item_root.rotation = Vector3.ZERO


func _detach_item_to_turn_in() -> void:
	if _item_root == null:
		return
	if _item_root.get_parent() != _turn_in_root:
		_item_root.reparent(_turn_in_root)
	_item_root.position = Vector3(0.0, 1.2, 0.0)
	_item_root.scale = Vector3.ONE * 0.85
	if _turn_in_mesh != null:
		var shrine_mat := _turn_in_mesh.material_override as StandardMaterial3D
		if shrine_mat != null:
			shrine_mat.emission = Color(0.55, 0.95, 0.65) * 0.9


func _stop_caster_spells(player: Node) -> void:
	if player is Player:
		(player as Player).stop_casting_for_relic_carry()
