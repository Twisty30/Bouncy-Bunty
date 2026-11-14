# Bouncy Bunty

A bouncy 2D pixel-art platformer made in **Godot 4.7**, for 1 to 3 players.

King Bear has carried Miss Bear off to his castle. Run, jump, dash and bounce on
mushrooms through 14 lands (hills, desert and snow) to reach his throne and beat
him in a boss fight.

## Game modes

| Mode | What it is |
| --- | --- |
| **Tutorial** | One short level that teaches every move, with signs along the way. |
| **Story Mode** | 14 levels plus the King Bear boss fight, with an intro and an ending. Progress is saved, so you can continue where you left off. Play alone or in co-op with 2 or 3 players. |
| **Time Trial** | An endless run built from random pieces. Get as far as you can in 60 seconds. Your best distance is saved. |

## Controls

Up to three people can play at once: two on one keyboard and one on a controller.
In single-player, all three control schemes move the same bear.

| Action | Player 1 (keyboard) | Player 2 (keyboard) | Player 3 (controller) |
| --- | --- | --- | --- |
| Move | A / D | ← / → | Left stick |
| Jump (hold for higher) | W | ↑ | A / Cross |
| Crouch | S | ↓ | Hold RB / R1 |
| Dash | Q | Ctrl | X / Square |
| Interact (levers) | E | Right Shift | Y / Triangle |

| Menus | Keyboard | Controller |
| --- | --- | --- |
| Move between buttons | Arrow keys | Stick / D-pad |
| Select | Enter / Space | A / Cross |
| Back / quit to menu | Esc | B / Circle |

Controller buttons are mapped by position, so Xbox, PlayStation and Switch pads all work the same way.

## Things to know

- **Mushrooms** bounce you high. Land on them from above.
- **Dash** works once in the air. You get it back when you land or bounce.
- **The pink Bounce Gem** makes you extra bouncy for 12 seconds.
- **Checkpoints** are the flags. Touch one and you respawn there.
- **Levers and pressure plates** open doors. Some doors only appear in co-op and need two players: one stands on the plate while the other goes through.
- **Co-op:** if one bear dies, the whole team goes back to the checkpoint.
- **King Bear** has 25 HP. Jump on his head, and watch out: he gets faster as he gets hurt.

## Running the game

1. Install [Godot 4.7](https://godotengine.org/download) (the standard version, not .NET).
2. Open Godot, click **Import**, and pick this folder's `project.godot`.
3. Press **F5** to play.

## Exporting for the web

The project has a ready-made **Web** export preset.

1. Install the export templates: **Editor → Manage Export Templates → Download and Install**.
2. Go to **Project → Export**, choose **Web**, and click **Export Project**. The game goes into `build/web/`.
3. A web export has to be served by a web server. Opening `index.html` by double-clicking it shows a black screen. To try it locally, use the **Remote Deploy → Run in Browser** button at the top right of the editor.
4. To share it, zip the files in `build/web/` (with `index.html` at the top of the zip) and upload the zip to [itch.io](https://itch.io) as an HTML game.

Thread support is turned off in the preset, so the game runs on itch.io and GitHub Pages without any special server settings.

## Project layout

| File | What it does |
| --- | --- |
| `game.gd` | Autoload `Game`: input setup, game modes, scene changes, saving, sound and music |
| `menu.gd` / `menu.tscn` | Main menu and the Story submenus |
| `cutscene.gd` | Intro and ending dialogue |
| `level.gd` | Builds and runs a level: tiles, coins, gems, checkpoints, doors, camera, HUD |
| `levels.gd` | Level data: the 15 story levels, the tutorial and the time-trial pieces |
| `player.gd` | Bunty: movement, jumping, dashing, crouching and animation |
| `boss.gd` | King Bear |
| `sfx/`, `music/` | Sound effects and music loops |

Levels are built in code from reusable pieces (`gap`, `steps`, `mushroom_wall`, `dash_gap` and more). To make a new level, add an entry to `LEVELS` in `levels.gd` with a list of pieces.

## Credits

- **Art:** [Pixel Platformer](https://kenney.nl/assets/pixel-platformer) by Kenney (CC0)
- **Font:** [Typeface Mario World Pixel](https://www.fontspace.com/typeface-mario-world-pixel-font-f564478) by ripoof (CC BY-NC-ND, non-commercial use only)
- **Engine:** [Godot Engine](https://godotengine.org)
- **Team:** Mahmoud Sami Atta (Mxord), Mohamed Amr (twisty30), and Mujitaba (h6wl)

Because the font's license is non-commercial, the game can't be sold while it uses this font.
