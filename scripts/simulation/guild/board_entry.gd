class_name BoardEntry
extends RefCounted

var base_quest: QuestData
var quest: QuestData
var shown_danger: int
var passes: int = 0


func _init(entry_quest: QuestData, entry_danger: int) -> void:
	base_quest = entry_quest
	quest = entry_quest
	shown_danger = entry_danger


func worsen(rules: CampaignRulesData) -> void:
	passes += 1
	quest = base_quest.duplicate() as QuestData
	var worsening: float = passes / 100.0
	quest.enemy_health += roundi(
		base_quest.enemy_health * worsening * rules.worsen_health_percent
	)
	quest.pay += roundi(base_quest.pay * worsening * rules.worsen_pay_percent)
