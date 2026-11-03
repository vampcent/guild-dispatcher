class_name WeaponData
extends Resource

@export var display_name: String = ""
@export_range(0, 10000) var price: int = 0
@export var main_hand_classes: Array[String] = []
@export var off_hand_classes: Array[String] = []
@export var two_handed: bool = false
@export_range(-10, 10) var attack_bonus: int = 0
@export_range(-10, 10) var defence_bonus: int = 0
@export_range(-10, 10) var off_hand_defence_bonus: int = 0
@export_range(1, 5) var shots_per_round: int = 1
@export_range(0, 50) var shot_damage: int = 0
