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
var reputation: int = 0
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


func get_guild_rank() -> int:
	var guild_rank: int = QuestData.Rank.F

	for rank: int in _rules.ranks.size():
		if reputation >= _rules.ranks[rank].reputation_needed:
			guild_rank = rank

	return guild_rank


# The reputation the guild has to reach for its next rank, or -1 at rank S.
func get_next_rank_reputation() -> int:
	var next_rank: int = get_guild_rank() + 1
	return _rules.ranks[next_rank].reputation_needed if next_rank < _rules.ranks.size() else -1


func get_recommended_strength(rank: int) -> int:
	return _rules.ranks[rank].recommended_strength


# Judged against the rank shown on the board, which may be misread until scouted.
func is_party_too_weak(party: Array[Loadout], entry: BoardEntry) -> bool:
	return Loadout.get_party_strength(party) < get_recommended_strength(entry.shown_rank)


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

	# A guild is offered quests up to one rank above its own.
	for quest: QuestData in _rules.quests:
		if quest.rank <= get_guild_rank() + 1:
			pool.append(quest)

	for entry: BoardEntry in board:
		pool.erase(entry.base_quest)

	var target_rank: int = get_target_rank()

	while not pool.is_empty() and board.size() < _rules.board_size:
		var quest: QuestData = _pick_near_rank(pool, target_rank)
		pool.erase(quest)
		board.append(BoardEntry.new(quest, _get_shown_rank(quest)))


# The rank the board leans towards. It rises with time, but never past the
# highest rank whose recommended strength the roster's best party reaches.
func get_target_rank() -> int:
	var by_time: int = floori(quests_attempted / float(_rules.quests_per_target_rank))
	var by_roster: int = QuestData.Rank.F
	var strength: int = get_roster_strength()

	for rank: int in _rules.ranks.size():
		if strength >= _rules.ranks[rank].recommended_strength:
			by_roster = rank

	return mini(by_time, by_roster)


# Attack plus defence, before gear, of the strongest party the living roster can send.
func get_roster_strength() -> int:
	var strengths: Array[int] = []

	for adventurer: AdventurerData in roster:
		if not dead.has(adventurer):
			strengths.append(adventurer.attack + adventurer.defence)

	strengths.sort()
	strengths.reverse()
	var total: int = 0

	for strength: int in strengths.slice(0, _rules.max_party_size):
		total += strength

	return total


func _pick_near_rank(pool: Array[QuestData], target_rank: int) -> QuestData:
	var weights: Array[int] = []
	var total: int = 0

	for quest: QuestData in pool:
		var distance: int = mini(absi(quest.rank - target_rank), _rules.board_rank_weights.size() - 1)
		weights.append(_rules.board_rank_weights[distance])
		total += weights.back()

	var pick: int = _rng.randi_range(1, total)

	for index: int in pool.size():
		pick -= weights[index]

		if pick <= 0:
			return pool[index]

	return pool.back()


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
	entry.shown_rank = entry.quest.rank
	return true


func get_scout_report(entry: BoardEntry) -> ScoutReport:
	var report: ScoutReport = ScoutReport.new()
	report.true_rank = entry.quest.rank

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
		reputation += _rules.ranks[quest.rank].reputation

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


# A misread rank is one step off, but never outside F to S.
func _get_shown_rank(quest: QuestData) -> int:
	if _rng.randi_range(1, 100) > _rules.rank_error_chance:
		return quest.rank

	var error: int = -1 if _rng.randi_range(0, 1) == 0 else 1
	return clampi(quest.rank + error, QuestData.Rank.F, QuestData.Rank.S)
