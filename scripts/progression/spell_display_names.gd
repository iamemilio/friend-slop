class_name SpellDisplayNames
extends RefCounted

## Spell labels and short descriptions for UI.


static func build_catalog() -> Dictionary:
	return {
		"show_me": "Show Me",
		"fireball": "Fireball",
		"haste": "Haste",
		"light": "Light",
		"light_ball": "Light Ball",
		"target": "Target",
		"pull": "Pull",
		"follow": "Follow",
		"dispell": "Dispell",
		"fake_wall": "Fake Wall",
	}


static func build_descriptions() -> Dictionary:
	return {
		"show_me": "Cast to reveal recent player smoke trails for 20 seconds.",
		"fireball": "Launch a fireball that explodes on impact.",
		"haste": "Surge forward with increased movement speed.",
		"light": "Say \"light\" to toggle your wand flashlight on or off.",
		"light_ball": (
			"Leave a glowing orb ahead of you that fades after 30 seconds. "
			+ "Dispell can destroy it."
		),
		"target": (
			"Outline the light orb, relic, or fake wall closest to your aim for 10 seconds."
		),
		"pull": (
			"Pull a Target-outlined object toward you along a clear line of sight."
		),
		"follow": (
			"Make a Target-outlined object follow you along open maze paths."
		),
		"dispell": (
			"While Target outlines are active, end Follow/Pull, clear outlines, "
			+ "and destroy a targeted light ball or fake wall."
		),
		"fake_wall": (
			"Preview an open corridor, then confirm with Interact to place a "
			+ "lookalike wall decoy. Contact flickers it; Dispell destroys it."
		),
	}
