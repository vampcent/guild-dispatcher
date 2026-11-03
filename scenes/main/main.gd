extends Control

const OUTCOME_NAMES: Array[String] = ["Success", "Costly success", "Failure"]
const SLOT_LABELS: Array[String] = ["No back item", "No face item", "No ring", "No necklace"]
const OUTCOME_STYLES: Array[StringName] = [&"GoodLabel", &"WarningLabel", &"BadLabel"]
const MAX_CONTENT_WIDTH: int = 960
const MIN_SIDE_MARGIN: int = 24
# Rank badge colours, from F to S.
const RANK_COLOURS: Array[Color] = [
	Color("#8a8178"),
	Color("#7fa65f"),
	Color("#5b9bc4"),
	Color("#9a7bd0"),
	Color("#d48f3b"),
	Color("#d0605a"),
	Color("#e6c25a"),
]


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
var _code_edit: LineEdit
var _rows: Array[PartyRow] = []
var _notes_label: Label
var _send_button: Button

@onready var _margin: MarginContainer = $Margin
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
	_session.online_status_changed.connect(_on_players_changed)
	resized.connect(_fit_width)
	_fit_width()
	_start_from_command_line()


# Keeps the text a readable width on wide windows.
func _fit_width() -> void:
	var side: int = maxi(MIN_SIDE_MARGIN, floori((size.x - MAX_CONTENT_WIDTH) / 2.0))
	_margin.add_theme_constant_override("margin_left", side)
	_margin.add_theme_constant_override("margin_right", side)


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
	_add_label("Guild Dispatcher", &"TitleLabel")
	_add_label("Run an adventurers' guild. Send parties out, then read what came back.", &"MutedLabel")

	if not message.is_empty():
		_add_warning(message)

	var start: VBoxContainer = _add_card()
	_add_label("Start a guild", &"SectionLabel", start)
	var buttons: HBoxContainer = _add_row(start)
	_add_button("Play alone", _session.play_alone, buttons, &"AccentButton")
	_add_button("Host a game for two (port %d)" % GuildSession.DEFAULT_PORT, _on_host_pressed, buttons)

	var join: VBoxContainer = _add_card()
	_add_label("Join a friend", &"SectionLabel", join)
	_add_label("Enter the join code shown on your friend's quest board.", &"MutedLabel", join)
	var code_row: HBoxContainer = _add_row(join)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "Join code, for example K7F2-QX9M"
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_edit.text_submitted.connect(func(code: String) -> void: _join.call_deferred(code))
	code_row.add_child(_code_edit)
	_add_button("Join", func() -> void: _join(_code_edit.text), code_row)


func _on_host_pressed() -> void:
	var error: Error = _session.host()

	if error != OK:
		_show_lobby("Couldn't host on port %d (%s)." % [GuildSession.DEFAULT_PORT, error_string(error)])


# Takes a join code, or a plain address such as 127.0.0.1 for testing on one computer.
func _join(code: String) -> void:
	code = code.strip_edges()
	var address: String = code if code.count(".") == 3 else JoinCode.decode(code)

	if code.is_empty():
		_show_lobby("Enter your partner's join code.")
		return

	if address.is_empty():
		_show_lobby("%s isn't a join code. Check it with your partner." % code)
		_code_edit.text = code
		return

	var error: Error = _session.join(address)

	if error != OK:
		_show_lobby("Couldn't connect with that join code (%s)." % error_string(error))
		_code_edit.text = code
		return

	_set_screen(_join.bind(code))
	_add_label("Joining your partner's guild...", &"TitleLabel")
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
		return "%s bought %s." % [who, load(action["equipment"]).get("display_name")]

	return "%s paid to scout %s." % [who, (load(action["quest"]) as QuestData).display_name]


func _on_players_changed() -> void:
	if _session.guild != null and _screen.is_valid():
		_screen.call()


func _show_board() -> void:
	_set_screen(_show_board)
	_add_label("Quest board", &"TitleLabel")
	_add_session_status()

	var status: VBoxContainer = _add_card()
	var top: HBoxContainer = _add_row(status)
	_add_label(_get_guild_rank_text(), &"HeadingLabel", top)
	_add_button("Visit the market", _show_market, top)
	_add_label("Gold: %d    Debt: %d / %d    Wages due in %s" % [
		_guild.ledger.gold,
		_guild.ledger.debt,
		_economy_rules.debt_limit,
		_count_quests(_guild.ledger.quests_until_wages),
	], &"", status)
	_add_label("Fit for duty: %s" % _join_names(_guild.get_available()), &"MutedLabel", status)

	if not _guild.resting.is_empty():
		_add_label("Injured, sitting out this quest: %s" % _join_names(_guild.resting), &"WarningLabel", status)

	if not _guild.dead.is_empty():
		_add_label("Lost: %s" % _join_names(_guild.dead), &"BadLabel", status)

	if not _guild.expired_quests.is_empty():
		_add_label(
			"Contracts lost while you were busy: %s" % ", ".join(_guild.expired_quests),
			&"MutedLabel",
			status
		)

	for warning: String in _guild.ledger.get_warnings(_guild.get_living_count()):
		_add_warning(warning)

	_add_label("Quests on offer", &"SectionLabel")

	for entry: BoardEntry in _guild.board:
		_add_quest_card(entry)


