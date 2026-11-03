extends Control

const OUTCOME_NAMES: Array[String] = ["Success", "Costly success", "Failure"]
const SLOT_LABELS: Array[String] = ["No back item", "No face item", "No ring", "No necklace"]


var _campaign_rules: CampaignRulesData
var _armoury_data: ArmouryData
var _economy_rules: EconomyRulesData
var _encounter_rules: EncounterRulesData
var _phrases: ReportPhrasesData
var _ui_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _session: GuildSession
var _guild: GuildState:
	get:
		return _session.guild
var _quest: QuestData
var _screen: Callable
var _notice: String = ""
var _address_edit: LineEdit
var _rows: Array[PartyRow] = []
var _notes_label: Label
var _send_button: Button

@onready var _content: VBoxContainer = $Margin/Scroll/Content


func _ready() -> void:
	_campaign_rules = load("res://data/rules/campaign_rules.tres") as CampaignRulesData
	_armoury_data = load("res://data/equipment/armoury.tres") as ArmouryData
	_economy_rules = load("res://data/rules/economy_rules.tres") as EconomyRulesData
	_encounter_rules = load("res://data/rules/encounter_rules.tres") as EncounterRulesData
	_phrases = load("res://data/reports/report_phrases.tres") as ReportPhrasesData
	_ui_rng.randomize()
	_session = GuildSession.new(
		_campaign_rules, _armoury_data, _economy_rules, _encounter_rules, _phrases
	)
	add_child(_session)
	_session.started.connect(_show_board)
	_session.action_applied.connect(_on_action_applied)
	_session.players_changed.connect(_on_players_changed)
	_session.connection_lost.connect(_show_lobby)
	_start_from_command_line()


# Run with -- --host or -- --join=ADDRESS to skip the lobby, for example when testing.
func _start_from_command_line() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--host":
			_on_host_pressed()
			return

		if arg.begins_with("--join="):
			_join(arg.trim_prefix("--join="))
			return

	_show_lobby()


func _show_lobby(message: String = "") -> void:
	_set_screen(_show_lobby.bind(message))
	_add_label("Guild Dispatcher", 24)

	if not message.is_empty():
		_add_label(message)

	_add_button("Play alone", _session.play_alone)
	_add_button("Host a game for two (port %d)" % GuildSession.DEFAULT_PORT, _on_host_pressed)
	_add_label("Or join a friend's game. Enter the address they see on their quest board:")
	_address_edit = LineEdit.new()
	_address_edit.placeholder_text = "Address, for example 192.168.1.20"
	_address_edit.text_submitted.connect(func(address: String) -> void: _join(address))
	_content.add_child(_address_edit)
	_add_button("Join", func() -> void: _join(_address_edit.text))


func _on_host_pressed() -> void:
	var error: Error = _session.host()

	if error != OK:
		_show_lobby("Couldn't host on port %d (%s)." % [GuildSession.DEFAULT_PORT, error_string(error)])


func _join(address: String) -> void:
	address = address.strip_edges()

	if address.is_empty():
		address = "127.0.0.1"

	var error: Error = _session.join(address)

	if error != OK:
		_show_lobby("Couldn't connect to %s (%s)." % [address, error_string(error)])
		return

	_set_screen(_join.bind(address))
	_add_label("Joining the guild at %s..." % address, 24)
	_add_button("Cancel", func() -> void:
		_session.leave()
		_show_lobby()
	)


func _on_action_applied(action: Dictionary, outcome: Dictionary) -> void:
	var mine: bool = action.get("player") == multiplayer.get_unique_id()

	if outcome.has("error"):
		if mine:
			_notice = outcome["error"]
			_screen.call()

		return

	match action.get("type"):
		"new_guild":
			_notice = "" if mine else "Your partner founded a new guild."
			_show_board()
		"dispatch":
			_show_report(action, outcome)
		_:
			if not mine:
				_notice = _describe(action)

			_screen.call()


func _describe(action: Dictionary) -> String:
	var who: String = _session.get_player_name(action.get("player"))

	if action.get("type") == "buy":
		return "%s bought %s." % [who, (load(action["item"]) as ItemData).display_name]

	return "%s paid to scout %s." % [who, (load(action["quest"]) as QuestData).display_name]


func _on_players_changed() -> void:
	if _session.guild != null and _screen.is_valid():
		_screen.call()


