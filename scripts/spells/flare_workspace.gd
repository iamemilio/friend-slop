@tool
extends Node3D

## Flare look-dev studio: one authored Flare instance + launch preview.

const FlareEffectScript := preload("res://scripts/spells/flare_effect.gd")
const FlareSpell := preload("res://resources/spells/flare.tres")

@export_group("Launch preview")
@export var hide_lookdev_during_cast := true
@export_range(0.0, 1.5, 0.05) var tip_forward_nudge: float = 0.0
@export_tool_button("Launch Flare", "Callable")
var launch_flare_action := launch_flare_preview
@export_tool_button("Clear Launch", "Callable")
var clear_launch_action := clear_launch_preview
@export_tool_button("Replay Lookdev Burn", "Callable")
var replay_lookdev_action := replay_lookdev_burn

var _preview_flare: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bucket("LaunchPreview")
	_refresh_lookdev_visibility()
	_force_wand_tip_visible()


func launch_flare_preview() -> void:
	if not is_inside_tree():
		return
	clear_launch_preview()
	var wand := _wand()
	var origin := Vector3(0.15, 1.05, 1.15)
	var direction := Vector3(0.15, 0.85, -0.4).normalized()
	if wand != null:
		origin = _resolve_cast_origin(wand)
		direction = (-wand.global_transform.basis.z).normalized()
		if wand.has_method("play_cast_success"):
			wand.call("play_cast_success", FlareSpell, true)
	origin += direction * tip_forward_nudge
	var bucket := _ensure_bucket("LaunchPreview")
	_preview_flare = FlareEffectScript.spawn_launched(bucket, origin, direction)
	if _preview_flare != null:
		_preview_flare.process_mode = Node.PROCESS_MODE_ALWAYS
		_preview_flare.tree_exited.connect(_on_preview_exited, CONNECT_ONE_SHOT)
	_refresh_lookdev_visibility()


func clear_launch_preview() -> void:
	_clear_bucket("LaunchPreview")
	_preview_flare = null
	_refresh_lookdev_visibility()


func replay_lookdev_burn() -> void:
	var lookdev := _lookdev_flare()
	if lookdev != null and lookdev.has_method("play_launch"):
		lookdev.call("play_launch")


func _on_preview_exited() -> void:
	_preview_flare = null
	_refresh_lookdev_visibility()


func _wand() -> Node3D:
	return get_node_or_null("Wand") as Node3D


func _lookdev_flare() -> Node3D:
	return get_node_or_null("Flare") as Node3D


func _resolve_cast_origin(wand: Node3D) -> Vector3:
	var tip := wand.get_node_or_null("Model/CastOrigin") as Node3D
	if tip == null:
		tip = wand.get_node_or_null("CastOrigin") as Node3D
	if tip != null:
		return tip.global_position
	return wand.global_position


func _force_wand_tip_visible() -> void:
	var wand := _wand()
	if wand == null:
		return
	var tip := wand.get_node_or_null("Model/Tip") as Node3D
	if tip == null:
		tip = wand.get_node_or_null("Tip") as Node3D
	if tip != null:
		tip.visible = true


func _ensure_bucket(bucket_name: String) -> Node3D:
	var bucket := get_node_or_null(bucket_name) as Node3D
	if bucket != null:
		bucket.process_mode = Node.PROCESS_MODE_ALWAYS
		return bucket
	bucket = Node3D.new()
	bucket.name = bucket_name
	bucket.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(bucket)
	if Engine.is_editor_hint():
		var root := get_tree().edited_scene_root
		if root != null:
			bucket.owner = root
	return bucket


func _clear_bucket(bucket_name: String) -> void:
	var bucket := get_node_or_null(bucket_name)
	if bucket == null:
		return
	for child in bucket.get_children():
		if Engine.is_editor_hint():
			child.free()
		else:
			child.queue_free()


func _refresh_lookdev_visibility() -> void:
	var lookdev := _lookdev_flare()
	if lookdev == null:
		return
	var preview_live := (
		_preview_flare != null and is_instance_valid(_preview_flare)
	)
	lookdev.visible = not (hide_lookdev_during_cast and preview_live)
