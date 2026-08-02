class_name BroomFlight
extends Node

## Toggleable broom mount shared by every PlayableCharacter.
## [1] summons when can_summon; world pickups ride via mount_world_broom().
## Tune flight feel on PlayableCharacter → BroomFlight — BroomMount is poses only.

const BroomLocomotionScript := preload("res://scripts/headmaster/broom_locomotion.gd")
const InputPromptScript := preload("res://scripts/ui/input_prompt.gd")
const BroomScene := preload("res://scenes/headmaster/broom.tscn")
const DroppedBroomScript := preload("res://scripts/headmaster/dropped_broom.gd")

## If true, [1] summons when unmounted.
@export var can_summon := true

@export_group("Flight feel")
@export_range(0.5, 40.0, 0.1, "or_greater") var move_speed: float = (
	BroomLocomotionScript.MAX_SPEED
)
@export_range(0.5, 80.0, 0.1, "or_greater") var sprint_speed: float = 15.0
@export_range(0.0, 40.0, 0.1, "or_greater") var friction: float = (
	BroomLocomotionScript.FRICTION
)
@export_range(0.5, 40.0, 0.1, "or_greater") var acceleration: float = (
	BroomLocomotionScript.ACCEL
)
@export_range(0.5, 40.0, 0.1, "or_greater") var climb_speed: float = (
	BroomLocomotionScript.CLIMB_SPEED
)

var _player: CharacterBody3D
var _active := false
## True while riding a dropped/contested broom — [1] dismount drops it.
var _world_broom := false
## World-space XZ momentum — camera turns do not redirect coasting.
var _planar_vel := Vector3.ZERO
var _mount_visual: Node3D
var _mount_anchor: Node3D


static func ensure_on(player: CharacterBody3D, summon_allowed: bool = true) -> Node:
	if player == null:
		return null
	var existing := player.get_node_or_null("BroomFlight")
	if existing != null:
		if summon_allowed:
			existing.set("can_summon", true)
		if existing.has_method("configure"):
			existing.call("configure", player)
		return existing
	var flight = new()
	flight.name = "BroomFlight"
	flight.can_summon = summon_allowed
	player.add_child(flight)
	flight.configure(player)
	return flight


func configure(player: CharacterBody3D) -> void:
	_player = player


func is_active() -> bool:
	return _active


func get_planar_velocity() -> Vector3:
	return _planar_vel


func get_prompt() -> String:
	if _active:
		return InputPromptScript.with_action("broom_toggle", "Dismount broom")
	if can_summon:
		return InputPromptScript.with_action("broom_toggle", "Mount broom")
	return ""


func _ready() -> void:
	if _player == null:
		_player = get_parent() as CharacterBody3D
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or not _player.is_multiplayer_authority():
		return
	if not event.is_action_pressed("broom_toggle"):
		return
	if _active:
		## Personal summon holsters; a picked-up world broom drops back out.
		dismount(_world_broom)
		get_viewport().set_input_as_handled()
	elif can_summon:
		mount()
		get_viewport().set_input_as_handled()


func mount() -> void:
	if _active or _player == null:
		return
	_world_broom = false
	_active = true
	_planar_vel = Vector3.ZERO
	_ensure_mount_visual()
	_apply_mount_pose(true)
	_sync_player_broom_flag(true)


func mount_world_broom() -> void:
	## Ride a dropped broom; dismount returns it to the world.
	if _active or _player == null:
		return
	_world_broom = true
	_active = true
	_planar_vel = Vector3.ZERO
	_ensure_mount_visual()
	_apply_mount_pose(true)
	_sync_player_broom_flag(true)


func dismount(drop_to_world: bool) -> void:
	if not _active:
		return
	var drop_vel := _planar_vel
	var drop_pos := Vector3.ZERO
	if _player != null:
		drop_pos = _player.global_position
	var should_drop := drop_to_world or _world_broom
	_world_broom = false
	_active = false
	_planar_vel = Vector3.ZERO
	_apply_mount_pose(false)
	_sync_player_broom_flag(false)
	if should_drop and _player != null:
		DroppedBroomScript.spawn_networked(drop_pos, drop_vel, _player)


