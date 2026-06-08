extends MeshInstance3D

## A single flat slime streak segment that fades out over time.

var _lifetime: float = 1.0
var _elapsed: float = 0.0


func begin_fade(lifetime: float) -> void:
	_lifetime = maxf(lifetime, 0.1)


func _process(delta: float) -> void:
	_elapsed += delta
	var progress := clampf(_elapsed / _lifetime, 0.0, 1.0)
	var alpha := lerpf(0.82, 0.0, progress)

	if material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = material_override
		mat.albedo_color.a = alpha
		mat.emission_energy_multiplier = lerpf(1.4, 0.0, progress)

	if progress >= 1.0:
		queue_free()
