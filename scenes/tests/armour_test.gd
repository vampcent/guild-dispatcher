extends Node

const SAMPLE_RUNS: int = 2000
const ARMOUR_IDS: Array[String] = ["", "leather_armour", "chain_mail", "plate_armour"]


func _ready() -> void:
	var armoury: Armoury = Armoury.new(load("res://data/armoury.tres") as ArmouryData)
	var thief: AdventurerData = load("res://data/adventurers/thief.tres") as AdventurerData
	var evoker: AdventurerData = load("res://data/adventurers/evoker.tres") as AdventurerData
	var exorcist: AdventurerData = load("res://data/adventurers/exorcist.tres") as AdventurerData
	var plate: ArmourData = _load_armour("plate_armour")

	for armour_id: String in ARMOUR_IDS:
		_compare(thief, _load_armour(armour_id))

	var party: Array[Loadout] = [Loadout.new(thief, null, null, plate), Loadout.new(evoker, null, null, plate)]
	print("Two sets of plate: %s" % _describe(armoury, party))
	party.append(Loadout.new(exorcist, null, null, plate))
	print("Three sets of plate: %s" % _describe(armoury, party))


func _compare(adventurer: AdventurerData, armour: ArmourData) -> void:
	var rules: EncounterRulesData = load("res://data/encounter_rules.tres") as EncounterRulesData
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


func _describe(armoury: Armoury, party: Array[Loadout]) -> String:
	var problems: PackedStringArray = armoury.get_problems(party)
	return "allowed" if problems.is_empty() else "REFUSED: %s" % " ".join(problems)


func _load_armour(id: String) -> ArmourData:
	if id.is_empty():
		return null

	return load("res://data/armour/%s.tres" % id) as ArmourData
