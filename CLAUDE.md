# Resonance — project context

A pixel-art 2D metroidvania built in **Godot 4.7 (GDScript)**. This is a game project, not a website:
the global web-dev standards (Tailwind, WordPress, GSAP, Lighthouse) do not apply here. Accessibility
still does. Support remappable controls, a reduced-motion/screen-shake toggle, and readable contrast,
and give any audio-only cue a visual counterpart.

**Full design doc: [docs/design/GDD.md](docs/design/GDD.md).** Read the relevant section before designing or
building a system. When a design decision gets made or changed, update the GDD in the same change.

## The game in brief
- A boy inherits his dying grandfather's **staff**, which is a walking stick, flute, weapon and traversal tool
  in one. Upgrading the staff upgrades combat, movement and music together.
- Music is the core mechanic. Copying tunes on the flute reveals secrets and heals the land. Songs have
  visible **cymatic/Chladni shapes** that act as a wordless language the player learns.
- Nothing is explained in text (Tunic/Fez/Hyper Light Drifter). Teach through the environment.
- Feel targets: Celeste/Hollow Knight movement, Rain World survival between regions, Hollow Knight fight
  followed by an Ori-style escape for each boss.
- Regions: Desert/Sunken Ship (start), Old Forest/Ziggurat, Mountains/Mine, White City (central hub,
  final boss), plus the Spirit Plain (upgrade and fast-travel hub). The world map is a concentric
  cymatic shape.

## Where things are
- **Display:** 480×270 base resolution, integer-scaled (window 1440×810), nearest filtering. All gameplay units
  are pixels at that resolution. Tiles are 16px; the character is ~30px tall with a 12×28 box, origin at the feet.
- `assets/`: a purchased placeholder sprite pack (one folder per animation, PNG strips + `.aseprite`).
- `player/player.tscn`: `Player` (CharacterBody2D) with AnimatedSprite2D, CollisionShape2D, Camera2D, PunchHitbox,
  and one child **component node per system**. Each component script holds that system's `@export` tunables,
  its state and its code, and reaches the body through `player`:

  | Node | Script | Covers |
  |---|---|---|
  | (root) | `player_controller.gd` (`Player`) | run, jump, gravity, coyote/buffer, wall slide, wall jumps, wall run, wall probes, ability flags, the per-frame order (`_physics_process()`), `respawn()` |
  | Dash | `player_dash.gd` | dash, dive, windup + glow tint, cooldown, air ability limit, hard landing, refill/bounce diamonds |
  | Crouch | `player_crouch.gd` | crouch/crawl, low body box, roll, slide, slide jump, charged jump |
  | Slope | `player_slope.gd` | slide slopes: slide, kick, run-up, steep-slope stop |
  | Climb | `player_climb.gd` | grip-surface climb, handholds, attach, block push/pull |
  | Ledge | `player_ledge.gd` | ledge grab, hang, climb, wall-run mount |
  | Rope | `player_rope.gd` | rope catch, swing, pump, release |
  | Punch | `player_punch.gd` | jab/cross combo, hitbox, `punch_landed` |
  | Animation | `player_animation.gd` | animation choice, sprite tilt/lean, somersault |

  To change one mechanic, read its component (and only the parts of `player_controller.gd` it calls). The
  **comments in each script are the reference for how a mechanic works and why**; keep them up to date rather than
  describing mechanics here. Live-tuning a component's exports happens on its child node in the Remote inspector.
- **Ability flags** on `Player` (`can_dash`, `can_dive`, `can_wall_jump`, `can_ledge_grab`, `can_climb`,
  `can_wall_run`, `can_charge_jump`, `max_air_abilities` 1-3) are the staff-upgrade hooks.
- `levels/`: `test_room.tscn` (main scene, a movement sandbox), `cave_tile_painter.gd`, `cave_tileset.tres`, and
  the level objects, each a `class_name` with its own comments: `GripSurface`, `SwingRope`, `MovableBlock`,
  `SlideSlope`, `RefillDiamond`.

## Design decisions that aren't obvious from the code
- More rhythmic than Celeste: no climb jump straight up a wall; every jump off a climb is a wall jump.
- Abilities are powerful but must be intentional: real cooldowns, once-per-trip air abilities, only the ground
  refills (walls, ledges and ropes don't). Diamonds give back one use, not all.
- Wall jumps shrink each time in a trip so a shaft can be worked down but never bounced up.
- Tried and removed (in git history if wanted): Celeste stamina bar, free-to-climb ladder variant, standing roll
  (replaced by the ground dash), an absolute wall-jump ceiling at the first jump's peak (left later kicks with no
  height), a pendulum that shortened as the player climbed (whipped the rope into a frantic swing).
