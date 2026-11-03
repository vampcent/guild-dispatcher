extends TestCase

var _economy_rules: EconomyRulesData
var _armoury_data: ArmouryData = make_stocked_armoury_data()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	_economy_rules = load("res://data/rules/economy_rules.tres") as EconomyRulesData
	var phrases: ReportPhrasesData = (
		load("res://data/reports/report_phrases.tres") as ReportPhrasesData
	)

	print("--- Game over ---")
	var guild: GuildState = _make_guild()
	check_equal(guild.get_game_over_reason(), GuildState.GameOverReason.NONE, "A new guild is open")
	check(not guild.is_over(), "A new guild is not over")

	guild.ledger.debt = _economy_rules.debt_limit
	check_equal(
		guild.get_game_over_reason(),
		GuildState.GameOverReason.NONE,
		"Debt exactly at the limit keeps the guild open"
	)
	guild.ledger.debt = _economy_rules.debt_limit + 1
	check_equal(
		guild.get_game_over_reason(),
		GuildState.GameOverReason.DEBT,
		"Debt over the limit closes the guild for debt"
	)
	check(guild.is_over(), "A guild closed for debt is over")

	var fallen: GuildState = _make_guild()
	fallen.ledger.gold = 10000
	fallen.dead = fallen.roster.duplicate()
	check_equal(
		fallen.get_game_over_reason(),
		GuildState.GameOverReason.ALL_DEAD,
		"A rich guild with everyone dead closes because everyone died"
	)
	fallen.ledger.debt = _economy_rules.debt_limit + 1
	check_equal(
		fallen.get_game_over_reason(),
		GuildState.GameOverReason.ALL_DEAD,
		"Losing everyone is the reason given even when the guild is also in debt"
	)

	print("--- Game over text ---")
	var reason: GuildState.GameOverReason = GuildState.GameOverReason.ALL_DEAD
	var dead_line: String = ReportWriter.write_game_over(reason, phrases, _rng)
	reason = GuildState.GameOverReason.DEBT
	var debt_line: String = ReportWriter.write_game_over(reason, phrases, _rng)
	print("All dead: %s" % dead_line)
	print("Debt: %s" % debt_line)
	check(
		phrases.templates.get("GAME_OVER_ALL_DEAD", []).has(dead_line),
		"Losing everyone uses an all-dead line"
	)
	check(
		phrases.templates.get("GAME_OVER_DEBT", []).has(debt_line),
		"Closing for debt uses a debt line"
	)
	check_equal(
		ReportWriter.write_game_over(GuildState.GameOverReason.NONE, phrases, _rng),
		"",
		"An open guild has no game-over line"
	)

	print("--- Party checks ---")
	var rules: CampaignRulesData = (
		load("res://data/rules/campaign_rules.tres").duplicate() as CampaignRulesData
	)
	rules.max_party_size = 2
	var small: GuildState = _make_guild(rules)
	var party: Array[Loadout] = []
	check_equal(
		small.get_party_problems(party),
		PackedStringArray(["Pick at least one adventurer."]),
		"An empty party is refused"
	)
	party.append(Loadout.new(_load_adventurer("sentinel"), _load_weapon("longsword")))
	party.append(Loadout.new(_load_adventurer("berserker"), _load_weapon("greatsword")))
	check(small.get_party_problems(party).is_empty(), "A full party within the rules is accepted")
	party.append(Loadout.new(_load_adventurer("evoker"), _load_weapon("staff")))
	check_equal(
		small.get_party_problems(party),
		PackedStringArray(["A party can have at most 2 adventurers."]),
		"The party size limit comes from the campaign rules"
	)

	var miswielded: Array[Loadout] = [Loadout.new(_load_adventurer("spy"), _load_weapon("staff"))]
	check_equal(
		small.get_party_problems(miswielded),
		PackedStringArray(["Spy can't use Staff."]),
		"Loadout problems are reported"
	)
	var unarmed: Array[Loadout] = [Loadout.new(_load_adventurer("spy"))]
	check(small.get_party_problems(unarmed).is_empty(), "An unarmed adventurer can be sent out")

	var pendant: AccessoryData = load("res://data/equipment/accessories/dragonscale_pendant.tres")
	var unowned: Array[AccessoryData] = [pendant]
	var borrowed: Array[Loadout] = [
		Loadout.new(_load_adventurer("sentinel"), _load_weapon("longsword"), null, null, unowned),
	]
	check_equal(
		small.get_party_problems(borrowed),
		PackedStringArray(["The armoury only has 0 of Dragonscale Pendant."]),
		"Armoury problems are reported"
	)

	_check_board()
	_check_ranks()
	_check_starter_quests()
	_check_escalation()
	_check_scaling()
	_check_resting()
	_check_history()
	finish()


