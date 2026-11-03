extends Control

const OUTCOME_NAMES: Array[String] = ["Success", "Costly success", "Failure"]
const SLOT_LABELS: Array[String] = ["No back item", "No face item", "No ring", "No necklace"]


class PartyRow:
	var adventurer: AdventurerData
	var check_box: CheckBox
	var main_option: OptionButton
	var off_option: OptionButton
	var armour_option: OptionButton
	var stats_label: Label
	var main_choices: Array[WeaponData] = []
	var off_choices: Array[WeaponData] = []
	var armour_choices: Array[ArmourData] = []
	var item_option: OptionButton
	var item_choices: Array[ItemData] = []
	var accessory_options: Array[OptionButton] = []
	var accessory_choices: Array[Array] = []


var _campaign_rules: CampaignRulesData
var _armoury_data: ArmouryData
var _economy_rules: EconomyRulesData
var _encounter_rules: EncounterRulesData
var _phrases: ReportPhrasesData
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _guild: GuildState
var _quest: QuestData
var _rows: Array[PartyRow] = []
var _notes_label: Label
var _send_button: Button

@onready var _content: VBoxContainer = $Margin/Scroll/Content


func _ready() -> void:
	_campaign_rules = load("res://data/campaign_rules.tres") as CampaignRulesData
	_armoury_data = load("res://data/armoury.tres") as ArmouryData
	_economy_rules = load("res://data/economy_rules.tres") as EconomyRulesData
	_encounter_rules = load("res://data/encounter_rules.tres") as EncounterRulesData
	_phrases = load("res://data/report_phrases.tres") as ReportPhrasesData
	_rng.randomize()
	_start_guild()


func _start_guild() -> void:
	_guild = GuildState.new(_campaign_rules, _armoury_data, _economy_rules, _rng)
	_show_board()


func _show_board() -> void:
	_clear_screen()
	_add_label("Quest board", 24)
	_add_label("Gold: %d | Debt: %d | Wages due in %d quests" % [
		_guild.ledger.gold,
		_guild.ledger.debt,
		_guild.ledger.quests_until_wages,
	])
	_add_label("Fit for duty: %s" % _join_names(_guild.get_available()))

	if not _guild.resting.is_empty():
		_add_label("Injured, sitting out this quest: %s" % _join_names(_guild.resting))

	if not _guild.dead.is_empty():
		_add_label("Lost: %s" % _join_names(_guild.dead))

	_add_button("Buy supplies", _show_supplies)

	for entry: BoardEntry in _guild.board:
		_add_button(
			"%s | Danger %d of %d | Pays %d\n%s" % [
				entry.quest.display_name,
				entry.shown_danger,
				GuildState.MAX_DANGER,
				entry.quest.pay,
				entry.quest.briefing,
			],
			_on_quest_chosen.bind(entry.quest)
		)


func _show_supplies() -> void:
	_clear_screen()
	_add_label("Supplies", 24)
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
	_guild.buy_item(item)
	_show_supplies()


func _on_quest_chosen(quest: QuestData) -> void:
	_quest = quest
	_show_party_setup()


func _show_party_setup() -> void:
	_clear_screen()
	_rows.clear()
	_add_label("Party setup: %s" % _quest.display_name, 24)
	_add_label(_quest.briefing)
	_add_label("Tick up to 4 adventurers and equip them from the armoury.")

	for adventurer: AdventurerData in _guild.get_available():
		_add_party_row(adventurer)

	_notes_label = _add_label("")
	_send_button = _add_button("Send them off", _on_send_pressed)
	_add_button("Back to the board", _show_board)
	_refresh_setup()


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
	_add_accessory_option(row, trinkets, AccessoryData.Slot.BACK)
	_add_accessory_option(row, trinkets, AccessoryData.Slot.FACE)
	_add_accessory_option(row, trinkets, AccessoryData.Slot.RING)
	_add_accessory_option(row, trinkets, AccessoryData.Slot.RING)
	_add_accessory_option(row, trinkets, AccessoryData.Slot.NECKLACE)

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
	var problems: PackedStringArray = _get_party_problems(party)
	_send_button.disabled = not problems.is_empty()
	_notes_label.text = " ".join(problems)


func _get_party_problems(party: Array[Loadout]) -> PackedStringArray:
	var problems: PackedStringArray = []

	if party.is_empty():
		problems.append("Pick at least one adventurer.")
	elif party.size() > 4:
		problems.append("A party can have at most 4 adventurers.")

	for loadout: Loadout in party:
		problems.append_array(loadout.get_problems())

	problems.append_array(_guild.armoury.get_problems(party))
	return problems


func _on_send_pressed() -> void:
	var party: Array[Loadout] = _get_party()
	var gold_before: int = _guild.ledger.gold
	var simulator: EncounterSimulator = EncounterSimulator.new(
		party,
		_quest,
		_encounter_rules,
		_rng,
		_guild.armoury.get_owned_accessories()
	)
	var result: QuestResult = simulator.run()
	var pay: int = _guild.ledger.get_pay(_quest, result)
	_guild.finish_quest(_quest, party, result)
	_show_report(result, pay, gold_before)


func _show_report(result: QuestResult, pay: int, gold_before: int) -> void:
	_clear_screen()
	_add_label("Report: %s" % _quest.display_name, 24)
	_add_label("Outcome: %s | Pay: %d gold | Loot: %d gold" % [
		OUTCOME_NAMES[result.get_outcome()],
		pay,
		result.loot_gold,
	])
	_add_label(ReportWriter.write_report(result.events, _phrases, _rng))

	if not result.injured.is_empty():
		_add_label("Injured, will sit out the next quest: %s" % _join_names(result.injured))

	if not result.dead.is_empty():
		_add_label("Lost: %s" % _join_names(result.dead))

	if not result.used_items.is_empty():
		var used: PackedStringArray = []

		for item: ItemData in result.used_items:
			used.append(item.display_name)

		_add_label("Supplies used: %s" % ", ".join(used))

	_add_label("Gold: %d to %d | Debt: %d" % [gold_before, _guild.ledger.gold, _guild.ledger.debt])
	_add_button("Continue", _on_report_closed)


func _on_report_closed() -> void:
	if _guild.is_over():
		_show_history()
	else:
		_show_board()


func _show_history() -> void:
	_clear_screen()
	_add_label("History of the guild", 24)
	_add_label("Quests attempted: %d | Quests completed: %d" % [
		_guild.quests_attempted,
		_guild.quests_succeeded,
	])
	_add_label("The fallen: %s" % ("None" if _guild.dead.is_empty() else _join_names(_guild.dead)))
	_add_label("Most famous hero: %s" % _guild.get_most_famous_hero())

	if not _guild.worst_disaster.is_empty():
		_add_label("Worst disaster: %s" % _guild.worst_disaster)

	_add_button("Found a new guild", _start_guild)


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
