class_name TestMazeWallMesh
extends RefCounted

const MazeWallMeshScript := preload("res://scripts/maze_wall_mesh.gd")


func run() -> int:
	var failures := 0
	failures += _test_solid_wall_normals_point_outward()
	failures += _test_collision_shape_is_created()
	return failures


func _test_solid_wall_normals_point_outward() -> int:
	var grid := [
		[1, 1, 1],
		[1, 0, 1],
		[1, 1, 1],
	]
	var mesh := MazeWallMeshScript.build(
		grid,
		Vector3(3.0, 3.0, 3.0),
		func(gx: int, gy: int) -> Vector3:
			return Vector3(gx * 3.0, 0.0, gy * 3.0)
	)
	var failures := 0
	if mesh.get_surface_count() == 0:
		push_error("Expected wall mesh to contain at least one surface")
		return 1

	var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	if normals.is_empty():
		push_error("Expected wall mesh vertex normals")
		failures += 1
	else:
		if not _has_normal(normals, Vector3(0.0, 0.0, -1.0)):
			push_error("Expected outward -Z wall normals")
			failures += 1
		if not _has_normal(normals, Vector3(0.0, 1.0, 0.0)):
			push_error("Expected outward +Y wall normals")
			failures += 1
	return failures


func _test_collision_shape_is_created() -> int:
	var grid := [[1]]
	var mesh := MazeWallMeshScript.build(
		grid,
		Vector3(3.0, 3.0, 3.0),
		func(_gx: int, _gy: int) -> Vector3:
			return Vector3.ZERO
	)
	if mesh.create_trimesh_shape() == null:
		push_error("Expected solid wall mesh to produce a trimesh shape")
		return 1
	return 0


func _has_normal(normals: PackedVector3Array, target: Vector3) -> bool:
	for i in normals.size():
		if normals[i].dot(target) > 0.99:
			return true
	return false
