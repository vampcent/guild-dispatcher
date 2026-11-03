extends Node

const SAMPLE_RUNS: int = 2000
const ADVENTURER_IDS: Array[String] = ["sentinel", "thief", "evoker", "exorcist"]


func _ready() -> void:
	var rules: EncounterRulesData = load("res://data/rules/encounter_rules.tres") as EncounterRulesData
	var quest: QuestData = load("res://data/quests/goblin_raid.tres") as QuestData
	var party: Array[Loadout] = []

	for id: String in ADVENTURER_IDS:
		party.append(Loadout.new(load("res://data/characters/adventurers/%s.tres" % id) as AdventurerData))

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234
	var dodges: Dictionary[String, int] = {}

	for _run: int in SAMPLE_RUNS:
		var result: QuestResult = EncounterSimulator.new(party, quest, rules, rng).run()

		for event: QuestEvent in result.events:
			if event.type == QuestEvent.Type.ATTACK_DODGED:
				dodges[event.target] = dodges.get(event.target, 0) + 1

	for loadout: Loadout in party:
		var adventurer: AdventurerData = loadout.adventurer
		print("%s | Speed %d | Dodges: %d" % [
			adventurer.display_name,
			adventurer.speed,
			dodges.get(adventurer.display_name, 0),
		])
