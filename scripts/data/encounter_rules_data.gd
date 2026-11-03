class_name EncounterRulesData
extends Resource

@export_range(0, 100) var hit_base: int = 55
@export_range(0, 10) var hit_per_attack: int = 3
@export_range(0, 100) var enemy_hit_base: int = 20
@export_range(0, 10) var enemy_hit_per_power: int = 4
@export_range(0, 10) var enemy_hit_per_defence: int = 3
@export_range(0, 10) var dodge_per_speed: int = 3
@export_range(0, 100) var min_hit_chance: int = 5
@export_range(0, 100) var max_hit_chance: int = 95
@export_range(1, 5) var wounds_to_die: int = 2
@export_range(0, 100) var fireball_loot_burn_chance: int = 20
@export var rarity_weights: Array[int] = [55, 28, 12, 4, 1]
@export_range(0, 100) var item_damage: int = 10
@export var abilities: Array[AbilityData] = []
