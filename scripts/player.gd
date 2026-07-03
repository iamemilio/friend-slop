extends CharacterBody3D

const WALK_SPEED := 3.0
const SPRINT_SPEED := 5.0
const JUMP_VELOCITY := 2.5
const MOUSE_SENSITIVITY := 0.002
const THIRD_PERSON_DISTANCE := 3.5
const THIRD_PERSON_HEIGHT := 2.0
const THIRD_PERSON_LOOK_AHEAD := 4.0
const THIRD_PERSON_WALL_PADDING := 0.35
const INTERACT_RANGE_SQ := 9.0
const PLAYER_MIN_SEPARATION := 0.55
const BODY_RADIUS := 0.20
const HEAD_RADIUS := 0.16
const BODY_CENTER_Y := BODY_RADIUS
const HEAD_CENTER_Y := BODY_RADIUS * 2.0 + HEAD_RADIUS
const COLLISION_WALL_PADDING := 0.08
const BODY_COLLISION_RADIUS := BODY_RADIUS + COLLISION_WALL_PADDING

const FireballProjectileScript := preload("res://scripts/spells/fireball_projectile.gd")

@export var player_index: int = 0
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _third_person: bool = false
var _snail_color: Color = Color.WHITE
var _spell_book: SpellBook
var _casting_session: SpellCastingSession
var _game_hud: CanvasLayer
var _effect_applier: Node
var _speed_boost_multiplier: float = 1.0
var _speed_boost_timer: float = 0.0
var _wand: PlayerWand

@onready var head: Node3D = $Head
@onready var camera_pivot: Node3D = $Head/CameraPivot
@onready var first_person_camera: Camera3D = $Head/CameraPivot/FirstPersonCamera
@onready var third_person_anchor: Node3D = $ThirdPersonAnchor
@onready var third_person_camera: Camera3D = $ThirdPersonCamera
@onready var position_trail: Node = $PositionTrailRecorder
@onready var spell_book: SpellBook = $SpellBook
@onready var casting_session: SpellCastingSession = $SpellCastingSession
@onready var effect_applier: Node = $SpellEffectApplier
@onready var _body_mesh: MeshInstance3D = $Body
@onready var _head_mesh: MeshInstance3D = $Head/HeadMesh
@onready var _body_collision: CollisionShape3D = $CollisionShape3D
@onready var _wand_node: PlayerWand = $Head/CameraPivot/FirstPersonCamera/Wand

func _ready() -> void:
	add_to_group("player")
	floor_block_on_wall = false
	floor_snap_length = 0.15
	safe_margin = 0.04
	_wand = _wand_node
	_configure_collision()
	_snail_color = GameState.get_snail_color(player_index)
	_apply_snail_color(_snail_color)
	_configure_network_player()


func _configure_collision() -> void:
	var body_capsule := CapsuleShape3D.new()
	body_capsule.radius = BODY_COLLISION_RADIUS
	var bottom_y := BODY_CENTER_Y - BODY_RADIUS
	var top_y := HEAD_CENTER_Y + HEAD_RADIUS
	var total_height := top_y - bottom_y
	body_capsule.height = maxf(0.08, total_height - body_capsule.radius * 2.0)
	_body_collision.shape = body_capsule
	_body_collision.position.y = bottom_y + body_capsule.radius + body_capsule.height * 0.5


func _configure_network_player() -> void:
	if is_multiplayer_authority():
		_third_person = SettingsManager.start_third_person
		_apply_camera_mode()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		first_person_camera.current = false
		third_person_camera.current = false


func initialize_player(index: int) -> void:
	player_index = index
	_snail_color = GameState.get_snail_color(player_index)
	_apply_snail_color(_snail_color)
	position_trail.setup(self)


func configure_interaction(
	spell_book_ref: SpellBook,
	casting_session_ref: SpellCastingSession,
	game_hud: CanvasLayer,
	effect_applier_ref: Node
) -> void:
	_spell_book = spell_book_ref
	_casting_session = casting_session_ref
	_game_hud = game_hud
	_effect_applier = effect_applier_ref
	if _casting_session != null:
		if not _casting_session.state_changed.is_connected(_on_cast_session_state_changed):
			_casting_session.state_changed.connect(_on_cast_session_state_changed)
		if not _casting_session.listen_level_changed.is_connected(_on_cast_listen_level_changed):
			_casting_session.listen_level_changed.connect(_on_cast_listen_level_changed)
		if not _casting_session.cast_succeeded.is_connected(_on_wand_cast_succeeded):
			_casting_session.cast_succeeded.connect(_on_wand_cast_succeeded)
		if not _casting_session.cast_failed.is_connected(_on_wand_cast_failed):
			_casting_session.cast_failed.connect(_on_wand_cast_failed)


func get_spell_book() -> SpellBook:
	return spell_book


func get_casting_session() -> SpellCastingSession:
	return casting_session


func get_effect_applier() -> Node:
	return effect_applier


