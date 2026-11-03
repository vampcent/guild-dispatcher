class_name BoardEntry
extends RefCounted

var quest: QuestData
var shown_danger: int


func _init(entry_quest: QuestData, entry_danger: int) -> void:
	quest = entry_quest
	shown_danger = entry_danger
