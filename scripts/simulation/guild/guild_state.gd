class_name GuildState
extends RefCounted

enum GameOverReason {
	NONE,
	ALL_DEAD,
	DEBT,
}

var roster: Array[AdventurerData] = []
var dead: Array[AdventurerData] = []
var resting: Array[AdventurerData] = []
var armoury: Armoury
var ledger: GuildLedger
var board: Array[BoardEntry] = []
var expired_quests: Array[String] = []
var quests_attempted: int = 0
var quests_succeeded: int = 0
var worst_disaster: String = ""
var worst_disaster_deaths: int = 0

var _rules: CampaignRulesData
var _armoury_data: ArmouryData
var _rng: RandomNumberGenerator
var _hits: Dictionary[String, int] = {}


func _init(
	rules: CampaignRulesData,
	armoury_data: ArmouryData,
	economy_rules: EconomyRulesData,
	rng: RandomNumberGenerator
) -> void:
	_rules = rules
	_armoury_data = armoury_data
	_rng = rng
	roster = rules.adventurers.duplicate()
	armoury = Armoury.new(armoury_data)
	ledger = GuildLedger.new(economy_rules)
	refresh_board()


func get_available() -> Array[AdventurerData]:
	var available: Array[AdventurerData] = []

	for adventurer: AdventurerData in roster:
		if not dead.has(adventurer) and not resting.has(adventurer):
			available.append(adventurer)

	return available


func get_living_count() -> int:
	return roster.size() - dead.size()


func get_party_problems(party: Array[Loadout]) -> PackedStringArray:
	var problems: PackedStringArray = []

	if party.is_empty():
		problems.append("Pick at least one adventurer.")
	elif party.size() > _rules.max_party_size:
		problems.append("A party can have at most %d adventurers." % _rules.max_party_size)

	for loadout: Loadout in party:
		problems.append_array(loadout.get_problems())

	problems.append_array(armoury.get_problems(party))
	return problems


# Buys one item, weapon or armour for the armoury.
func buy_equipment(equipment: Resource) -> bool:
	var price: int = equipment.get("price")

	if not ledger.can_afford(price):
		return false

	ledger.spend_gold(price)
	armoury.add(equipment)
	return true


func refresh_board() -> void:
	var pool: Array[QuestData] = []

	for quest: QuestData in _rules.quests:
		if quest.min_quests_attempted <= quests_attempted:
			pool.append(quest)

	for entry: BoardEntry in board:
		pool.erase(entry.base_quest)

	while not pool.is_empty() and board.size() < _rules.board_size:
		var quest: QuestData = pool[_rng.randi_range(0, pool.size() - 1)]
		pool.erase(quest)
		board.append(BoardEntry.new(quest, _get_shown_danger(quest)))


func advance_board(chosen_quest: QuestData) -> void:
	var remaining: Array[BoardEntry] = []
	expired_quests.clear()

	for entry: BoardEntry in board:
		if entry.quest == chosen_quest:
			continue

		entry.worsen(_rules)

		if entry.passes >= _rules.expire_after_passes:
			expired_quests.append(entry.quest.display_name)
		else:
			remaining.append(entry)

	board = remaining
	refresh_board()


func find_entry(quest: QuestData) -> BoardEntry:
	for entry: BoardEntry in board:
		if entry.quest == quest:
			return entry

	return null


func get_scout_cost(entry: BoardEntry) -> int:
	return roundi(entry.quest.pay * _rules.scout_cost_percent / 100.0)


func can_scout(entry: BoardEntry) -> bool:
	return not entry.scouted and ledger.can_afford(get_scout_cost(entry))


func scout(entry: BoardEntry) -> bool:
	if not can_scout(entry):
		return false

	ledger.spend_gold(get_scout_cost(entry))
	entry.scouted = true
	entry.shown_danger = entry.quest.danger
	return true


func get_scout_report(entry: BoardEntry) -> ScoutReport:
	var report: ScoutReport = ScoutReport.new()
	report.true_danger = entry.quest.danger

	for item: ItemData in _armoury_data.items:
		for tag: String in item.quest_tags:
			if entry.quest.quest_tags.has(tag):
				report.helpful_items.append(item)
				break

	report.suggested_adventurer = _get_suggested_adventurer(entry.quest)
	return report


func _get_suggested_adventurer(quest: QuestData) -> AdventurerData:
	var available: Array[AdventurerData] = get_available()

	for subclass: String in quest.suggested_subclasses:
		for adventurer: AdventurerData in available:
			if adventurer.subclass_title == subclass:
				return adventurer

	return null


func get_passes_left(entry: BoardEntry) -> int:
	return _rules.expire_after_passes - entry.passes


func finish_quest(quest: QuestData, party: Array[Loadout], result: QuestResult) -> QuestPayout:
	dead.append_array(result.dead)
	armoury.apply_result(party, result)
	var payout: QuestPayout = ledger.record_quest(quest, result, get_living_count())
	resting = result.injured.duplicate()
	quests_attempted += 1

	if result.succeeded:
		quests_succeeded += 1

	if result.dead.size() > worst_disaster_deaths:
		worst_disaster_deaths = result.dead.size()
		worst_disaster = quest.display_name

	for event: QuestEvent in result.events:
		if event.type == QuestEvent.Type.ADVENTURER_HIT:
			_hits[event.actor] = _hits.get(event.actor, 0) + 1

	if get_available().is_empty():
		resting.clear()

	advance_board(quest)
	return payout


func is_over() -> bool:
	return get_game_over_reason() != GameOverReason.NONE


func get_game_over_reason() -> GameOverReason:
	if get_living_count() == 0:
		return GameOverReason.ALL_DEAD

	if ledger.is_closed(get_living_count()):
		return GameOverReason.DEBT

	return GameOverReason.NONE


func get_most_famous_hero() -> String:
	var best_name: String = "Nobody"
	var best_hits: int = 0

	for hero_name: String in _hits:
		if _hits[hero_name] > best_hits:
			best_hits = _hits[hero_name]
			best_name = hero_name

	return best_name


func _get_shown_danger(quest: QuestData) -> int:
	if _rng.randi_range(1, 100) > _rules.danger_error_chance:
		return quest.danger

	var error: int = -1 if _rng.randi_range(0, 1) == 0 else 1
	return clampi(quest.danger + error, 1, _rules.max_danger)
