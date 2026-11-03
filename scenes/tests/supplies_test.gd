extends Node

const SAMPLE_RUNS: int = 2000


func _ready() -> void:
	var rules: EncounterRulesData = load("res://data/encounter_rules.tres") as EncounterRulesData
	var quest: QuestData = load("res://data/quests/restless_crypt.tres") as QuestData
	var holy_water: ItemData = _load_item("holy_water")
	var potion: ItemData = _load_item("healing_potion")
	var lockpicks: ItemData = _load_item("lockpicks")

	_compare("No items", null, null, quest, rules)
	_compare("Holy Water helps", holy_water, null, quest, rules)
	_compare("Lockpicks don't help here", lockpicks, null, quest, rules)
	_compare("Healing Potion", null, potion, quest, rules)
	_check_stock(holy_water)
	_check_shop(potion)


func _compare(
	label: String,
	first_item: ItemData,
	second_item: ItemData,
	quest: QuestData,
	rules: EncounterRulesData
) -> void:
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


func _check_stock(item: ItemData) -> void:
	var armoury: Armoury = Armoury.new(load("res://data/armoury.tres") as ArmouryData)
	var sentinel: AdventurerData = _load_adventurer("sentinel")
	var party: Array[Loadout] = [Loadout.new(sentinel, null, null, null, [], item)]
	var result: QuestResult = QuestResult.new()
	print("Holy Water at the start: %d" % armoury.get_count(item))
	result.used_items.append(item)
	armoury.apply_result(party, result)
	print("Holy Water after using one: %d" % armoury.get_count(item))


func _check_shop(item: ItemData) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var guild: GuildState = GuildState.new(
		load("res://data/campaign_rules.tres") as CampaignRulesData,
		load("res://data/armoury.tres") as ArmouryData,
		load("res://data/economy_rules.tres") as EconomyRulesData,
		rng
	)
	print("Before buying: Gold %d | Potions %d" % [guild.ledger.gold, guild.armoury.get_count(item)])
	guild.buy_item(item)
	print("After buying: Gold %d | Potions %d" % [guild.ledger.gold, guild.armoury.get_count(item)])
	guild.ledger.gold = 10
	print("Buying with 10 gold allowed: %s" % guild.buy_item(item))


func _load_adventurer(id: String) -> AdventurerData:
	return load("res://data/adventurers/%s.tres" % id) as AdventurerData


func _load_item(id: String) -> ItemData:
	return load("res://data/items/%s.tres" % id) as ItemData