func apply_speed_boost(duration: float, multiplier: float) -> void:
	_speed_boost_multiplier = multiplier
	_speed_boost_timer = duration


func apply_light_pulse(duration: float) -> void:
	if _wand != null:
		_wand.play_spell_light(duration)


func launch_fireball() -> void:
	launch_fireball_from_params(_aim_fireball_origin(), _aim_fireball_direction())


func launch_fireball_from_params(origin: Vector3, direction: Vector3) -> void:
	var world := get_tree().current_scene
	if world == null:
		world = get_parent()
	FireballProjectileScript.spawn(world, origin, direction.normalized())


func get_wand_cast_origin() -> Vector3:
	if _wand != null:
		return _wand.get_cast_origin()
	return _head_aim_origin()


func get_wand_cast_direction() -> Vector3:
	if _wand != null:
		return _wand.get_cast_direction()
	return _camera_aim_direction()


func _camera_aim_direction() -> Vector3:
	var forward := -camera_pivot.global_transform.basis.z.normalized()
	forward.y = clampf(forward.y, -0.25, 0.25)
	return forward.normalized()


func _head_aim_origin() -> Vector3:
	return head.global_position + _camera_aim_direction() * 0.6 + Vector3(0.0, 0.1, 0.0)


func _aim_fireball_direction() -> Vector3:
	return get_wand_cast_direction()


func _aim_fireball_origin() -> Vector3:
	return get_wand_cast_origin()


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		head.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		if not _third_person:
			camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
			camera_pivot.rotation.x = clampf(
				camera_pivot.rotation.x,
				deg_to_rad(-70.0),
				deg_to_rad(70.0)
			)

	if event.is_action_pressed("toggle_camera"):
		_third_person = not _third_person
		if _third_person:
			camera_pivot.rotation.x = 0.0
		_apply_camera_mode()

	if event.is_action_pressed("spellbook"):
		if _casting_session != null \
				and (_casting_session.is_active() or _casting_session.is_tome_teaching()):
			return
		if _game_hud != null and _game_hud.has_method("toggle_spellbook"):
			_game_hud.toggle_spellbook()

	if event.is_action_pressed("interact"):
		_try_interact()

	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_try_wand_arm()


func _on_cast_session_state_changed(state: String, _spell: SpellDefinition) -> void:
	if _wand == null:
		return
	var armed := (
		state == SpellCastingSession.STATE_ARMING
		or state == SpellCastingSession.STATE_LISTENING
		or state == SpellCastingSession.STATE_VALIDATING
	)
	_wand.set_armed(armed)


func _on_cast_listen_level_changed(level: float) -> void:
	if _wand != null:
		_wand.set_listen_level(level)


func _on_wand_cast_succeeded(
	spell: SpellDefinition,
	mode: String,
	_validation: CastValidationResult
) -> void:
	if _wand == null or mode != "cast":
		return
	_wand.play_cast_success(spell)


func _on_wand_cast_failed(
	_spell: SpellDefinition,
	_reason: String,
	_partial: CastValidationResult
) -> void:
	if _wand == null or _casting_session == null:
		return
	if _casting_session.is_tome_teaching():
		return
	_wand.play_fizzle()


func _apply_camera_mode() -> void:
	first_person_camera.current = not _third_person
	third_person_camera.current = _third_person
	if _third_person:
		_update_third_person_camera()


func _update_third_person_camera() -> void:
	third_person_anchor.rotation.y = head.rotation.y

	var origin := third_person_anchor.global_position
	var desired := third_person_anchor.to_global(
		Vector3(0.0, THIRD_PERSON_HEIGHT, THIRD_PERSON_DISTANCE)
	)

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, desired)
	query.exclude = [get_rid()]
	var hit := space_state.intersect_ray(query)

	if hit.is_empty():
		third_person_camera.global_position = desired
	else:
		var direction := (desired - origin).normalized()
		third_person_camera.global_position = hit.position - direction * THIRD_PERSON_WALL_PADDING

	var look_at_point := third_person_anchor.to_global(
		Vector3(0.0, 0.0, -THIRD_PERSON_LOOK_AHEAD)
	)
	third_person_camera.look_at(look_at_point, Vector3.UP)


func _separate_from_players() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if node == self or not node is CharacterBody3D:
			continue

		var other: CharacterBody3D = node as CharacterBody3D
		var away: Vector3 = global_position - other.global_position
		away.y = 0.0
		if away.length_squared() < 0.0001:
			away = Vector3(1.0, 0.0, 0.0)
		var distance: float = away.length()
		if distance >= PLAYER_MIN_SEPARATION:
			continue
		global_position += away.normalized() * (PLAYER_MIN_SEPARATION - distance)


