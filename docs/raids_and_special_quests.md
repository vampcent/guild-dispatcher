# Raids and special quests

Status: design only (GD-51). Nothing here is playable yet. This note keeps the quest rank work (GD-41) from closing the door on raids and special quests at the top ranks.

## The two new kinds of quest

Every quest has a `kind` (`QuestData.kind`): `NORMAL`, `RAID` or `SPECIAL`. All current quests are `NORMAL`, and the game treats the other two kinds exactly like normal quests until the features below are built.

### Raids

A raid is one big target, such as a dragon's hoard, a bandit fortress or a lich's tower, that needs more than one ordinary party.

- **Who goes:** either two or three parties sent together, or one party allowed above `max_party_size` (for example up to 8).
- **How it plays out:** the same hidden rounds as now, but the enemy has much more health and attacks more often, and each party fights its own share of the rounds. Losses in one party can leave another to finish the job.
- **When it appears:** rank B and up only, and rarely. It stays on the board longer than a normal quest so the guild has time to gather enough adventurers.
- **Pay:** split between the parties on success. A failed raid can cost the gear of every party that went (today a fully dead party loses its gear).

### Special quests

A special quest is a one-off or story quest that only appears when its conditions are met.

- **Examples:** a noble's job that only appears after the guild reaches rank C, a revenge quest after an adventurer dies to a named enemy, or a quest offered once the guild owns a particular legendary accessory.
- **Rules:** shown at most once per guild and marked differently on the board. It can't be misread by scouting, because the client tells you exactly what they want.
- **Rewards:** can grant something no market sells, such as a unique accessory, a recruit (GD-19) or a guild upgrade (GD-29).
- **Possible data:** an `appear_condition` (guild rank, day, owns accessory, adventurer died) and a `once_only` flag.

## What would need to change

These parts of the code currently assume one normal party per quest.

| Area | Assumption today | Change for raids or special quests |
|---|---|---|
| `EncounterSimulator` | Takes one `Array[Loadout]` party and one enemy pool | Accept several parties, or run one encounter per party against shared enemy health |
| `GuildState.get_party_problems` | Rejects parties above `max_party_size` | Use a raid limit for `RAID` quests |
| `GuildState.finish_quest` | One party, one result, one payout | Combine several results; split pay; record each party's losses |
| `Armoury.apply_result` | Gear is lost when the whole party dies | Apply per party |
| `GuildState.refresh_board` | Picks from every unlocked quest, weighted by rank | Respect `appear_condition` and `once_only`; keep raids rare and on the board longer |
| `BoardEntry` / `_get_shown_rank` | Every quest can be misread | Special quests always show their true rank |
| `GuildSession` dispatch action | Carries one party | Carry a list of parties so both players see the same raid |
| Party setup screen (`main.gd`) | Picks one party | Pick several parties, or one large one |
| Day system (GD-21, GD-22) | Not built yet | A raid ties up every party that went until it returns |