func _check_board() -> void:
	print("--- Quest board ---")
	var rules: CampaignRulesData = load("res://data/rules/campaign_rules.tres") as CampaignRulesData
	var board_size: int = rules.board_size
	var late_shown: int = 0
	var full_boards: int = 0
	var unique_boards: int = 0
	var readings: int = 0
	var off_by_one: int = 0
	var out_of_range: int = 0
	var wrong: int = 0
	var expected_wrong: float = 0.0

	for _guild_number: int in 2000:
		var guild: GuildState = _make_guild()
		var shown_quests: Array[QuestData] = []

		for entry: BoardEntry in guild.board:
			if not shown_quests.has(entry.base_quest):
				shown_quests.append(entry.base_quest)

			late_shown += 1 if entry.quest.rank > QuestData.Rank.E else 0

			var rank: int = entry.quest.rank
			var error: int = absi(entry.shown_rank - rank)
			readings += 1
			off_by_one += 1 if error <= 1 else 0
			var outside: bool = entry.shown_rank < QuestData.Rank.F or entry.shown_rank > QuestData.Rank.S
			out_of_range += 1 if outside else 0
			wrong += 1 if error != 0 else 0
			# A wrong reading at the edge of the scale is clamped back, so only half show up.
			var at_edge: bool = rank == QuestData.Rank.F or rank == QuestData.Rank.S
			expected_wrong += rules.rank_error_chance * (0.5 if at_edge else 1.0)

		full_boards += 1 if guild.board.size() == board_size else 0
		unique_boards += 1 if shown_quests.size() == guild.board.size() else 0

	check_equal(full_boards, 2000, "Every new board shows %d quests" % board_size)
	check_equal(unique_boards, 2000, "No board shows the same quest twice")
	check_equal(late_shown, 0, "A new rank F guild is only offered F and E quests")
	check_equal(off_by_one, readings, "A shown rank is never more than one step from the truth")
	check_equal(out_of_range, 0, "Shown ranks stay between F and S")
	check_percent(
		100.0 * wrong / readings,
		expected_wrong / readings,
		"Share of wrong rank readings"
	)