func _apply_snail_color(color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.55
	material.emission_enabled = true
	material.emission = color * 0.25
	material.emission_energy_multiplier = 0.8
	_body_mesh.material_override = material
	var head_material := material.duplicate()
	head_material.albedo_color = color.lightened(0.08)
	head_material.emission = head_material.albedo_color * 0.25
	_head_mesh.material_override = head_material


func get_snail_color() -> Color:
	return _snail_color


func _try_interact() -> void:
	TomeDebug.log("Player", "F pressed — try_interact")
	if _casting_session != null and _casting_session.is_active():
		TomeDebug.log(
			"Player",
			"ignored: casting session active (state=%s)" % _casting_session.get_state()
		)
		return

	if _try_tome_teaching_interact():
		return

	var interactable: Interactable = _find_nearest_interactable()
	if interactable != null:
		TomeDebug.log(
			"Player",
			"interacting with %s (%s) dist=%.2f"
			% [
				interactable.name,
				interactable.get_class(),
				global_position.distance_to(interactable.global_position),
			]
		)
		interactable.interact(self)
		return

	TomeDebug.log("Player", "no interactable in range")


func _try_wand_arm() -> void:
	if not is_multiplayer_authority():
		return
	if _casting_session != null and _casting_session.is_tome_teaching():
		return
	if _casting_session != null and _casting_session.is_active():
		TomeDebug.log("Player", "canceling wand cast")
		_casting_session.cancel()
		if _wand != null:
			_wand.set_armed(false)
		return
	if _try_free_cast():
		return
	TomeDebug.log("Player", "wand arm ignored — no cast available")


func _try_tome_teaching_interact() -> bool:
	if _casting_session == null or not _casting_session.is_tome_teaching():
		return false
	var tome: TomeInteractable = _find_nearest_tome()
	if tome == null or not tome.can_interact(self):
		return false
	tome.interact(self)
	return true


func _try_free_cast() -> bool:
	if _spell_book == null or _casting_session == null:
		return false
	if not _spell_book.has_known_spells():
		return false
	if _game_hud != null and _game_hud.has_method("is_spellbook_open") \
			and _game_hud.is_spellbook_open():
		return false
	var candidates := _get_free_cast_candidates()
	if candidates.is_empty():
		return false
	TomeDebug.log(
		"Player",
		"starting free voice cast (%s)"
		% _format_candidate_ids(candidates)
	)
	_casting_session.start_free_cast(candidates)
	return true


func _get_free_cast_candidates() -> Array[SpellDefinition]:
	var candidates: Array[SpellDefinition] = _spell_book.get_known_spells()
	if candidates.is_empty():
		return candidates

	if _game_hud != null and _game_hud.has_method("get_selected_spell_id"):
		var selected_id: String = _game_hud.get_selected_spell_id()
		if not selected_id.is_empty() and _spell_book.knows(selected_id):
			var selected: SpellDefinition = _spell_book.get_spell_definition(selected_id)
			if selected != null:
				return [selected]

	if candidates.size() == 1:
		return candidates
	return candidates


func _format_candidate_ids(candidates: Array[SpellDefinition]) -> String:
	var ids: PackedStringArray = PackedStringArray()
	for spell in candidates:
		if spell != null:
			ids.append(spell.id)
	return ", ".join(ids)


func _find_nearest_interactable() -> Interactable:
	var best: Interactable = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("interactable"):
		if not node is Interactable:
			continue
		var interactable := node as Interactable
		if not interactable.can_interact(self):
			continue
		var dist := global_position.distance_squared_to(interactable.global_position)
		if dist < best_dist and dist <= INTERACT_RANGE_SQ:
			best_dist = dist
			best = interactable
	return best


func _find_nearest_tome() -> TomeInteractable:
	var best: TomeInteractable = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("interactable"):
		if not node is TomeInteractable:
			continue
		var tome := node as TomeInteractable
		if not tome.can_interact(self):
			continue
		var dist := global_position.distance_squared_to(tome.global_position)
		if dist < best_dist and dist <= INTERACT_RANGE_SQ:
			best_dist = dist
			best = tome
	return best


func _update_interaction_prompt() -> void:
	if _game_hud == null or not _game_hud.has_method("set_interaction_prompt"):
		return
	if _casting_session != null and _casting_session.is_tome_teaching():
		_game_hud.set_interaction_prompt("Leave tome [F]")
		return
	if _casting_session != null and _casting_session.is_active():
		return
	var interactable: Interactable = _find_nearest_interactable()
	if interactable != null:
		_game_hud.set_interaction_prompt(interactable.get_prompt())
		return
	if _spell_book != null and _spell_book.has_known_spells():
		_game_hud.set_interaction_prompt("Arm wand [LMB] · Spellbook [B]")
		return
	_game_hud.set_interaction_prompt("")


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if _speed_boost_timer > 0.0:
		_speed_boost_timer -= delta
		if _speed_boost_timer <= 0.0:
			_speed_boost_multiplier = 1.0

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (head.transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var speed := (SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED)
	speed *= _speed_boost_multiplier
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()
	_separate_from_players()
	_update_interaction_prompt()

	if _third_person:
		_update_third_person_camera()
