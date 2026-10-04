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

## Controls (gamepad)
A dash · B jump · X throw/recall staff · Y attack · hold RB for instrument mode (X/Y/B/A play notes) ·
ZL crouch · ZR grab/climb · D-pad moves (up climbs, down crouches); Minus opens the inventory; the map needs a new button. Keyboard bindings go through the Input Map.

## Current state of the code
- **Display:** 480×270 base resolution, integer-scaled (window 1440×810), nearest filtering. All gameplay
  units are pixels at that base resolution. Tiles are 16px and the character is about 30px tall.
- `assets/`: a purchased placeholder sprite pack. It has one folder per animation (PNG strips plus
  `.aseprite` sources) and `Tilemap (Super Basic)/Basic Tilemap.png`.
- `player/player.tscn`: Player (CharacterBody2D) with these children:
  - AnimatedSprite2D: idle, walk, run, jump, fall, land
  - a 12×28 collision box
  - Camera2D with smoothing

  The origin is at the feet.
- `player/player_controller.gd`: movement and animation.
  - Movement: accel/friction, asymmetric gravity, coyote time, jump buffering, variable jump height. Every
    value is an `@export`.
  - Animation: the sprite flips on input. The `land` animation plays only when touching down while standing
    still.
  - `respawn()` returns the player to the spawn point.
  - The current tuning gives a jump of about 75px (4.5 tiles).
  - **Dash:** eight directions, Celeste-style. The direction comes from the d-pad or stick snapped to
    8-way, or facing if nothing is held. It moves at 300px/s for 0.15s (about 45px in every direction) with
    gravity off, and the player gets one air dash per jump.
    - A diagonal that meets a surface slides along it (up a wall, along the floor). The dash only ends
      early when it's fully blocked (`get_real_velocity()`).
    - The exit runs at `max_speed` in the dash direction, with upward exits scaled by 0.75.
    - On a wall or climb, the part of the direction that points into the wall is flipped away from it.
    - A jump cancels the dash. Straight up and down use the jump and fall poses, because the pack has no
      vertical dash art.
  - **Wall slide and wall jump:** the slide caps the fall at 60px/s while holding toward a wall. The jump
    pushes away from the wall, then ignores input for 0.14s. Walls are detected with `test_move`, so a jump
    still counts briefly after drifting off a wall (wall coyote time).
    - A slide only starts when the wall covers head and feet and continues at least 8px below the feet
      (`_is_wall_full_height`). That stops a slide pose flashing when the feet clip a block corner, or on
      a 2×2 block that's barely taller than the player.
  - **Ledge grab:** catches only while `grab` is held. The player must also be falling (or climbing),
    facing a wall, with the hands within 8px of a ledge top that has standing room. It uses physics ray and shape probes, not tile reads.
    - From the hang: Up or a fresh jump press climbs, and toward the ledge never does. Away, Down, or
      releasing grab drops.
    - The climb art is drawn in place, so `CLIMB_KEYS` moves the body pose by pose. Re-measure it if the
      climb sheet changes.
  - **Push:** running into a wall on the ground plays `push`. The check uses the `_wall_side()` probe,
    because `is_on_wall()` flickers against walls. The push frames use AtlasTexture margins to sit 6px back
    and 2px down, so the hands meet the wall face. A real push/pull ability is planned.
  - **Climb** (Celeste-style):
    - **Grab:** hold `grab` facing a wall while not rising. From the ground it also needs Up. Starting needs
      the wall to cover the whole body (`_is_wall_full_height`, as for the slide), so feet-only contact never
      shows the hands gripping air. Once on, only the hands need to touch (`_is_wall_at_hands`): the player
      can climb down until hanging by the arms from a wall's bottom edge.
    - **Moving:** Up climbs at 60px/s, Down slides at 110px/s, and holding still clings.
    - **Stamina:** 3 seconds of upward climbing. Holding still drains at 0.22 times that rate, sliding down
      is free, and a climb jump costs 0.75. It refills only on the ground.
    - **Low stamina:** below 0.6 the sprite pulses red (a soft tint at 2Hz). At 0 the player lets go.
    - **Jump:** jumping while climbing climb-jumps straight up and re-grabs at the apex. Jump while holding
      away is a wall jump.
    - **Top of the wall:** climbing up hands off to the ledge hang.
  - **Ability flags:** `can_dash`, `can_wall_jump`, `can_ledge_grab` and `can_climb` are the hooks for staff upgrades.
- `levels/test_room.tscn` (the main scene) is a movement sandbox.
  - `test_room.gd` sets the camera limits and respawns the player after a fall into the pit.
  - The room contains a floor step, floating blocks, a pillar, a pit, a raised ledge and a wall-jump
    shaft between a tall column and the right wall.
- `levels/cave_tileset.tres` is the TileSet. Solid tiles get full 16×16 collision.
- `levels/cave_tile_painter.gd` (`@tool` TileMapLayer) autotiles an ASCII `layout` (`#` solid, `.` air).
  Press "Rebuild From Layout" in the Inspector to regenerate it. Layout rules:
  - air gaps of at least 2 tiles
  - free-floating blocks exactly 2×2
  - walkable tops on even rows
- **Input actions:** `move_left`/`move_right`, `move_up`, `crouch`, `jump`, `dash`, `grab` and `inventory`.
  - Keyboard: arrows or WASD to move (Up/W climbs, Down/S crouches), Space to jump, Shift to dash, Z to grab.
  - Gamepad:
    - Move: d-pad or left stick. The d-pad is the primary way the player plays, so up/down on it climb and
      crouch.
    - Jump: button 0. Dash: button 1. Grab: ZR (trigger axis 5).
    - Stick up/down maps to `move_up`/`crouch`, and ZL (trigger axis 4) also crouches.
    - Inventory: Minus (button 4, "back") or I. Nothing uses it yet.
    - The map (d-pad up in the GDD) needs a new button now that the d-pad moves.
  - Godot reads joypad buttons by **position** (Xbox layout), not by the label printed on them. On a Switch
    Pro controller, button 0 (bottom) is B and button 1 (right) is A.
  - Interact lost its button when dash moved to A. It is unassigned until a new button is picked.

## Conventions
- GDScript with static typing (`var x: float`, `:=`, typed function signatures). Tunables are `@export`.
- snake_case for files, folders, functions and variables. PascalCase for node names and `class_name`.
- Comment the *why* (feel and design intent), matching the style in `player_controller.gd`.
- Add new input actions to `project.godot`'s Input Map. Never hardcode keys.
- Docs live in `docs/` (has `.gdignore`, so Godot skips it).