func _add_quest_card(entry: BoardEntry) -> void:
	var card: VBoxContainer = _add_card()
	var header: HBoxContainer = _add_row(card)
	_add_label(entry.quest.display_name, &"HeadingLabel", header)
	_add_rank_badge(entry.shown_rank, header)
	_add_tag("%d gold" % entry.quest.pay, &"SectionLabel", header)
	_add_label(
		"Recommended party strength %d" % _guild.get_recommended_strength(entry.shown_rank),
		&"MutedLabel",
		card
	)
	_add_label(entry.quest.briefing, &"", card)

	if entry.passes > 0:
		_add_label(
			"The situation is getting worse. Expires in %s." % _count_quests(_guild.get_passes_left(entry)),
			&"WarningLabel",
			card
		)

	if entry.scouted:
		_add_label(_get_scout_text(entry), &"GoodLabel", card)

	var actions: HBoxContainer = _add_row(card)
	_add_button("Choose a party", _on_quest_chosen.bind(entry.quest), actions, &"AccentButton")

	if not entry.scouted:
		var scout_button: Button = _add_button(
			"Scout for %d gold" % _guild.get_scout_cost(entry),
			_on_scout_pressed.bind(entry),
			actions
		)
		scout_button.disabled = not _guild.can_scout(entry)


func _get_guild_rank_text() -> String:
	var text: String = "Guild rank %s | Reputation %d" % [
		QuestData.get_rank_name(_guild.get_guild_rank()),
		_guild.reputation,
	]

	if _guild.get_next_rank_reputation() >= 0:
		text += " (rank %s at %d)" % [
			QuestData.get_rank_name(_guild.get_guild_rank() + 1),
			_guild.get_next_rank_reputation(),
		]

	return text


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

	return "Scout's report: Rank %s confirmed. %s" % [QuestData.get_rank_name(report.true_rank), advice]


func _show_market() -> void:
	_set_screen(_show_market)
	_add_label("Market", &"TitleLabel")
	_add_session_status()
	var top: HBoxContainer = _add_row()
	_add_label("Gold: %d" % _guild.ledger.gold, &"HeadingLabel", top)
	_add_button("Back to the board", _show_board, top)
	_add_market_section("Items", _armoury_data.items)
	_add_market_section("Weapons", _armoury_data.weapons)
	_add_market_section("Armour", _armoury_data.armour)


func _add_market_section(title: String, stock: Array) -> void:
	var card: VBoxContainer = _add_card()
	_add_label(title, &"SectionLabel", card)

	for equipment: Resource in stock:
		var price: int = equipment.get("price")
		var row: HBoxContainer = _add_row(card)
		_add_label(equipment.get("display_name"), &"", row)
		_add_tag("In the armoury: %d" % _guild.armoury.get_count(equipment), &"MutedLabel", row)
		var button: Button = _add_button(
			"Buy for %d gold" % price, _on_buy_pressed.bind(equipment), row
		)
		button.custom_minimum_size.x = 170
		button.disabled = not _guild.ledger.can_afford(price)


func _on_buy_pressed(equipment: Resource) -> void:
	_session.buy_equipment(equipment)


func _on_quest_chosen(quest: QuestData) -> void:
	_quest = quest
	_show_party_setup()


