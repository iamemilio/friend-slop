@tool
extends Node3D

## Monster look-dev: one monster + wand. Cast Fireball aims at the monster (no aiming UI).
## Works in the editor via lookdev flight, and in Play (F6) — Space also casts.

const MonsterScene := preload("res://scenes/monsters/monster.tscn")
const FireballProjectileScript := preload("res://scripts/spells/fireball_projectile.gd")
const FireballSpell := preload("res://resources/spells/fireball.tres")

@export_group("Monster")
@export_tool_button("Ensure One Monster", "Callable")
var ensure_monster_action := ensure_one_monster
@export_tool_button("Clear Monster + Corpses", "Callable")
var clear_monsters_action := clear_monsters_and_corpses
## Look-dev HP so one default fireball (20) can kill for death/ragdoll preview.
@export_range(1.0, 200.0, 1.0) var preview_max_health: float = 20.0
@export_range(1.0, 60.0, 0.5) var preview_death_linger_sec: float = 10.0
@export_range(0.25, 10.0, 0.25) var preview_death_fade_sec: float = 2.0

@export_group("Fireball")
@export_tool_button("Cast Fireball", "Callable")
var cast_fireball_action := cast_fireball_at_monster
@export_range(0.0, 1.5, 0.05) var tip_forward_nudge: float = 0.08

var _spawn_root: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cache_spawn_root()
	_ensure_bucket("FireballPreview")
	ensure_one_monster()
	_aim_wand_at_monster()
	set_process(true)
	set_process_unhandled_input(true)


func _process(_delta: float) -> void:
	_aim_wand_at_monster()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() and not _is_playing_lookdev():
		return
	if event.is_action_pressed("ui_accept") or (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and (event as InputEventKey).keycode == KEY_SPACE
	):
		cast_fireball_at_monster()
		get_viewport().set_input_as_handled()


func ensure_one_monster() -> void:
	_cache_spawn_root()
	if _spawn_root == null:
		return
	var living := _living_monster()
	if living != null:
		living.process_mode = Node.PROCESS_MODE_ALWAYS
		_apply_preview_stats(living)
		return
	## Remove leftover corpses / dead shells, then spawn exactly one.
	for child in _spawn_root.get_children():
		child.queue_free()
	var monster: Node = MonsterScene.instantiate()
	monster.process_mode = Node.PROCESS_MODE_ALWAYS
	_spawn_root.add_child(monster)
	if Engine.is_editor_hint():
		var edited := get_tree().edited_scene_root if get_tree() != null else null
		if edited != null:
			monster.owner = edited
	if monster is Node3D:
		(monster as Node3D).global_position = _spawn_root.global_position
	_apply_preview_stats(monster)


func clear_monsters_and_corpses() -> void:
	_cache_spawn_root()
	if _spawn_root == null:
		return
	for child in _spawn_root.get_children():
		child.queue_free()
	_clear_bucket("FireballPreview")


func cast_fireball_at_monster() -> void:
	if not is_inside_tree():
		return
	ensure_one_monster()
	var monster := _living_monster()
	if monster == null:
		push_warning("MonsterWorkspace: no living monster to shoot")
		return
	_apply_preview_stats(monster)

	var origin := _wand_cast_origin()
	var aim_at: Vector3 = (monster as Node3D).global_position + Vector3(0.0, 0.4, 0.0)
	var direction := aim_at - origin
	if direction.length_squared() < 0.0001:
		direction = Vector3(0.0, 0.0, -1.0)
	else:
		direction = direction.normalized()
	origin += direction * tip_forward_nudge

	var wand := _wand()
	if wand != null and wand.has_method("play_cast_success"):
		wand.call("play_cast_success", FireballSpell, true)

	var bucket := _ensure_bucket("FireballPreview")
	## One shot at a time for clear look-dev.
	_clear_bucket_children(bucket)
	var lookdev := Engine.is_editor_hint()
	var projectile: Node = FireballProjectileScript.spawn(
		bucket, origin, direction, null, lookdev
	)
	if projectile != null:
		projectile.process_mode = Node.PROCESS_MODE_ALWAYS
		if lookdev and get_tree() != null:
			var root := get_tree().edited_scene_root
			if root != null:
				projectile.owner = root


func _living_monster() -> Node:
	_cache_spawn_root()
	if _spawn_root == null:
		return null
	for child in _spawn_root.get_children():
		if not (child is Node3D):
			continue
		if not child.has_method("die"):
			continue
		var alive = child.get("is_alive")
		if alive != null and not bool(alive):
			continue
		return child
	return null


func _apply_preview_stats(node: Node) -> void:
	if node == null:
		return
	if "max_health" in node:
		node.set("max_health", preview_max_health)
	if "current_health" in node:
		node.set("current_health", preview_max_health)
	if "death_linger_sec" in node:
		node.set("death_linger_sec", preview_death_linger_sec)
	if "death_fade_sec" in node:
		node.set("death_fade_sec", preview_death_fade_sec)


func _wand() -> Node3D:
	return get_node_or_null("Wand") as Node3D


func _wand_cast_origin() -> Vector3:
	var wand := _wand()
	if wand == null:
		return global_position + Vector3(-1.5, 1.0, 2.5)
	var tip := wand.get_node_or_null("Model/CastOrigin") as Node3D
	if tip == null:
		tip = wand.get_node_or_null("CastOrigin") as Node3D
	if tip != null:
		return tip.global_position
	return wand.global_position


func _aim_wand_at_monster() -> void:
	var wand := _wand()
	var monster := _living_monster()
	if wand == null or monster == null:
		return
	var tip := wand.get_node_or_null("Model/CastOrigin") as Node3D
	var from: Vector3 = tip.global_position if tip != null else wand.global_position
	var to: Vector3 = (monster as Node3D).global_position + Vector3(0.0, 0.4, 0.0)
	var flat := Vector3(to.x - from.x, to.y - from.y, to.z - from.z)
	if flat.length_squared() < 0.0001:
		return
	## Wand shaft points along local -Z (see player_wand Model).
	wand.look_at(to, Vector3.UP)


func _is_playing_lookdev() -> bool:
	## Editor Play Scene / runtime — not idle edited scene.
	return not Engine.is_editor_hint() or get_tree() != null and get_tree().edited_scene_root == null


func _ensure_bucket(bucket_name: String) -> Node3D:
	var bucket := get_node_or_null(bucket_name) as Node3D
	if bucket != null:
		bucket.process_mode = Node.PROCESS_MODE_ALWAYS
		return bucket
	bucket = Node3D.new()
	bucket.name = bucket_name
	bucket.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(bucket)
	if Engine.is_editor_hint() and get_tree() != null:
		var root := get_tree().edited_scene_root
		if root != null:
			bucket.owner = root
	return bucket


func _clear_bucket(bucket_name: String) -> void:
	var bucket := get_node_or_null(bucket_name) as Node3D
	if bucket == null:
		return
	_clear_bucket_children(bucket)


func _clear_bucket_children(bucket: Node) -> void:
	for child in bucket.get_children():
		child.queue_free()


func _cache_spawn_root() -> void:
	_spawn_root = get_node_or_null("SpawnRoot") as Node3D
