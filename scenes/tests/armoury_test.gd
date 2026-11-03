extends Node

const SAMPLE_RUNS: int = 2000

var _armoury: Armoury


func _ready() -> void:
	var data: ArmouryData = load("res://data/armoury.tres") as ArmouryData
	_armoury = Armoury.new(data)
	print("Armoury: %d weapon types, %d of each" % [data.weapons.size(), data.base_copies])

	_check_loadout("sentinel", "longsword", "shield")
	_check_loadout("berserker", "greatsword", "")
	_check_loadout("thief", "short_sword", "dagger")
	_check_loadout("evoker", "staff", "")
	print("--- These should all be refused ---")
	_check_loadout("thief", "short_sword", "shield")
	_check_loadout("evoker", "wand", "dagger")
	_check_loadout("sentinel", "greatsword", "shield")
	_check_loadout("exorcist", "longsword", "")
	_check_loadout("spy", "", "")

	var party: Array[Loadout] = [
		Loadout.new(_load_adventurer("sentinel"), _load_weapon("longsword")),
		Loadout.new(_load_adventurer("berserker"), _load_weapon("longsword")),
		Loadout.new(_load_adventurer("evoker"), _load_weapon("wand")),
		Loadout.new(_load_adventurer("exorcist"), _load_weapon("wand")),
	]
	print("Two swords, two wands: %s" % _describe_stock(party))
	party.append(Loadout.new(_load_adventurer("thief"), _load_weapon("longsword")))
	print("Three swords: %s" % _describe_stock(party))

	_compare_ranged()


func _check_loadout(adventurer_id: String, main_id: String, off_id: String) -> void:
	var main_hand: WeaponData = null if main_id.is_empty() else _load_weapon(main_id)
	var off_hand: WeaponData = null if off_id.is_empty() else _load_weapon(off_id)
	var loadout: Loadout = Loadout.new(_load_adventurer(adventurer_id), main_hand, off_hand)
	var problems: PackedStringArray = loadout.get_problems()

	if problems.is_empty():
		print("%s | ATK %d | DEF %d" % [
			loadout.adventurer.display_name,
			loadout.get_total_attack(),
			loadout.get_total_defence(),
		])
	else:
		print("REFUSED: %s" % " ".join(problems))


func _describe_stock(party: Array[Loadout]) -> String:
	var problems: PackedStringArray = _armoury.get_problems(party)
	return "allowed" if problems.is_empty() else "REFUSED: %s" % " ".join(problems)


func _compare_ranged() -> void:
	var ranger: AdventurerData = AdventurerData.new()
	ranger.display_name = "Test Ranger"
	ranger.class_title = "Ranger"
	ranger.attack = 5
	var quest: QuestData = load("res://data/quests/goblin_raid.tres") as QuestData
	var rules: EncounterRulesData = load("res://data/encounter_rules.tres") as EncounterRulesData

	for weapon_id: String in ["bow", "crossbow"]:
		var party: Array[Loadout] = [Loadout.new(ranger, _load_weapon(weapon_id))]
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 1234
		var total_damage: int = 0
		var rounds: int = 0

		for _run: int in SAMPLE_RUNS:
			var result: QuestResult = EncounterSimulator.new(party, quest, rules, rng).run()
			rounds += result.rounds_fought

			for event: QuestEvent in result.events:
				if event.type == QuestEvent.Type.ADVENTURER_HIT:
					total_damage += event.amount

		print("%s | Average damage per round: %.1f" % [
			weapon_id,
			float(total_damage) / rounds,
		])


func _load_adventurer(id: String) -> AdventurerData:
	return load("res://data/adventurers/%s.tres" % id) as AdventurerData


func _load_weapon(id: String) -> WeaponData:
	return load("res://data/weapons/%s.tres" % id) as WeaponData
