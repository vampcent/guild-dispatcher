# Guild Dispatcher

A 2D fantasy guild management game built in Godot 4 with GDScript.

You run an adventurers' guild. You build a party, equip it and send it out, but you never see the action. You find out what happened from the written report that comes back, and those reports are built from what really happened in the simulation.

The tone is tongue-in-cheek fantasy, inspired by D&D.

> **Status:** early development. The game is playable, but most numbers and content are placeholders, and there's no art yet.

## What's in the game so far

- **An endless guild:** keep taking quests until your guild fails.
- **Quest board:** choose from a selection of quests, each with a danger rating, pay and a briefing that hints at what to pack.
- **Round-based encounters:** quests play out unseen in hidden rounds, with an approach stage that can trigger traps.
- **Six adventurers:** Sentinel, Berserker, Thief, Spy, Evoker and Exorcist.
- **Abilities:** 9 of a planned 32 class and subclass abilities, including Hold the Line, Fireball and Light Fingers.
- **Shared armoury:** assign weapons, armour, accessories and supply items before each dispatch. What each adventurer can use depends on their class.
- **Loot:** accessories come in five tiers, from common to legendary. Unique and legendary items have special effects.
- **Economy:** earn quest pay, buy supplies and pay wages. Fall too far into debt and the guild closes.
- **Permanent death:** a second wound in the same quest kills an adventurer. The guild history records the fallen when your guild ends.

## Getting started

You'll need [Godot 4.7](https://godotengine.org/download).

1. Clone this repository.
2. Open Godot and import the project using `project.godot`.
3. In the FileSystem panel, open `scenes/main/main.tscn`.
4. Press **F6** to run it.

To make **F5** start the game, right-click `main.tscn` and choose **Set as Main Scene**.

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
│   └── reports/           # Turns recorded events into written reports
└── scenes/
    ├── main/              # The playable game and its screens
    └── tests/             # Small scenes that test one system at a time
```

Two rules keep the project easy to extend:

- **Game data is separate from logic.** Most new content, such as a quest or an item, is a new data file rather than new code.
- **The simulation is separate from the UI.** It records events as a quest plays out, and reports are written only from those events.

## Running the tests

Open any scene in `scenes/tests`, press **F6**, then check the **Output** panel.

| Scene | What it checks |
|---|---|
| `encounter_test` | Rounds and encounter results |
| `ability_test` | What each ability adds |
| `speed_test` | Speed and dodging |
| `armoury_test` | Weapons, class rules and armoury stock |
| `armour_test` | Armour trade-offs |
| `loot_test` | Accessories, item tiers and loot |
| `economy_test` | Pay, wages, debt and closing the guild |
| `supplies_test` | Supply items and buying more |
| `board_test` | Quests worsening and expiring |
| `report_test` | Written reports |

## Roadmap

1. **Core simulation:** hidden rounds, class features and abilities
2. **Full gear:** armoury, armour, accessories and loot
3. **Endless guild:** quest board, gold, wages and game over
4. **Time and parties:** day-by-day time and several parties at once
5. **Living roster:** hand-crafted characters, quirks, relationships and recruiting
6. **Report depth:** far more report and quest text, with personality-specific wording
7. **Wider world:** market, guild upgrades, rival guilds, factions and world events
8. **Presentation:** secretary art and customisation, plus the final UI

Stage 3 is in progress. The remaining abilities are being added as the systems they rely on are built.
