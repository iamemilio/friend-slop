class_name IncantationMatcher
extends RefCounted

## Matches speech-to-text transcripts against spell incantations.


static func matches(
	transcript_words: PackedStringArray,
	spell: SpellDefinition
) -> bool:
	if spell == null:
		return false
	return matches_incantation_words(transcript_words, spell.incantation_words)


static func matches_incantation_words(
	transcript_words: PackedStringArray,
	incantation_words: PackedStringArray
) -> bool:
	if transcript_words.is_empty() or incantation_words.is_empty():
		return false
	if _exact_word_sequence(transcript_words, incantation_words):
		return true

	var heard_text := heard_text_from_words(transcript_words)
	var expected_text := " ".join(incantation_words).to_lower()
	if heard_text.contains(expected_text):
		return true

	if incantation_words.size() == 1:
		if _matches_compound_single_word(
			transcript_words, incantation_words[0]
		):
			return true

	return _fuzzy_word_sequence(transcript_words, incantation_words)


static func _matches_compound_single_word(
	transcript_words: PackedStringArray,
	expected_word: String
) -> bool:
	var expected := expected_word.to_lower().strip_edges()
	if expected.is_empty():
		return false

	var heard_compact := heard_text_from_words(transcript_words).replace(" ", "")
	if heard_compact == expected or _word_similar(heard_compact, expected):
		return true

	var normalized: Array[String] = []
	for word in transcript_words:
		var cleaned := word.to_lower().strip_edges()
		if not cleaned.is_empty():
			normalized.append(cleaned)

	for start_idx in normalized.size():
		var built := ""
		for end_idx in range(start_idx, normalized.size()):
			built += normalized[end_idx]
			if built == expected or _word_similar(built, expected):
				return true
			if built.length() > expected.length() + 2:
				break
	return false


static func heard_text_from_words(transcript_words: PackedStringArray) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for word in transcript_words:
		var cleaned := word.to_lower().strip_edges()
		if not cleaned.is_empty():
			parts.append(cleaned)
	return " ".join(parts)


static func _exact_word_sequence(
	detected: PackedStringArray,
	expected: PackedStringArray
) -> bool:
	if detected.size() < expected.size():
		return false

	var normalized_expected: Array[String] = []
	for word in expected:
		normalized_expected.append(word.to_lower().strip_edges())

	var normalized_detected: Array[String] = []
	for word in detected:
		normalized_detected.append(word.to_lower().strip_edges())

	var start := 0
	while start < normalized_detected.size() and normalized_detected[start].is_empty():
		start += 1

	for i in expected.size():
		var idx := start + i
		if idx >= normalized_detected.size():
			return false
		if normalized_detected[idx] != normalized_expected[i]:
			return false
	return true


static func _fuzzy_word_sequence(
	transcript_words: PackedStringArray,
	expected_words: PackedStringArray
) -> bool:
	var normalized_detected: Array[String] = []
	for word in transcript_words:
		var cleaned := word.to_lower().strip_edges()
		if not cleaned.is_empty():
			normalized_detected.append(cleaned)

	var scan_idx := 0
	for expected_word in expected_words:
		var target := expected_word.to_lower()
		var found := false
		while scan_idx < normalized_detected.size():
			if _word_similar(normalized_detected[scan_idx], target):
				found = true
				scan_idx += 1
				break
			scan_idx += 1
		if not found:
			return false
	return true


static func _word_similar(detected: String, expected: String) -> bool:
	if detected.is_empty() or expected.is_empty():
		return false
	if detected == expected:
		return true
	if detected.contains(expected) or expected.contains(detected):
		return true
	var max_distance: int = maxi(1, int(round(float(expected.length()) / 4.0)))
	return _edit_distance(detected, expected) <= max_distance


static func _edit_distance(a: String, b: String) -> int:
	var m: int = a.length()
	var n: int = b.length()
	if m == 0:
		return n
	if n == 0:
		return m

	var dp: Array = []
	for _i in m + 1:
		var row: Array = []
		row.resize(n + 1)
		dp.append(row)

	for j in n + 1:
		dp[0][j] = j
	for i in range(1, m + 1):
		dp[i][0] = i
		for j in range(1, n + 1):
			var cost: int = 0 if a[i - 1] == b[j - 1] else 1
			dp[i][j] = mini(
				mini(dp[i - 1][j] + 1, dp[i][j - 1] + 1),
				dp[i - 1][j - 1] + cost
			)
	return dp[m][n]
