class_name GuildSession
extends Node

# Keeps one guild in step between players. Every change goes to the host, which
# picks the order and sends it to everyone. Each player applies the same changes,
# in the same order and with the same random seed, to their own copy of the guild,
# so all copies match. Playing alone uses the same path without a network.

signal started
signal action_applied(action: Dictionary, outcome: Dictionary)
signal players_changed
signal connection_lost(message: String)
signal online_status_changed

const DEFAULT_PORT: int = 7777
const MAX_GUESTS: int = 1
# Notice a partner whose game crashed or lost its network within about 8 seconds.
const TIMEOUT_MIN_MS: int = 3000
const TIMEOUT_MAX_MS: int = 8000

var guild: GuildState
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
# While hosting: the code for partners on the internet, or why there isn't one.
# Both are empty while the router is still being asked.
var online_code: String = ""
var online_problem: String = ""

var _campaign_rules: CampaignRulesData
var _armoury_data: ArmouryData
var _economy_rules: EconomyRulesData
var _encounter_rules: EncounterRulesData
var _phrases: ReportPhrasesData
var _log: Array = []
var _seed: int = 0
var _router: UPNP
var _router_thread: Thread
var _port: int = DEFAULT_PORT


func _init(
	campaign_rules: CampaignRulesData,
	armoury_data: ArmouryData,
	economy_rules: EconomyRulesData,
	encounter_rules: EncounterRulesData,
	phrases: ReportPhrasesData
) -> void:
	name = "Session"
	_campaign_rules = campaign_rules
	_armoury_data = armoury_data
	_economy_rules = economy_rules
	_encounter_rules = encounter_rules
	_phrases = phrases


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connected_to_server.connect(_shorten_timeout.bind(1))
	multiplayer.peer_disconnected.connect(func(_id: int) -> void: players_changed.emit())
	multiplayer.connection_failed.connect(_on_connection_lost.bind("Couldn't reach the host."))
	multiplayer.server_disconnected.connect(_on_connection_lost.bind("The host left the game."))


func play_alone() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_reset(randi())
	started.emit()


# With open_router, also asks the home router to let partners on the internet in.
func host(port: int = DEFAULT_PORT, open_router: bool = true) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(port, MAX_GUESTS)

	if error != OK:
		return error

	multiplayer.multiplayer_peer = peer
	_port = port
	online_code = ""
	online_problem = "" if open_router else "Online play wasn't requested."

	if open_router and _router_thread == null:
		_router_thread = Thread.new()
		_router_thread.start(_open_router.bind(port))

	_reset(randi())
	started.emit()
	return OK


