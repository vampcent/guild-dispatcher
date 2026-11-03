class_name QuestData
extends Resource

@export var display_name: String = ""
@export_multiline var briefing: String = ""
@export_range(1, 5) var danger: int = 1
@export var enemy_name: String = ""
@export_range(0, 10000) var pay: int = 0
@export var quest_tags: Array[String] = []
@export_range(0, 100) var trap_chance: int = 0
@export_range(0, 100) var loot_chance: int = 0
@export_range(0, 10) var loot_rolls: int = 2
@export var loot_table: Array[AccessoryData] = []
@export_range(1, 10) var round_count: int = 3
@export_range(1, 500) var enemy_health: int = 40
@export_range(0, 10) var enemy_attacks_per_round: int = 2
@export_range(0, 20) var enemy_power: int = 5
