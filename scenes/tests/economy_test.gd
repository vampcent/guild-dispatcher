extends Node

const ROSTER_SIZE: int = 6

var _rules: EconomyRulesData
var _quest: QuestData


func _ready() -> void:
	_rules = load("res://data/economy_rules.tres") as EconomyRulesData
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

	print("--- Everyone dead ---")
	var empty: GuildLedger = GuildLedger.new(_rules)
	print("Can afford a recruit: closed = %s" % empty.is_closed(0))
	empty.gold = 100
	print("Can't afford a recruit: closed = %s" % empty.is_closed(0))


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
