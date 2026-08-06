class_name Monster
extends Character

## Combat-ready AI character. Extends Character (not PlayableCharacter):
## no camera, wand, "player" group, or multiplayer authority.
##
## AI: senses append interest candidates → _prefer_interest → IDLE/PATROL/CHASE.
## Override _prefer_interest / _append_default_interest_candidates on children;
## add MonsterSense nodes under Senses to customize perception without forking the FSM.

const BroomLocomotionScript := preload("res://scripts/headmaster/broom_locomotion.gd")
const MonsterAIScript := preload("res://scripts/monsters/monster_ai.gd")
const MonsterInterestScript := preload("res://scripts/monsters/monster_interest.gd")
const MonsterCorpseScript := preload("res://scripts/monsters/monster_corpse.gd")

const DEFAULT_TINT := Color(0.72, 0.28, 0.22, 1.0)
const IDLE_DURATION_SEC := 1.2
const PATROL_RADIUS := 4.0
const PATROL_ARRIVE_DIST := 0.45
const KNOCKBACK_TIMER_SEC := 0.35
const DEFAULT_PLAYER_SOURCE := &"player"
const DEATH_IMPULSE_SCALE := 1.35

@export var max_health: float = 60.0
@export var move_speed: float = 3.2
@export var chase_range: float = 12.0
@export var attack_range: float = 1.4
@export var touch_damage: float = 8.0
@export var gravity: float = 18.0
@export var death_linger_sec: float = 30.0
@export var death_fade_sec: float = 3.0

var current_health: float = 60.0
var is_alive: bool = true

var _ai_state: int = MonsterAIScript.State.IDLE
var _idle_timer: float = 0.0
var _patrol_goal: Vector3 = Vector3.ZERO
var _interest: RefCounted = null
var _knockback_vel: Vector3 = Vector3.ZERO
var _knockback_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _senses_root: Node = null
var _last_hit_dir: Vector3 = Vector3.FORWARD
var _dying: bool = false


func _ready() -> void:
	add_to_group("monster")
	add_to_group("combat_target")
	current_health = max_health
	is_alive = true
	_rng.randomize()
	_senses_root = get_node_or_null("Senses")
	_apply_character_color(DEFAULT_TINT)
	_enter_idle()
	set_physics_process(true)


func apply_summon_appearance(tint: Color) -> void:
	## Used by the headmaster summon book after instantiate.
	_apply_character_color(tint)


func take_damage(amount: float, from: Node3D = null) -> void:
	if not is_alive:
		return
	_remember_hit_dir(from)
	current_health = MonsterAIScript.apply_damage(current_health, amount)
	if MonsterAIScript.is_dead(current_health):
		die()


func heal(amount: float) -> void:
	if not is_alive:
		return
	current_health = MonsterAIScript.apply_heal(current_health, amount, max_health)


func die() -> void:
	if _dying or not is_alive:
		return
	_dying = true
	is_alive = false
	current_health = 0.0
	_ai_state = MonsterAIScript.State.IDLE
	_interest = null
	velocity = Vector3.ZERO
	set_physics_process(false)
	if is_in_group("monster"):
		remove_from_group("monster")
	if is_in_group("combat_target"):
		remove_from_group("combat_target")
	_spawn_ragdoll_corpse()
	queue_free()


func apply_fireball_knockback(fireball_dir: Vector3) -> void:
	if not is_alive:
		return
	if fireball_dir.length_squared() > 0.0001:
		_last_hit_dir = fireball_dir.normalized()
	var impulse: Vector3 = BroomLocomotionScript.knockback_impulse(fireball_dir)
	_knockback_vel = impulse
	_knockback_timer = KNOCKBACK_TIMER_SEC
	velocity += impulse


func _remember_hit_dir(from: Node3D) -> void:
	if from == null:
		return
	var away := global_position - from.global_position
	away.y = 0.0
	if away.length_squared() > 0.0001:
		_last_hit_dir = away.normalized()


func _spawn_ragdoll_corpse() -> void:
	## No skeleton on the character shell — tumble as one RigidBody with body/head meshes.
	var parent_node := get_parent()
	if parent_node == null or not is_inside_tree():
		return
	var corpse := RigidBody3D.new()
	corpse.name = "%sCorpse" % name
	corpse.set_script(MonsterCorpseScript)
	parent_node.add_child(corpse)
	corpse.global_transform = global_transform

	_reparent_to_corpse(_body_collision, corpse)
	_reparent_to_corpse(_body_mesh, corpse)
	_reparent_to_corpse(head, corpse)

	var impulse: Vector3 = BroomLocomotionScript.knockback_impulse(_last_hit_dir)
	impulse *= DEATH_IMPULSE_SCALE
	if corpse.has_method("begin_death_sequence"):
		corpse.call(
			"begin_death_sequence",
			impulse,
			death_linger_sec,
			death_fade_sec
		)


func _reparent_to_corpse(node: Node, corpse: Node) -> void:
	if node == null or corpse == null:
		return
	var xf: Transform3D
	var is_spatial := node is Node3D
	if is_spatial:
		xf = (node as Node3D).global_transform
	var old_parent := node.get_parent()
	if old_parent != null:
		old_parent.remove_child(node)
	corpse.add_child(node)
	if is_spatial:
		(node as Node3D).global_transform = xf


