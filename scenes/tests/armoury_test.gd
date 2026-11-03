extends TestCase

const SAMPLE_RUNS: int = 2000

var _armoury: Armoury


func _ready() -> void:
	var data: ArmouryData = load("res://data/armoury.tres") as ArmouryData
	_armoury = Armoury.new(data)
	print("Armoury: %d weapon types, %d of each" % [data.weapons.size(), data.base_copies])

	check(_check_loadout("sentinel", "longsword", "shield"), "Sentinel can use a longsword and shield")
	check(_check_loadout("berserker", "greatsword", ""), "Berserker can use a greatsword")
	check(_check_loadout("thief", "short_sword", "dagger"), "Thief can use a short sword and dagger")
	check(_check_loadout("evoker", "staff", ""), "Evoker can use a staff")
	print("--- These should all be refused ---")
	check(not _check_loadout("thief", "short_sword", "shield"), "Thief can't use a shield")
	check(not _check_loadout("evoker", "wand", "dagger"), "Evoker can't use an off-hand dagger")
	check(not _check_loadout("sentinel", "greatsword", "shield"), "A greatsword needs both hands")
	check(not _check_loadout("exorcist", "longsword", ""), "Exorcist can't use a longsword")
	check(not _check_loadout("spy", "", ""), "Spy needs a main weapon")

	var sentinel: Loadout = Loadout.new(
		_load_adventurer("sentinel"),
		_load_weapon("longsword"),
		_load_weapon("shield")
	)
	check_equal(sentinel.get_total_attack(), 6, "Sentinel's attack with a longsword and shield")
	check_equal(sentinel.get_total_defence(), 11, "Sentinel's defence with a longsword and shield")

	var party: Array[Loadout] = [
		Loadout.new(_load_adventurer("sentinel"), _load_weapon("longsword")),
		Loadout.new(_load_adventurer("berserker"), _load_weapon("longsword")),
		Loadout.new(_load_adventurer("evoker"), _load_weapon("wand")),
		Loadout.new(_load_adventurer("exorcist"), _load_weapon("wand")),
	]
	print("Two swords, two wands: %s" % _describe_stock(party))
	check(_armoury.get_problems(party).is_empty(), "The armoury can supply two swords and two wands")
	party.append(Loadout.new(_load_adventurer("thief"), _load_weapon("longsword")))
	print("Three swords: %s" % _describe_stock(party))
	check(not _armoury.get_problems(party).is_empty(), "The armoury can't supply three swords")

	_compare_ranged()
	finish()


func _check_loadout(adventurer_id: String, main_id: String, off_id: String) -> bool:
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

	return problems.is_empty()


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
		check(total_damage > 0, "The %s deals damage" % weapon_id)


func _load_adventurer(id: String) -> AdventurerData:
	return load("res://data/adventurers/%s.tres" % id) as AdventurerData


func _load_weapon(id: String) -> WeaponData:
	return load("res://data/weapons/%s.tres" % id) as WeaponData
