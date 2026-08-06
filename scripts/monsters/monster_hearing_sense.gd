class_name MonsterHearingSense
extends MonsterSense

const MonsterInterestScript := preload("res://scripts/monsters/monster_interest.gd")

## Stub hearing sense. Wire to voice / loud events later; appends nothing until fed.

@export var hear_range: float = 14.0
@export var speech_urgency: float = 1.25

## Last heard world position (set by gameplay / voice bus). Cleared when stale.
var last_heard_position: Vector3 = Vector3.ZERO
var has_last_heard: bool = false
var last_heard_urgency: float = 0.0


func append_interest_candidates(_monster: CharacterBody3D, out: Array) -> void:
	if not enabled or not has_last_heard or last_heard_urgency <= 0.0:
		return
	if _monster == null:
		return
	var origin: Vector3 = _monster.global_position
	var flat := Vector3(
		last_heard_position.x - origin.x,
		0.0,
		last_heard_position.z - origin.z
	)
	if flat.length() > hear_range:
		return
	out.append(
		MonsterInterestScript.from_position(
			last_heard_position,
			last_heard_urgency,
			&"hearing"
		)
	)


## Gameplay hook: something loud / speech at world position.
func notify_heard(world_position: Vector3, urgency: float = -1.0) -> void:
	last_heard_position = world_position
	has_last_heard = true
	last_heard_urgency = speech_urgency if urgency < 0.0 else urgency


func clear_heard() -> void:
	has_last_heard = false
	last_heard_urgency = 0.0
