# Guild rank

Status: decided (GD-54). Unlocking quests by guild rank is built (GD-50). The other unlocks below are plans for the tickets named.

## What it is

The guild has a rank on the same F to S scale as quests (`QuestData.Rank`). A new guild is rank F. Rank is shown on the quest board and in the guild history.

Guild rank is the guild's fame. GD-27 ("guild fame unlocks harder quests and a bigger board") uses this rank rather than a separate fame number.

## How it is earned

- Every successful quest, including a costly success, earns **reputation**. The amount depends on the quest's true rank (`QuestRankData.reputation` in `campaign_rules`).
- A failed quest earns nothing.
- The guild reaches a rank once its reputation is at least that rank's `reputation_needed`.

| Rank | Reputation per success | Reputation needed |
|---|---|---|
| F | 1 | 0 |
| E | 2 | 2 |
| D | 3 | 6 |
| C | 5 | 14 |
| B | 8 | 28 |
| A | 12 | 50 |
| S | 20 | 80 |

So a careful guild reaches E after two starter jobs and D after two more E jobs. Each rank after that takes roughly three or four successes at the guild's own rank, or fewer at the stretch rank above it.

## Can a guild lose rank?

No. Reputation only goes up. A guild hit by a disaster keeps its rank, but its board eases off while its roster is weak (GD-52), so it is not left facing only quests it can't win. Debt and deaths already punish a disaster.

## What each rank unlocks

| Unlock | Rule | Ticket |
|---|---|---|
| Quest ranks | The board offers quests up to one rank above the guild's rank: an F guild sees F and E jobs, a C guild sees up to B. | GD-50 (built) |
| Board difficulty | Within those ranks, the board leans towards a target rank set by time and roster strength. | GD-52 |
| Board size | One more board slot at ranks D and B. | GD-27 |
| Hire candidates | Better candidates appear more often at higher ranks. | GD-60 |
| Market stock | Better weapons and armour go on sale from rank D. | GD-28 |
| Guild upgrades | Upgrades unlock by rank, such as an infirmary at C and a training yard at B. | GD-29 |

`QuestData.min_quests_attempted`, which held quests back until the guild had attempted enough of them (GD-9), is removed. Guild rank replaces it.
