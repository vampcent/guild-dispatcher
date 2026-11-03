class_name EncounterSimulator
extends RefCounted

var _party: Array[AdventurerData] = []
var _loadouts: Dictionary[AdventurerData, Loadout] = {}
var _quest: QuestData
var _rules: EncounterRulesData
var _rng: RandomNumberGenerator
var _result: QuestResult = QuestResult.new()
var _wounds: Dictionary[AdventurerData, int] = {}
var _enemy_health: int = 0
var _ability_uses: Dictionary[String, int] = {}
var _owned_accessories: Array[AccessoryData] = []
var _fireballs_cast: int = 0
var _used_accessories: Array[AccessoryData] = []
var _spent_item_holders: Array[AdventurerData] = []


func _init(
	party: Array[Loadout],
	quest: QuestData,
	rules: EncounterRulesData,
	rng: RandomNumberGenerator,
	owned_accessories: Array[AccessoryData] = []
) -> void:
	_owned_accessories = owned_accessories

	for loadout: Loadout in party:
		_party.append(loadout.adventurer)
		_loadouts[loadout.adventurer] = loadout

	_quest = quest
	_rules = rules
	_rng = rng


func run() -> QuestResult:
	_enemy_health = _quest.enemy_health
	_record(QuestEvent.Type.QUEST_STARTED, "", "", _quest.display_name)
	_run_approach()
	_use_quest_items()

	for round_number: int in range(1, _quest.round_count + 1):
		if _get_living().is_empty():
			break

		_result.rounds_fought = round_number
		_record(QuestEvent.Type.ROUND_STARTED, "", "", "", round_number)
		_run_enemy_phase()

		if _get_living().is_empty():
			break

		_run_recovery_phase()
		_run_party_phase()

		if _enemy_health <= 0:
			_record(QuestEvent.Type.ENEMIES_DEFEATED, "", "", _quest.enemy_name)
			break

	_result.succeeded = _enemy_health <= 0 and not _get_living().is_empty()

	if _result.succeeded:
		_run_loot()

	_record(
		QuestEvent.Type.QUEST_SUCCEEDED if _result.succeeded else QuestEvent.Type.QUEST_FAILED
	)
	return _result


func _run_loot() -> void:
	var chance: int = _quest.loot_chance
	var thief: AdventurerData = null
	var fingers: AbilityData = null

	for adventurer: AdventurerData in _get_living():
		fingers = _get_ability(adventurer, AbilityData.Effect.LIGHT_FINGERS)

		if fingers != null:
			thief = adventurer
			chance += fingers.power
			_spend(thief, fingers)
			break

	if chance <= 0:
		return

	for _loot_roll: int in _quest.loot_rolls:
		if not _roll(chance):
			continue

		var accessory: AccessoryData = _pick_loot()

		if accessory == null:
			continue

		if _fireballs_cast > 0 and _roll(_rules.fireball_loot_burn_chance):
			_record(QuestEvent.Type.LOOT_BURNED, "", "", accessory.display_name)
		elif thief != null and _roll(fingers.chance):
			_record(QuestEvent.Type.LOOT_POCKETED, thief.display_name)
		else:
			_result.found_accessories.append(accessory)
			_record(QuestEvent.Type.LOOT_FOUND, "", "", accessory.display_name)


func _pick_loot() -> AccessoryData:
	var total_weight: int = 0
	var options: Array[AccessoryData] = []

	for accessory: AccessoryData in _quest.loot_table:
		if _can_drop(accessory):
			options.append(accessory)
			total_weight += _rules.rarity_weights[accessory.rarity]

	if total_weight <= 0:
		return null

	var pick: int = _rng.randi_range(1, total_weight)

	for accessory: AccessoryData in options:
		pick -= _rules.rarity_weights[accessory.rarity]

		if pick <= 0:
			return accessory

	return null


func _can_drop(accessory: AccessoryData) -> bool:
	if not accessory.is_one_of_a_kind():
		return true

	return (
		not _owned_accessories.has(accessory)
		and not _result.found_accessories.has(accessory)
	)


