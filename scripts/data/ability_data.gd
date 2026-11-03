class_name AbilityData
extends Resource

enum Effect {
	HOLD_THE_LINE,
	SECOND_WIND,
	KEEN_EYE,
	SPELL_SLOTS,
	HEALING_PRAYERS,
	FIREBALL,
	RAGE,
	BANISH,
	LIGHT_FINGERS,
}

@export var display_name: String = ""
@export var class_title: String = ""
@export var subclass_title: String = ""
@export var effect: Effect = Effect.HOLD_THE_LINE
@export_range(1, 10) var uses_per_quest: int = 1
@export_range(0, 50) var power: int = 0
@export_range(0, 100) var chance: int = 100
@export var required_tag: String = ""
@export_multiline var report_line: String = ""
