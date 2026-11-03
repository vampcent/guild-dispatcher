class_name ArmourData
extends Resource

enum Weight {
	LIGHT,
	MEDIUM,
	HEAVY,
}

@export var display_name: String = ""
@export_range(0, 10000) var price: int = 0
@export var weight: Weight = Weight.LIGHT
@export var allowed_classes: Array[String] = []
@export_range(0, 20) var defence_bonus: int = 0
@export_range(0, 20) var speed_penalty: int = 0