func _run_approach() -> void:
	if _quest.trap_chance <= 0 or not _roll(_quest.trap_chance):
		return

	for adventurer: AdventurerData in _party:
		var ability: AbilityData = _get_ability(adventurer, AbilityData.Effect.KEEN_EYE)

		if ability == null:
			continue

		_spend(adventurer, ability)

		if _roll(ability.chance):
			_record(QuestEvent.Type.TRAP_SPOTTED, adventurer.display_name, "", ability.display_name)
			return

	var victim: AdventurerData = _party[_rng.randi_range(0, _party.size() - 1)]
	_record(QuestEvent.Type.TRAP_SPRUNG, "", victim.display_name)
	_wound(victim)


func _use_quest_items() -> void:
	for tag: String in _quest.quest_tags:
		for adventurer: AdventurerData in _get_living():
			var item: ItemData = _loadouts[adventurer].item

			if item == null or _spent_item_holders.has(adventurer):
				continue

			if item.quest_tags.has(tag):
				_enemy_health -= _rules.item_damage
				_spend_item(adventurer, item)
				break


func _spend_item(adventurer: AdventurerData, item: ItemData) -> void:
	_spent_item_holders.append(adventurer)
	_result.used_items.append(item)
	var line: String = item.report_line.format({"actor": adventurer.display_name})
	_record(QuestEvent.Type.ITEM_USED, adventurer.display_name, "", line)


func _try_item_heal(adventurer: AdventurerData) -> bool:
	var item: ItemData = _loadouts[adventurer].item

	if item == null or not item.heals_wound or _spent_item_holders.has(adventurer):
		return false

	_spend_item(adventurer, item)
	_clear_wound(adventurer)
	return true


func _run_recovery_phase() -> void:
	for adventurer: AdventurerData in _get_living():
		if _wounds.get(adventurer, 0) == 0:
			continue

		if _try_item_heal(adventurer):
			continue

		var ability: AbilityData = _get_ability(adventurer, AbilityData.Effect.SECOND_WIND)

		if ability != null:
			_spend(adventurer, ability)
			_clear_wound(adventurer)
			_record(
				QuestEvent.Type.SECOND_WIND_USED,
				adventurer.display_name,
				"",
				ability.display_name
			)


func _run_enemy_phase() -> void:
	for _attack_index: int in _quest.enemy_attacks_per_round:
		var living: Array[AdventurerData] = _get_living()

		if living.is_empty():
			return

		var target: AdventurerData = living[_rng.randi_range(0, living.size() - 1)]

		if _try_ward(target):
			continue

		if _try_dodge(target):
			continue

		if _roll(_get_enemy_hit_chance(target)):
			_resolve_enemy_hit(target)
		else:
			_record(QuestEvent.Type.ENEMY_ATTACK_MISSED, "", target.display_name, _quest.enemy_name)


func _try_ward(target: AdventurerData) -> bool:
	var accessory: AccessoryData = _get_special(
		target,
		AccessoryData.SpecialEffect.WARD_FIRST_ATTACK
	)

	if accessory == null:
		return false

	_use_special(target, accessory)
	return true


func _get_first_strike_bonus(adventurer: AdventurerData) -> int:
	var accessory: AccessoryData = _get_special(
		adventurer,
		AccessoryData.SpecialEffect.FIRST_STRIKE
	)

	if accessory == null:
		return 0

	_use_special(adventurer, accessory)
	return accessory.special_power


func _get_special(
	adventurer: AdventurerData,
	effect: AccessoryData.SpecialEffect
) -> AccessoryData:
	for accessory: AccessoryData in _loadouts[adventurer].accessories:
		if accessory.special_effect != effect or _used_accessories.has(accessory):
			continue
		if accessory.special_tag.is_empty() or _quest.quest_tags.has(accessory.special_tag):
			return accessory

	return null


func _use_special(adventurer: AdventurerData, accessory: AccessoryData) -> void:
	_used_accessories.append(accessory)
	var line: String = accessory.report_line.format({
		"actor": adventurer.display_name,
		"enemies": _quest.enemy_name,
	})
	_record(QuestEvent.Type.ACCESSORY_TRIGGERED, adventurer.display_name, "", line)