func _show_party_setup() -> void:
	_set_screen(_refresh_party_setup)
	_rows.clear()
	_add_label("Party setup", &"TitleLabel")
	var entry: BoardEntry = _guild.find_entry(_quest)
	var intro: VBoxContainer = _add_card()
	var header: HBoxContainer = _add_row(intro)
	_add_label(_quest.display_name, &"HeadingLabel", header)

	if entry != null:
		_add_rank_badge(entry.shown_rank, header)

	_add_tag("%d gold" % _quest.pay, &"SectionLabel", header)
	_add_label(_quest.briefing, &"", intro)

	if entry != null and entry.scouted:
		_add_label(_get_scout_text(entry), &"GoodLabel", intro)

	_add_label(
		"Tick up to %d adventurers and equip them from the armoury" % _campaign_rules.max_party_size,
		&"SectionLabel"
	)

	for adventurer: AdventurerData in _guild.get_available():
		_add_party_row(adventurer)

	var footer: VBoxContainer = _add_card()
	_notes_label = _add_label("", &"MutedLabel", footer)
	var actions: HBoxContainer = _add_row(footer)
	_send_button = _add_button("Send them off", _on_send_pressed, actions, &"AccentButton")
	_add_button("Back to the board", _show_board, actions)
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
	var card: VBoxContainer = _add_card()
	var header: HBoxContainer = _add_row(card)
	row.adventurer = adventurer
	row.check_box = CheckBox.new()
	row.check_box.text = "%s (%s)" % [adventurer.display_name, adventurer.class_title]
	row.check_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.check_box.toggled.connect(func(_pressed: bool) -> void: _refresh_setup())
	header.add_child(row.check_box)
	row.stats_label = _add_tag("", &"MutedLabel", header)

	var gear: HBoxContainer = _add_row(card, 6)
	row.main_option = _add_option(gear)
	row.off_option = _add_option(gear)
	row.armour_option = _add_option(gear)
	row.item_option = _add_option(gear)
	_fill_weapons(row)
	_fill_armour(row)
	_fill_items(row)

	var trinkets: HBoxContainer = _add_row(card, 6)

	for slot: AccessoryData.Slot in Loadout.ACCESSORY_SLOTS:
		_add_accessory_option(row, trinkets, slot)

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

	row.main_choices.append(null)
	row.main_option.add_item("Unarmed")


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
	var main_hand: WeaponData = row.main_choices[row.main_option.selected]
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
		row.stats_label.text = "ATK %d | DEF %d | SPD %d%s" % [
			loadout.get_total_attack(),
			loadout.get_total_defence(),
			loadout.get_total_speed(),
			" | Unarmed: fights bare-handed" if loadout.is_unarmed() else "",
		]

	var party: Array[Loadout] = _get_party()
	var problems: PackedStringArray = _guild.get_party_problems(party)
	var notes: PackedStringArray = []
	_send_button.disabled = not problems.is_empty()

	var entry: BoardEntry = _guild.find_entry(_quest)

	if not party.is_empty() and entry != null:
		notes.append("Party strength %d, recommended %d." % [
			Loadout.get_party_strength(party),
			_guild.get_recommended_strength(entry.shown_rank),
		])

		if _guild.is_party_too_weak(party, entry):
			notes.append("Warning: this party is weaker than recommended.")

	notes.append_array(problems)
	_notes_label.text = " ".join(notes)

	if not problems.is_empty():
		_notes_label.theme_type_variation = &"BadLabel"
	elif not party.is_empty() and entry != null and _guild.is_party_too_weak(party, entry):
		_notes_label.theme_type_variation = &"WarningLabel"
	else:
		_notes_label.theme_type_variation = &"MutedLabel"


func _on_send_pressed() -> void:
	_send_button.disabled = true
	_session.dispatch(_quest, _get_party())


func _show_report(action: Dictionary, outcome: Dictionary) -> void:
	var result: QuestResult = outcome["result"]
	var payout: QuestPayout = outcome["payout"]
	_set_screen(func() -> void: pass)
	_add_label("Report: %s" % (outcome["quest"] as QuestData).display_name, &"TitleLabel")

	if _session.is_online():
		_add_label("Sent by: %s" % _session.get_player_name(action.get("player")), &"MutedLabel")

	_add_label(
		"Outcome: %s" % OUTCOME_NAMES[result.get_outcome()],
		OUTCOME_STYLES[result.get_outcome()]
	).add_theme_font_size_override("font_size", 20)

	if outcome["ranked_up"]:
		_add_label("The guild has risen to rank %s! Harder quests will reach the board." % (
			QuestData.get_rank_name(_guild.get_guild_rank())
		), &"GoodLabel")

	var report: VBoxContainer = _add_card(&"ReportPanel")
	_add_label(outcome["report"], &"", report)

	if not result.injured.is_empty():
		_add_label("Injured, will sit out the next quest: %s" % _join_names(result.injured), &"WarningLabel")

	if not result.dead.is_empty():
		_add_label("Lost: %s" % _join_names(result.dead), &"BadLabel")

	if not result.used_items.is_empty():
		var used: PackedStringArray = []

		for item: ItemData in result.used_items:
			used.append(item.display_name)

		_add_label("Supplies used: %s" % ", ".join(used), &"MutedLabel")

	var ledger: VBoxContainer = _add_card()
	_add_label("Ledger", &"SectionLabel", ledger)
	_add_payout_line(ledger, "Quest pay: +%d gold", payout.pay)
	_add_payout_line(ledger, "Loot: +%d gold", payout.loot_gold)
	_add_payout_line(ledger, "Paid towards the debt: -%d gold", payout.debt_repaid)
	_add_payout_line(ledger, "Wages: -%d gold", payout.wages_paid)
	_add_payout_line(ledger, "Borrowed to cover wages: debt +%d gold, with interest", payout.debt_added)
	_add_label("Gold: %d to %d    Debt: %d / %d" % [
		outcome["gold_before"],
		_guild.ledger.gold,
		_guild.ledger.debt,
		_economy_rules.debt_limit,
	], &"HeadingLabel", ledger)
	_add_button("Continue", _on_report_closed, null, &"AccentButton")


