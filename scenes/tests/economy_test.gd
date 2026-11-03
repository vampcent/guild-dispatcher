extends Node

const ROSTER_SIZE: int = 6

var _rules: EconomyRulesData
var _quest: QuestData


func _ready() -> void:
	_rules = load("res://data/rules/economy_rules.tres") as EconomyRulesData
	_quest = load("res://data/quests/goblin_raid.tres") as QuestData

	var ledger: GuildLedger = GuildLedger.new(_rules)
	_print_state("Start", ledger)
	_play(ledger, "Success", _make_result(true, false))
	_play(ledger, "Costly success", _make_result(true, true))
	_play(ledger, "Failure, wages due", _make_result(false, false))

	print("--- A run of bad luck ---")
	var broke: GuildLedger = GuildLedger.new(_rules)

	for quest_number: int in range(1, 13):
		_play(broke, "Failure %d" % quest_number, _make_result(false, false))

		if broke.is_closed(ROSTER_SIZE):
			print("The guild has closed.")
			break

	print("--- Gold loot ---")
	_compare_gold("With Thief", ["sentinel", "thief", "evoker", "exorcist"])
	_compare_gold("Without Thief", ["sentinel", "spy", "evoker", "exorcist"])
	var loot_ledger: GuildLedger = GuildLedger.new(_rules)
	var loot_result: QuestResult = _make_result(true, false)
	loot_result.loot_gold = 50
	_play(loot_ledger, "Success with 50 loot gold", loot_result)

	print("--- Everyone dead ---")
	var empty: GuildLedger = GuildLedger.new(_rules)
	print("Can afford a recruit: closed = %s" % empty.is_closed(0))
	empty.gold = 100
	print("Can't afford a recruit: closed = %s" % empty.is_closed(0))


func _compare_gold(label: String, ids: Array[String]) -> void:
	var rules: EncounterRulesData = load("res://data/rules/encounter_rules.tres") as EncounterRulesData
	var quest: QuestData = load("res://data/quests/counting_house_job.tres") as QuestData
	var party: Array[Loadout] = []

	for id: String in ids:
		party.append(Loadout.new(load("res://data/characters/adventurers/%s.tres" % id) as AdventurerData))

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234
	var gold: int = 0
	var wins: int = 0

	for _run: int in 2000:
		var result: QuestResult = EncounterSimulator.new(party, quest, rules, rng).run()
		gold += result.loot_gold
		wins += 1 if result.succeeded else 0

	print("%s | Average loot per win: %d gold" % [label, roundi(float(gold) / wins)])


func _play(ledger: GuildLedger, label: String, result: QuestResult) -> void:
	ledger.record_quest(_quest, result, ROSTER_SIZE)
	_print_state(label, ledger)


func _make_result(succeeded: bool, costly: bool) -> QuestResult:
	var result: QuestResult = QuestResult.new()
	result.succeeded = succeeded

	if costly:
		result.injured.append(AdventurerData.new())

	return result


func _print_state(label: String, ledger: GuildLedger) -> void:
	print("%s | Gold %d | Debt %d | Quests until wages %d" % [
		label,
		ledger.gold,
		ledger.debt,
		ledger.quests_until_wages,
	])