func _check_ranks() -> void:
	print("--- Quest ranks ---")
	var rules: CampaignRulesData = load("res://data/rules/campaign_rules.tres") as CampaignRulesData
	check_equal(rules.ranks.size(), QuestData.Rank.size(), "Every rank from F to S has a row")

	for rank: int in range(1, rules.ranks.size()):
		var lower: QuestRankData = rules.ranks[rank - 1]
		var higher: QuestRankData = rules.ranks[rank]
		var name: String = QuestData.get_rank_name(rank)
		check(higher.min_pay > lower.min_pay, "Rank %s pays more than the rank below" % name)
		check(
			higher.recommended_strength > lower.recommended_strength,
			"Rank %s needs a stronger party than the rank below" % name
		)

	for quest: QuestData in rules.quests:
		var row: QuestRankData = rules.ranks[quest.rank]
		var label: String = "%s (rank %s)" % [quest.display_name, QuestData.get_rank_name(quest.rank)]
		check(quest.pay >= row.min_pay and quest.pay <= row.max_pay, "%s pays within its rank" % label)
		check(
			quest.enemy_power >= row.min_enemy_power and quest.enemy_power <= row.max_enemy_power,
			"%s faces enemies as strong as its rank says" % label
		)

	# The same party should win less often as the rank rises.
	var encounter_rules: EncounterRulesData = (
		load("res://data/rules/encounter_rules.tres") as EncounterRulesData
	)
	var party: Array[Loadout] = [
		Loadout.new(_load_adventurer("berserker"), _load_weapon("greatsword")),
		Loadout.new(_load_adventurer("evoker"), _load_weapon("staff")),
	]
	var wins: Dictionary[int, int] = {}
	var runs: Dictionary[int, int] = {}

	for quest: QuestData in rules.quests:
		for _run: int in 300:
			var result: QuestResult = EncounterSimulator.new(party, quest, encounter_rules, _rng).run()
			wins[quest.rank] = wins.get(quest.rank, 0) + (1 if result.succeeded else 0)
			runs[quest.rank] = runs.get(quest.rank, 0) + 1

	var ranks: Array[int] = runs.keys()
	ranks.sort()
	var rates: PackedStringArray = []

	for rank: int in ranks:
		rates.append("%s %d%%" % [QuestData.get_rank_name(rank), roundi(100.0 * wins[rank] / runs[rank])])

	print("Win rate for a party of strength %d: %s" % [Loadout.get_party_strength(party), ", ".join(rates)])

	for index: int in range(1, ranks.size()):
		var lower: float = float(wins[ranks[index - 1]]) / runs[ranks[index - 1]]
		var higher: float = float(wins[ranks[index]]) / runs[ranks[index]]
		check(
			higher < lower,
			"The same party wins less often at rank %s than rank %s"
			% [QuestData.get_rank_name(ranks[index]), QuestData.get_rank_name(ranks[index - 1])]
		)


# F-rank jobs are for a brand-new guild: two adventurers with no gear should
# nearly always manage, and a couple of jobs should pay for a first weapon.
func _check_starter_quests() -> void:
	print("--- F-rank starter quests ---")
	var rules: CampaignRulesData = load("res://data/rules/campaign_rules.tres") as CampaignRulesData
	var encounter_rules: EncounterRulesData = (
		load("res://data/rules/encounter_rules.tres") as EncounterRulesData
	)
	var armoury_data: ArmouryData = load("res://data/equipment/armoury.tres") as ArmouryData
	var starters: Array[QuestData] = []

	for quest: QuestData in rules.quests:
		if quest.rank == QuestData.Rank.F:
			starters.append(quest)

	check(starters.size() >= 5, "There are at least 5 F-rank quests (found %d)" % starters.size())
	var lowest_pay: int = 100000

	for quest: QuestData in starters:
		lowest_pay = mini(lowest_pay, quest.pay)
		var wins: int = 0
		var deaths: int = 0
		var runs: int = 0

		for first: int in rules.adventurers.size():
			for second: int in range(first + 1, rules.adventurers.size()):
				var party: Array[Loadout] = [
					Loadout.new(rules.adventurers[first]),
					Loadout.new(rules.adventurers[second]),
				]

				for _run: int in 100:
					var result: QuestResult = EncounterSimulator.new(
						party, quest, encounter_rules, _rng
					).run()
					wins += 1 if result.succeeded else 0
					deaths += result.dead.size()
					runs += 1

		print("%s: unarmed pairs win %d%%, %.1f deaths per 100 quests" % [
			quest.display_name,
			roundi(100.0 * wins / runs),
			100.0 * deaths / runs,
		])
		check_percent(100.0 * wins / runs, 88, "Unarmed pairs win %s about 85-90%% of the time" % quest.display_name)
		check(100.0 * deaths / runs <= 3.0, "Deaths are rare on %s" % quest.display_name)

	# Every class's cheapest main weapon should be affordable after two starter jobs.
	var classes: Array[String] = []

	for adventurer: AdventurerData in rules.adventurers:
		if not classes.has(adventurer.class_title):
			classes.append(adventurer.class_title)

	for class_title: String in classes:
		var cheapest: int = 100000

		for weapon: WeaponData in armoury_data.weapons:
			if weapon.main_hand_classes.has(class_title):
				cheapest = mini(cheapest, weapon.price)

		check(
			lowest_pay * 2 >= cheapest,
			"Two F-rank jobs pay for a %s's cheapest weapon (%d gold)" % [class_title, cheapest]
		)


