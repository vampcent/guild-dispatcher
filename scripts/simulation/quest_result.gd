class_name QuestResult
extends RefCounted

enum Outcome {
	SUCCESS,
	COSTLY_SUCCESS,
	FAILURE,
}

var succeeded: bool = false
var rounds_fought: int = 0
var events: Array[QuestEvent] = []
var injured: Array[AdventurerData] = []
var dead: Array[AdventurerData] = []
var found_accessories: Array[AccessoryData] = []
var used_items: Array[ItemData] = []


func get_outcome() -> Outcome:
	if not succeeded:
		return Outcome.FAILURE

	if injured.is_empty() and dead.is_empty():
		return Outcome.SUCCESS

	return Outcome.COSTLY_SUCCESS
