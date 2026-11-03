extends Node

const SAMPLE_RUNS: int = 2000


func _ready() -> void:
	_check_equipment()
	_compare_loot("With Thief", ["sentinel", "thief", "evoker", "exorcist"])
	_compare_loot("Without Thief or Evoker", ["sentinel", "berserker", "spy", "exorcist"])
	_check_tiers()
	_check_specials()
	_check_party_wipe()


func _check_equipment() -> void:
	var thief: AdventurerData = _load_adventurer("thief")
	var fury: AccessoryData = _load_accessory("ring_of_fury")
	var warding: AccessoryData = _load_accessory("ring_of_warding")
	var tooth: AccessoryData = _load_accessory("goblin_king_tooth")
	var short_sword: WeaponData = load("res://data/weapons/short_sword.tres") as WeaponData
	var two_rings: Array[AccessoryData] = [fury, warding, tooth]
	var worn: Loadout = Loadout.new(thief, short_sword, null, null, two_rings)
	print("Thief with two rings and a necklace: %s | ATK %d | DEF %d | Speed %d" % [
		_describe(worn),
		worn.get_total_attack(),
		worn.get_total_defence(),
		worn.get_total_speed(),
	])

	var three_rings: Array[AccessoryData] = [fury, warding, fury]
	print("Three rings: %s" % _describe(Loadout.new(thief, short_sword, null, null, three_rings)))
	_check_armour("evoker", "staff", "chain_mail")
	_check_armour("evoker", "staff", "leather_armour")
	_check_armour("thief", "short_sword", "plate_armour")
	_check_armour("sentinel", "longsword", "plate_armour")


func _check_armour(adventurer_id: String, weapon_id: String, armour_id: String) -> void:
	var weapon: WeaponData = load("res://data/weapons/%s.tres" % weapon_id) as WeaponData
	var armour: ArmourData = load("res://data/armour/%s.tres" % armour_id) as ArmourData
	var adventurer: AdventurerData = _load_adventurer(adventurer_id)
	print("%s in %s: %s" % [
		adventurer.display_name,
		armour.display_name,
		_describe(Loadout.new(adventurer, weapon, null, armour)),
	])


func _describe(loadout: Loadout) -> String:
	var problems: PackedStringArray = loadout.get_problems()
	return "allowed" if problems.is_empty() else "REFUSED: %s" % " ".join(problems)


func _compare_loot(label: String, ids: Array[String]) -> void:
	var rules: EncounterRulesData = load("res://data/encounter_rules.tres") as EncounterRulesData
	var quest: QuestData = load("res://data/quests/goblin_raid.tres") as QuestData
	var party: Array[Loadout] = _make_party(ids)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234
	var found: int = 0
	var pocketed: int = 0
	var burned: int = 0

	for _run: int in SAMPLE_RUNS:
		var result: QuestResult = EncounterSimulator.new(party, quest, rules, rng).run()
		found += result.found_accessories.size()

		for event: QuestEvent in result.events:
			if event.type == QuestEvent.Type.LOOT_POCKETED:
				pocketed += 1
			elif event.type == QuestEvent.Type.LOOT_BURNED:
				burned += 1

	print("%s | Found %d | Pocketed %d | Burned %d" % [label, found, pocketed, burned])


func _check_tiers() -> void:
	var rules: EncounterRulesData = load("res://data/encounter_rules.tres") as EncounterRulesData
	var quest: QuestData = load("res://data/quests/dragon_lair.tres") as QuestData
	var armoury: Armoury = Armoury.new(load("res://data/armoury.tres") as ArmouryData)
	var party: Array[Loadout] = _make_party(["sentinel", "thief", "evoker", "exorcist"])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234
	var tiers: Array[int] = [0, 0, 0, 0, 0]
	var duplicates: int = 0

	for _run: int in SAMPLE_RUNS:
		var owned: Array[AccessoryData] = armoury.get_owned_accessories()
		var result: QuestResult = EncounterSimulator.new(party, quest, rules, rng, owned).run()

		for accessory: AccessoryData in result.found_accessories:
			tiers[accessory.rarity] += 1

			if accessory.is_one_of_a_kind() and owned.has(accessory):
				duplicates += 1

		armoury.apply_result(party, result)

	print("Found by tier: Common %d | Uncommon %d | Rare %d | Unique %d | Legendary %d" % tiers)
	print("One-of-a-kind duplicates: %d" % duplicates)


func _check_specials() -> void:
	var rules: EncounterRulesData = load("res://data/encounter_rules.tres") as EncounterRulesData
	var quest: QuestData = load("res://data/quests/dragon_lair.tres") as QuestData
	var pendant: Array[AccessoryData] = [_load_accessory("dragonscale_pendant")]
	var tooth: Array[AccessoryData] = [_load_accessory("goblin_king_tooth")]
	var party: Array[Loadout] = [
		Loadout.new(_load_adventurer("thief"), null, null, null, pendant),
		Loadout.new(_load_adventurer("evoker"), null, null, null, tooth),
	]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234
	var result: QuestResult = EncounterSimulator.new(party, quest, rules, rng).run()

	for event: QuestEvent in result.events:
		if event.type == QuestEvent.Type.ACCESSORY_TRIGGERED:
			print(event.detail)


func _check_party_wipe() -> void:
	var armoury: Armoury = Armoury.new(load("res://data/armoury.tres") as ArmouryData)
	var longsword: WeaponData = load("res://data/weapons/longsword.tres") as WeaponData
	var sentinel: AdventurerData = _load_adventurer("sentinel")
	var party: Array[Loadout] = [Loadout.new(sentinel, longsword)]
	var survivor_result: QuestResult = QuestResult.new()
	armoury.apply_result(party, survivor_result)
	print("Longswords after a quest with survivors: %d" % armoury.get_count(longsword))
	var wiped_result: QuestResult = QuestResult.new()
	wiped_result.dead.append(sentinel)
	armoury.apply_result(party, wiped_result)
	print("Longswords after a party wipe: %d" % armoury.get_count(longsword))


func _make_party(ids: Array[String]) -> Array[Loadout]:
	var party: Array[Loadout] = []

	for id: String in ids:
		party.append(Loadout.new(_load_adventurer(id)))

	return party


func _load_adventurer(id: String) -> AdventurerData:
	return load("res://data/adventurers/%s.tres" % id) as AdventurerData


func _load_accessory(id: String) -> AccessoryData:
	return load("res://data/accessories/%s.tres" % id) as AccessoryData
