class_name GuildLedger
extends RefCounted

var gold: int = 0
var debt: int = 0
var quests_until_wages: int = 0

var _rules: EconomyRulesData


func _init(rules: EconomyRulesData) -> void:
	_rules = rules
	gold = rules.starting_gold
	quests_until_wages = rules.quests_between_wages


func get_pay(quest: QuestData, result: QuestResult) -> int:
	match result.get_outcome():
		QuestResult.Outcome.SUCCESS:
			return quest.pay
		QuestResult.Outcome.COSTLY_SUCCESS:
			return roundi(quest.pay * _rules.costly_pay_percent / 100.0)
		_:
			return 0


func record_quest(quest: QuestData, result: QuestResult, roster_size: int) -> QuestPayout:
	var payout: QuestPayout = QuestPayout.new()
	payout.pay = get_pay(quest, result)
	payout.loot_gold = result.loot_gold
	payout.debt_repaid = _receive(payout.pay + payout.loot_gold)
	quests_until_wages -= 1

	if quests_until_wages <= 0:
		quests_until_wages = _rules.quests_between_wages
		payout.wages_paid = get_wage_bill(roster_size)
		payout.debt_added = _spend(payout.wages_paid)

	return payout


func get_wage_bill(roster_size: int) -> int:
	return roster_size * _rules.wage_per_adventurer


func get_warnings(roster_size: int) -> PackedStringArray:
	var warnings: PackedStringArray = []

	if debt * 100 > _rules.debt_limit * _rules.debt_warning_percent:
		warnings.append(
			"The lender is losing patience. The guild closes if its debt goes over %d gold."
			% _rules.debt_limit
		)

	var wage_bill: int = get_wage_bill(roster_size)

	if quests_until_wages == 1 and gold < wage_bill:
		warnings.append(
			"Wages of %d gold are due after the next quest, and the guild has only %d gold."
			% [wage_bill, gold]
		)

	return warnings


func can_afford(amount: int) -> bool:
	return gold >= amount


func spend_gold(amount: int) -> void:
	gold -= amount


func is_closed(living_adventurers: int) -> bool:
	if debt > _rules.debt_limit:
		return true

	return living_adventurers == 0 and gold < _rules.recruit_cost


func _receive(amount: int) -> int:
	var repayment: int = mini(
		roundi(amount * _rules.income_to_debt_percent / 100.0),
		debt
	)
	debt -= repayment
	gold += amount - repayment
	return repayment


func _spend(amount: int) -> int:
	var shortfall: int = maxi(amount - gold, 0)
	var borrowed: int = roundi(shortfall * (100 + _rules.loan_interest_percent) / 100.0)
	gold = maxi(gold - amount, 0)
	debt += borrowed
	return borrowed