## Collects candidates (default players + senses) and prefers one. Override to replace.
func _gather_interest() -> RefCounted:
	var candidates: Array = []
	_append_default_interest_candidates(candidates)
	_append_sense_interest_candidates(candidates)
	return _prefer_interest(candidates)


## Default: nearest living player in chase_range as a proximity-scored interest.
func _append_default_interest_candidates(out: Array) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var players := tree.get_nodes_in_group("player")
	var positions: Array = []
	var alive_flags: Array = []
	var nodes: Array = []
	for node in players:
		if node is Node3D:
			var n3 := node as Node3D
			positions.append(n3.global_position)
			var alive_value = n3.get("is_alive")
			alive_flags.append(true if alive_value == null else bool(alive_value))
			nodes.append(n3)
	var idx: int = MonsterAIScript.pick_nearest_target_index(
		global_position, positions, alive_flags, chase_range
	)
	if idx < 0:
		return
	var target: Node3D = nodes[idx] as Node3D
	var urgency: float = MonsterAIScript.proximity_urgency(
		global_position, target.global_position, chase_range
	)
	out.append(
		MonsterInterestScript.from_target(target, urgency, DEFAULT_PLAYER_SOURCE)
	)


## Reads MonsterSense children under Senses/.
func _append_sense_interest_candidates(out: Array) -> void:
	if _senses_root == null:
		_senses_root = get_node_or_null("Senses")
	if _senses_root == null:
		return
	for child in _senses_root.get_children():
		if child.has_method("append_interest_candidates"):
			child.call("append_interest_candidates", self, out)


## Default preferencing: highest urgency. Children override to weight sources.
func _prefer_interest(candidates: Array) -> RefCounted:
	return MonsterAIScript.prefer_highest_urgency(candidates)


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	_interest = _gather_interest()
	var has_interest := _interest_is_actionable(_interest)
	var previous: int = _ai_state
	_ai_state = MonsterAIScript.resolve_state(_ai_state, has_interest)
	if previous == MonsterAIScript.State.CHASE and _ai_state == MonsterAIScript.State.IDLE:
		_enter_idle()

	match _ai_state:
		MonsterAIScript.State.IDLE:
			_tick_idle(delta)
		MonsterAIScript.State.PATROL:
			_tick_patrol(delta)
		MonsterAIScript.State.CHASE:
			_tick_chase(delta)

	_apply_knockback_bleed(delta)
	move_and_slide()


func _interest_is_actionable(interest: RefCounted) -> bool:
	if interest == null:
		return false
	if interest.has_method("is_actionable"):
		return bool(interest.call("is_actionable"))
	return false


func _enter_idle() -> void:
	_ai_state = MonsterAIScript.State.IDLE
	_idle_timer = 0.0
	velocity.x = 0.0
	velocity.z = 0.0


func _tick_idle(delta: float) -> void:
	_idle_timer += delta
	velocity.x = 0.0
	velocity.z = 0.0
	if _idle_timer >= IDLE_DURATION_SEC:
		_begin_patrol()


func _begin_patrol() -> void:
	_ai_state = MonsterAIScript.State.PATROL
	_patrol_goal = MonsterAIScript.random_patrol_point(
		global_position,
		PATROL_RADIUS,
		_rng.randf() * TAU,
		_rng.randf_range(0.35, 1.0)
	)


func _tick_patrol(_delta: float) -> void:
	var flat := Vector3(
		_patrol_goal.x - global_position.x,
		0.0,
		_patrol_goal.z - global_position.z
	)
	if flat.length() <= PATROL_ARRIVE_DIST:
		_enter_idle()
		return
	var desired: Vector3 = MonsterAIScript.horizontal_velocity_toward(
		global_position, _patrol_goal, move_speed, velocity.y
	)
	velocity.x = desired.x
	velocity.z = desired.z
	_face_horizontal(desired)


func _tick_chase(_delta: float) -> void:
	if not _interest_is_actionable(_interest):
		_enter_idle()
		return
	var goal: Vector3 = _interest.call("resolved_goal_position", global_position)
	var target: Node3D = _interest.get("target") as Node3D
	var to_goal := Vector3(goal.x - global_position.x, 0.0, goal.z - global_position.z)
	if to_goal.length() <= attack_range:
		velocity.x = 0.0
		velocity.z = 0.0
		if target != null and is_instance_valid(target):
			_try_touch_damage(target)
		return
	var desired: Vector3 = MonsterAIScript.horizontal_velocity_toward(
		global_position, goal, move_speed, velocity.y
	)
	velocity.x = desired.x
	velocity.z = desired.z
	_face_horizontal(desired)


func _try_touch_damage(target: Node3D) -> void:
	if target == null or not target.has_method("take_damage"):
		return
	target.call("take_damage", touch_damage * get_physics_process_delta_time(), self)


func _face_horizontal(desired_vel: Vector3) -> void:
	var flat := Vector3(desired_vel.x, 0.0, desired_vel.z)
	if flat.length_squared() < 0.0001:
		return
	look_at(global_position + flat.normalized(), Vector3.UP)


func _apply_knockback_bleed(delta: float) -> void:
	if _knockback_timer <= 0.0:
		return
	_knockback_timer -= delta
	velocity.x += _knockback_vel.x * 0.35
	velocity.z += _knockback_vel.z * 0.35
	_knockback_vel = _knockback_vel.move_toward(Vector3.ZERO, 28.0 * delta)
