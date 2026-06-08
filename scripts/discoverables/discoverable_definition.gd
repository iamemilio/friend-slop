class_name DiscoverableDefinition
extends Resource

## Base resource for maze discoverables (tomes, potions, relics, etc.).

@export var id: String = ""
@export var display_name: String = ""
@export var scene: PackedScene
@export var min_dist_from_special: int = 4
@export var min_dist_between: int = 6
