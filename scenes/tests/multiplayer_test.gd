extends TestCase

const TIMEOUT_FRAMES: int = 600

var _host: GuildSession
var _guest: GuildSession
var _outcomes: Dictionary[GuildSession, Array] = {}
var _host_baseline: int = 0
var _guest_baseline: int = 0


func _ready() -> void:
	var port: int = 20000 + randi() % 20000
	seed(7)
	_host = _make_session("Host")
	check_equal(_host.host(port), OK, "The host opens a game")
	var item: ItemData = _first_item()

	print("--- Joining late ---")
	_host.buy_equipment(item)
	_host.scout(_host.guild.board[0])
	_guest = _make_session("Guest")
	check_equal(_guest.join("127.0.0.1", port), OK, "The guest starts connecting")
	await _wait_until(func() -> bool: return _guest.guild != null)
	check(_guest.guild != null, "The guest receives the guild")
	_check_same("A guest who joins late sees everything that already happened")

	print("--- Both players have equal control ---")
	var gold: int = _host.guild.ledger.gold
	await _act(func() -> void: _guest.buy_equipment(item))
	check_equal(
		_host.guild.ledger.gold,
		gold - item.price,
		"The guest's purchase comes out of the shared gold"
	)
	_check_same("Both players see the guest's purchase")

	await _act(func() -> void: _guest.scout(_guest.guild.board[1]))
	check(_host.guild.board[1].scouted, "The guest can scout for the guild")
	_check_same("Both players see the guest's scouting")

	var host_quest: QuestData = _host.guild.board[0].quest
	await _act(func() -> void: _host.dispatch(host_quest, _make_party(_host.guild)))
	check_equal(_host.guild.quests_attempted, 1, "The host can send a party")
	_check_same("Both players see the host's quest")

	var guest_quest: QuestData = _guest.guild.board[0].quest
	await _act(func() -> void: _guest.dispatch(guest_quest, _make_party(_guest.guild)))
	check_equal(_host.guild.quests_attempted, 2, "The guest can send a party")
	_check_same("Both players see the guest's quest")

	print("--- Conflicts ---")
	while _host.guild.ledger.gold >= item.price * 2:
		await _act(func() -> void: _host.buy_equipment(item))

	gold = _host.guild.ledger.gold
	_mark()
	_host.buy_equipment(item)
	_guest.buy_equipment(item)
	await _wait_until(_both_applied.bind(2))
	check_equal(
		_host.guild.ledger.gold,
		gold - item.price,
		"Only one of two purchases for the last gold goes through"
	)
	check(_host.guild.ledger.gold >= 0, "Gold never goes below zero")
	var failures: int = 0

	for outcome: Dictionary in _outcomes[_host].slice(-2):
		failures += 1 if outcome.has("error") else 0

	check_equal(failures, 1, "Exactly one of the two purchases is refused")
	_check_same("Both players agree on who got the last purchase")

	# Each player holds their own copy of the quest, as they would on two machines.
	var host_copy: QuestData = _host.guild.board[0].quest
	var guest_copy: QuestData = _guest.guild.board[0].quest
	await _act(func() -> void: _host.dispatch(host_copy, _make_party(_host.guild)))
	check(not _outcomes[_host].back().has("error"), "The host takes a quest")
	var attempted: int = _guest.guild.quests_attempted
	await _act(func() -> void: _guest.dispatch(guest_copy, _make_party(_guest.guild)))
	check(
		_outcomes[_guest].back().has("error"),
		"Sending a party to a quest that was just taken is refused"
	)
	check_equal(_guest.guild.quests_attempted, attempted, "The refused quest isn't attempted")
	_check_same("A refused quest changes nothing for either player")

	print("--- New guild ---")
	await _act(func() -> void: _guest.found_new_guild())
	check_equal(_host.guild.quests_attempted, 0, "Either player can found a new guild")
	_check_same("Both players start the new guild with the same board")

	_guest.leave()
	_host.leave()
	finish()


