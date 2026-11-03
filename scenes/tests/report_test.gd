extends TestCase


func _ready() -> void:
	var rules: EncounterRulesData = load("res://data/rules/encounter_rules.tres") as EncounterRulesData
	var phrases: ReportPhrasesData = load("res://data/reports/report_phrases.tres") as ReportPhrasesData
	var quest: QuestData = load("res://data/quests/restless_crypt.tres") as QuestData
	var party: Array[Loadout] = []

	# The Evoker (index 2) casts spells, so its spell line must reach the report.
	for id: String in ["sentinel", "berserker", "evoker", "exorcist"]:
		party.append(Loadout.new(load("res://data/characters/adventurers/%s.tres" % id) as AdventurerData))

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var result: QuestResult = EncounterSimulator.new(party, quest, rules, rng).run()
	var report: String = ReportWriter.write_report(result.events, phrases, rng)
	print(report)
	check(not report.is_empty(), "The report has text")
	check(not report.contains("{"), "The report has no unfilled placeholders")
	var names_someone: bool = false

	for loadout: Loadout in party:
		names_someone = names_someone or report.contains(loadout.adventurer.display_name)

	check(names_someone, "The report names someone in the party")

	var evoker_name: String = party[2].adventurer.display_name
	var mentions_spell: bool = false

	for template: String in phrases.templates.get("SPELL_CAST", []):
		mentions_spell = mentions_spell or report.contains(template.format({"actor": evoker_name}))

	check(mentions_spell, "The Evoker's spell shows up in the report")
	_check_templates(phrases)
	finish()


func _check_templates(phrases: ReportPhrasesData) -> void:
	var missing: PackedStringArray = []

	for key: String in QuestEvent.Type.keys():
		if key != "ROUND_STARTED" and phrases.templates.get(key, []).is_empty():
			missing.append(key)

	check_equal(missing, PackedStringArray(), "Every event type except ROUND_STARTED has a template")

	var placeholder: RegEx = RegEx.create_from_string("\\{(\\w*)\\}")
	var unknown: PackedStringArray = []

	for key: String in phrases.templates:
		for template: String in phrases.templates[key]:
			for found: RegExMatch in placeholder.search_all(template):
				if not ["actor", "target", "detail"].has(found.get_string(1)):
					unknown.append("%s uses {%s}" % [key, found.get_string(1)])

	check_equal(unknown, PackedStringArray(), "Templates only use {actor}, {target} and {detail}")
