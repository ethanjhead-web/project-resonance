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
A interact · B jump · X throw/recall staff · Y attack · hold RB for instrument mode (X/Y/B/A play notes) ·
ZL crouch · ZR dash · D-pad up for map, down for inventory. Keyboard bindings go through the Input Map.

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
- `levels/test_room.tscn` (the main scene) is a movement sandbox.
  - `test_room.gd` sets the camera limits and respawns the player after a fall into the pit.
  - The room contains a floor step, floating blocks, a pillar, a pit and a raised ledge.
- `levels/cave_tileset.tres` is the TileSet. Solid tiles get full 16×16 collision.
- `levels/cave_tile_painter.gd` (`@tool` TileMapLayer) autotiles an ASCII `layout` (`#` solid, `.` air).
  Press "Rebuild From Layout" in the Inspector to regenerate it. Layout rules:
  - air gaps of at least 2 tiles
  - free-floating blocks exactly 2×2
  - walkable tops on even rows
- **Input actions:** `move_left`/`move_right` and `jump`.
  - Keyboard: arrows or A/D to move, Space to jump.
  - Gamepad: d-pad or left stick to move, and joypad button 0 to jump. Button 0 is the bottom face
    button, which is B on a Switch layout, matching the GDD.

## Conventions
- GDScript with static typing (`var x: float`, `:=`, typed function signatures). Tunables are `@export`.
- snake_case for files, folders, functions and variables. PascalCase for node names and `class_name`.
- Comment the *why* (feel and design intent), matching the style in `player_controller.gd`.
- Add new input actions to `project.godot`'s Input Map. Never hardcode keys.
- Docs live in `docs/` (has `.gdignore`, so Godot skips it).
