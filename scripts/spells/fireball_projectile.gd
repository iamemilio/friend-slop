class_name FireballProjectile
extends Area3D

## Simple forward-moving fireball spawned by the fireball spell.

const SPEED := 16.0
const MAX_LIFETIME := 2.5
const HIT_RADIUS := 0.35

var _direction := Vector3.FORWARD
var _elapsed := 0.0


static func spawn(parent: Node, origin: Vector3, direction: Vector3) -> FireballProjectile:
	var projectile := FireballProjectile.new()
	projectile._direction = direction.normalized()
	projectile.global_position = origin
	parent.add_child(projectile)
	return projectile


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1

	var shape := SphereShape3D.new()
	shape.radius = HIT_RADIUS
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.45, 0.1)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.35, 0.05)
	material.emission_energy_multiplier = 2.5
	material.roughness = 0.2
	mesh_instance.material_override = material
	add_child(mesh_instance)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.15)
	light.light_energy = 2.0
	light.omni_range = 5.0
	add_child(light)

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= MAX_LIFETIME:
		queue_free()
		return

	var motion: Vector3 = _direction * SPEED * delta
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + motion)
	query.exclude = [get_rid()]
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		global_position += motion
	else:
		global_position = hit.position
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		return
	queue_free()
