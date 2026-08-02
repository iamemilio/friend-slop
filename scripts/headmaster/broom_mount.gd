@tool
class_name BroomMount
extends Node3D

## Anchor for the shared playable broom visual (lives under Body so yaw follows torso).
## Edit Mounted / Dismounted poses in the Inspector (toggle `editor_pose`).

enum EditorPose {
	MOUNTED,
	DISMOUNTED,
}

@export_group("Editor pose preview")
@export var editor_pose: EditorPose = EditorPose.DISMOUNTED:
	set(value):
		if editor_pose != value and get_broom() != null:
			_capture_current_into_active_pose()
		editor_pose = value
		_apply_editor_pose()

@export_group("Stored poses")
@export var mount_transform: Transform3D = Transform3D.IDENTITY:
	set(value):
		mount_transform = value
		if Engine.is_editor_hint() and editor_pose == EditorPose.MOUNTED:
			_apply_transform_to_broom(mount_transform)

@export var dismount_transform: Transform3D = Transform3D(
	Basis.from_euler(Vector3(deg_to_rad(70.0), deg_to_rad(90.0), 0.0)),
	Vector3(0.35, 0.1, -0.05)
):
	set(value):
		dismount_transform = value
		if Engine.is_editor_hint() and editor_pose == EditorPose.DISMOUNTED:
			_apply_transform_to_broom(dismount_transform)

@export var show_broom_when_dismounted := true


func _ready() -> void:
	if Engine.is_editor_hint():
		_apply_editor_pose()
		return
	apply_dismounted()


func get_broom() -> Node3D:
	return get_node_or_null("Broom") as Node3D


func apply_mounted() -> void:
	var broom := get_broom()
	if broom == null:
		return
	broom.transform = mount_transform
	broom.visible = true


func apply_dismounted() -> void:
	var broom := get_broom()
	if broom == null:
		return
	broom.transform = dismount_transform
	broom.visible = show_broom_when_dismounted


func _apply_editor_pose() -> void:
	if not Engine.is_editor_hint():
		return
	var broom := get_broom()
	if broom == null:
		return
	match editor_pose:
		EditorPose.MOUNTED:
			broom.transform = mount_transform
			broom.visible = true
		EditorPose.DISMOUNTED:
			broom.transform = dismount_transform
			broom.visible = true


func _capture_current_into_active_pose() -> void:
	if not Engine.is_editor_hint():
		return
	var broom := get_broom()
	if broom == null:
		return
	match editor_pose:
		EditorPose.MOUNTED:
			mount_transform = broom.transform
		EditorPose.DISMOUNTED:
			dismount_transform = broom.transform


func _apply_transform_to_broom(xf: Transform3D) -> void:
	var broom := get_broom()
	if broom != null:
		broom.transform = xf


func _notification(what: int) -> void:
	if what != NOTIFICATION_EDITOR_PRE_SAVE:
		return
	_capture_current_into_active_pose()
