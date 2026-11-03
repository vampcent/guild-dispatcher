extends TestCase

const SAMPLE_RUNS: int = 2000


func _ready() -> void:
	var rules: EncounterRulesData = load("res://data/rules/encounter_rules.tres") as EncounterRulesData
	var quest: QuestData = load("res://data/quests/restless_crypt.tres") as QuestData
	var holy_water: ItemData = _load_item("holy_water")
	var potion: ItemData = _load_item("healing_potion")
	var lockpicks: ItemData = _load_item("lockpicks")

	var none: Vector2i = _compare("No items", null, null, quest, rules)
	var water: Vector2i = _compare("Holy Water helps", holy_water, null, quest, rules)
	var picks: Vector2i = _compare("Lockpicks don't help here", lockpicks, null, quest, rules)
	var healing: Vector2i = _compare("Healing Potion", null, potion, quest, rules)
	check(water.x > none.x, "Holy Water wins more crypt quests")
	check_equal(water.y, SAMPLE_RUNS, "Holy Water gets used on every crypt quest")
	check_equal(picks.y, 0, "Lockpicks never get used in the crypt")
	check_equal(picks.x, none.x, "Lockpicks don't change the crypt's results")
	check(healing.y > 0, "Healing Potions get used")
	check_percent(100.0 * none.x / SAMPLE_RUNS, 34, "Crypt win rate with no items")
	check_percent(100.0 * water.x / SAMPLE_RUNS, 57, "Crypt win rate with Holy Water")
	check_percent(100.0 * healing.x / SAMPLE_RUNS, 33, "Crypt win rate with a Healing Potion")
	check_relative(healing.y, 474, "Healing Potions used")
	_check_stock(holy_water)
	_check_shop(potion)
	_check_shop(load("res://data/equipment/weapons/longsword.tres") as WeaponData)
	_check_shop(load("res://data/equipment/armour/plate_armour.tres") as ArmourData)
	_check_prices()
	_check_new_guild()
	finish()


func _compare(
	label: String,
	first_item: ItemData,
	second_item: ItemData,
	quest: QuestData,
	rules: EncounterRulesData
) -> Vector2i:
	var sentinel: AdventurerData = _load_adventurer("sentinel")
	var evoker: AdventurerData = _load_adventurer("evoker")
	var party: Array[Loadout] = [
		Loadout.new(sentinel, null, null, null, [], first_item),
		Loadout.new(evoker, null, null, null, [], second_item),
	]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234
	var wins: int = 0
	var used: int = 0

	for _run: int in SAMPLE_RUNS:
		var result: QuestResult = EncounterSimulator.new(party, quest, rules, rng).run()
		wins += 1 if result.succeeded else 0
		used += result.used_items.size()

	print("%s | Wins %d%% | Items used: %d" % [
		label,
		roundi(100.0 * wins / SAMPLE_RUNS),
		used,
	])
	return Vector2i(wins, used)


func _check_stock(item: ItemData) -> void:
	var armoury: Armoury = Armoury.new(make_stocked_armoury_data())
	var sentinel: AdventurerData = _load_adventurer("sentinel")
	var party: Array[Loadout] = [Loadout.new(sentinel, null, null, null, [], item)]
	var result: QuestResult = QuestResult.new()
	var stocked: int = armoury.get_count(item)
	print("Holy Water at the start: %d" % stocked)
	result.used_items.append(item)
	armoury.apply_result(party, result)
	print("Holy Water after using one: %d" % armoury.get_count(item))
	check_equal(armoury.get_count(item), stocked - 1, "Using Holy Water takes it out of stock")


func _check_shop(equipment: Resource) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var guild: GuildState = GuildState.new(
		load("res://data/rules/campaign_rules.tres") as CampaignRulesData,
		load("res://data/equipment/armoury.tres") as ArmouryData,
		load("res://data/rules/economy_rules.tres") as EconomyRulesData,
		rng
	)
	var item_name: String = equipment.get("display_name")
	var price: int = equipment.get("price")
	guild.ledger.gold = 500
	var gold: int = guild.ledger.gold
	var stocked: int = guild.armoury.get_count(equipment)
	print("Before buying: Gold %d | %s %d" % [gold, item_name, stocked])
	check(guild.buy_equipment(equipment), "The guild can buy %s" % item_name)
	print("After buying: Gold %d | %s %d" % [
		guild.ledger.gold,
		item_name,
		guild.armoury.get_count(equipment),
	])
	check_equal(guild.ledger.gold, gold - price, "Buying %s costs its price" % item_name)
	check_equal(
		guild.armoury.get_count(equipment),
		stocked + 1,
		"Buying %s adds it to stock" % item_name
	)
	guild.ledger.gold = price - 1
	check(
		not guild.buy_equipment(equipment),
		"The guild can't buy %s with 1 gold too little" % item_name
	)
	check_equal(guild.ledger.gold, price - 1, "A refused purchase of %s costs nothing" % item_name)
	check_equal(
		guild.armoury.get_count(equipment),
		stocked + 1,
		"A refused purchase of %s adds nothing to stock" % item_name
	)


# A new guild starts poor with an empty armoury, and has to send people out
# unarmed or buy its first weapon at the market.
func _check_new_guild() -> void:
	var data: ArmouryData = load("res://data/equipment/armoury.tres") as ArmouryData
	var economy: EconomyRulesData = load("res://data/rules/economy_rules.tres") as EconomyRulesData
	var guild: GuildState = GuildState.new(
		load("res://data/rules/campaign_rules.tres") as CampaignRulesData,
		data,
		economy,
		RandomNumberGenerator.new()
	)
	var owned: PackedStringArray = []

	for equipment: Resource in data.items + data.weapons + data.armour:
		if guild.armoury.get_count(equipment) > 0:
			owned.append(equipment.get("display_name"))

	check_equal(owned, PackedStringArray(), "A new guild's armoury is empty")
	check(guild.ledger.gold <= 150, "A new guild starts with little gold (%d)" % guild.ledger.gold)
	check_equal(guild.board.size(), 3, "A new guild still has a full quest board")
	var unarmed: Array[Loadout] = [Loadout.new(guild.roster[0]), Loadout.new(guild.roster[1])]
	check(guild.get_party_problems(unarmed).is_empty(), "A new guild can send a party out unarmed")
	var dagger: WeaponData = load("res://data/equipment/weapons/dagger.tres") as WeaponData
	check(guild.buy_equipment(dagger), "A new guild can afford a dagger")
	check_equal(guild.armoury.get_count(dagger), 1, "The dagger is in the armoury")


func _check_prices() -> void:
	var data: ArmouryData = load("res://data/equipment/armoury.tres") as ArmouryData
	var free: PackedStringArray = []

	for equipment: Resource in data.items + data.weapons + data.armour:
		if equipment.get("price") <= 0:
			free.append(equipment.get("display_name"))

	check_equal(free, PackedStringArray(), "Everything in the market has a price")


func _load_adventurer(id: String) -> AdventurerData:
	return load("res://data/characters/adventurers/%s.tres" % id) as AdventurerData


func _load_item(id: String) -> ItemData:
	return load("res://data/equipment/items/%s.tres" % id) as ItemData
