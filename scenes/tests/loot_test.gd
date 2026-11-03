extends TestCase

const SAMPLE_RUNS: int = 2000


func _ready() -> void:
	_check_equipment()
	var thief_loot: Vector3i = _compare_loot("With Thief", ["sentinel", "thief", "evoker", "exorcist"])
	var other_loot: Vector3i = _compare_loot(
		"Without Thief or Evoker",
		["sentinel", "berserker", "spy", "exorcist"]
	)
	check_relative(thief_loot.x, 1966, "Accessories found with a Thief and Evoker")
	check_relative(thief_loot.y, 208, "Accessories pocketed by the Thief")
	check_relative(thief_loot.z, 522, "Accessories burned by the Evoker")
	check_relative(other_loot.x, 1112, "Accessories found without a Thief or Evoker")
	_check_tiers()
	_check_specials()
	_check_party_wipe()
	finish()


func _check_equipment() -> void:
	var thief: AdventurerData = _load_adventurer("thief")
	var fury: AccessoryData = _load_accessory("ring_of_fury")
	var warding: AccessoryData = _load_accessory("ring_of_warding")
	var tooth: AccessoryData = _load_accessory("goblin_king_tooth")
	var short_sword: WeaponData = load("res://data/equipment/weapons/short_sword.tres") as WeaponData
	var two_rings: Array[AccessoryData] = [fury, warding, tooth]
	var worn: Loadout = Loadout.new(thief, short_sword, null, null, two_rings)
	print("Thief with two rings and a necklace: %s | ATK %d | DEF %d | Speed %d" % [
		_describe(worn),
		worn.get_total_attack(),
		worn.get_total_defence(),
		worn.get_total_speed(),
	])
	check(worn.get_problems().is_empty(), "Thief can wear two rings and a necklace")
	check_equal(worn.get_total_attack(), 10, "Thief's attack with two rings and a necklace")
	check_equal(worn.get_total_defence(), 6, "Thief's defence with two rings and a necklace")
	check_equal(worn.get_total_speed(), 8, "Thief's speed with two rings and a necklace")

	var three_rings: Array[AccessoryData] = [fury, warding, fury]
	var overloaded: Loadout = Loadout.new(thief, short_sword, null, null, three_rings)
	print("Three rings: %s" % _describe(overloaded))
	check(not overloaded.get_problems().is_empty(), "Nobody can wear three rings")
	check(not _check_armour("evoker", "staff", "chain_mail"), "Evoker can't wear chain mail")
	check(_check_armour("evoker", "staff", "leather_armour"), "Evoker can wear leather armour")
	check(not _check_armour("thief", "short_sword", "plate_armour"), "Thief can't wear plate armour")
	check(_check_armour("sentinel", "longsword", "plate_armour"), "Sentinel can wear plate armour")


func _check_armour(adventurer_id: String, weapon_id: String, armour_id: String) -> bool:
	var weapon: WeaponData = load("res://data/equipment/weapons/%s.tres" % weapon_id) as WeaponData
	var armour: ArmourData = load("res://data/equipment/armour/%s.tres" % armour_id) as ArmourData
	var adventurer: AdventurerData = _load_adventurer(adventurer_id)
	var loadout: Loadout = Loadout.new(adventurer, weapon, null, armour)
	print("%s in %s: %s" % [
		adventurer.display_name,
		armour.display_name,
		_describe(loadout),
	])
	return loadout.get_problems().is_empty()


func _describe(loadout: Loadout) -> String:
	var problems: PackedStringArray = loadout.get_problems()
	return "allowed" if problems.is_empty() else "REFUSED: %s" % " ".join(problems)


func _compare_loot(label: String, ids: Array[String]) -> Vector3i:
	var rules: EncounterRulesData = load("res://data/rules/encounter_rules.tres") as EncounterRulesData
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
	check(found > 0, "%s finds loot" % label)
	var has_thief: bool = ids.has("thief")
	var has_evoker: bool = ids.has("evoker")
	check(
		(pocketed > 0) == has_thief,
		"%s: loot is pocketed only when a Thief is in the party" % label
	)
	check(
		(burned > 0) == has_evoker,
		"%s: loot is burned only when an Evoker is in the party" % label
	)
	return Vector3i(found, pocketed, burned)


func _check_tiers() -> void:
	var rules: EncounterRulesData = load("res://data/rules/encounter_rules.tres") as EncounterRulesData
	var quest: QuestData = load("res://data/quests/dragon_lair.tres") as QuestData
	var armoury: Armoury = Armoury.new(load("res://data/equipment/armoury.tres") as ArmouryData)
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
	check_relative(tiers[AccessoryData.Rarity.COMMON], 2270, "Common accessories found")
	check_relative(tiers[AccessoryData.Rarity.UNCOMMON], 549, "Uncommon accessories found")
	check_relative(tiers[AccessoryData.Rarity.RARE], 401, "Rare accessories found")
	check_equal(duplicates, 0, "One-of-a-kind accessories are never found twice")


func _check_specials() -> void:
	var rules: EncounterRulesData = load("res://data/rules/encounter_rules.tres") as EncounterRulesData
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

	var triggers: Dictionary[String, int] = {}
	var repeats: int = 0

	for _run: int in SAMPLE_RUNS:
		var run_triggers: Dictionary[String, int] = {}

		for event: QuestEvent in EncounterSimulator.new(party, quest, rules, rng).run().events:
			if event.type == QuestEvent.Type.ACCESSORY_TRIGGERED:
				run_triggers[event.actor] = run_triggers.get(event.actor, 0) + 1

		for actor: String in run_triggers:
			triggers[actor] = triggers.get(actor, 0) + 1
			repeats += 1 if run_triggers[actor] > 1 else 0

	for loadout: Loadout in party:
		var wearer: String = loadout.adventurer.display_name
		check(
			triggers.get(wearer, 0) > 0,
			"%s's %s triggers" % [wearer, loadout.accessories[0].display_name]
		)

	check_equal(repeats, 0, "Special effects trigger at most once per quest")


func _check_party_wipe() -> void:
	var armoury: Armoury = Armoury.new(load("res://data/equipment/armoury.tres") as ArmouryData)
	var longsword: WeaponData = load("res://data/equipment/weapons/longsword.tres") as WeaponData
	var sentinel: AdventurerData = _load_adventurer("sentinel")
	var party: Array[Loadout] = [Loadout.new(sentinel, longsword)]
	var stocked: int = armoury.get_count(longsword)
	var survivor_result: QuestResult = QuestResult.new()
	armoury.apply_result(party, survivor_result)
	print("Longswords after a quest with survivors: %d" % armoury.get_count(longsword))
	check_equal(armoury.get_count(longsword), stocked, "Survivors bring their longsword home")
	var wiped_result: QuestResult = QuestResult.new()
	wiped_result.dead.append(sentinel)
	armoury.apply_result(party, wiped_result)
	print("Longswords after a party wipe: %d" % armoury.get_count(longsword))
	check_equal(armoury.get_count(longsword), stocked - 1, "A party wipe loses the longsword")


func _make_party(ids: Array[String]) -> Array[Loadout]:
	var party: Array[Loadout] = []

	for id: String in ids:
		party.append(Loadout.new(_load_adventurer(id)))

	return party


func _load_adventurer(id: String) -> AdventurerData:
	return load("res://data/characters/adventurers/%s.tres" % id) as AdventurerData


func _load_accessory(id: String) -> AccessoryData:
	return load("res://data/equipment/accessories/%s.tres" % id) as AccessoryData
