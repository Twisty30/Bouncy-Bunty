# Bouncy Bunty REBOUND

A bouncy 2D pixel-art platformer with claws, made in **Godot 4.7**, for 1 to 3 players.

King Bear is back. He has smashed the Rebound Crystal, the thing that keeps the world
bouncy, and handed a shard to each of his four generals. Run, jump, dash, wall-kick and claw
through 50 levels across five worlds, beat five bosses and put the crystal back together.

## Game modes

| Mode | What it is |
| --- | --- |
| **Story** | 50 levels in 5 worlds, each ending in a boss fight, with story scenes between worlds. Every level hides 3 gems and gives you a rank (S, A, B, C). Progress, best times, gems and ranks are saved. Play alone or in co-op with 2 or 3 players. |
| **Rush Mode** | The time trial, renewed. An endless run that gets harder every 170 m as it moves through all five worlds. You start with 60 seconds; green orbs give +3, each new zone gives +12. Bronze at 150 m, silver at 350 m, gold at 600 m. |
| **Bootcamp** | The tutorial, renewed. Miss Bear coaches you through every move, one short room at a time, and finishes with a practice fight. |

## Controls

Up to three people can play at once: two on one keyboard and one on a controller.
In single player, all three control schemes move the same bear.

| Action | Player 1 (keyboard) | Player 2 (keyboard) | Player 3 (controller) |
| --- | --- | --- | --- |
| Move | A / D | ← / → | Left stick or d-pad |
| Jump (hold for higher) | W or Space | ↑ | A / Cross |
| Claw (tap 3 times for a combo) | F or J | Enter or / | X / Square |
| Dash | Q or K | Ctrl | B / Circle or RB |
| Crouch, and ground pound in the air | S | ↓ | Stick down, d-pad down or LB |
| Interact (levers) | E | Right Shift | Y / Triangle |
| Pause | Esc or P | | Start |

In menus: arrows or stick to move, Enter / Space / (A) to choose, Esc / (B) to go back.

### Touch controls

On a phone or tablet the game shows on-screen buttons: arrows and a down button on the left,
JUMP, CLAW, DASH and USE on the right, pause in the top corner. **Options → Touch controls**
switches between **AUTO** (on when the device has a touchscreen), **ON** and **OFF**. The
same toggle is in the pause menu.

## Things to know

- **Claws:** three quick swings make a combo; the third hits twice as hard. Claws also break
  crates and swat projectiles out of the air.
- **Ground pound:** press down in the air. It hits hardest, breaks crates under you and
  bounces extra high off mushrooms.
- **Wall kick:** jump at a wall, then press jump again to kick off it. Two walls close
  together can be climbed.
- **Dash** works once in the air and hurts baddies you dash through.
- **Hearts:** you have 3. Checkpoint flags refill them and are where you come back.
- **Baddies:** bots and bats can be stomped. Drills have a spike on top, so claw or dash
  them. Ghosts only fear claws. Thwomps, saws, sparks, fire jets and electric arcs can't be
  hurt at all.
- **Power Star:** 10 seconds of being invincible, extra bouncy and extra strong.
- **Power-up bubbles:** you lose them when you fall.

  | Bubble | What it does |
  | --- | --- |
  | Speed Boost (red shoe) | 12 seconds of running 45% faster |
  | Extra Jump (wing) | one more jump in the air. Grab a second one for a triple jump |
  | Super Bounce (spring) | 12 seconds of much higher jumps, mushrooms and springs |
  | Coin Magnet | 15 seconds of coins flying to you |
  | Bubble Shield | blocks the next hit |
- **Platforms:** moving platforms ride side to side or up and down. Blue fading platforms
  blink before they vanish, and the next one along is always out of step. Orange falling
  platforms shake when you land on them, then drop away and come back later.
- **Bear Shop:** coins you pick up go into the bank when a level ends (Rush Mode too).
  Bootcamp only has coins until you finish it once, so it can't be farmed. Spend them in **Bear Shop** on the title screen on new fur colours and hats.
  Point at anything to try it on.
