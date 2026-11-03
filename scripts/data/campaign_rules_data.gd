class_name CampaignRulesData
extends Resource

@export_range(1, 10) var board_size: int = 3
@export_range(0, 100) var danger_error_chance: int = 10
@export var adventurers: Array[AdventurerData] = []
@export var quests: Array[QuestData] = []
