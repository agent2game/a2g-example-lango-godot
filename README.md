# Lango with A2G (Godot 4)

This is a fork of [Lango_GodotRPG](https://github.com/Delta12Studio/Lango_GodotRPG) by Delta12 Studio, converted to **Godot 4.7** and integrated with the [Agent2Game (A2G) protocol](https://agent2game.org): the bees, bats and boss can ask an AI model what to do next, while their original state machines stay in place and take over whenever there is no valid decision.

The original Godot 3 code is kept in the [`godot3`](../../tree/godot3) branch.

## What A2G adds

- `a2g_manifest.json`: the world, scopes per level type, the boss profile, entity types, events and cache rules.
- `addons/a2g/`: the [A2G SDK for Godot](https://github.com/agent2game/a2g-sdk-godot) `v0.1.1`, vendored as-is (game-agnostic). Update it with `scripts/update-a2g-sdk.sh <tag>`.
- `A2G/LangoA2G.gd`: the Lango adapter (what enemies observe, which actions are legal, how to run them).
- One `A2G.execute(self, delta)` call at the top of each enemy's physics step; the original AI runs whenever it returns `false`.
- `Debug/`: an in-game debug panel and enemy labels, plus headless tests.

A full walkthrough with messages on the wire is on [agent2game.org/examples/lango](https://agent2game.org/examples/lango/).

## Run

1. Open the project in Godot 4.7.
2. Start an A2G decision service on `http://127.0.0.1:8787`, for example the [reference service](https://github.com/agent2game/a2g-service): `docker run -d -p 127.0.0.1:8787:8787 -e OPENAI_API_KEY=... ghcr.io/agent2game/a2g-service:0.1.2`.
3. Run the game. AI control is off by default; turn it on in the debug panel (`~`) or start with `-- --a2g-ai`.

Without a service the game plays exactly like the original, on its native AI.

## Controls

| Key | Action |
| --- | --- |
| WASD / arrows | Move |
| J / Space | Attack |
| K | Roll |
| I | Inventory |
| Esc | Menu |
| `~` | Debug panel: switch native AI / A2G, enemy labels, test options |

## Credits

Game, art and code by Delta12 Studio. Intro music by Dark Reaven Music. Thanks to waffle, the HeartBeast YouTube channel and dadivepesce.com, as credited by the original project below. The Godot 4 conversion and the A2G integration are by agent2game.

---

The original README follows.

# Lango_GodotRPG

Lango is a simple and open source project of an RPG game in the style of the Legendary Legends of Zelda, 
made on the Godot Engine with the intention of serving as an initial base for you to create your own game.

The game features 

* map transition, 
* two types of enemies with A.I., 
* a system to drop items randomly when we kill enemies and destroy grasses, 
* animation of doors and cave entrances, 
* a sleeping system to recover health,
* a cave of madness (puzzle),
* chests with random drop items 
* a small quest system and more...

You can learn with my tutorials on 
https://www.youtube.com/c/DELTA12STUDIO

The great intro music was made by Dark Reaven Music
https://www.youtube.com/watch?v=mDokP-LgiR0

Thanks to waffle for the note - Instructions for Beginners

Special thanks to Heartbeast Youtube channel and dadivepesce.com website.
