class_name SpellDefinition
extends Resource

const DEFAULT_ONE_WORD_DURATION_MS := 700

@export var id: String = ""
@export var display_name: String = ""
@export var incantation_words: PackedStringArray = PackedStringArray()
@export var syllable_cadence_ms: PackedInt32Array = PackedInt32Array()
@export var pitch_targets_hz: PackedFloat32Array = PackedFloat32Array()
@export var require_rhythm: bool = false
@export var cooldown_sec: float = 8.0
@export var effect_id: String = ""


func get_incantation_text() -> String:
	return " ".join(incantation_words)


func word_count() -> int:
	return incantation_words.size()


func get_target_duration_sec() -> float:
	return float(get_target_duration_ms()) / 1000.0


func get_target_duration_ms() -> int:
	if syllable_cadence_ms.is_empty():
		return maxi(600, word_count() * 450)
	var last_ms: int = syllable_cadence_ms[syllable_cadence_ms.size() - 1]
	if word_count() == 1 and last_ms <= 0:
		return DEFAULT_ONE_WORD_DURATION_MS
	if last_ms <= 0:
		return DEFAULT_ONE_WORD_DURATION_MS
	return last_ms + 250


func get_timing_guide_text() -> String:
	if not require_rhythm or incantation_words.is_empty():
		return ""
	if syllable_cadence_ms.size() >= word_count() and word_count() > 1:
		var parts: PackedStringArray = []
		for i in word_count():
			var ms: int = syllable_cadence_ms[i]
			parts.append('"%s" at %.2fs' % [incantation_words[i], float(ms) / 1000.0])
		return "Beat: " + ", ".join(parts)
	return 'Say "%s" in about %.1fs' % [get_incantation_text(), get_target_duration_sec()]


func get_listen_coaching_text() -> String:
	if incantation_words.is_empty():
		return "Speak the incantation clearly when the mic bar appears."
	if not require_rhythm:
		return (
			'Say "%s" clearly at normal volume. '
			% get_incantation_text()
			+ "Take your time — timing does not matter."
		)
	var duration: float = get_target_duration_sec()
	if word_count() == 1:
		return (
			'Say "%s" once, clearly, in about %.1fs. '
			% [incantation_words[0], duration]
			+ "Aim for normal speaking volume — the mic bar should move."
		)
	return (
		'Say "%s" at a steady pace (~%.1fs total). '
		% [get_incantation_text(), duration]
		+ "Watch the mic bar while you speak."
	)


func get_tome_lesson_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(get_listen_coaching_text())
	var timing: String = get_timing_guide_text()
	if not timing.is_empty():
		parts.append(timing)
	return "\n".join(parts)


func get_pitch_guide_text() -> String:
	if pitch_targets_hz.is_empty():
		return ""
	var parts: PackedStringArray = []
	for i in pitch_targets_hz.size():
		var label := hz_to_note_label(pitch_targets_hz[i])
		if word_count() > 1 and i < word_count():
			parts.append('"%s" ~ %s' % [incantation_words[i], label])
		else:
			parts.append(label)
	return "Pitch: " + " → ".join(parts)


static func hz_to_note_label(hz: float) -> String:
	if hz <= 0.0:
		return "?"
	var names := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	var midi := 69.0 + 12.0 * log(hz / 440.0) / log(2.0)
	var rounded := int(round(midi))
	var octave := int(floor(float(rounded) / 12.0)) - 1
	var name_idx := posmod(rounded, 12)
	return "%s%d (%.0f Hz)" % [names[name_idx], octave, hz]


func get_learned_confirmation_text() -> String:
	return (
		'"%s" is yours now.\n'
		% display_name
		+ "Press [F] anywhere to cast by voice. [B] opens your spellbook to review."
	)


func get_cast_success_text() -> String:
	match effect_id:
		"light":
			return "A warm golden light glows around you for several seconds."
		"haste":
			return "You surge forward — movement speed increased!"
		"fireball":
			return "A blazing fireball launches from your wand!"
		_:
			return "The spell takes effect."
