extends TestCase

const SAMPLE_RUNS: int = 2000

var _rules: EncounterRulesData


func _ready() -> void:
	_rules = load("res://data/rules/encounter_rules.tres") as EncounterRulesData
	var party: Array[Loadout] = _load_party(
		["sentinel", "thief", "evoker", "exorcist"]
	)
	var goblins: QuestData = load("res://data/quests/goblin_raid.tres") as QuestData
	var boss: QuestData = load("res://data/quests/dragon_lair.tres") as QuestData

	_print_round_log(goblins, party)
	print("--- Results over %d runs ---" % SAMPLE_RUNS)
	var goblin_odds: Vector3 = _print_odds(goblins, party)
	var boss_odds: Vector3 = _print_odds(boss, party)
	check(goblin_odds.x > boss_odds.x, "The goblin raid is won more often than the dragon's lair")
	check_percent(goblin_odds.x, 91, "Goblin Raid win rate")
	check_percent(goblin_odds.y, 2, "Goblin Raid deaths per 100 quests")
	check_relative(goblin_odds.z, 2.4, "Goblin Raid average rounds")
	check_percent(boss_odds.x, 79, "Dragon's Lair win rate")
	check_percent(boss_odds.y, 30, "Dragon's Lair deaths per 100 quests")
	check_relative(boss_odds.z, 4.4, "Dragon's Lair average rounds")
	_check_unarmed()
	finish()


# Bare hands use the adventurer's own attack, so the same party does clearly worse without weapons.
func _check_unarmed() -> void:
	print("--- Unarmed against armed ---")
	var quest: QuestData = load("res://data/quests/night_watch.tres") as QuestData
	var unarmed: Array[Loadout] = _load_party(["sentinel", "berserker", "thief"])
	var armed: Array[Loadout] = _load_party(["sentinel", "berserker", "thief"])
	var weapons: Array[String] = ["longsword", "greatsword", "short_sword"]

	for index: int in armed.size():
		armed[index].main_hand = load("res://data/equipment/weapons/%s.tres" % weapons[index]) as WeaponData

	var unarmed_odds: Vector3 = _print_odds(quest, unarmed)
	var armed_odds: Vector3 = _print_odds(quest, armed)
	check(
		armed_odds.x - unarmed_odds.x >= 20,
		"Weapons add at least 20 points to the win rate (unarmed %d%%, armed %d%%)"
		% [roundi(unarmed_odds.x), roundi(armed_odds.x)]
	)


func _load_party(ids: Array[String]) -> Array[Loadout]:
	var party: Array[Loadout] = []

	for id: String in ids:
		party.append(Loadout.new(load("res://data/characters/adventurers/%s.tres" % id) as AdventurerData))

	return party


func _print_round_log(quest: QuestData, party: Array[Loadout]) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var result: QuestResult = EncounterSimulator.new(party, quest, _rules, rng).run()
	var names: Array = QuestEvent.Type.keys()
	var first: QuestEvent = result.events.front()
	var last: QuestEvent = result.events.back()
	check_equal(names[first.type], "QUEST_STARTED", "The round log starts with the quest")
	check(
		last.type == QuestEvent.Type.QUEST_SUCCEEDED or last.type == QuestEvent.Type.QUEST_FAILED,
		"The round log ends with the quest's outcome"
	)

	for event: QuestEvent in result.events:
		print("%s | %s | %s | %d" % [
			names[event.type],
			event.actor,
			event.target,
			event.amount,
		])


func _print_odds(quest: QuestData, party: Array[Loadout]) -> Vector3:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234
	var wins: int = 0
	var deaths: int = 0
	var rounds: int = 0
	var bad_rounds: int = 0
	var dead_winners: int = 0

	for _run: int in SAMPLE_RUNS:
		var result: QuestResult = EncounterSimulator.new(party, quest, _rules, rng).run()
		wins += 1 if result.succeeded else 0
		deaths += result.dead.size()
		rounds += result.rounds_fought

		if result.rounds_fought < 1 or result.rounds_fought > quest.round_count:
			bad_rounds += 1
		if result.succeeded and result.dead.size() == party.size():
			dead_winners += 1

	print("%s | Wins %d%% | Deaths per 100 quests: %d | Average rounds: %.1f" % [
		quest.display_name,
		roundi(100.0 * wins / SAMPLE_RUNS),
		roundi(100.0 * deaths / SAMPLE_RUNS),
		float(rounds) / SAMPLE_RUNS,
	])
	check_equal(bad_rounds, 0, "%s always lasts between 1 and %d rounds" % [
		quest.display_name,
		quest.round_count,
	])
	check_equal(dead_winners, 0, "%s is never won by a dead party" % quest.display_name)
	return Vector3(
		100.0 * wins / SAMPLE_RUNS,
		100.0 * deaths / SAMPLE_RUNS,
		float(rounds) / SAMPLE_RUNS
	)
