extends Node


func _ready() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var guild: GuildState = GuildState.new(
		load("res://data/rules/campaign_rules.tres") as CampaignRulesData,
		load("res://data/equipment/armoury.tres") as ArmouryData,
		load("res://data/rules/economy_rules.tres") as EconomyRulesData,
		rng
	)
	var tracked: BoardEntry = guild.board[0]
	var base_health: int = tracked.base_quest.enemy_health
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
		else:
			print("Pass %d | Expired: %s" % [turn, ", ".join(guild.expired_quests)])

	print("Board size after expiry: %d" % guild.board.size())
	print("Original quest unchanged: %s" % (tracked.base_quest.enemy_health == base_health))
