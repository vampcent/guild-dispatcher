extends TestCase

const SAMPLE_RUNS: int = 2000


func _ready() -> void:
	var rules: EncounterRulesData = load("res://data/rules/encounter_rules.tres") as EncounterRulesData
	var quest: QuestData = load("res://data/quests/goblin_raid.tres") as QuestData
	var party: Array[Loadout] = []

	for id: String in ["sentinel", "thief", "evoker", "exorcist"]:
		party.append(Loadout.new(load("res://data/characters/adventurers/%s.tres" % id) as AdventurerData))

	_print_sample(party, quest, rules)
	var all_odds: Vector2 = _print_odds("All abilities", party, quest, rules)

	for ability: AbilityData in rules.abilities:
		var reduced: EncounterRulesData = rules.duplicate() as EncounterRulesData
		var remaining: Array[AbilityData] = rules.abilities.duplicate()
		remaining.erase(ability)
		reduced.abilities = remaining
		_print_odds("Without %s" % ability.display_name, party, quest, reduced)

	var none: EncounterRulesData = rules.duplicate() as EncounterRulesData
	none.abilities = []
	var no_odds: Vector2 = _print_odds("No abilities", party, quest, none)
	check(all_odds.x > no_odds.x, "Abilities win more quests than no abilities")
	check_percent(all_odds.x, 91, "Win rate with all abilities")
	check_percent(all_odds.y, 2, "Deaths per 100 quests with all abilities")
	check_percent(no_odds.x, 64, "Win rate with no abilities")
	check_percent(no_odds.y, 24, "Deaths per 100 quests with no abilities")
	finish()


func _print_sample(
	party: Array[Loadout],
	quest: QuestData,
	rules: EncounterRulesData
) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var result: QuestResult = EncounterSimulator.new(party, quest, rules, rng).run()

	for event: QuestEvent in result.events:
		if event.type == QuestEvent.Type.ROUND_STARTED:
			print("Round %d" % event.amount)
		elif event.type == QuestEvent.Type.ABILITY_USED:
			print("%s used %s to protect %s" % [event.actor, event.detail, event.target])
		elif event.type == QuestEvent.Type.BLOW_PARRIED:
			print("%s parried the blow" % event.actor)
		elif event.type == QuestEvent.Type.TRAP_SPOTTED:
			print("%s spotted a trap" % event.actor)
		elif event.type == QuestEvent.Type.TRAP_SPRUNG:
			print("%s hit a trap" % event.target)
		elif event.type == QuestEvent.Type.WOUND_RECOVERED:
			print("%s used %s on %s" % [event.actor, event.detail, event.target])
		elif event.type == QuestEvent.Type.SPELL_CAST:
			print("%s spent a spell slot" % event.actor)


func _print_odds(
	label: String,
	party: Array[Loadout],
	quest: QuestData,
	rules: EncounterRulesData
) -> Vector2:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234
	var wins: int = 0
	var deaths: int = 0

	for _run: int in SAMPLE_RUNS:
		var result: QuestResult = EncounterSimulator.new(party, quest, rules, rng).run()
		wins += 1 if result.succeeded else 0
		deaths += result.dead.size()

	print("%s | Wins %d%% | Deaths per 100 quests: %d" % [
		label,
		roundi(100.0 * wins / SAMPLE_RUNS),
		roundi(100.0 * deaths / SAMPLE_RUNS),
	])
	return Vector2(100.0 * wins / SAMPLE_RUNS, 100.0 * deaths / SAMPLE_RUNS)
