class_name SpellDefinition
extends Resource

const DEFAULT_ONE_WORD_DURATION_MS := 700
const SpellEffectSyncScript := preload("res://scripts/spells/spell_effect_sync.gd")

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
		+ "Hold [LMB], say the incantation, then release. [B] opens your spell codex."
	)


func get_cast_success_text() -> String:
	var text := "The spell takes effect."
	match effect_id:
		"light":
			text = "Smoke trails glow in the maze for several seconds."
		"haste":
			text = "You surge forward — movement speed increased!"
		"fireball":
			text = "A blazing fireball launches from your wand!"
		"flame_on":
			text = "Your wand tip flares with a deep red glow!"
		"flashlight_on":
			text = "A steady beam of light shines from your wand."
		"flashlight_off":
			text = "The wand light clicks off."
	return text


func get_codex_effect_detail() -> String:
	var text := get_cast_success_text()
	match effect_id:
		"light":
			text = (
				"Reveals recent player smoke trails in the maze for %.0f seconds."
				% SpellEffectSyncScript.DEFAULT_LIGHT_DURATION
			)
		"haste":
			text = (
				"Increases movement speed by %.0f%% for %.0f seconds."
				% [
					(SpellEffectSyncScript.DEFAULT_HASTE_MULTIPLIER - 1.0) * 100.0,
					SpellEffectSyncScript.DEFAULT_HASTE_DURATION,
				]
			)
		"fireball":
			text = (
				"Launches a blazing fireball from your wand. "
				+ "Shots explode on impact with sparks and smoke."
			)
		"flame_on":
			text = "Ignites the wand tip with a steady deep-red glow."
		"flashlight_on":
			text = (
				"Projects a focused beam from your wand until you cast Light Off. "
				+ "Illuminates the maze ahead of you."
			)
		"flashlight_off":
			text = "Extinguishes your wand flashlight beam."
	return text


func get_codex_detail_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append('Incantation: "%s"' % get_incantation_text())
	lines.append("")
	lines.append("How to cast")
	lines.append(get_listen_coaching_text())
	var timing := get_timing_guide_text()
	if not timing.is_empty():
		lines.append(timing)
	var pitch := get_pitch_guide_text()
	if not pitch.is_empty():
		lines.append(pitch)
	lines.append("")
	lines.append("What it does")
	lines.append(get_codex_effect_detail())
	return lines