func _mark() -> void:
	_host_baseline = _count(_host)
	_guest_baseline = _count(_guest)


# Runs one action and waits until both players have applied it.
func _act(action: Callable) -> void:
	_mark()
	action.call()
	await _wait_until(_both_applied.bind(1))


func _both_applied(actions: int) -> bool:
	return _count(_host) >= _host_baseline + actions and _count(_guest) >= _guest_baseline + actions


func _count(session: GuildSession) -> int:
	return _outcomes[session].size()


func _wait_until(condition: Callable) -> void:
	for _frame: int in TIMEOUT_FRAMES:
		if condition.call():
			return

		await get_tree().process_frame


func _make_session(root_name: String) -> GuildSession:
	var root: Node = Node.new()
	root.name = root_name
	add_child(root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
	var session: GuildSession = GuildSession.new(
		load("res://data/rules/campaign_rules.tres") as CampaignRulesData,
		load("res://data/equipment/armoury.tres") as ArmouryData,
		load("res://data/rules/economy_rules.tres") as EconomyRulesData,
		load("res://data/rules/encounter_rules.tres") as EncounterRulesData,
		load("res://data/reports/report_phrases.tres") as ReportPhrasesData
	)
	_outcomes[session] = []
	session.action_applied.connect(
		func(_action: Dictionary, outcome: Dictionary) -> void: _outcomes[session].append(outcome)
	)
	root.add_child(session)
	return session


func _first_item() -> ItemData:
	return (load("res://data/equipment/armoury.tres") as ArmouryData).items[0]


# Up to two adventurers who are fit for duty, each with a weapon their class can hold.
func _make_party(guild: GuildState) -> Array[Loadout]:
	var armoury_data: ArmouryData = load("res://data/equipment/armoury.tres") as ArmouryData
	var party: Array[Loadout] = []
	var used: Dictionary[WeaponData, int] = {}

	for adventurer: AdventurerData in guild.get_available():
		for weapon: WeaponData in armoury_data.weapons:
			var left: int = guild.armoury.get_count(weapon) - used.get(weapon, 0)

			if weapon.main_hand_classes.has(adventurer.class_title) and left > 0:
				used[weapon] = used.get(weapon, 0) + 1
				party.append(Loadout.new(adventurer, weapon))
				break

		if party.size() == 2:
			break

	return party


func _check_same(description: String) -> void:
	check_equal(_describe(_guest.guild), _describe(_host.guild), description)


func _describe(guild: GuildState) -> String:
	var parts: PackedStringArray = [
		"gold %d" % guild.ledger.gold,
		"debt %d" % guild.ledger.debt,
		"wages in %d" % guild.ledger.quests_until_wages,
		"attempted %d/%d" % [guild.quests_attempted, guild.quests_succeeded],
		"dead %s" % _names(guild.dead),
		"resting %s" % _names(guild.resting),
		"worst %s" % guild.worst_disaster,
		"famous %s" % guild.get_most_famous_hero(),
	]

	for entry: BoardEntry in guild.board:
		parts.append("%s d%d p%d s%s" % [
			entry.quest.display_name,
			entry.shown_danger,
			entry.passes,
			entry.scouted,
		])

	var armoury_data: ArmouryData = load("res://data/equipment/armoury.tres") as ArmouryData

	for item: ItemData in armoury_data.items:
		parts.append("%s x%d" % [item.display_name, guild.armoury.get_count(item)])

	for accessory: AccessoryData in guild.armoury.get_owned_accessories():
		parts.append("%s x%d" % [accessory.display_name, guild.armoury.get_count(accessory)])

	return " | ".join(parts)


func _names(adventurers: Array[AdventurerData]) -> String:
	var names: PackedStringArray = []

	for adventurer: AdventurerData in adventurers:
		names.append(adventurer.display_name)

	return ",".join(names)