- Flashing effects stay under 3 flashes a second (the charged-jump pulse is 2/s).

## Test room names
Shown in-game and in the editor as `Label`s under `Labels`, so the user can point at things by name. Every room is
40 tiles (640px) wide inside, between the faces of the walls or columns bounding it; room titles are centred there.
Columns and blocks share one sequence per room, numbered left to right.
- **Room A** (left wall face x 16 to A6's face x 656): the pit; **A1** floor step (cols 8-11); **A2**, **A3** floating
  2×2 blocks (cols 13-14, 18-19; tops y 256, 192); **A4** column past the pit (cols 30-31, y 256-352) with the `Ladder`
  grip on its left face; **A5** floating 2×2 (cols 35-36, top y 192); **A6** tall column (cols 41-42), grip on its left
  face y 96-208. **Handhold1-5** up the A6/B1 shaft (hands at y 225, 196, 167, 138, 109, alternating B1 x 753 / A6
  x 687, no labels): each is where the best jump off the one before meets the other wall, so **re-measure them with
  a headless sim if jump, wall-jump, gravity or air-speed tuning changes**.
- **Room B** (cols 49-88, B1 face x 784 to C1 face x 1424), reached through a 2-tile doorway at B1's foot: **B1** the
  ceiling column; **B2**, **B6** floating steps (cols 53-54, 83-84, tops y 192, out of reach from the floor);
  **B3**, **B5** 150px `SwingRope`s at x 997 and 1211 (thirds of the room); **B4** a `MovableBlock` starting at x 1104
  (its label is its child, so it moves with it).
- **Room C** (cols 92-131, camera limit x 2128), a slide-slope playground reached by crawling/rolling under **C1**
  (thin ceiling column, cols 89-91, `C1Grip` on its right face y 16-304, over a 1-tile tunnel). **C2** and **C3** are
  4×4 45° slopes (x 1520-1584 y 96-160; x 1680-1744 y 192-256); **C4** a 6×4 ~34° slope on the floor running down
  to the left (x 1776-1872), shallow enough to run up.
- No `RefillDiamond`s are placed right now (removed while their positions get worked out); the code is live.
- New things are numbered by position and later names shift up one. **Tell the user whenever an existing name changes.**
- Tile layout (`cave_tile_painter.gd`, ASCII `layout`, "Rebuild From Layout" in the Inspector): air gaps at least
  2 tiles, free-floating blocks exactly 2×2, walkable tops on even rows. C1's one-tile tunnel breaks the 2-tile rule.

## Controls and input
Gamepad: B jump (Down+B held charges, fires on release) · Y punch · A dash (ground only while moving; Down+A rolls,
or slides out of a sprint; Down+A in the air dives) · RB grab/climb/attach (hold) · ZR sprint (hold) · R3 turn on a
rope · Minus inventory · d-pad/left stick move (up climbs, down crouches). X and ZL are free. Still needs buttons:
staff throw/recall, the map, interact. Instrument mode is planned as hold RB + X/Y/B/A, so grab or instrument must
move before the instrument is built.
Keyboard: arrows/WASD, Space jump, Shift sprint, Z punch, C dash, X grab, F turn, I inventory.
- Input actions: `move_left`/`move_right`, `move_up`, `crouch`, `jump`, `sprint`, `dash`, `grab`, `attack`, `turn`,
  `inventory`. `dash` covers dash, dive, roll and slide (no separate `roll`). Add new actions to `project.godot`'s
  Input Map; never hardcode keys.
- Godot reads joypad buttons by **position** (Xbox layout): on a Switch Pro controller button 0 (bottom) is B and
  button 1 (right) is A.
- `crouch` doubles as Down, so it must never share a button with `dash`, or every air dash would dive and every
  ground dash would roll.

## Conventions
- GDScript with static typing (`var x: float`, `:=`, typed signatures). Tunables are `@export`, on the component
  that owns them.
- snake_case for files, folders, functions and variables. PascalCase for node names and `class_name`.
- Comment the *why* (feel and design intent), matching the existing scripts.
- Docs live in `docs/` (has `.gdignore`, so Godot skips it).
- Script check without a window: `/Users/EthanHead/Desktop/Godot.app/Contents/MacOS/Godot --headless --path .
  --check-only --script <file.gd>`. A new `class_name` needs the class cache refreshed first:
  `... --headless --path . --editor --quit-after 600` (macOS has no `timeout`).
