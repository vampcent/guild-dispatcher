extends Node

const SAMPLE_RUNS: int = 2000

var _rules: EncounterRulesData


func _ready() -> void:
	_rules = load("res://data/encounter_rules.tres") as EncounterRulesData
	var party: Array[Loadout] = _load_party(
		["sentinel", "thief", "evoker", "exorcist"]
	)
	var goblins: QuestData = load("res://data/quests/goblin_raid.tres") as QuestData
	var boss: QuestData = load("res://data/quests/dragon_lair.tres") as QuestData

	_print_round_log(goblins, party)
	print("--- Results over %d runs ---" % SAMPLE_RUNS)
	_print_odds(goblins, party)
	_print_odds(boss, party)


func _load_party(ids: Array[String]) -> Array[Loadout]:
	var party: Array[Loadout] = []

	for id: String in ids:
		party.append(Loadout.new(load("res://data/adventurers/%s.tres" % id) as AdventurerData))

	return party


func _print_round_log(quest: QuestData, party: Array[Loadout]) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var result: QuestResult = EncounterSimulator.new(party, quest, _rules, rng).run()
	var names: Array = QuestEvent.Type.keys()

	for event: QuestEvent in result.events:
		print("%s | %s | %s | %d" % [
			names[event.type],
			event.actor,
			event.target,
			event.amount,
		])


func _print_odds(quest: QuestData, party: Array[Loadout]) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234
	var wins: int = 0
	var deaths: int = 0
	var rounds: int = 0

	for _run: int in SAMPLE_RUNS:
		var result: QuestResult = EncounterSimulator.new(party, quest, _rules, rng).run()
		wins += 1 if result.succeeded else 0
		deaths += result.dead.size()
		rounds += result.rounds_fought

	print("%s | Wins %d%% | Deaths per 100 quests: %d | Average rounds: %.1f" % [
		quest.display_name,
		roundi(100.0 * wins / SAMPLE_RUNS),
		roundi(100.0 * deaths / SAMPLE_RUNS),
		float(rounds) / SAMPLE_RUNS,
	])
