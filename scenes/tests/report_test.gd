extends Node


func _ready() -> void:
	var rules: EncounterRulesData = load("res://data/encounter_rules.tres") as EncounterRulesData
	var phrases: ReportPhrasesData = load("res://data/report_phrases.tres") as ReportPhrasesData
	var quest: QuestData = load("res://data/quests/restless_crypt.tres") as QuestData
	var party: Array[Loadout] = []

	for id: String in ["sentinel", "berserker", "evoker", "exorcist"]:
		party.append(Loadout.new(load("res://data/adventurers/%s.tres" % id) as AdventurerData))

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var result: QuestResult = EncounterSimulator.new(party, quest, rules, rng).run()
	print(ReportWriter.write_report(result.events, phrases, rng))
