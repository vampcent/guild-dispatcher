extends TestCase


func _ready() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var rules: CampaignRulesData = load("res://data/rules/campaign_rules.tres") as CampaignRulesData
	var guild: GuildState = GuildState.new(
		rules,
		load("res://data/equipment/armoury.tres") as ArmouryData,
		load("res://data/rules/economy_rules.tres") as EconomyRulesData,
		rng
	)
	var tracked: BoardEntry = guild.board[0]
	var base_health: int = tracked.base_quest.enemy_health
	var health: int = base_health
	var pay: int = tracked.quest.pay
	print("Tracking %s | Health %d | Pay %d" % [
		tracked.base_quest.display_name,
		base_health,
		tracked.quest.pay,
	])

	for turn: int in range(1, 4):
		var other: QuestData = null

		for entry: BoardEntry in guild.board:
			if entry != tracked:
				other = entry.quest
				break

		guild.advance_board(other)

		if guild.board.has(tracked):
			print("Pass %d | Health %d | Pay %d | Expires in %d" % [
				turn,
				tracked.quest.enemy_health,
				tracked.quest.pay,
				guild.get_passes_left(tracked),
			])
			check(tracked.quest.enemy_health > health, "Pass %d makes the quest harder" % turn)
			check(tracked.quest.pay > pay, "Pass %d raises the quest's pay" % turn)
			check_equal(
				guild.get_passes_left(tracked),
				rules.expire_after_passes - turn,
				"Pass %d counts down to expiry" % turn
			)
			health = tracked.quest.enemy_health
			pay = tracked.quest.pay
		else:
			print("Pass %d | Expired: %s" % [turn, ", ".join(guild.expired_quests)])
			check(
				guild.expired_quests.has(tracked.quest.display_name),
				"Pass %d reports the expired quest" % turn
			)

		check_equal(
			guild.board.has(tracked),
			turn < rules.expire_after_passes,
			"Pass %d keeps the quest only until it expires" % turn
		)

	print("Board size after expiry: %d" % guild.board.size())
	check_equal(guild.board.size(), rules.board_size, "The board refills after a quest expires")
	print("Original quest unchanged: %s" % (tracked.base_quest.enemy_health == base_health))
	check_equal(
		tracked.base_quest.enemy_health,
		base_health,
		"Worsening a quest leaves the original unchanged"
	)
	finish()