func knock_off(_fireball_dir: Vector3) -> void:
	if not _active or _player == null:
		return
	var broom_vel := _planar_vel
	if broom_vel.length_squared() < 2.25:
		var forward := _facing_forward()
		broom_vel = BroomLocomotionScript.flat_forward(forward) * 1.5
	broom_vel.y = 2.0
	var drop_pos := _player.global_position
	_world_broom = false
	_active = false
	_planar_vel = Vector3.ZERO
	_apply_mount_pose(false)
	_sync_player_broom_flag(false)
	DroppedBroomScript.spawn_networked(drop_pos, broom_vel, _player)


func apply_locomotion(player: CharacterBody3D, delta: float, speed_multiplier: float = 1.0) -> void:
	if not _active or player == null:
		return
	var throttle := 0.0
	if Input.is_action_pressed("move_forward"):
		throttle += 1.0
	if Input.is_action_pressed("move_back"):
		throttle -= 1.0
	var strafe := 0.0
	if Input.is_action_pressed("move_right"):
		strafe += 1.0
	if Input.is_action_pressed("move_left"):
		strafe -= 1.0
	var boosting := Input.is_action_pressed("sprint")
	var haste := maxf(speed_multiplier, 0.1)
	var max_speed := (sprint_speed if boosting else move_speed) * haste
	var wish := BroomLocomotionScript.wish_direction(
		_facing_forward(), throttle, strafe
	)
	_planar_vel = BroomLocomotionScript.step_planar_velocity(
		_planar_vel, wish, delta, max_speed, acceleration, friction
	)
	var ascend := Input.is_action_pressed("jump")
	var descend := (
		Input.is_action_pressed("crouch") or Input.is_action_pressed("fly_descend")
	)
	var vertical := BroomLocomotionScript.vertical_velocity(ascend, descend, climb_speed)
	player.velocity.x = _planar_vel.x
	player.velocity.z = _planar_vel.z
	player.velocity.y = vertical


func set_active_visual(active: bool) -> void:
	## Remote peers: show mount/dismount pose from replicated broom_active.
	if active == _active and _mount_visual != null:
		_apply_mount_pose(active)
		return
	_active = active
	if active:
		_ensure_mount_visual()
	_apply_mount_pose(active)


func _facing_forward() -> Vector3:
	if _player == null:
		return Vector3.FORWARD
	var head: Node3D = _player.get_node_or_null("Head") as Node3D
	if head != null:
		return -head.global_transform.basis.z
	return -_player.global_transform.basis.z


func _ensure_mount_visual() -> void:
	if _mount_visual != null and is_instance_valid(_mount_visual):
		return
	if _player == null:
		return
	## Prefer Body/BroomMount so the broom yaws with the torso, not the camera pitch.
	_mount_anchor = _player.get_node_or_null("Body/BroomMount") as Node3D
	if _mount_anchor == null:
		_mount_anchor = _player.get_node_or_null("BroomMount") as Node3D
	if _mount_anchor == null:
		var body: Node3D = _player.get_node_or_null("Body") as Node3D
		_mount_anchor = Node3D.new()
		_mount_anchor.name = "BroomMount"
		if body != null:
			body.add_child(_mount_anchor)
		else:
			_player.add_child(_mount_anchor)
		_mount_anchor.position = Vector3(0.0, 0.15, -0.15)
		_mount_anchor.rotation_degrees = Vector3(12.0, 0.0, 0.0)
	## Prefer the scene-instanced broom (Headmaster), else spawn a runtime copy.
	if _mount_anchor.has_method("get_broom"):
		_mount_visual = _mount_anchor.call("get_broom") as Node3D
	if _mount_visual == null:
		_mount_visual = _mount_anchor.get_node_or_null("Broom") as Node3D
	if _mount_visual == null:
		_mount_visual = BroomScene.instantiate() as Node3D
		_mount_anchor.add_child(_mount_visual)


func _apply_mount_pose(mounted: bool) -> void:
	_ensure_mount_visual()
	if _mount_anchor != null and _mount_anchor.has_method("apply_mounted"):
		if mounted:
			_mount_anchor.call("apply_mounted")
		else:
			_mount_anchor.call("apply_dismounted")
		return
	if _mount_visual != null:
		_mount_visual.visible = mounted


func _sync_player_broom_flag(active: bool) -> void:
	if _player != null:
		_player.set("broom_active", active)