func _show_board() -> void:
	_set_screen(_show_board)
	_add_label("Quest board", 24)
	_add_session_status()
	_add_label("Gold: %d | Debt: %d / %d | Wages due in %d quests" % [
		_guild.ledger.gold,
		_guild.ledger.debt,
		_economy_rules.debt_limit,
		_guild.ledger.quests_until_wages,
	])

	for warning: String in _guild.ledger.get_warnings(_guild.get_living_count()):
		_add_label("Warning: %s" % warning)

	_add_label("Fit for duty: %s" % _join_names(_guild.get_available()))

	if not _guild.resting.is_empty():
		_add_label("Injured, sitting out this quest: %s" % _join_names(_guild.resting))

	if not _guild.dead.is_empty():
		_add_label("Lost: %s" % _join_names(_guild.dead))

	if not _guild.expired_quests.is_empty():
		_add_label("Contracts lost while you were busy: %s" % ", ".join(_guild.expired_quests))

	_add_button("Buy supplies", _show_supplies)

	for entry: BoardEntry in _guild.board:
		var pressure: String = ""
		var scouting: String = ""

		if entry.passes > 0:
			pressure = "\nThe situation is getting worse. Expires in %d quests." % _guild.get_passes_left(entry)

		if entry.scouted:
			scouting = "\n%s" % _get_scout_text(entry)

		_add_button(
			"%s | Danger %d of %d | Pays %d\n%s%s%s" % [
				entry.quest.display_name,
				entry.shown_danger,
				_campaign_rules.max_danger,
				entry.quest.pay,
				entry.quest.briefing,
				pressure,
				scouting,
			],
			_on_quest_chosen.bind(entry.quest)
		)

		if not entry.scouted:
			var scout_button: Button = _add_button(
				"Scout %s for %d gold" % [entry.quest.display_name, _guild.get_scout_cost(entry)],
				_on_scout_pressed.bind(entry)
			)
			scout_button.disabled = not _guild.can_scout(entry)


func _on_scout_pressed(entry: BoardEntry) -> void:
	_session.scout(entry)


func _get_scout_text(entry: BoardEntry) -> String:
	var report: ScoutReport = _guild.get_scout_report(entry)
	var items: PackedStringArray = []

	for item: ItemData in report.helpful_items:
		items.append(item.display_name)

	var advice: String = "Worth packing: %s." % ", ".join(items)

	if report.suggested_adventurer != null:
		advice += " Suggested: %s." % report.suggested_adventurer.display_name
	else:
		advice += " Nobody fit for duty is especially suited to this."

	return "Scout's report: Danger confirmed. %s" % advice


func _show_supplies() -> void:
	_set_screen(_show_supplies)
	_add_label("Supplies", 24)
	_add_session_status()
	_add_label("Gold: %d" % _guild.ledger.gold)

	for item: ItemData in _armoury_data.items:
		var button: Button = _add_button(
			"Buy %s for %d gold (you have %d)" % [
				item.display_name,
				item.price,
				_guild.armoury.get_count(item),
			],
			_on_buy_pressed.bind(item)
		)
		button.disabled = not _guild.ledger.can_afford(item.price)

	_add_button("Back to the board", _show_board)


func _on_buy_pressed(item: ItemData) -> void:
	_session.buy_item(item)


func _on_quest_chosen(quest: QuestData) -> void:
	_quest = quest
	_show_party_setup()


func _show_party_setup() -> void:
	_set_screen(_refresh_party_setup)
	_rows.clear()
	_add_label("Party setup: %s" % _quest.display_name, 24)
	_add_label(_quest.briefing)
	var entry: BoardEntry = _guild.find_entry(_quest)

	if entry != null and entry.scouted:
		_add_label(_get_scout_text(entry))

	_add_label(
		"Tick up to %d adventurers and equip them from the armoury." % _campaign_rules.max_party_size
	)

	for adventurer: AdventurerData in _guild.get_available():
		_add_party_row(adventurer)

	_notes_label = _add_label("")
	_send_button = _add_button("Send them off", _on_send_pressed)
	_add_button("Back to the board", _show_board)
	_refresh_setup()


# Keeps the player's choices when the guild changes underneath them, unless their quest is gone.
func _refresh_party_setup() -> void:
	if _guild.find_entry(_quest) == null:
		_notice = "%s is no longer on the board." % _quest.display_name
		_show_board()
		return

	_refresh_setup()

	if not _notice.is_empty():
		_notes_label.text = "%s %s" % [_notice, _notes_label.text]
		_notice = ""


