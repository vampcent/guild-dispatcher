class_name QuestRankData
extends Resource

# What a quest of one rank pays and faces, and how strong a party it needs.
# Party strength is the party's total attack plus total defence, gear included.
@export_range(0, 100000) var min_pay: int = 0
@export_range(0, 100000) var max_pay: int = 0
@export_range(0, 20) var min_enemy_power: int = 0
@export_range(0, 20) var max_enemy_power: int = 0
@export_range(0, 500) var recommended_strength: int = 0
# Guild rank (docs/guild_rank.md): each success at this rank earns reputation,
# and the guild reaches this rank once it has reputation_needed.
@export_range(0, 1000) var reputation: int = 0
@export_range(0, 100000) var reputation_needed: int = 0
