class_name MonsterSense
extends Node

## Base for authored senses under Monster/Senses.
## Enabled senses append MonsterInterest candidates; Monster prefers among them.

@export var enabled: bool = true


func append_interest_candidates(_monster: CharacterBody3D, _out: Array) -> void:
	## Override in Hearing / LightAwareness / custom senses.
	pass