func _add_party_row(adventurer: AdventurerData) -> void:
	var row: PartyRow = PartyRow.new()
	row.adventurer = adventurer
	row.check_box = CheckBox.new()
	row.check_box.text = "%s (%s)" % [adventurer.display_name, adventurer.class_title]
	row.check_box.toggled.connect(func(_pressed: bool) -> void: _refresh_setup())
	_content.add_child(row.check_box)

	var gear: HBoxContainer = HBoxContainer.new()
	_content.add_child(gear)
	row.main_option = _add_option(gear)
	row.off_option = _add_option(gear)
	row.armour_option = _add_option(gear)
	row.item_option = _add_option(gear)
	_fill_weapons(row)
	_fill_armour(row)
	_fill_items(row)

	var trinkets: HBoxContainer = HBoxContainer.new()
	_content.add_child(trinkets)

	for slot: AccessoryData.Slot in Loadout.ACCESSORY_SLOTS:
		_add_accessory_option(row, trinkets, slot)

	row.stats_label = Label.new()
	_content.add_child(row.stats_label)
	_rows.append(row)


func _fill_weapons(row: PartyRow) -> void:
	var class_title: String = row.adventurer.class_title
	row.off_choices.append(null)
	row.off_option.add_item("Empty off-hand")

	for weapon: WeaponData in _armoury_data.weapons:
		if _guild.armoury.get_count(weapon) <= 0:
			continue

		if weapon.main_hand_classes.has(class_title):
			row.main_choices.append(weapon)
			row.main_option.add_item(weapon.display_name)

		if weapon.off_hand_classes.has(class_title):
			row.off_choices.append(weapon)
			row.off_option.add_item(weapon.display_name)


func _fill_armour(row: PartyRow) -> void:
	row.armour_choices.append(null)
	row.armour_option.add_item("No armour")

	for armour: ArmourData in _armoury_data.armour:
		if _guild.armoury.get_count(armour) > 0 and armour.allowed_classes.has(row.adventurer.class_title):
			row.armour_choices.append(armour)
			row.armour_option.add_item(armour.display_name)


func _fill_items(row: PartyRow) -> void:
	row.item_choices.append(null)
	row.item_option.add_item("No item")

	for item: ItemData in _armoury_data.items:
		var left: int = _guild.armoury.get_count(item)

		if left > 0:
			row.item_choices.append(item)
			row.item_option.add_item("%s (%d left)" % [item.display_name, left])


func _add_accessory_option(
	row: PartyRow,
	parent: Control,
	slot: AccessoryData.Slot
) -> void:
	var option: OptionButton = _add_option(parent)
	var choices: Array = [null]
	option.add_item(SLOT_LABELS[slot])

	for accessory: AccessoryData in _guild.armoury.get_owned_accessories():
		if accessory.slot == slot:
			choices.append(accessory)
			option.add_item(accessory.display_name)

	row.accessory_options.append(option)
	row.accessory_choices.append(choices)


func _add_option(parent: Control) -> OptionButton:
	var option: OptionButton = OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.clip_text = true
	option.item_selected.connect(func(_index: int) -> void: _refresh_setup())
	parent.add_child(option)
	return option


func _make_loadout(row: PartyRow) -> Loadout:
	var main_hand: WeaponData = null

	if row.main_option.selected >= 0:
		main_hand = row.main_choices[row.main_option.selected]

	var accessories: Array[AccessoryData] = []

	for index: int in row.accessory_options.size():
		var choice: Variant = row.accessory_choices[index][row.accessory_options[index].selected]

		if choice != null:
			accessories.append(choice)

	return Loadout.new(
		row.adventurer,
		main_hand,
		row.off_choices[row.off_option.selected],
		row.armour_choices[row.armour_option.selected],
		accessories,
		row.item_choices[row.item_option.selected]
	)


func _get_party() -> Array[Loadout]:
	var party: Array[Loadout] = []

	for row: PartyRow in _rows:
		if row.check_box.button_pressed:
			party.append(_make_loadout(row))

	return party


func _refresh_setup() -> void:
	for row: PartyRow in _rows:
		var loadout: Loadout = _make_loadout(row)
		var two_handed: bool = loadout.main_hand != null and loadout.main_hand.two_handed

		if two_handed:
			row.off_option.select(0)
			loadout = _make_loadout(row)

		row.off_option.disabled = two_handed
		row.stats_label.text = "ATK %d | DEF %d | SPD %d" % [
			loadout.get_total_attack(),
			loadout.get_total_defence(),
			loadout.get_total_speed(),
		]

	var party: Array[Loadout] = _get_party()
	var problems: PackedStringArray = _guild.get_party_problems(party)
	_send_button.disabled = not problems.is_empty()
	_notes_label.text = " ".join(problems)


