class_name Armoury
extends RefCounted

var _counts: Dictionary[Resource, int] = {}


func _init(data: ArmouryData) -> void:
	for equipment: Resource in data.starting_stock:
		add(equipment)


func get_count(equipment: Resource) -> int:
	return _counts.get(equipment, 0)


func add(equipment: Resource) -> void:
	_counts[equipment] = get_count(equipment) + 1


func get_owned_accessories() -> Array[AccessoryData]:
	var owned: Array[AccessoryData] = []

	for equipment: Resource in _counts:
		if equipment is AccessoryData and _counts[equipment] > 0:
			owned.append(equipment)

	return owned


func get_problems(party: Array[Loadout]) -> PackedStringArray:
	var problems: PackedStringArray = []
	var assigned: Dictionary[Resource, int] = {}

	for loadout: Loadout in party:
		for equipment: Resource in loadout.get_all_equipment():
			assigned[equipment] = assigned.get(equipment, 0) + 1

	for equipment: Resource in assigned:
		if assigned[equipment] > get_count(equipment):
			problems.append("The armoury only has %d of %s." % [
				get_count(equipment),
				equipment.get("display_name"),
			])

	return problems


func apply_result(party: Array[Loadout], result: QuestResult) -> void:
	if result.dead.size() == party.size():
		_lose_gear(party)
		return

	for item: ItemData in result.used_items:
		_counts[item] = maxi(get_count(item) - 1, 0)

	for accessory: AccessoryData in result.found_accessories:
		if accessory.is_one_of_a_kind():
			_counts[accessory] = 1
		else:
			_counts[accessory] = get_count(accessory) + 1


func _lose_gear(party: Array[Loadout]) -> void:
	for loadout: Loadout in party:
		for equipment: Resource in loadout.get_all_equipment():
			_counts[equipment] = maxi(get_count(equipment) - 1, 0)
