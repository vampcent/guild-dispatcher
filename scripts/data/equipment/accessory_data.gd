class_name AccessoryData
extends Resource

enum Slot {
	BACK,
	FACE,
	RING,
	NECKLACE,
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	UNIQUE,
	LEGENDARY,
}

enum SpecialEffect {
	NONE,
	WARD_FIRST_ATTACK,
	FIRST_STRIKE,
	CHEAT_DEATH,
}

@export var display_name: String = ""
@export var slot: Slot = Slot.RING
@export var rarity: Rarity = Rarity.COMMON
@export var special_effect: SpecialEffect = SpecialEffect.NONE
@export_range(0, 50) var special_power: int = 0
@export var special_tag: String = ""
@export_multiline var report_line: String = ""
@export_range(-10, 10) var attack_bonus: int = 0
@export_range(-10, 10) var defence_bonus: int = 0
@export_range(-10, 10) var speed_bonus: int = 0


func is_one_of_a_kind() -> bool:
	return rarity == Rarity.UNIQUE or rarity == Rarity.LEGENDARY