func _on_send_pressed() -> void:
	_send_button.disabled = true
	_session.dispatch(_quest, _get_party())


func _show_report(action: Dictionary, outcome: Dictionary) -> void:
	var result: QuestResult = outcome["result"]
	var payout: QuestPayout = outcome["payout"]
	_set_screen(func() -> void: pass)
	_add_label("Report: %s" % (outcome["quest"] as QuestData).display_name, 24)

	if _session.is_online():
		_add_label("Sent by: %s" % _session.get_player_name(action.get("player")))

	_add_label("Outcome: %s" % OUTCOME_NAMES[result.get_outcome()])
	_add_label(outcome["report"])

	if not result.injured.is_empty():
		_add_label("Injured, will sit out the next quest: %s" % _join_names(result.injured))

	if not result.dead.is_empty():
		_add_label("Lost: %s" % _join_names(result.dead))

	if not result.used_items.is_empty():
		var used: PackedStringArray = []

		for item: ItemData in result.used_items:
			used.append(item.display_name)

		_add_label("Supplies used: %s" % ", ".join(used))

	_add_payout_line("Quest pay: +%d gold", payout.pay)
	_add_payout_line("Loot: +%d gold", payout.loot_gold)
	_add_payout_line("Paid towards the debt: -%d gold", payout.debt_repaid)
	_add_payout_line("Wages: -%d gold", payout.wages_paid)
	_add_payout_line("Borrowed to cover wages: debt +%d gold, with interest", payout.debt_added)
	_add_label("Gold: %d to %d | Debt: %d / %d" % [
		outcome["gold_before"],
		_guild.ledger.gold,
		_guild.ledger.debt,
		_economy_rules.debt_limit,
	])
	_add_button("Continue", _on_report_closed)


func _add_payout_line(text: String, amount: int) -> void:
	if amount != 0:
		_add_label(text % amount)


func _on_report_closed() -> void:
	if _guild.is_over():
		_show_history()
	else:
		_show_board()


func _show_history() -> void:
	_set_screen(func() -> void: pass)
	_add_label("History of the guild", 24)
	_add_label(ReportWriter.write_game_over(_guild.get_game_over_reason(), _phrases, _ui_rng))
	_add_label("Final gold: %d | Debt: %d / %d" % [
		_guild.ledger.gold,
		_guild.ledger.debt,
		_economy_rules.debt_limit,
	])
	_add_label("Quests attempted: %d | Quests completed: %d" % [
		_guild.quests_attempted,
		_guild.quests_succeeded,
	])
	_add_label("The fallen: %s" % ("None" if _guild.dead.is_empty() else _join_names(_guild.dead)))
	_add_label("Most famous hero: %s" % _guild.get_most_famous_hero())

	if not _guild.worst_disaster.is_empty():
		_add_label("Worst disaster: %s" % _guild.worst_disaster)

	_add_button("Found a new guild", _session.found_new_guild)


func _set_screen(screen: Callable) -> void:
	_screen = screen
	_clear_screen()


func _add_session_status() -> void:
	if _session.is_online():
		if _session.get_player_count() < 2:
			_add_label("Hosting. Waiting for a second player to join at %s." % _get_addresses())
		elif multiplayer.is_server():
			_add_label("Your partner is here. You both run this guild.")
		else:
			_add_label("You've joined your partner's guild. You both run it.")

	if not _notice.is_empty():
		_add_label(_notice)
		_notice = ""


func _get_addresses() -> String:
	var addresses: PackedStringArray = []

	for address: String in IP.get_local_addresses():
		if address.count(".") == 3 and not address.begins_with("127."):
			addresses.append(address)

	return " or ".join(addresses) if not addresses.is_empty() else "this computer's address"


func _clear_screen() -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func _add_label(text: String, font_size: int = 0) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)

	_content.add_child(label)
	return label


func _add_button(text: String, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(on_pressed)
	_content.add_child(button)
	return button


func _join_names(adventurers: Array[AdventurerData]) -> String:
	var names: PackedStringArray = []

	for adventurer: AdventurerData in adventurers:
		names.append(adventurer.display_name)

	return ", ".join(names)
