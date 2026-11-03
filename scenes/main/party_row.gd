class_name PartyRow
extends RefCounted

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
