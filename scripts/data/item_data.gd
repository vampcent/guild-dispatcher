class_name ItemData
extends Resource

@export var display_name: String = ""
@export_range(0, 10000) var price: int = 0
@export var quest_tags: Array[String] = []
@export var heals_wound: bool = false
@export_multiline var report_line: String = ""
