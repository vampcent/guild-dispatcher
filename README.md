# Guild Dispatcher

A 2D fantasy guild management game built in Godot 4 with GDScript.

You run an adventurers' guild. You build a party, equip it and send it out, but you never see the action. You find out what happened from the written report that comes back, and those reports are built from what really happened in the simulation.

The tone is tongue-in-cheek fantasy, inspired by D&D.

> **Status:** early development. The game is playable, but most numbers and content are placeholders, and there's no art yet.

## What's in the game so far

- **An endless guild:** keep taking quests until your guild fails.
- **Quest board:** choose from a selection of quests, each with a rank from F (odd jobs) to S (legends), pay, a recommended party strength and a briefing that hints at what to pack. Party strength is total attack plus total defence, gear included.
- **Guild rank:** successful quests earn reputation, which raises the guild from rank F towards S. The board offers quests up to one rank above the guild's own (see `docs/guild_rank.md`), leaning towards harder ranks as quests go by, but easing off again if the roster is weakened.
- **Round-based encounters:** quests play out unseen in hidden rounds, with an approach stage that can trigger traps.
- **Six adventurers:** Sentinel, Berserker, Thief, Spy, Evoker and Exorcist.
- **Abilities:** 9 of a planned 32 class and subclass abilities, including Hold the Line, Fireball and Light Fingers.
- **Shared armoury:** assign weapons, armour, accessories and supply items before each dispatch. What each adventurer can use depends on their class. Anyone sent without a weapon fights bare-handed with their own attack, which is a lot weaker.
- **Loot:** accessories come in five tiers, from common to legendary. Unique and legendary items have special effects.
- **Scouting:** pay a share of a quest's reward to confirm its rank and learn what to pack and who to send.
- **Economy:** earn quest pay, buy items, weapons and armour at the market, and pay wages. Fall too far into debt and the guild closes.
- **Permanent death:** a second wound in the same quest kills an adventurer. The guild history records the fallen when your guild ends.

## Getting started

You'll need [Godot 4.7](https://godotengine.org/download).

1. Clone this repository.
2. Open Godot and import the project using `project.godot`.
3. In the FileSystem panel, open `scenes/main/main.tscn`.
4. Press **F6** to run it.

To make **F5** start the game, right-click `main.tscn` and choose **Set as Main Scene**.

### Playing with a friend

Two people can run the same guild at once over a local network. You share one pot of gold, one armoury, one roster and one quest board, and either of you can buy supplies, scout, send a party or found a new guild. When a party comes back, you both see the report.

1. One player chooses **Host a game for two**. Their quest board shows join codes, such as `R2M0-253N`.
2. The other player types a code on the start screen and chooses **Join**. Use the **online** code from anywhere on the internet, or the **same network** code when you're both on the same home network.

A join code stands for the host's address. To make the online code, the game asks the host's router to open UDP port 7777 using UPnP, which most home routers allow. If the router refuses, or the internet provider shares one address between customers (common on mobile networks), the quest board says so: the same network code still works, and you can forward UDP port 7777 on the router yourself and share the public IP address instead. The host's firewall also needs to allow the game. To skip the start screen, run the game with `-- --host` or `-- --join=CODE`.

## Project structure

```text
res://
├── data/                  # Game content, stored as .tres files
│   ├── characters/        # Adventurers and abilities
│   ├── equipment/         # Weapons, armour, accessories, items and the armoury
│   ├── quests/
│   ├── reports/           # Report wording
│   └── rules/             # Balance numbers for encounters, the economy and the campaign
├── scripts/
│   ├── data/              # Definitions of each type of game data, in the same groups
│   ├── simulation/
│   │   ├── encounter/     # Running a quest and recording events
│   │   └── guild/         # Gold, the armoury, the quest board and guild state
│   ├── multiplayer/       # Keeps one guild in step between two players
│   └── reports/           # Turns recorded events into written reports
└── scenes/
    ├── main/              # The playable game and its screens
    └── tests/             # Small scenes that test one system at a time
```

Two rules keep the project easy to extend:

- **Game data is separate from logic.** Most new content, such as a quest or an item, is a new data file rather than new code.
- **The simulation is separate from the UI.** It records events as a quest plays out, and reports are written only from those events.

## Running the tests

Each test scene runs its checks, printing `ok` or `FAILED` for each one, then ends with a `PASS` or `FAIL n` line and exits with status 1 if any check failed. Tests also run on GitHub for every push and pull request.

**In the editor:** open any scene in `scenes/tests` and press **F6**. The scene closes once its checks finish, and the results stay in the **Output** panel.

**From the command line:** run every test scene headless with:

```sh
tools/run_tests.sh
```

The script uses the `godot` command. If your Godot 4.7 binary has a different name or isn't on your `PATH`, set `GODOT`, for example `GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64 tools/run_tests.sh`. On Windows, run it from Git Bash and point `GODOT` at the `_console.exe` build so the output shows up. It exits with a non-zero status if any scene fails, hits a script error or runs longer than 300 seconds (change this with `TEST_TIMEOUT`).

To add a test, create a scene in `scenes/tests` whose name ends in `_test`, give it a script that extends `TestCase`, call `check()` or `check_equal()`, and finish with `finish()`.

| Scene | What it checks |
|---|---|
| `encounter_test` | Rounds and encounter results |
| `ability_test` | What each ability adds |
| `speed_test` | Speed and dodging |
| `armoury_test` | Weapons, class rules and armoury stock |
| `armour_test` | Armour trade-offs |
| `loot_test` | Accessories, item tiers and loot |
| `economy_test` | Pay, wages, debt and closing the guild |
| `supplies_test` | Supply items and buying from the market |
| `board_test` | Quests worsening and expiring |
| `scout_test` | Paying to scout quests |
| `guild_test` | Quest board, resting, game over and guild history |
| `report_test` | Written reports |
| `multiplayer_test` | Join codes, and two players sharing one guild over the network |

## Roadmap

1. **Core simulation:** hidden rounds, class features and abilities
2. **Full gear:** armoury, armour, accessories and loot
3. **Endless guild:** quest board, gold, wages and game over
4. **Time and parties:** day-by-day time and several parties at once
5. **Living roster:** hand-crafted characters, quirks, relationships and recruiting
6. **Report depth:** far more report and quest text, with personality-specific wording
7. **Wider world:** market, guild upgrades, rival guilds, factions and world events
8. **Presentation:** pixel art for the guild secretary and adventurers, plus the final UI

Stage 3 is in progress. The remaining abilities are being added as the systems they rely on are built.