func _check_escalation() -> void:
	print("--- Quest pool and escalation ---")
	var rules: CampaignRulesData = load("res://data/rules/campaign_rules.tres") as CampaignRulesData
	var ranks: Array[int] = []

	for quest: QuestData in rules.quests:
		if not ranks.has(quest.rank):
			ranks.append(quest.rank)

	ranks.sort()
	check_equal(
		ranks,
		[
			QuestData.Rank.F,
			QuestData.Rank.E,
			QuestData.Rank.D,
			QuestData.Rank.C,
			QuestData.Rank.B,
			QuestData.Rank.A,
		] as Array[int],
		"The quest pool covers ranks F to A"
	)

	print("--- Guild rank ---")
	var guild: GuildState = _make_guild()
	var starter: QuestData = load("res://data/quests/lost_goat.tres") as QuestData
	var night_watch: QuestData = load("res://data/quests/night_watch.tres") as QuestData
	check_equal(guild.get_guild_rank(), QuestData.Rank.F, "A new guild is rank F")
	check_equal(guild.get_next_rank_reputation(), 2, "A new guild needs 2 reputation for rank E")
	guild.finish_quest(starter, [], _make_result(false))
	check_equal(guild.reputation, 0, "A failed quest earns no reputation")
	guild.finish_quest(starter, [], _make_result(true))
	check_equal(guild.reputation, 1, "An F-rank success earns 1 reputation")
	check_equal(guild.get_guild_rank(), QuestData.Rank.F, "One starter job isn't enough for rank E")
	var costly: QuestResult = _make_result(true)
	costly.injured.append(guild.roster[0])
	guild.finish_quest(starter, [], costly)
	check_equal(guild.get_guild_rank(), QuestData.Rank.E, "A costly success still counts towards rank E")
	guild.finish_quest(night_watch, [], _make_result(true))
	check_equal(guild.reputation, 4, "An E-rank success earns 2 reputation")

	# Each rank lets quests one rank higher onto the board, and not before.
	for rank: int in range(QuestData.Rank.D, QuestData.Rank.S):
		var needed: int = rules.ranks[rank - 1].reputation_needed
		var name: String = QuestData.get_rank_name(rank)
		check_equal(
			_count_rank_appearances(rank, needed - 1),
			0,
			"Rank %s quests stay off the board until the guild is rank %s" % [name, QuestData.get_rank_name(rank - 1)]
		)
		check(
			_count_rank_appearances(rank, needed) > 0,
			"Rank %s quests can appear once the guild reaches rank %s" % [name, QuestData.get_rank_name(rank - 1)]
		)

	var seen: Array[QuestData] = []
	var full_boards: int = 0
	var unique_boards: int = 0

	for _guild_number: int in 500:
		var veteran: GuildState = _make_guild()
		veteran.reputation = 1000
		veteran.board.clear()
		veteran.refresh_board()
		var shown_quests: Array[QuestData] = []

		for entry: BoardEntry in veteran.board:
			if not shown_quests.has(entry.base_quest):
				shown_quests.append(entry.base_quest)

			if not seen.has(entry.base_quest):
				seen.append(entry.base_quest)

		full_boards += 1 if veteran.board.size() == rules.board_size else 0
		unique_boards += 1 if shown_quests.size() == veteran.board.size() else 0

	check_equal(seen.size(), rules.quests.size(), "A veteran guild can be offered every quest")
	check_equal(full_boards, 500, "A veteran guild's board is always full")
	check_equal(unique_boards, 500, "A veteran guild's board never shows a quest twice")


