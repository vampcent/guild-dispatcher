class_name CampaignRulesData
extends Resource

@export_range(1, 10) var board_size: int = 3
@export_range(1, 10) var max_party_size: int = 4
@export_range(0, 100) var rank_error_chance: int = 10
@export_range(1, 10) var expire_after_passes: int = 3
@export_range(0, 100) var worsen_health_percent: int = 15
@export_range(0, 100) var worsen_pay_percent: int = 20
@export_range(0, 100) var scout_cost_percent: int = 15
@export var adventurers: Array[AdventurerData] = []
@export var quests: Array[QuestData] = []
# One entry per quest rank, from F to S.
@export var ranks: Array[QuestRankData] = []
