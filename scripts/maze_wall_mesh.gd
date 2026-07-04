class_name MazeWallMesh
extends RefCounted

## Solid wall boxes with outward-facing normals for lighting and trimesh collision.


static func build(
	wall_grid: Array,
	size: Vector3,
	grid_to_world: Callable
) -> ArrayMesh:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := Vector3(size.x * 0.5, size.y * 0.5, size.z * 0.5)

	for gx in wall_grid.size():
		for gy in wall_grid[gx].size():
			if wall_grid[gx][gy] != 1:
				continue
			var center: Vector3 = grid_to_world.call(gx, gy)
			center.y = half.y
			_add_solid_box(surface_tool, center, half)

	return surface_tool.commit()


static func _add_solid_box(
	surface_tool: SurfaceTool,
	center: Vector3,
	half: Vector3
) -> void:
	var corners := [
		center + Vector3(-half.x, -half.y, -half.z),
		center + Vector3(half.x, -half.y, -half.z),
		center + Vector3(half.x, -half.y, half.z),
		center + Vector3(-half.x, -half.y, half.z),
		center + Vector3(-half.x, half.y, -half.z),
		center + Vector3(half.x, half.y, -half.z),
		center + Vector3(half.x, half.y, half.z),
		center + Vector3(-half.x, half.y, half.z),
	]
	_add_quad_with_normal(
		surface_tool, corners[4], corners[5], corners[6], corners[7], Vector3.UP
	)
	_add_quad_with_normal(
		surface_tool, corners[0], corners[3], corners[2], corners[1], Vector3.DOWN
	)
	_add_quad_with_normal(
		surface_tool, corners[0], corners[1], corners[5], corners[4], Vector3(0.0, 0.0, -1.0)
	)
	_add_quad_with_normal(
		surface_tool, corners[2], corners[3], corners[7], corners[6], Vector3(0.0, 0.0, 1.0)
	)
	_add_quad_with_normal(
		surface_tool, corners[1], corners[2], corners[6], corners[5], Vector3(1.0, 0.0, 0.0)
	)
	_add_quad_with_normal(
		surface_tool, corners[3], corners[0], corners[4], corners[7], Vector3(-1.0, 0.0, 0.0)
	)


static func _add_quad_with_normal(
	surface_tool: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	normal: Vector3
) -> void:
	surface_tool.set_normal(normal)
	surface_tool.add_vertex(a)
	surface_tool.add_vertex(b)
	surface_tool.add_vertex(c)
	surface_tool.set_normal(normal)
	surface_tool.add_vertex(a)
	surface_tool.add_vertex(c)
	surface_tool.add_vertex(d)
