class_name BoardEntry
extends RefCounted

var base_quest: QuestData
var quest: QuestData
var shown_rank: int
var passes: int = 0
var scouted: bool = false


func _init(entry_quest: QuestData, entry_rank: int) -> void:
	base_quest = entry_quest
	quest = entry_quest
	shown_rank = entry_rank


func worsen(rules: CampaignRulesData) -> void:
	passes += 1
	quest = base_quest.duplicate() as QuestData
	var worsening: float = passes / 100.0
	quest.enemy_health += roundi(
		base_quest.enemy_health * worsening * rules.worsen_health_percent
	)
	quest.pay += roundi(base_quest.pay * worsening * rules.worsen_pay_percent)
