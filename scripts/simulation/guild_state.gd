class_name GuildState
extends RefCounted

const MAX_DANGER: int = 5

var roster: Array[AdventurerData] = []
var dead: Array[AdventurerData] = []
var resting: Array[AdventurerData] = []
var armoury: Armoury
var ledger: GuildLedger
var board: Array[BoardEntry] = []
var quests_attempted: int = 0
var quests_succeeded: int = 0
var worst_disaster: String = ""
var worst_disaster_deaths: int = 0

var _rules: CampaignRulesData
var _rng: RandomNumberGenerator
var _hits: Dictionary[String, int] = {}


func _init(
	rules: CampaignRulesData,
	armoury_data: ArmouryData,
	economy_rules: EconomyRulesData,
	rng: RandomNumberGenerator
) -> void:
	_rules = rules
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


func buy_item(item: ItemData) -> bool:
	if not ledger.can_afford(item.price):
		return false

	ledger.spend_gold(item.price)
	armoury.add_item(item)
	return true


func refresh_board() -> void:
	var pool: Array[QuestData] = _rules.quests.duplicate()
	board.clear()

	while not pool.is_empty() and board.size() < _rules.board_size:
		var quest: QuestData = pool[_rng.randi_range(0, pool.size() - 1)]
		pool.erase(quest)
		board.append(BoardEntry.new(quest, _get_shown_danger(quest)))


func finish_quest(quest: QuestData, party: Array[Loadout], result: QuestResult) -> void:
	dead.append_array(result.dead)
	armoury.apply_result(party, result)
	ledger.record_quest(quest, result, get_living_count())
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

	refresh_board()


func is_over() -> bool:
	return get_living_count() == 0 or ledger.is_closed(get_living_count())


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
	return clampi(quest.danger + error, 1, MAX_DANGER)
