class_name SpellDisplayNames
extends RefCounted

## Spell labels and short descriptions for UI.


static func build_catalog() -> Dictionary:
	return {
		"show_me": "Show Me",
		"fireball": "Fireball",
		"flare": "Flare",
		"ward": "Ward",
		"haste": "Haste",
		"light": "Light",
		"light_ball": "Light Ball",
		"target": "Target",
		"pull": "Pull",
		"follow": "Follow",
		"stop": "Stop",
		"dispell": "Dispell",
		"fake_wall": "Fake Wall",
		"clone": "Clone",
	}


static func build_descriptions() -> Dictionary:
	return {
		"show_me": "Cast to reveal recent player smoke trails for 20 seconds.",
		"fireball": "Launch a fireball that explodes on impact and knocks players back.",
		"flare": "Launch a rising signal flare that bursts into a sky beacon.",
		"ward": (
			"Raise a blue shield dome in front of you for 1 second. Blocks one "
			+ "incoming fireball. 1.5s cooldown."
		),
		"haste": "Surge forward with increased movement speed.",
		"light": "Say \"light\" to toggle your wand flashlight on or off.",
		"light_ball": (
			"Leave a glowing orb ahead of you that fades after 30 seconds. "
			+ "Dispell can destroy it."
		),
		"target": (
			"Outline the light orb, relic, fake wall, or relic clone closest to "
			+ "your aim for 10 seconds."
		),
		"pull": (
			"Pull a Target-outlined object along the ground toward you. "
			+ "Requires clear line of sight."
		),
		"follow": (
			"Make a Target-outlined object follow you along open maze paths."
		),

		"stop": (
			"End Follow/Pull channels for everyone and clear Target outlines."
		),
		"dispell": (
			"While Target outlines are active, end Follow/Pull, clear outlines, "
			+ "and destroy a targeted light ball, fake wall, or relic clone."
		),
		"fake_wall": (
			"Preview an open corridor, then confirm with Interact to place a "
			+ "lookalike wall decoy. Contact flickers it; Dispell destroys it."
		),
		"clone": (
			"While Target outlines are active, duplicate a targeted light ball "
			+ "or the relic once. Relic clones cannot be picked up."
		),
	}
