extends TestCase

# Plays many new guilds through their first quests with a cautious bot and
# checks the early game against the targets in GD-53. One quest stands in for
# one day until GD-21 adds days.

const GUILDS: int = 300
const QUESTS: int = 10
const EARLY_QUESTS: int = 3

var _campaign_rules: CampaignRulesData
var _armoury_data: ArmouryData
var _economy_rules: EconomyRulesData
var _encounter_rules: EncounterRulesData
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_campaign_rules = load("res://data/rules/campaign_rules.tres") as CampaignRulesData
	_armoury_data = load("res://data/equipment/armoury.tres") as ArmouryData
	_economy_rules = load("res://data/rules/economy_rules.tres") as EconomyRulesData
	_encounter_rules = load("res://data/rules/encounter_rules.tres") as EncounterRulesData
	_rng.seed = 2026

	var attempts: Array[int] = []
	var wins: Array[int] = []
	var deaths: Array[int] = []
	var open: Array[int] = []
	attempts.resize(QUESTS)
	wins.resize(QUESTS)
	deaths.resize(QUESTS)
	open.resize(QUESTS)
	var armed_by_early: int = 0
	var final_gold: int = 0
	var final_debt: int = 0

	for _guild_number: int in GUILDS:
		var guild: GuildState = GuildState.new(
			_campaign_rules, _armoury_data, _economy_rules, _rng
		)

		for quest_number: int in QUESTS:
			if guild.is_over():
				break

			_shop(guild)

			if quest_number == EARLY_QUESTS - 1 and _owns_a_weapon(guild):
				armed_by_early += 1

			var quest: QuestData = _pick_quest(guild)
			var party: Array[Loadout] = _make_party(guild)
			var result: QuestResult = EncounterSimulator.new(
				party, quest, _encounter_rules, _rng, guild.armoury.get_owned_accessories()
			).run()
			guild.finish_quest(quest, party, result)
			attempts[quest_number] += 1
			wins[quest_number] += 1 if result.succeeded else 0
			deaths[quest_number] += result.dead.size()
			open[quest_number] += 0 if guild.is_over() else 1

		final_gold += guild.ledger.gold
		final_debt += guild.ledger.debt

	print("Quest | Guilds | Success | Deaths per 100 quests | Still open")

	for quest_number: int in QUESTS:
		print("%5d | %6d | %6d%% | %21.1f | %9d%%" % [
			quest_number + 1,
			attempts[quest_number],
			roundi(100.0 * wins[quest_number] / maxi(attempts[quest_number], 1)),
			100.0 * deaths[quest_number] / maxi(attempts[quest_number], 1),
			roundi(100.0 * open[quest_number] / GUILDS),
		])

	var early_attempts: int = 0
	var early_wins: int = 0
	var early_deaths: int = 0

	for quest_number: int in EARLY_QUESTS:
		early_attempts += attempts[quest_number]
		early_wins += wins[quest_number]
		early_deaths += deaths[quest_number]

	var early_success: float = 100.0 * early_wins / early_attempts
	var early_death_rate: float = 100.0 * early_deaths / early_attempts
	var armed_share: float = 100.0 * armed_by_early / GUILDS
	var survival: float = 100.0 * open[QUESTS - 1] / GUILDS
	print("First %d quests: %.0f%% success, %.1f deaths per 100 quests" % [
		EARLY_QUESTS, early_success, early_death_rate,
	])
	print("Guilds owning a weapon by quest %d: %.0f%%" % [EARLY_QUESTS, armed_share])
	print("Guilds still open after %d quests: %.0f%%, with %d gold and %d debt on average" % [
		QUESTS, survival, roundi(float(final_gold) / GUILDS), roundi(float(final_debt) / GUILDS),
	])

	check(early_success >= 85.0, "The first %d quests succeed at least 85%% of the time" % EARLY_QUESTS)
	check(early_death_rate <= 3.0, "Almost nobody dies in the first %d quests" % EARLY_QUESTS)
	check(armed_share >= 50.0, "Most guilds own a weapon by quest %d" % EARLY_QUESTS)
	check(survival >= 75.0, "Most guilds are still open after %d quests" % QUESTS)
	finish()


# Buys the cheapest weapon an unarmed adventurer can use, keeping enough gold for the next wages.
func _shop(guild: GuildState) -> void:
	var reserve: int = guild.ledger.get_wage_bill(guild.get_living_count())
	var party: Array[Loadout] = _make_party(guild)

	for loadout: Loadout in party:
		if not loadout.is_unarmed():
			continue

		var cheapest: WeaponData = null

		for weapon: WeaponData in _armoury_data.weapons:
			if weapon.main_hand_classes.has(loadout.adventurer.class_title):
				if cheapest == null or weapon.price < cheapest.price:
					cheapest = weapon

		if cheapest != null and guild.ledger.gold >= cheapest.price + reserve:
			guild.buy_equipment(cheapest)


func _owns_a_weapon(guild: GuildState) -> bool:
	for weapon: WeaponData in _armoury_data.weapons:
		if guild.armoury.get_count(weapon) > 0:
			return true

	return false


# A cautious player: the lowest-ranked quest on the board, and the best-paid of those.
func _pick_quest(guild: GuildState) -> QuestData:
	var best: BoardEntry = guild.board[0]

	for entry: BoardEntry in guild.board:
		if entry.shown_rank < best.shown_rank or (
			entry.shown_rank == best.shown_rank and entry.quest.pay > best.quest.pay
		):
			best = entry

	return best.quest


# The strongest adventurers fit for duty, each with the best weapon left in the armoury for them.
func _make_party(guild: GuildState) -> Array[Loadout]:
	var available: Array[AdventurerData] = guild.get_available()
	available.sort_custom(func(a: AdventurerData, b: AdventurerData) -> bool:
		return a.attack + a.defence > b.attack + b.defence
	)
	var party: Array[Loadout] = []
	var used: Dictionary[WeaponData, int] = {}

	for adventurer: AdventurerData in available.slice(0, _campaign_rules.max_party_size):
		var best: WeaponData = null

		for weapon: WeaponData in _armoury_data.weapons:
			var left: int = guild.armoury.get_count(weapon) - used.get(weapon, 0)

			if left > 0 and weapon.main_hand_classes.has(adventurer.class_title):
				if best == null or weapon.attack_bonus > best.attack_bonus:
					best = weapon

		if best != null:
			used[best] = used.get(best, 0) + 1

		party.append(Loadout.new(adventurer, best))

	return party
