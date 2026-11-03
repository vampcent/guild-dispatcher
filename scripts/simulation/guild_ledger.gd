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


func record_quest(quest: QuestData, result: QuestResult, roster_size: int) -> void:
	_receive(get_pay(quest, result))
	quests_until_wages -= 1

	if quests_until_wages <= 0:
		quests_until_wages = _rules.quests_between_wages
		_spend(roster_size * _rules.wage_per_adventurer)


func can_afford(amount: int) -> bool:
	return gold >= amount


func spend_gold(amount: int) -> void:
	gold -= amount


func is_closed(living_adventurers: int) -> bool:
	if debt > _rules.debt_limit:
		return true

	return living_adventurers == 0 and gold < _rules.recruit_cost


func _receive(amount: int) -> void:
	var repayment: int = mini(
		roundi(amount * _rules.income_to_debt_percent / 100.0),
		debt
	)
	debt -= repayment
	gold += amount - repayment


func _spend(amount: int) -> void:
	var shortfall: int = maxi(amount - gold, 0)
	gold = maxi(gold - amount, 0)
	debt += roundi(shortfall * (100 + _rules.loan_interest_percent) / 100.0)