func _try_dodge(target: AdventurerData) -> bool:
	var dodge_chance: int = _loadouts[target].get_total_speed() * _rules.dodge_per_speed

	if dodge_chance <= 0 or not _roll(dodge_chance):
		return false

	_record(QuestEvent.Type.ATTACK_DODGED, "", target.display_name, _quest.enemy_name)
	return true


func _get_enemy_hit_chance(target: AdventurerData) -> int:
	return (
		_rules.enemy_hit_base
		+ _quest.enemy_power * _rules.enemy_hit_per_power
		- _loadouts[target].get_total_defence() * _rules.enemy_hit_per_defence
	)


func _resolve_enemy_hit(target: AdventurerData) -> void:
	for adventurer: AdventurerData in _get_living():
		if adventurer == target:
			continue

		var ability: AbilityData = _get_ability(adventurer, AbilityData.Effect.HOLD_THE_LINE)

		if ability != null:
			_protect(adventurer, target, ability)
			return

	_wound(target)


func _protect(
	protector: AdventurerData,
	target: AdventurerData,
	ability: AbilityData
) -> void:
	_spend(protector, ability)
	_record(
		QuestEvent.Type.ABILITY_USED,
		protector.display_name,
		target.display_name,
		ability.display_name
	)

	if _try_dodge(protector):
		return

	if _roll(_get_enemy_hit_chance(protector)):
		_wound(protector)
	else:
		_record(QuestEvent.Type.BLOW_PARRIED, protector.display_name, target.display_name)


func _get_ability(adventurer: AdventurerData, effect: AbilityData.Effect) -> AbilityData:
	for ability: AbilityData in _rules.abilities:
		if ability.effect != effect or not _owns(adventurer, ability):
			continue
		if _ability_uses.get(_get_use_key(adventurer, ability), 0) < ability.uses_per_quest:
			return ability

	return null


func _owns(adventurer: AdventurerData, ability: AbilityData) -> bool:
	return (
		adventurer.class_title == ability.class_title
		or adventurer.subclass_title == ability.subclass_title
	)


func _spend(adventurer: AdventurerData, ability: AbilityData) -> void:
	var key: String = _get_use_key(adventurer, ability)
	_ability_uses[key] = _ability_uses.get(key, 0) + 1


func _get_use_key(adventurer: AdventurerData, ability: AbilityData) -> String:
	return "%s:%s" % [adventurer.display_name, ability.display_name]


func _run_party_phase() -> void:
	var order: Array[AdventurerData] = _get_living()

	for index: int in range(order.size() - 1, 0, -1):
		var swap_index: int = _rng.randi_range(0, index)
		var held: AdventurerData = order[index]
		order[index] = order[swap_index]
		order[swap_index] = held

	for adventurer: AdventurerData in order:
		if _result.dead.has(adventurer):
			continue

		if _try_heal(adventurer):
			continue

		var bonus_damage: int = (
			_get_spell_bonus(adventurer)
			+ _get_rage_bonus(adventurer)
			+ _get_banish_bonus(adventurer)
		)

		if _result.dead.has(adventurer) or _get_living().is_empty():
			continue

		var loadout: Loadout = _loadouts[adventurer]
		var hit_chance: int = _rules.hit_base + loadout.get_total_attack() * _rules.hit_per_attack

		for shot: int in loadout.get_shots_per_round():
			var damage: int = loadout.get_shot_damage() + (bonus_damage if shot == 0 else 0)

			if _roll(hit_chance):
				damage += _get_first_strike_bonus(adventurer)
				_enemy_health -= damage
				_record(
					QuestEvent.Type.ADVENTURER_HIT,
					adventurer.display_name,
					"",
					_quest.enemy_name,
					damage
				)
			else:
				_record(
					QuestEvent.Type.ADVENTURER_MISSED,
					adventurer.display_name,
					"",
					_quest.enemy_name
				)

			if _enemy_health <= 0:
				return