func _add_payout_line(parent: Control, text: String, amount: int) -> void:
	if amount != 0:
		_add_label(text % amount, &"", parent)


func _on_report_closed() -> void:
	if _guild.is_over():
		_show_history()
	else:
		_show_board()


func _show_history() -> void:
	_set_screen(func() -> void: pass)
	_add_label("History of the guild", &"TitleLabel")
	var ending: VBoxContainer = _add_card(&"ReportPanel")
	_add_label(ReportWriter.write_game_over(_guild.get_game_over_reason(), _phrases, _ui_rng), &"", ending)

	var record: VBoxContainer = _add_card()
	_add_label("Final gold: %d    Debt: %d / %d" % [
		_guild.ledger.gold,
		_guild.ledger.debt,
		_economy_rules.debt_limit,
	], &"HeadingLabel", record)
	_add_label("Quests attempted: %d    Quests completed: %d    Guild rank reached: %s" % [
		_guild.quests_attempted,
		_guild.quests_succeeded,
		QuestData.get_rank_name(_guild.get_guild_rank()),
	], &"", record)
	_add_label(
		"The fallen: %s" % ("None" if _guild.dead.is_empty() else _join_names(_guild.dead)),
		&"BadLabel" if not _guild.dead.is_empty() else &"",
		record
	)
	_add_label("Most famous hero: %s" % _guild.get_most_famous_hero(), &"", record)

	if not _guild.worst_disaster.is_empty():
		_add_label("Worst disaster: %s" % _guild.worst_disaster, &"MutedLabel", record)

	_add_button("Found a new guild", _session.found_new_guild, null, &"AccentButton")


func _set_screen(screen: Callable) -> void:
	_screen = screen
	_clear_screen()


func _add_session_status() -> void:
	if _session.is_online():
		if _session.get_player_count() < 2:
			var hosting: VBoxContainer = _add_card()
			_add_label(_get_hosting_text(), &"", hosting)
		elif multiplayer.is_server():
			_add_label("Your partner is here. You both run this guild.", &"GoodLabel")
		else:
			_add_label("You've joined your partner's guild. You both run it.", &"GoodLabel")

	if not _notice.is_empty():
		_add_warning(_notice)
		_notice = ""


func _get_hosting_text() -> String:
	var lines: PackedStringArray = ["Hosting. Your partner enters a join code on their start screen."]
	var address: String = JoinCode.pick_local_address(IP.get_local_addresses())

	if not _session.online_code.is_empty():
		lines.append("Online join code: %s" % _session.online_code)
	elif _session.online_problem.is_empty():
		lines.append("Opening your router for online play...")
	else:
		lines.append(
			"Online play isn't available: %s. To play online anyway, forward UDP port %d on"
			% [_session.online_problem, GuildSession.DEFAULT_PORT]
			+ " your router and give your partner your public IP address instead of a code."
		)

	if not address.is_empty():
		lines.append("Same network join code: %s" % JoinCode.encode(address))

	return "\n".join(lines)


func _clear_screen() -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func _add_label(text: String, variation: StringName = &"", parent: Control = null) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(parent if parent != null else _content).add_child(label)
	return label


# A short label that keeps its own width, for use beside others in a row.
func _add_tag(text: String, variation: StringName, parent: Control) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(label)
	return label


func _add_rank_badge(rank: int, parent: Control) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = RANK_COLOURS[rank]
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	var badge: Label = _add_tag("Rank %s" % QuestData.get_rank_name(rank), &"", parent)
	badge.add_theme_stylebox_override("normal", style)
	badge.add_theme_color_override("font_color", Color("#1f1b17"))


func _add_card(variation: StringName = &"CardPanel", parent: Control = null) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = variation
	(parent if parent != null else _content).add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return box


func _add_row(parent: Control = null, separation: int = 10) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	(parent if parent != null else _content).add_child(row)
	return row


func _add_warning(text: String) -> void:
	var panel: VBoxContainer = _add_card(&"WarningPanel")
	_add_label(text, &"WarningLabel", panel)


func _add_button(
	text: String,
	on_pressed: Callable,
	parent: Control = null,
	variation: StringName = &""
) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(on_pressed)
	(parent if parent != null else _content).add_child(button)
	return button


func _count_quests(count: int) -> String:
	return "1 quest" if count == 1 else "%d quests" % count


func _join_names(adventurers: Array[AdventurerData]) -> String:
	var names: PackedStringArray = []

	for adventurer: AdventurerData in adventurers:
		names.append(adventurer.display_name)

	return ", ".join(names)
