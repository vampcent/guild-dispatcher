extends TestCase

const ROSTER_SIZE: int = 6

var _rules: EconomyRulesData
var _quest: QuestData


func _ready() -> void:
	_rules = load("res://data/rules/economy_rules.tres") as EconomyRulesData
	_quest = load("res://data/quests/goblin_raid.tres") as QuestData

	var ledger: GuildLedger = GuildLedger.new(_rules)
	_print_state("Start", ledger)
	check_equal(ledger.gold, _rules.starting_gold, "The guild starts with its starting gold")
	check_equal(ledger.debt, 0, "The guild starts with no debt")

	var gold: int = ledger.gold
	_play(ledger, "Success", _make_result(true, false))
	check_equal(ledger.gold - gold, _quest.pay, "A success earns full pay")

	gold = ledger.gold
	_play(ledger, "Costly success", _make_result(true, true))
	check_equal(
		ledger.gold - gold,
		roundi(_quest.pay * _rules.costly_pay_percent / 100.0),
		"A costly success earns reduced pay"
	)

	gold = ledger.gold
	_play(ledger, "Failure, wages due", _make_result(false, false))
	check_equal(
		gold - ledger.gold,
		ROSTER_SIZE * _rules.wage_per_adventurer,
		"A failure earns nothing, and wages are paid"
	)
	check_equal(
		ledger.quests_until_wages,
		_rules.quests_between_wages,
		"The wage countdown restarts after payday"
	)

	print("--- A run of bad luck ---")
	var broke: GuildLedger = GuildLedger.new(_rules)

	for quest_number: int in range(1, 13):
		_play(broke, "Failure %d" % quest_number, _make_result(false, false))

		if broke.is_closed(ROSTER_SIZE):
			print("The guild has closed.")
			break

	check(broke.is_closed(ROSTER_SIZE), "Twelve failures in a row close the guild")
	check(broke.debt > _rules.debt_limit, "The guild closes once its debt passes the limit")

	print("--- Gold loot ---")
	var thief_gold: float = _compare_gold("With Thief", ["sentinel", "thief", "evoker", "exorcist"])
	var other_gold: float = _compare_gold("Without Thief", ["sentinel", "spy", "evoker", "exorcist"])
	check(thief_gold > other_gold, "A Thief brings back more loot gold")
	check_relative(thief_gold, 228, "Average loot gold per win with a Thief")
	check_relative(other_gold, 176, "Average loot gold per win without a Thief")
	var loot_ledger: GuildLedger = GuildLedger.new(_rules)
	var loot_result: QuestResult = _make_result(true, false)
	loot_result.loot_gold = 50
	gold = loot_ledger.gold
	_play(loot_ledger, "Success with 50 loot gold", loot_result)
	check_equal(loot_ledger.gold - gold, _quest.pay + 50, "Loot gold is added to quest pay")

	print("--- Everyone dead ---")
	var empty: GuildLedger = GuildLedger.new(_rules)
	print("Can afford a recruit: closed = %s" % empty.is_closed(0))
	check(not empty.is_closed(0), "A guild with no adventurers stays open if it can recruit")
	empty.gold = 100
	print("Can't afford a recruit: closed = %s" % empty.is_closed(0))
	check(empty.is_closed(0), "A guild with no adventurers closes if it can't recruit")
	finish()


func _compare_gold(label: String, ids: Array[String]) -> float:
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

	check(wins > 0, "%s wins at least one heist" % label)
	var average: float = float(gold) / maxi(wins, 1)
	print("%s | Average loot per win: %d gold" % [label, roundi(average)])
	return average


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
