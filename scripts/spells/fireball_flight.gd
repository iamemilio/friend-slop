class_name FireballFlight
extends RefCounted

## Pure fireball trajectory rules — unit-testable without a scene tree.

const SKY_FLARE_MIN_Y := 0.45
const SKY_FLARE_TRAVEL_DIST := 24.0
const SKY_FLARE_MAX_RISE_SEC := 2.0
const MAX_LIFETIME := 2.5
const VISUAL_RADIUS := 0.22
const HIT_RADIUS := 0.16


static func is_sky_flare_direction(direction: Vector3) -> bool:
	return direction.normalized().y >= SKY_FLARE_MIN_Y


static func should_finish_normal(elapsed_sec: float) -> bool:
	return elapsed_sec >= MAX_LIFETIME


static func should_finish_sky_flare(
	elapsed_sec: float,
	travelled_dist: float
) -> bool:
	if elapsed_sec >= SKY_FLARE_MAX_RISE_SEC:
		return true
	return travelled_dist >= SKY_FLARE_TRAVEL_DIST
