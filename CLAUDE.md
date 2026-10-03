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
- `node_2d.tscn`: test scene (main scene) with a placeholder player and a floor.
- `player_controller.gd`: CharacterBody2D movement. Accel/friction, asymmetric gravity, coyote time,
  jump buffering, variable jump height. All values tuned via `@export`.
- Input actions defined so far: `move_left`, `move_right`, `jump`.

## Conventions
- GDScript with static typing (`var x: float`, `:=`, typed function signatures). Tunables are `@export`.
- snake_case for files, folders, functions and variables. PascalCase for node names and `class_name`.
- Comment the *why* (feel and design intent), matching the style in `player_controller.gd`.
- Add new input actions to `project.godot`'s Input Map. Never hardcode keys.
- Docs live in `docs/` (has `.gdignore`, so Godot skips it).