func _try_heal(healer: AdventurerData) -> bool:
	var ability: AbilityData = _get_ability(healer, AbilityData.Effect.HEALING_PRAYERS)

	if ability == null:
		return false

	for adventurer: AdventurerData in _get_living():
		if _wounds.get(adventurer, 0) > 0:
			_spend(healer, ability)
			_clear_wound(adventurer)
			_record(
				QuestEvent.Type.WOUND_RECOVERED,
				healer.display_name,
				adventurer.display_name,
				ability.display_name
			)
			return true

	return false


func _get_spell_bonus(adventurer: AdventurerData) -> int:
	var ability: AbilityData = _get_ability(adventurer, AbilityData.Effect.SPELL_SLOTS)

	if ability == null:
		return 0

	_spend(adventurer, ability)
	_record(QuestEvent.Type.SPELL_CAST, adventurer.display_name, "", ability.display_name)
	return ability.power + _get_fireball_bonus(adventurer)


func _get_fireball_bonus(caster: AdventurerData) -> int:
	var ability: AbilityData = _get_ability(caster, AbilityData.Effect.FIREBALL)

	if ability == null:
		return 0

	_trigger(caster, ability)
	_fireballs_cast += 1

	if _roll(ability.chance):
		var allies: Array[AdventurerData] = _get_living()
		allies.erase(caster)

		if not allies.is_empty():
			var ally: AdventurerData = allies[_rng.randi_range(0, allies.size() - 1)]
			_record(QuestEvent.Type.COLLATERAL_HIT, caster.display_name, ally.display_name)
			_wound(ally)

	return ability.power


func _get_rage_bonus(adventurer: AdventurerData) -> int:
	if _wounds.get(adventurer, 0) == 0:
		return 0

	var ability: AbilityData = _get_ability(adventurer, AbilityData.Effect.RAGE)

	if ability == null:
		return 0

	_trigger(adventurer, ability)
	return ability.power


func _get_banish_bonus(adventurer: AdventurerData) -> int:
	var ability: AbilityData = _get_ability(adventurer, AbilityData.Effect.BANISH)

	if ability == null or not _quest.quest_tags.has(ability.required_tag):
		return 0

	_trigger(adventurer, ability)
	return ability.power


func _trigger(adventurer: AdventurerData, ability: AbilityData) -> void:
	_spend(adventurer, ability)
	var line: String = ability.report_line.format({
		"actor": adventurer.display_name,
		"enemies": _quest.enemy_name,
	})
	_record(QuestEvent.Type.ABILITY_TRIGGERED, adventurer.display_name, "", line)


func _clear_wound(adventurer: AdventurerData) -> void:
	_wounds[adventurer] = maxi(_wounds.get(adventurer, 0) - 1, 0)

	if _wounds[adventurer] == 0:
		_result.injured.erase(adventurer)


func _wound(adventurer: AdventurerData) -> void:
	if _wounds.get(adventurer, 0) + 1 >= _rules.wounds_to_die:
		var saving: AccessoryData = _get_special(
			adventurer,
			AccessoryData.SpecialEffect.CHEAT_DEATH
		)

		if saving != null:
			_use_special(adventurer, saving)
			return

	_wounds[adventurer] = _wounds.get(adventurer, 0) + 1

	if _wounds[adventurer] >= _rules.wounds_to_die:
		_result.injured.erase(adventurer)
		_result.dead.append(adventurer)
		_record(QuestEvent.Type.ADVENTURER_DIED, "", adventurer.display_name, _quest.enemy_name)
	else:
		_result.injured.append(adventurer)
		_record(QuestEvent.Type.ADVENTURER_WOUNDED, "", adventurer.display_name, _quest.enemy_name)


func _get_living() -> Array[AdventurerData]:
	var living: Array[AdventurerData] = []

	for adventurer: AdventurerData in _party:
		if not _result.dead.has(adventurer):
			living.append(adventurer)

	return living


func _roll(chance: int) -> bool:
	var clamped: int = clampi(chance, _rules.min_hit_chance, _rules.max_hit_chance)
	return _rng.randi_range(1, 100) <= clamped


func _record(
	type: QuestEvent.Type,
	actor: String = "",
	target: String = "",
	detail: String = "",
	amount: int = 0
) -> void:
	_result.events.append(QuestEvent.new(type, actor, target, detail, amount))
