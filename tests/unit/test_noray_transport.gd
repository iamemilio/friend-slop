class_name TestNorayTransport
extends RefCounted

const NorayTransportScript := preload("res://scripts/network/noray_transport.gd")


func run() -> int:
	var failures := 0
	failures += _test_default_room_code_is_empty()
	failures += _test_validate_room_code_rejects_blank()
	failures += _test_validate_room_code_accepts_non_blank()
	failures += _test_disconnect_session_without_peer()
	return failures


func _test_default_room_code_is_empty() -> int:
	var transport := NorayTransportScript.new()
	if transport.get_room_code() != "":
		push_error("Expected Noray transport room code to start empty")
		return 1
	return 0


func _test_validate_room_code_rejects_blank() -> int:
	if NorayTransportScript.validate_room_code("") != ERR_INVALID_PARAMETER:
		push_error("Expected blank room code to be invalid")
		return 1
	if NorayTransportScript.validate_room_code("   ") != ERR_INVALID_PARAMETER:
		push_error("Expected whitespace-only room code to be invalid")
		return 1
	return 0


func _test_validate_room_code_accepts_non_blank() -> int:
	if NorayTransportScript.validate_room_code("abcd1234") != OK:
		push_error("Expected non-empty room code to validate")
		return 1
	return 0


func _test_disconnect_session_without_peer() -> int:
	var tree := Engine.get_main_loop()
	if tree == null or not tree is SceneTree:
		push_error("Expected headless tests to run under a SceneTree")
		return 1

	var transport := NorayTransportScript.new()
	transport.setup(tree as SceneTree)
	transport.disconnect_session()

	if transport.get_room_code() != "":
		push_error("Expected disconnect_session to clear room code")
		return 1
	return 0
