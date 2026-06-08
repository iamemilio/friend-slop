class_name NorayTransport
extends MultiplayerTransport

const DEFAULT_NORAY_HOST := "tomfol.io"
const DEFAULT_NORAY_PORT := 8890
const MAX_PLAYERS := 4
const CONNECT_TIMEOUT_SEC := 12.0

var _tree: SceneTree
var _noray_host: String = DEFAULT_NORAY_HOST
var _noray_port: int = DEFAULT_NORAY_PORT
var _room_code: String = ""
var _connect_handlers_bound: bool = false
var _client_connect_pending: bool = false
var _client_connect_result: Error = OK


func setup(tree: SceneTree) -> void:
	_tree = tree


func get_room_code() -> String:
	return _room_code


static func validate_room_code(room_code: String) -> Error:
	if room_code.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	return OK


func host(options: Dictionary) -> Error:
	_noray_host = str(options.get("noray_host", DEFAULT_NORAY_HOST))
	_noray_port = int(options.get("noray_port", DEFAULT_NORAY_PORT))
	_room_code = ""
	_bind_connect_handlers()
	_ensure_offline_peer()

	status_changed.emit("Connecting to Noray…")
	var err: Error = await Noray.connect_to_host(_noray_host, _noray_port)
	if err != OK:
		status_changed.emit("Could not reach Noray.")
		return err

	status_changed.emit("Registering host…")
	Noray.register_host()
	await Noray.on_pid

	err = await Noray.register_remote()
	if err != OK:
		status_changed.emit("Failed to register with Noray.")
		return err

	var peer := ENetMultiplayerPeer.new()
	err = peer.create_server(Noray.local_port, MAX_PLAYERS)
	if err != OK:
		status_changed.emit("Failed to start game server.")
		return err

	_tree.get_multiplayer().multiplayer_peer = peer
	_room_code = Noray.oid
	status_changed.emit("Room ready. Share code: %s" % _room_code)
	return OK


func join(options: Dictionary) -> Error:
	_noray_host = str(options.get("noray_host", DEFAULT_NORAY_HOST))
	_noray_port = int(options.get("noray_port", DEFAULT_NORAY_PORT))
	var host_code := str(options.get("room_code", "")).strip_edges()
	var validation := validate_room_code(host_code)
	if validation != OK:
		status_changed.emit("Enter a room code.")
		return validation

	_bind_connect_handlers()
	_ensure_offline_peer()

	status_changed.emit("Connecting to Noray…")
	var err: Error = await Noray.connect_to_host(_noray_host, _noray_port)
	if err != OK:
		status_changed.emit("Could not reach Noray.")
		return err

	status_changed.emit("Registering client…")
	Noray.register_host()
	await Noray.on_pid

	err = await Noray.register_remote()
	if err != OK:
		status_changed.emit("Failed to register with Noray.")
		return err

	status_changed.emit("Finding host…")
	err = await _connect_to_host(host_code, true)
	if err == OK:
		status_changed.emit("Connected to host.")
		return OK

	status_changed.emit("NAT failed, trying relay…")
	err = await _connect_to_host(host_code, false)
	if err == OK:
		status_changed.emit("Connected to host via relay.")
		return OK

	status_changed.emit("Could not connect to host.")
	return err


func disconnect_session() -> void:
	var mp := _tree.get_multiplayer()
	var peer := mp.multiplayer_peer
	if peer != null and not peer is OfflineMultiplayerPeer:
		peer.close()
	_ensure_offline_peer()
	if Noray.is_connected_to_host():
		Noray.disconnect_from_host()
	_room_code = ""
	_client_connect_pending = false


func _ensure_offline_peer() -> void:
	var mp := _tree.get_multiplayer()
	if mp.multiplayer_peer == null:
		mp.multiplayer_peer = OfflineMultiplayerPeer.new()


func _bind_connect_handlers() -> void:
	if _connect_handlers_bound:
		return
	Noray.on_connect_nat.connect(_handle_connect)
	Noray.on_connect_relay.connect(_handle_connect)
	_connect_handlers_bound = true


func _connect_to_host(host_code: String, use_nat: bool) -> Error:
	_client_connect_pending = true
	_client_connect_result = ERR_TIMEOUT

	if use_nat:
		Noray.connect_nat(host_code)
	else:
		Noray.connect_relay(host_code)

	var elapsed := 0.0
	while _client_connect_pending and elapsed < CONNECT_TIMEOUT_SEC:
		await _tree.process_frame
		elapsed += _tree.root.get_process_delta_time()

	if _client_connect_pending:
		_client_connect_pending = false
		return ERR_TIMEOUT
	return _client_connect_result


func _handle_connect(address: String, port: int) -> void:
	var mp := _tree.get_multiplayer()
	var active_peer := mp.multiplayer_peer as ENetMultiplayerPeer
	if active_peer != null and mp.is_server():
		await PacketHandshake.over_enet_peer(active_peer, address, port)
		return

	var udp := PacketPeerUDP.new()
	udp.bind(Noray.local_port)
	udp.set_dest_address(address, port)

	var err: Error = await PacketHandshake.over_packet_peer(udp)
	udp.close()

	if err != OK and err != ERR_BUSY:
		_client_connect_result = err
		_client_connect_pending = false
		return

	var peer := ENetMultiplayerPeer.new()
	err = peer.create_client(address, port, 0, 0, 0, Noray.local_port)
	if err != OK:
		_client_connect_result = err
		_client_connect_pending = false
		return

	_tree.get_multiplayer().multiplayer_peer = peer
	_client_connect_result = OK
	_client_connect_pending = false
