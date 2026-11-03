extends TestCase


func _ready() -> void:
	var rules: EncounterRulesData = load("res://data/rules/encounter_rules.tres") as EncounterRulesData
	var phrases: ReportPhrasesData = load("res://data/reports/report_phrases.tres") as ReportPhrasesData
	var quest: QuestData = load("res://data/quests/restless_crypt.tres") as QuestData
	var party: Array[Loadout] = []

	for id: String in ["sentinel", "berserker", "evoker", "exorcist"]:
		party.append(Loadout.new(load("res://data/characters/adventurers/%s.tres" % id) as AdventurerData))

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var result: QuestResult = EncounterSimulator.new(party, quest, rules, rng).run()
	var report: String = ReportWriter.write_report(result.events, phrases, rng)
	print(report)
	check(report.is_empty(), "The report has text")
	check(not report.contains("{"), "The report has no unfilled placeholders")
	var names_someone: bool = false

	for loadout: Loadout in party:
		names_someone = names_someone or report.contains(loadout.adventurer.display_name)

	check(names_someone, "The report names someone in the party")
	finish()
