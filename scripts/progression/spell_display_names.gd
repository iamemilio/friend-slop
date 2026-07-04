class_name SpellDisplayNames
extends RefCounted

## Spell labels and short descriptions for UI.


static func build_catalog() -> Dictionary:
	return {
		"show_me": "Show Me",
		"fireball": "Fireball",
		"haste": "Haste",
		"warden_stalk": "Stalk",
		"warden_pounce": "Pounce",
		"warden_mark": "Mark",
		"warden_whisper": "Whisper",
		"warden_mirror": "Mirror",
		"warden_fade": "Fade",
		"warden_shift": "Shift",
		"warden_seal": "Seal",
		"warden_forge": "Forge",
	}


static func build_descriptions() -> Dictionary:
	return {
		"show_me": "Cast to light the area and reveal recent player smoke trails for 20 seconds.",
		"fireball": "Launch a fireball that explodes on impact.",
		"haste": "Surge forward with increased movement speed.",
		"warden_stalk": "Sense apprentice positions near your location.",
		"warden_pounce": "Close distance on a target in your line of sight.",
		"warden_mark": "Tag an apprentice so you can track them longer.",
		"warden_whisper": "Plant a false voice in a nearby room.",
		"warden_mirror": "Leave a brief decoy of yourself behind.",
		"warden_fade": "Slip out of sight for a short moment.",
		"warden_shift": "Twist a corridor to cut off or open a path.",
		"warden_seal": "Lock an apprentice inside a sealed room.",
		"warden_forge": "Carve a lasting shortcut through the maze.",
	}
