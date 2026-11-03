extends TestCase

const CRYPT: String = "The Restless Crypt"


func _ready() -> void:
	var guild: GuildState = _make_guild()
	var entry: BoardEntry = _find_entry(guild, CRYPT)
	var cost: int = guild.get_scout_cost(entry)
	var gold_before: int = guild.ledger.gold

	check_equal(cost, roundi(entry.quest.pay * 0.15), "scouting costs 15% of the quest's pay")
	check(guild.scout(entry), "scouting succeeds when the guild can afford it")
	check_equal(guild.ledger.gold, gold_before - cost, "scouting takes the cost from gold")
	check_equal(entry.shown_rank, entry.quest.rank, "scouting confirms the true rank")
	check(not guild.scout(entry), "a quest can only be scouted once")
	check_equal(guild.ledger.gold, gold_before - cost, "a refused scout costs nothing")

	var report: ScoutReport = guild.get_scout_report(entry)
	var item_names: Array[String] = []

	for item: ItemData in report.helpful_items:
		item_names.append(item.display_name)

	check(item_names.has("Holy Water"), "the crypt report suggests Holy Water")
	check(item_names.has("Torches"), "the crypt report suggests Torches")
	check(not item_names.has("Lockpicks"), "the crypt report doesn't suggest Lockpicks")
	check_equal(report.suggested_adventurer.display_name, "Exorcist", "the crypt suggests the Exorcist")

	guild.resting.append(report.suggested_adventurer)
	var next_report: ScoutReport = guild.get_scout_report(entry)
	check_equal(next_report.suggested_adventurer.display_name, "Sentinel", "the next best is suggested")

	var poor_guild: GuildState = _make_guild()
	var poor_entry: BoardEntry = _find_entry(poor_guild, CRYPT)
	poor_guild.ledger.gold = 0
	check(not poor_guild.scout(poor_entry), "scouting is refused without enough gold")
	check(not poor_entry.scouted, "a refused scout leaves the quest unscouted")

	var worsened_guild: GuildState = _make_guild()
	var worsened: BoardEntry = _find_entry(worsened_guild, CRYPT)
	var first_cost: int = worsened_guild.get_scout_cost(worsened)
	worsened.worsen(load("res://data/rules/campaign_rules.tres") as CampaignRulesData)
	check(worsened_guild.get_scout_cost(worsened) > first_cost, "a worsened quest costs more to scout")
	finish()


func _make_guild() -> GuildState:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var rules: CampaignRulesData = load("res://data/rules/campaign_rules.tres") as CampaignRulesData
	var all_quests: CampaignRulesData = rules.duplicate() as CampaignRulesData
	all_quests.board_size = all_quests.quests.size()
	var guild: GuildState = GuildState.new(
		all_quests,
		load("res://data/equipment/armoury.tres") as ArmouryData,
		load("res://data/rules/economy_rules.tres") as EconomyRulesData,
		rng
	)
	# Famous enough to be offered every quest, so the crypt is on the board.
	guild.reputation = 1000
	guild.refresh_board()
	return guild


func _find_entry(guild: GuildState, quest_name: String) -> BoardEntry:
	for entry: BoardEntry in guild.board:
		if entry.quest.display_name == quest_name:
			return entry

	return null