# The guild arrives from the host once connected, and started is emitted then.
func join(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(address, port)

	if error == OK:
		multiplayer.multiplayer_peer = peer

	return error


func leave() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_close_router()


func _exit_tree() -> void:
	if _router_thread != null:
		_router_thread.wait_to_finish()
		_router_thread = null

	_close_router()


func is_online() -> bool:
	return not multiplayer.multiplayer_peer is OfflineMultiplayerPeer


func get_player_count() -> int:
	return multiplayer.get_peers().size() + 1


func get_player_name(player_id: int) -> String:
	if player_id == multiplayer.get_unique_id():
		return "You"

	return "The host" if player_id == 1 else "Your partner"


func buy_equipment(equipment: Resource) -> void:
	_request({"type": "buy", "equipment": equipment.resource_path})


func scout(entry: BoardEntry) -> void:
	_request({"type": "scout", "quest": entry.base_quest.resource_path})


func dispatch(quest: QuestData, party: Array[Loadout]) -> void:
	var entry: BoardEntry = guild.find_entry(quest)
	var members: Array = []

	for loadout: Loadout in party:
		var accessories: Array = []

		for accessory: AccessoryData in loadout.accessories:
			accessories.append(accessory.resource_path)

		members.append({
			"adventurer": loadout.adventurer.resource_path,
			"main_hand": _path_of(loadout.main_hand),
			"off_hand": _path_of(loadout.off_hand),
			"armour": _path_of(loadout.armour),
			"accessories": accessories,
			"item": _path_of(loadout.item),
		})

	_request({
		"type": "dispatch",
		"quest": entry.base_quest.resource_path if entry != null else "",
		"party": members,
	})


func found_new_guild() -> void:
	_request({"type": "new_guild"})


func _request(action: Dictionary) -> void:
	if multiplayer.is_server():
		_accept(action, multiplayer.get_unique_id())
	else:
		_request_action.rpc_id(1, action)


@rpc("any_peer", "call_remote", "reliable")
func _request_action(action: Dictionary) -> void:
	if multiplayer.is_server():
		_accept(action, multiplayer.get_remote_sender_id())


func _accept(action: Dictionary, player_id: int) -> void:
	action["player"] = player_id

	if action.get("type") == "new_guild":
		action["seed"] = randi()

	_apply_action.rpc(action)


@rpc("authority", "call_local", "reliable")
func _apply_action(action: Dictionary) -> void:
	var outcome: Dictionary = _apply(action)
	action_applied.emit(action, outcome)


@rpc("authority", "call_remote", "reliable")
func _receive_guild(guild_seed: int, actions: Array) -> void:
	_reset(guild_seed)

	for action: Dictionary in actions:
		_apply(action)

	started.emit()


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		_shorten_timeout(peer_id)
		_receive_guild.rpc_id(peer_id, _seed, _log)

	players_changed.emit()


# Runs on a separate thread, because finding the router can take a few seconds.
func _open_router(port: int) -> void:
	var router: UPNP = UPNP.new()
	var address: String = ""
	var problem: String = ""

	if router.discover(2000, 2, "InternetGatewayDevice") != UPNP.UPNP_RESULT_SUCCESS \
			or router.get_gateway() == null or not router.get_gateway().is_valid_gateway():
		problem = "your router didn't answer, so it may have UPnP turned off"
	elif router.add_port_mapping(port, port, "Guild Dispatcher", "UDP") != UPNP.UPNP_RESULT_SUCCESS:
		problem = "your router wouldn't open port %d" % port
	else:
		address = router.query_external_address()

		if not JoinCode.is_public(address):
			router.delete_port_mapping(port, "UDP")
			problem = "your internet provider shares one address between customers"

	_on_router_answered.call_deferred(router if problem.is_empty() else null, address, problem)


func _on_router_answered(router: UPNP, address: String, problem: String) -> void:
	_router_thread.wait_to_finish()
	_router_thread = null
	_router = router

	if not is_online() or not multiplayer.is_server():
		_close_router()
		return

	online_code = JoinCode.encode(address) if problem.is_empty() else ""
	online_problem = problem
	online_status_changed.emit()


func _close_router() -> void:
	if _router != null:
		_router.delete_port_mapping(_port, "UDP")
		_router = null


func _shorten_timeout(peer_id: int) -> void:
	var peer: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer

	if peer != null and peer.get_peer(peer_id) != null:
		peer.get_peer(peer_id).set_timeout(0, TIMEOUT_MIN_MS, TIMEOUT_MAX_MS)


func _on_connection_lost(message: String) -> void:
	leave()
	connection_lost.emit(message)


func _reset(guild_seed: int) -> void:
	_seed = guild_seed
	_log.clear()
	rng.seed = guild_seed
	guild = GuildState.new(_campaign_rules, _armoury_data, _economy_rules, rng)


# Runs on every player in the same order, so it must not depend on anything local.
func _apply(action: Dictionary) -> Dictionary:
	var outcome: Dictionary = {}

	match action.get("type"):
		"new_guild":
			_reset(action["seed"])
			return outcome
		"buy":
			var equipment: Resource = _load(action.get("equipment"))

			if not _is_sold_at_market(equipment) or not guild.buy_equipment(equipment):
				outcome["error"] = "The guild can't afford that any more."
		"scout":
			var entry: BoardEntry = _find_entry(action.get("quest"))

			if entry == null or not guild.scout(entry):
				outcome["error"] = "That quest can't be scouted any more."
		"dispatch":
			outcome = _apply_dispatch(action)
		_:
			outcome["error"] = "Unknown action."

	_log.append(action)
	return outcome


func _apply_dispatch(action: Dictionary) -> Dictionary:
	var entry: BoardEntry = _find_entry(action.get("quest"))

	if entry == null or guild.is_over():
		return {"error": "That quest is no longer on the board."}

	var party: Array[Loadout] = []
	var available: Array[AdventurerData] = guild.get_available()

	for member: Dictionary in action.get("party", []):
		var adventurer: AdventurerData = _load(member.get("adventurer")) as AdventurerData

		if adventurer == null or not available.has(adventurer):
			return {"error": "Someone in that party isn't fit for duty any more."}

		available.erase(adventurer)
		var accessories: Array[AccessoryData] = []

		for path: String in member.get("accessories", []):
			accessories.append(_load(path) as AccessoryData)

		party.append(Loadout.new(
			adventurer,
			_load(member.get("main_hand")) as WeaponData,
			_load(member.get("off_hand")) as WeaponData,
			_load(member.get("armour")) as ArmourData,
			accessories,
			_load(member.get("item")) as ItemData
		))

	var problems: PackedStringArray = guild.get_party_problems(party)

	if not problems.is_empty():
		return {"error": " ".join(problems)}

	var quest: QuestData = entry.quest
	var gold_before: int = guild.ledger.gold
	var result: QuestResult = EncounterSimulator.new(
		party,
		quest,
		_encounter_rules,
		rng,
		guild.armoury.get_owned_accessories()
	).run()
	var report: String = ReportWriter.write_report(result.events, _phrases, rng)
	var payout: QuestPayout = guild.finish_quest(quest, party, result)
	return {
		"quest": quest,
		"result": result,
		"report": report,
		"payout": payout,
		"gold_before": gold_before,
	}


func _find_entry(quest_path: Variant) -> BoardEntry:
	for entry: BoardEntry in guild.board:
		if entry.base_quest.resource_path == quest_path:
			return entry

	return null


func _load(path: Variant) -> Resource:
	if path is String and path.begins_with("res://") and ResourceLoader.exists(path):
		return load(path)

	return null


func _is_sold_at_market(equipment: Resource) -> bool:
	return equipment is ItemData or equipment is WeaponData or equipment is ArmourData


func _path_of(resource: Resource) -> String:
	return resource.resource_path if resource != null else ""
