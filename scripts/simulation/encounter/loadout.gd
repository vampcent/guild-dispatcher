class_name Loadout
extends RefCounted

const ACCESSORY_SLOTS: Array[AccessoryData.Slot] = [
	AccessoryData.Slot.BACK,
	AccessoryData.Slot.FACE,
	AccessoryData.Slot.RING,
	AccessoryData.Slot.RING,
	AccessoryData.Slot.NECKLACE,
]

var adventurer: AdventurerData
var main_hand: WeaponData
var off_hand: WeaponData
var armour: ArmourData
var accessories: Array[AccessoryData] = []
var item: ItemData


func _init(
	loadout_adventurer: AdventurerData,
	loadout_main_hand: WeaponData = null,
	loadout_off_hand: WeaponData = null,
	loadout_armour: ArmourData = null,
	loadout_accessories: Array[AccessoryData] = [],
	loadout_item: ItemData = null
) -> void:
	adventurer = loadout_adventurer
	main_hand = loadout_main_hand
	off_hand = loadout_off_hand
	armour = loadout_armour
	accessories = loadout_accessories
	item = loadout_item


func get_problems() -> PackedStringArray:
	var problems: PackedStringArray = []
	_add_weapon_problems(problems)
	_add_armour_problems(problems)
	_add_accessory_problems(problems)
	return problems


func _add_weapon_problems(problems: PackedStringArray) -> void:
	var class_title: String = adventurer.class_title

	if main_hand == null:
		problems.append("%s needs a main weapon." % adventurer.display_name)
		return

	if not main_hand.main_hand_classes.has(class_title):
		problems.append("%s can't use %s." % [adventurer.display_name, main_hand.display_name])

	if off_hand == null:
		return

	if main_hand.two_handed:
		problems.append("%s needs both weapon slots." % main_hand.display_name)

	if not off_hand.off_hand_classes.has(class_title):
		problems.append("%s can't use %s in the off-hand." % [
			adventurer.display_name,
			off_hand.display_name,
		])


func _add_armour_problems(problems: PackedStringArray) -> void:
	if armour != null and not armour.allowed_classes.has(adventurer.class_title):
		problems.append("%s can't wear %s." % [adventurer.display_name, armour.display_name])


func _add_accessory_problems(problems: PackedStringArray) -> void:
	var worn: Dictionary[AccessoryData.Slot, int] = {}

	for accessory: AccessoryData in accessories:
		worn[accessory.slot] = worn.get(accessory.slot, 0) + 1

	for slot: AccessoryData.Slot in worn:
		if worn[slot] > ACCESSORY_SLOTS.count(slot):
			problems.append("%s has too many %s accessories." % [
				adventurer.display_name,
				AccessoryData.Slot.keys()[slot].to_lower(),
			])


# Total attack plus total defence of everyone in the party, gear included.
static func get_party_strength(party: Array[Loadout]) -> int:
	var strength: int = 0

	for loadout: Loadout in party:
		strength += loadout.get_total_attack() + loadout.get_total_defence()

	return strength


func get_all_equipment() -> Array[Resource]:
	var equipment: Array[Resource] = []

	for piece: Resource in [main_hand, off_hand, armour, item]:
		if piece != null:
			equipment.append(piece)

	equipment.append_array(accessories)
	return equipment


func get_total_attack() -> int:
	var total: int = adventurer.attack

	if main_hand != null:
		total += main_hand.attack_bonus
	if off_hand != null:
		total += off_hand.attack_bonus

	for accessory: AccessoryData in accessories:
		total += accessory.attack_bonus

	return maxi(total, 0)


func get_total_defence() -> int:
	var total: int = adventurer.defence

	if main_hand != null:
		total += main_hand.defence_bonus
	if off_hand != null:
		total += off_hand.defence_bonus + off_hand.off_hand_defence_bonus
	if armour != null:
		total += armour.defence_bonus

	for accessory: AccessoryData in accessories:
		total += accessory.defence_bonus

	return maxi(total, 0)


func get_total_speed() -> int:
	var total: int = adventurer.speed

	if armour != null:
		total -= armour.speed_penalty

	for accessory: AccessoryData in accessories:
		total += accessory.speed_bonus

	return maxi(total, 0)


func get_shots_per_round() -> int:
	return 1 if main_hand == null else main_hand.shots_per_round


func get_shot_damage() -> int:
	if main_hand != null and main_hand.shot_damage > 0:
		return main_hand.shot_damage

	return get_total_attack()
