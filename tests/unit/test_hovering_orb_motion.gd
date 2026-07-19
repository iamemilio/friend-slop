extends RefCounted

const HoveringOrbMotionScript := preload("res://scripts/spells/hovering_orb_motion.gd")


func run() -> int:
	var failures := 0
	failures += _test_bob_offset_and_visual()
	failures += _test_cruise_stays_on_xz()
	return failures


func _test_bob_offset_and_visual() -> int:
	var phase := PI * 0.5
	var offset := HoveringOrbMotionScript.bob_offset(phase, 0.1)
	if not is_equal_approx(offset.y, 0.1):
		push_error("Expected bob peak at phase pi/2")
		return 1
	var visual := HoveringOrbMotionScript.visual_from_base(
		Vector3(1.0, 2.0, 3.0), phase, 0.1
	)
	if not is_equal_approx(visual.x, 1.0) or not is_equal_approx(visual.z, 3.0):
		push_error("Expected visual XZ to match base")
		return 1
	if not is_equal_approx(visual.y, 2.1):
		push_error("Expected visual Y to include bob offset")
		return 1
	return 0


func _test_cruise_stays_on_xz() -> int:
	var from := Vector3(0.0, 1.15, 0.0)
	var waypoint := Vector3(10.0, 9.0, 0.0)
	var next := HoveringOrbMotionScript.cruise_base_toward(
		from, waypoint, 1.0 / 60.0, null, 1.15, 4.5, 7.5
	)
	if next.z != 0.0:
		push_error("Expected cruise to stay on the X axis corridor")
		return 1
	if next.x <= from.x:
		push_error("Expected cruise to advance toward the waypoint")
		return 1
	if not is_equal_approx(next.y, 1.15):
		push_error("Expected fallback height to remain 1.15 without a World3D")
		return 1
	return 0
