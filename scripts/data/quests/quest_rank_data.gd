class_name QuestRankData
extends Resource

# What a quest of one rank pays and faces, and how strong a party it needs.
# Party strength is the party's total attack plus total defence, gear included.
@export_range(0, 100000) var min_pay: int = 0
@export_range(0, 100000) var max_pay: int = 0
@export_range(0, 20) var min_enemy_power: int = 0
@export_range(0, 20) var max_enemy_power: int = 0
@export_range(0, 500) var recommended_strength: int = 0
