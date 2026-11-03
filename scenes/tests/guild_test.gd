extends TestCase

var _economy_rules: EconomyRulesData
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
	finish()


func _make_guild() -> GuildState:
	return GuildState.new(
		load("res://data/rules/campaign_rules.tres") as CampaignRulesData,
		load("res://data/equipment/armoury.tres") as ArmouryData,
		_economy_rules,
		_rng
	)
