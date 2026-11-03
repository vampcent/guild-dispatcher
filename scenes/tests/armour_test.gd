extends TestCase

const SAMPLE_RUNS: int = 2000
const ARMOUR_IDS: Array[String] = ["", "leather_armour", "chain_mail", "plate_armour"]
const EXPECTED_WOUNDS: Array[int] = [128, 120, 99, 74]


func _ready() -> void:
	var armoury: Armoury = Armoury.new(load("res://data/equipment/armoury.tres") as ArmouryData)
	var thief: AdventurerData = load("res://data/characters/adventurers/thief.tres") as AdventurerData
	var evoker: AdventurerData = load("res://data/characters/adventurers/evoker.tres") as AdventurerData
	var exorcist: AdventurerData = load("res://data/characters/adventurers/exorcist.tres") as AdventurerData
	var plate: ArmourData = _load_armour("plate_armour")
	var wounds: Array[int] = []

	for armour_id: String in ARMOUR_IDS:
		wounds.append(_compare(thief, _load_armour(armour_id)))

	var bare: Loadout = Loadout.new(thief)
	var plated: Loadout = Loadout.new(thief, null, null, plate)
	check(plated.get_total_defence() > bare.get_total_defence(), "Plate armour adds defence")
	check(plated.get_total_speed() < bare.get_total_speed(), "Plate armour costs speed")
	check(wounds.back() < wounds.front(), "Plate armour means fewer wounds than no armour")

	for index: int in ARMOUR_IDS.size():
		check_relative(
			100.0 * wounds[index] / SAMPLE_RUNS,
			EXPECTED_WOUNDS[index],
			"Wounds per 100 quests with %s" % (ARMOUR_IDS[index] if index > 0 else "no armour")
		)

	var party: Array[Loadout] = [Loadout.new(thief, null, null, plate), Loadout.new(evoker, null, null, plate)]
	print("Two sets of plate: %s" % _describe(armoury, party))
	check(armoury.get_problems(party).is_empty(), "The armoury can supply two sets of plate")
	party.append(Loadout.new(exorcist, null, null, plate))
	print("Three sets of plate: %s" % _describe(armoury, party))
	check(not armoury.get_problems(party).is_empty(), "The armoury can't supply three sets of plate")
	finish()


func _compare(adventurer: AdventurerData, armour: ArmourData) -> int:
	var rules: EncounterRulesData = load("res://data/rules/encounter_rules.tres") as EncounterRulesData
	var quest: QuestData = load("res://data/quests/goblin_raid.tres") as QuestData
	var loadout: Loadout = Loadout.new(adventurer, null, null, armour)
	var party: Array[Loadout] = [loadout]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234
	var wounds: int = 0

	for _run: int in SAMPLE_RUNS:
		var result: QuestResult = EncounterSimulator.new(party, quest, rules, rng).run()

		for event: QuestEvent in result.events:
			if event.type == QuestEvent.Type.ADVENTURER_WOUNDED:
				wounds += 1
			elif event.type == QuestEvent.Type.ADVENTURER_DIED:
				wounds += 1

	print("%s | DEF %d | Speed %d | Wounds per 100 quests: %d" % [
		"No armour" if armour == null else armour.display_name,
		loadout.get_total_defence(),
		loadout.get_total_speed(),
		roundi(100.0 * wounds / SAMPLE_RUNS),
	])
	return wounds


func _describe(armoury: Armoury, party: Array[Loadout]) -> String:
	var problems: PackedStringArray = armoury.get_problems(party)
	return "allowed" if problems.is_empty() else "REFUSED: %s" % " ".join(problems)


func _load_armour(id: String) -> ArmourData:
	if id.is_empty():
		return null

	return load("res://data/equipment/armour/%s.tres" % id) as ArmourData
