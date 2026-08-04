class_name PlayerInventory
extends Node

## Per-player bag: 10 slots. Indices 0–3 are hotbar keys 1–4 (UI is 1-based).

signal inventory_changed()
signal item_used(item_id: String, slot_index: int)

const SLOT_COUNT := 10
const HOTBAR_COUNT := 4
const ITEM_BROOM := "broom"

@export var starting_items: Array[String] = []

var _slots: Array[String] = []


func _ready() -> void:
	_ensure_slot_array()
	for item_id in starting_items:
		if item_id.is_empty():
			continue
		add(item_id)
	set_process_unhandled_input(true)


func _ensure_slot_array() -> void:
	if _slots.size() == SLOT_COUNT:
		return
	_slots.clear()
	_slots.resize(SLOT_COUNT)
	for i in SLOT_COUNT:
		_slots[i] = ""


func has(item_id: String) -> bool:
	if item_id.is_empty():
		return false
	return _slots.has(item_id)


func add(item_id: String) -> bool:
	if item_id.is_empty():
		return false
	_ensure_slot_array()
	for i in SLOT_COUNT:
		if _slots[i].is_empty():
			_slots[i] = item_id
			inventory_changed.emit()
			return true
	return false


func remove(item_id: String) -> bool:
	if item_id.is_empty():
		return false
	_ensure_slot_array()
	for i in SLOT_COUNT:
		if _slots[i] == item_id:
			_slots[i] = ""
			inventory_changed.emit()
			return true
	return false


func get_slot(index: int) -> String:
	_ensure_slot_array()
	if index < 0 or index >= SLOT_COUNT:
		return ""
	return _slots[index]


func set_slot(index: int, item_id: String) -> void:
	_ensure_slot_array()
	if index < 0 or index >= SLOT_COUNT:
		return
	var next := item_id
	if _slots[index] == next:
		return
	_slots[index] = next
	inventory_changed.emit()


func swap_slots(a: int, b: int) -> void:
	_ensure_slot_array()
	if a < 0 or a >= SLOT_COUNT or b < 0 or b >= SLOT_COUNT or a == b:
		return
	var tmp := _slots[a]
	_slots[a] = _slots[b]
	_slots[b] = tmp
	inventory_changed.emit()


func get_slots() -> Array[String]:
	_ensure_slot_array()
	return _slots.duplicate()


func find_slot(item_id: String) -> int:
	if item_id.is_empty():
		return -1
	_ensure_slot_array()
	for i in SLOT_COUNT:
		if _slots[i] == item_id:
			return i
	return -1


func use_slot(index: int) -> bool:
	_ensure_slot_array()
	if index < 0 or index >= SLOT_COUNT:
		return false
	var item_id := _slots[index]
	if item_id.is_empty():
		return false
	if not _use_item(item_id):
		return false
	item_used.emit(item_id, index)
	return true


func display_name(item_id: String) -> String:
	if item_id.is_empty():
		return ""
	match item_id:
		ITEM_BROOM:
			return "Broom"
		_:
			return item_id.capitalize()


func _use_item(item_id: String) -> bool:
	match item_id:
		ITEM_BROOM:
			return _toggle_broom()
		_:
			return false


func _toggle_broom() -> bool:
	var player := get_parent() as CharacterBody3D
	if player == null:
		return false
	var flight := player.get_node_or_null("BroomFlight")
	if flight == null:
		return false
	var mounted := flight.has_method("is_active") and bool(flight.call("is_active"))
	if mounted:
		if flight.has_method("dismount"):
			flight.call("dismount", false)
			return true
		return false
	if not has(ITEM_BROOM) or not flight.has_method("mount"):
		return false
	flight.call("mount")
	return true


func _unhandled_input(event: InputEvent) -> void:
	var player := get_parent() as Node
	if player == null or not player.is_multiplayer_authority():
		return
	if _is_menu_blocking():
		return
	for i in HOTBAR_COUNT:
		var action := "hotbar_%d" % (i + 1)
		if event.is_action_pressed(action):
			use_slot(i)
			get_viewport().set_input_as_handled()
			return


func _is_menu_blocking() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	if tree.paused:
		return true
	var hud := tree.get_first_node_in_group("game_hud")
	if hud != null and hud.has_method("is_player_menu_open") and bool(hud.call("is_player_menu_open")):
		return true
	return false
