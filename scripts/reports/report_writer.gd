class_name ReportWriter
extends RefCounted


static func write_report(
	events: Array[QuestEvent],
	phrases: ReportPhrasesData,
	rng: RandomNumberGenerator
) -> String:
	var paragraphs: PackedStringArray = []
	var sentences: PackedStringArray = []

	for event: QuestEvent in events:
		if event.type == QuestEvent.Type.ROUND_STARTED and not sentences.is_empty():
			paragraphs.append(" ".join(sentences))
			sentences.clear()

		var key: String = QuestEvent.Type.keys()[event.type]
		var options: Array = phrases.templates.get(key, [])

		if options.is_empty():
			continue

		var template: String = options[rng.randi_range(0, options.size() - 1)]
		sentences.append(template.format({
			"actor": event.actor,
			"target": event.target,
			"detail": event.detail,
		}))

	if not sentences.is_empty():
		paragraphs.append(" ".join(sentences))

	return "\n\n".join(paragraphs)