- **Bosses** telegraph every attack. Most can be made dizzy (Captain Clank by dodging his
  charge so he hits the wall); a dizzy boss takes extra damage.
- **Co-op:** if one bear falls, the whole team goes back to the checkpoint.

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
| `game.gd` | Autoload `Game`: controls, game modes, saving, sound, hit-stop, and scene changes with pixel transitions |
| `fx.gd`, `fx_sprite.gd`, `fx_data.gd`, `fx/` | Autoload `Fx`: plays the pixel art effects. `fx/` holds the sprite sheets, `fx_data.gd` their frame data |
| `boot.gd` | Loading bar and the logo animation |
| `menu.gd` | Title screen, story menu, world map, options, Bear Shop |
| `skins.gd`, `skin.gdshader` | Bear Shop goods: fur colours (a recolour shader) and hats |
| `powers.gd` | The power-up bubbles: what each one is called, lasts and looks like |
| `pixel_art.gd` | Tiny pixel art drawn from text (hats and power-up icons) |
| `cutscene.gd` | Story scenes, written as lists of steps (see the top of the file) |
| `level.gd` | Builds and runs a level: tiles, pickups, hazards, combat, boss cinematics, Rush Mode, Bootcamp |
| `levels.gd` | All level data: worlds, themes, chunks, the 50 levels, Bootcamp and Rush Mode pools |
| `player.gd` | Bunty: movement, wall kicks, dashing, claws, ground pound, hearts |
| `enemy.gd` | Every baddie and moving hazard |
| `boss.gd` | The five bosses |
| `hud.gd` | Hearts, gems, boss bar, VS splash, results screen, pause menu |
| `dialog.gd`, `cast.gd` | The dialogue box, and who the characters are |
| `backdrop.gd` | Sky, hills, clouds and weather |
| `touch.gd` | On-screen touch controls |
| `ui.gd` | Shared menu buttons, panels and labels |
| `tools/` | Scripts that made the effect sheets, extra sounds and new music |

### Making levels

Levels are built from text chunks. Open `levels.gd`: the legend at the top lists every
character (`#` ground, `o` coin, `a` bot, `M` mushroom...). Draw a chunk in `CHUNKS`, then
add its name to a level's `chunks` list in `LEVELS`.

### Testing switches

Run Godot with extra arguments after `--` to jump straight to something:

```
godot --path . -- --scene=story:12      (level 13; also trial, tutorial, cutscene:intro, map)
godot --path . -- --scene=story:9 --col=20   (start at tile column 20)
godot --headless --path . -- --testall   (build all 50 levels, both modes and every scene)
godot --path . -- --scene=shop --coins=500 --wear=golden,crown   (try the shop; saves nothing unless you buy)
```

### Effects, sounds and music

The effects are sprite sheets rendered from the [pixelfx](https://github.com/patch-gg/pixelfx)
library. To change the set, copy `tools/build_fx.mjs` into a pixelfx checkout, edit its list
and run `node build_fx.mjs <this folder>`. `tools/make_sfx.py` and `tools/make_music.py`
regenerate the extra sound effects and the newer music loops: the title, the final round, and a
song for each world (Dune Desert, Frost Peaks, Thunder Heights and King's Castle; Bouncy Hills
keeps the original level song). `python tools/make_music.py desert frost` remakes just those two.

## Credits

- **Art:** [Pixel Platformer](https://kenney.nl/assets/pixel-platformer) by Kenney (CC0)
- **Effects:** [pixelfx](https://github.com/patch-gg/pixelfx) (MIT)
- **Font:** [Typeface Mario World Pixel](https://www.fontspace.com/typeface-mario-world-pixel-font-f564478) by ripoof (CC BY-NC-ND, non-commercial use only)
- **Engine:** [Godot Engine](https://godotengine.org)
- **Team:** Mahmoud Sami Atta (Mxord9000), Mohamed Amr (Twisty30), and Mujitaba (h6wl)

Because the font's license is non-commercial, the game can't be sold while it uses this font.
