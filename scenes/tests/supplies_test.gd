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
	check(water.y > 0, "Holy Water gets used in the crypt")
	check_equal(picks.y, 0, "Lockpicks never get used in the crypt")
	check_equal(picks.x, none.x, "Lockpicks don't change the crypt's results")
	check(healing.y > 0, "Healing Potions get used")
	_check_stock(holy_water)
	_check_shop(potion)
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
	var armoury: Armoury = Armoury.new(load("res://data/equipment/armoury.tres") as ArmouryData)
	var sentinel: AdventurerData = _load_adventurer("sentinel")
	var party: Array[Loadout] = [Loadout.new(sentinel, null, null, null, [], item)]
	var result: QuestResult = QuestResult.new()
	var stocked: int = armoury.get_count(item)
	print("Holy Water at the start: %d" % stocked)
	result.used_items.append(item)
	armoury.apply_result(party, result)
	print("Holy Water after using one: %d" % armoury.get_count(item))
	check_equal(armoury.get_count(item), stocked - 1, "Using Holy Water takes it out of stock")


func _check_shop(item: ItemData) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var guild: GuildState = GuildState.new(
		load("res://data/rules/campaign_rules.tres") as CampaignRulesData,
		load("res://data/equipment/armoury.tres") as ArmouryData,
		load("res://data/rules/economy_rules.tres") as EconomyRulesData,
		rng
	)
	var gold: int = guild.ledger.gold
	var stocked: int = guild.armoury.get_count(item)
	print("Before buying: Gold %d | Potions %d" % [gold, stocked])
	check(guild.buy_item(item), "The guild can buy a Healing Potion")
	print("After buying: Gold %d | Potions %d" % [guild.ledger.gold, guild.armoury.get_count(item)])
	check_equal(guild.ledger.gold, gold - item.price, "Buying a potion costs its price")
	check_equal(guild.armoury.get_count(item), stocked + 1, "Buying a potion adds it to stock")
	guild.ledger.gold = 10
	var allowed: bool = guild.buy_item(item)
	print("Buying with 10 gold allowed: %s" % allowed)
	check(not allowed, "The guild can't buy a potion with 10 gold")
	check_equal(guild.ledger.gold, 10, "A refused purchase costs nothing")


func _load_adventurer(id: String) -> AdventurerData:
	return load("res://data/characters/adventurers/%s.tres" % id) as AdventurerData


func _load_item(id: String) -> ItemData:
	return load("res://data/equipment/items/%s.tres" % id) as ItemData