# The board leans harder as time passes, and eases off when the roster is weakened.
func _check_scaling() -> void:
	print("--- Board scaling ---")
	var rules: CampaignRulesData = load("res://data/rules/campaign_rules.tres") as CampaignRulesData
	var guild: GuildState = _make_guild()
	check_equal(guild.get_target_rank(), QuestData.Rank.F, "A new guild's board leans towards rank F")
	guild.quests_attempted = rules.quests_per_target_rank * 2
	check_equal(guild.get_target_rank(), QuestData.Rank.D, "Two steps of time move the target to rank D")
	guild.quests_attempted = 1000
	var full_strength: int = guild.get_target_rank()
	check(full_strength >= QuestData.Rank.C, "The full roster can handle rank C or above")
	guild.dead = guild.roster.slice(0, guild.roster.size() - 1)
	check(
		guild.get_target_rank() < full_strength,
		"Losing most of the roster lowers the target (%s to %s)"
		% [QuestData.get_rank_name(full_strength), QuestData.get_rank_name(guild.get_target_rank())]
	)

	var early: float = _average_board_rank(0, 0, [])
	var later: float = _average_board_rank(1000, rules.quests_per_target_rank * 2, [])
	var veteran: float = _average_board_rank(1000, 1000, [])
	var survivors: Array[String] = ["spy"]
	var weakened: float = _average_board_rank(1000, 1000, survivors)
	print("Average board rank (F=0): new %.2f, after %d quests %.2f, veteran %.2f, veteran with only the Spy left %.2f" % [
		early, rules.quests_per_target_rank * 2, later, veteran, weakened,
	])
	check(early < 0.5, "A new guild's board is mostly F-rank work")
	check(later > early + 0.5, "The board gets harder as quests go by")
	check(veteran > later, "A veteran guild sees harder quests still")
	check(weakened < veteran - 1.0, "A veteran guild that has lost its roster sees easier quests again")


# With high reputation every rank is unlocked, so only time and the roster shape the board.
func _average_board_rank(reputation: int, quests_attempted: int, survivors: Array[String]) -> float:
	var total: int = 0
	var shown: int = 0

	for _guild_number: int in 500:
		var guild: GuildState = _make_guild()
		guild.reputation = reputation
		guild.quests_attempted = quests_attempted

		if not survivors.is_empty():
			for adventurer: AdventurerData in guild.roster:
				if not survivors.has(adventurer.resource_path.get_file().get_basename()):
					guild.dead.append(adventurer)

		guild.board.clear()
		guild.refresh_board()

		for entry: BoardEntry in guild.board:
			total += entry.base_quest.rank
			shown += 1

	return float(total) / shown


func _count_rank_appearances(rank: int, reputation: int) -> int:
	var appearances: int = 0

	for _guild_number: int in 500:
		var guild: GuildState = _make_guild()
		guild.reputation = reputation
		guild.board.clear()
		guild.refresh_board()

		for entry: BoardEntry in guild.board:
			appearances += 1 if entry.base_quest.rank == rank else 0

	return appearances


func _make_result(succeeded: bool) -> QuestResult:
	var result: QuestResult = QuestResult.new()
	result.succeeded = succeeded
	return result


