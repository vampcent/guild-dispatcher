class_name QuestEvent
extends RefCounted

enum Type {
	QUEST_STARTED,
	ROUND_STARTED,
	ENEMY_ATTACK_MISSED,
	ADVENTURER_WOUNDED,
	ADVENTURER_DIED,
	ADVENTURER_HIT,
	ADVENTURER_MISSED,
	ENEMIES_DEFEATED,
	QUEST_SUCCEEDED,
	QUEST_FAILED,
	ABILITY_USED,
	BLOW_PARRIED,
	TRAP_SPRUNG,
	TRAP_SPOTTED,
	WOUND_RECOVERED,
	SPELL_CAST,
	ABILITY_TRIGGERED,
	COLLATERAL_HIT,
	SECOND_WIND_USED,
	ATTACK_DODGED,
	LOOT_FOUND,
	LOOT_POCKETED,
	LOOT_BURNED,
	ACCESSORY_TRIGGERED,
	ITEM_USED,
}

var type: Type
var actor: String
var target: String
var detail: String
var amount: int


func _init(
	event_type: Type,
	event_actor: String = "",
	event_target: String = "",
	event_detail: String = "",
	event_amount: int = 0
) -> void:
	type = event_type
	actor = event_actor
	target = event_target
	detail = event_detail
	amount = event_amount
