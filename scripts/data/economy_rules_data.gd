class_name EconomyRulesData
extends Resource

@export_range(0, 100000) var starting_gold: int = 500
@export_range(0, 100) var costly_pay_percent: int = 60
@export_range(0, 10000) var wage_per_adventurer: int = 50
@export_range(1, 20) var quests_between_wages: int = 3
@export_range(0, 100000) var debt_limit: int = 500
@export_range(0, 200) var loan_interest_percent: int = 25
@export_range(0, 100) var income_to_debt_percent: int = 50
@export_range(0, 100000) var recruit_cost: int = 150