func _check_resting() -> void:
	print("--- Resting ---")
	var guild: GuildState = _make_guild()
	var injured: AdventurerData = guild.roster[0]
	var result: QuestResult = QuestResult.new()
	result.succeeded = true
	result.injured.append(injured)
	guild.finish_quest(guild.board[0].quest, [], result)
	check(not guild.get_available().has(injured), "An injured adventurer sits out the next quest")
	check_equal(guild.get_available().size(), guild.roster.size() - 1, "Everyone else is available")

	guild.finish_quest(guild.board[0].quest, [], _make_success())
	check(guild.get_available().has(injured), "An injured adventurer is back after one quest")

	var nearly: GuildState = _make_guild()
	result = _make_success()
	result.injured = nearly.roster.slice(1)
	nearly.finish_quest(nearly.board[0].quest, [], result)
	check_equal(
		_names(nearly.get_available()),
		_names(nearly.roster.slice(0, 1)),
		"With one adventurer unhurt, the injured still sit out"
	)

	var everyone: GuildState = _make_guild()
	result = _make_success()
	result.dead = everyone.roster.slice(0, 4)
	result.injured = everyone.roster.slice(4)
	everyone.finish_quest(everyone.board[0].quest, [], result)
	check(everyone.resting.is_empty(), "If every living adventurer is injured, nobody has to rest")
	check_equal(
		_names(everyone.get_available()),
		_names(everyone.roster.slice(4)),
		"The injured survivors are available again"
	)


func _check_history() -> void:
	print("--- History stats ---")
	var guild: GuildState = _make_guild()
	check_equal(guild.worst_disaster, "", "A new guild has no worst disaster")
	check_equal(guild.get_most_famous_hero(), "Nobody", "A new guild has no famous hero")

	var rules: CampaignRulesData = load("res://data/rules/campaign_rules.tres") as CampaignRulesData
	var quests: Array[QuestData] = rules.quests
	var first: AdventurerData = guild.roster[0]
	var second: AdventurerData = guild.roster[1]
	var third: AdventurerData = guild.roster[2]

	var result: QuestResult = _make_success()
	result.dead.append(guild.roster[5])
	_add_events(result, QuestEvent.Type.ADVENTURER_HIT, second, 3)
	_add_events(result, QuestEvent.Type.ADVENTURER_HIT, first, 2)
	_add_events(result, QuestEvent.Type.ADVENTURER_MISSED, third, 9)
	guild.finish_quest(quests[0], [], result)
	check_equal(guild.get_most_famous_hero(), second.display_name, "The hero with most hits is famous")

	result = _make_success()
	result.dead.append_array([guild.roster[4], guild.roster[3]])
	_add_events(result, QuestEvent.Type.ADVENTURER_HIT, first, 2)
	guild.finish_quest(quests[1], [], result)
	check_equal(guild.get_most_famous_hero(), first.display_name, "Hits add up across quests")
	check_equal(
		guild.worst_disaster,
		quests[1].display_name,
		"The deadliest quest is the worst disaster"
	)

	result = _make_success()
	result.dead.append_array([guild.roster[2], guild.roster[1]])
	guild.finish_quest(quests[2], [], result)
	check_equal(
		guild.worst_disaster,
		quests[1].display_name,
		"A later quest with the same deaths doesn't replace the worst disaster"
	)


func _make_success() -> QuestResult:
	var result: QuestResult = QuestResult.new()
	result.succeeded = true
	return result


func _add_events(
	result: QuestResult,
	type: QuestEvent.Type,
	adventurer: AdventurerData,
	count: int
) -> void:
	for _event: int in count:
		result.events.append(QuestEvent.new(type, adventurer.display_name))


func _names(adventurers: Array[AdventurerData]) -> PackedStringArray:
	var names: PackedStringArray = []

	for adventurer: AdventurerData in adventurers:
		names.append(adventurer.display_name)

	return names


func _make_guild(
	rules: CampaignRulesData = load("res://data/rules/campaign_rules.tres") as CampaignRulesData
) -> GuildState:
	return GuildState.new(
		rules,
		_armoury_data,
		_economy_rules,
		_rng
	)


func _load_adventurer(id: String) -> AdventurerData:
	return load("res://data/characters/adventurers/%s.tres" % id) as AdventurerData


func _load_weapon(id: String) -> WeaponData:
	return load("res://data/equipment/weapons/%s.tres" % id) as WeaponData

