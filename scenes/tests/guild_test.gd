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

	var unarmed: Array[Loadout] = [Loadout.new(_load_adventurer("spy"))]
	check_equal(
		small.get_party_problems(unarmed),
		PackedStringArray(["Spy needs a main weapon."]),
		"Loadout problems are reported"
	)

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
	finish()


func _make_guild(
	rules: CampaignRulesData = load("res://data/rules/campaign_rules.tres") as CampaignRulesData
) -> GuildState:
	return GuildState.new(
		rules,
		load("res://data/equipment/armoury.tres") as ArmouryData,
		_economy_rules,
		_rng
	)


func _load_adventurer(id: String) -> AdventurerData:
	return load("res://data/characters/adventurers/%s.tres" % id) as AdventurerData


func _load_weapon(id: String) -> WeaponData:
	return load("res://data/equipment/weapons/%s.tres" % id) as WeaponData
