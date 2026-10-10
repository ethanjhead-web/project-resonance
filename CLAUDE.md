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
B jump · Y attack (punch) · RB grab/climb/attach (hold) · A slide on the ground while moving (down+A rolls), dash in the air (down+A dives) · ZR hold to sprint · staff throw/recall needs a new button · X and ZL unassigned · hold RB for instrument mode (X/Y/B/A play notes; RB is grab for now, so one of the two must move before the instrument is built) ·
D-pad moves (up climbs, down crouches); Minus opens the inventory; the map needs a new button. Keyboard bindings go through the Input Map.

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
  - **Dash** (`dash` action, A): air-only. On the ground the same button slides or rolls
    (`_try_start_ground_move()`, see below). Y always punches, sprint held or not. A dash with sprint held flows
    straight into a sprint. Left or right only, and left or right has
    to be held; neutral or Up does nothing (and doesn't spend the air dash). It moves at 300px/s for 0.15s
    (about 45px) with gravity off, and the player gets one air dash per jump. A **sprint dash** (after a sprinting
    takeoff with sprint still held, settled on the press as `dash_is_sprint`) lasts
    `sprint_dash_duration` (0.2s, about 60px) instead.
    - **Wind-up:** both the dash and the dive start with `ability_windup_time` (0.2s) of hanging still: the sprite
      freezes on its current frame (`speed_scale = 0`) and brightens toward `ability_windup_glow`, which
      then holds at full for the whole dash or dive, and after an air dash stays on until the dash is refilled
      (landing), then fades back over `ability_glow_fade_time`. The low-stamina climb pulse takes
      priority over the held glow. It's a stand-in
      for a power-up animation. The direction, cooldown and air dash are settled on the press.
    - **Dive** (Desolate Dive): dash with straight down held in the air (`can_dive`) drops at `dive_speed`
      (480px/s) until landing, with no steering, then holds the feet for `dive_land_time` (0.8s) frozen on
      `land`'s deepest crouch (frame 0), then plays the rest of `land` to stand up (movement cancels it). Down
      with a side held is still a sideways dash. Air-only, and it shares `has_air_dash`
      with the dash: one dash or dive per trip through the air, refilled only on the ground (not by a wall slide, climb or ledge hang).
    - **Hard landing:** a fall of at least `hard_land_height` (220px, just under the climbable column's 224px) gets the
      dive's landing recovery (`dive_land_timer`, held crouch then stand-up) without the glow. The fall is measured from
      `fall_peak_y`, the highest point since anything last held the player up (floor, wall slide, climb, ledge hang or
      wall run), so sliding down a tall wall doesn't count. It also ends an air punch.
    - It ends early on hitting a wall (`get_real_velocity()`). The exit runs at `max_speed` (sprint speed if sprint is
      still held), with no vertical speed.
    - On a wall, climb or wall run, a direction into the wall is flipped away from it.
    - **Sprint:** holding `sprint` (ZR) runs at `sprint_multiplier` (1.5x) `max_speed` while a direction
      is held. In the air it only applies if the player left the ground at sprint pace (`air_sprint`), and
      the button still has to be held; it can't be picked up mid-air. A dash with sprint held exits sideways at sprint speed, and the run cycle speeds up to match.
    - A jump cancels the dash.
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
  - **Attach** (`is_attached`): a fresh `grab` press on the ground, facing any wall at the hands (`_is_wall_at_hands`),
    holds on to it for as long as grab is held. A fresh press only, so grab held while walking along a wall doesn't
    stick the player to it. The feet stay planted and facing is
    locked to the wall: neutral plays `push_idle`, toward plays `push`, away plays `pull`. Against a plain wall it's
    pose-only. Against a **`MovableBlock`** (`levels/movable_block.gd`, a 32×32 AnimatableBody2D on the world layer,
    drawn with the 2×2 block art plus a blue bar on each side face) toward pushes and away pulls at `push_speed`
    (45px/s): the block moves first via `slide()` and the player follows exactly as far as it went, so the hands stay
    on it when it jams. A pull stops if something is behind the player. The block has its own gravity, so it falls
    off ledges (and the attach ends when it drops out of reach). It's kinematic and only moves when pushed or falling
    (a per-frame `move_and_slide()` made it creep at rest), and once nothing is pushing it, it snaps to a whole pixel
    where there's room, so it doesn't wobble against the tiles as the camera moves. Walking into a block on the ground (no grab) also
    pushes it (`_push_block_ahead()`, called from `_apply_movement()`) at the same `push_speed` as the attach: velocity is
    set outright (move_and_slide() zeroes it against the block each frame, so accelerating left it crawling), and any
    gap from the approach closes on the first frame. With sprint held it
    isn't pushed and acts as a wall, so a sprint into it wall runs and mounts the top. `_wall_at()` returns whatever
    body is at the hands (`_wall_hit()` gives the full ray hit). Letting go, a jump, or losing the wall or floor ends
    it, and Up on a grip wall starts the climb. `push_idle` uses push's AtlasTexture margins (same hand and feet
    position); `pull` reaches 1px less and stands on the ground, so its margin is `(0, 0, 10, 0)` (5px back, none down).
  - **Push:** running into a wall on the ground plays `push`. The check uses the `_wall_side()` probe,
    because `is_on_wall()` flickers against walls. The push frames use AtlasTexture margins to sit 6px back
    and 2px down, so the hands meet the wall face. A real push/pull ability is planned.
  - **Climb** (Celeste-style):
    - **Grip surfaces:** only walls marked with a `GripSurface` (`levels/grip_surface.gd`, an Area2D on physics
      layer 3 "grip", drawn as a red strip) can be climbed. `_grip_at_hands()` returns the one at the hand
      probe's end point, so the area has to straddle the wall face. Slides, wall jumps, wall runs and ledge grabs
      still work on any wall.
    - **Grab:** hold `grab` facing a grip surface while not rising. From the ground it also needs Up (pressed from
      an attach). Back on the ground with no Up held, the climb ends, into an attach if grab is still held. Starting and
      staying on both need the wall level with the hands (`_is_wall_at_hands`), and the feet don't matter.
      Feet-only contact (hands above the top) never grabs, so the hands never grip air; near the top, grab
      catches the ledge instead. The lower part of a small floating block can be grabbed from below, and a
      climb down continues until the player hangs by the arms from the bottom edge. The wall slide still
      needs head and feet (`_is_wall_full_height`).
    - **Moving:** Up climbs at 60px/s, Down slides at 110px/s, and holding still clings.
    - **Stamina:** 3 seconds of upward climbing. Holding still drains at 0.22 times that rate, sliding down
      is free. It refills only on the ground. A `GripSurface` with `drains_stamina` off (drawn green; the stand-in
      for ladders) costs nothing: no drain, no low-stamina pulse, it can be grabbed at 0 stamina, and it never
      drops the player (`climb_drains_stamina` tracks the surface under the hands each frame).
    - **Low stamina:** below 0.6 the sprite pulses red (a soft tint at 2Hz). At 0 the player lets go.
    - **Jump:** every jump while climbing is a wall jump, whatever direction is held. There is deliberately no
      Celeste-style climb jump (straight up the wall); the game aims to be more rhythmic than Celeste.
    - **Top of the wall:** climbing up hands off to the ledge hang.
  - **Wall run:** sprinting into a wall on the ground (speed at least `wall_run_min_speed`, 150px/s, with sprint held
    and the wall at the hands) runs the player up it starting at `wall_run_speed` (180px/s, the sprint speed) and
    slowing evenly to a stop at `wall_run_height` (40px, 2.5 tiles). The slowdown is solved from the two, so
    each can be tuned on its own. Toward is only needed to start it; after that
    holding sprint keeps it going, and the body is pinned to the wall whatever the d-pad says, so the jump off can
    be lined up early. It ends early on letting go of sprint, on a grab, on a jump (a wall jump), or on a ceiling.
    A wall jump out of the run is a plain wall jump (no wider push, no sprint carried), so it gains height rather
    than distance. If the hands come within `ledge_snap_range` of the top of a wall with standing room (and
    away isn't held), the player mounts it straight away with the ledge climb (no hang, no grab
    needed). `_find_ledge()` is the shared ledge probe for this and the ledge grab. It plays the climb cycle, sped up.
  - **Punch combo** (Y): a press on the ground or in the air throws a jab (`jab`, 48px sheet), and another press during it chains
    into a cross (`cross`, 64px sheet, centred so the feet line up with the 48px art). Presses are buffered for
    `attack_buffer_time` (0.2s), so mashing plays jab, cross, jab, cross. The cross can start from jab frame 3.
    Movement is locked (the run skids out under friction) until the recovery frame (jab 6, cross 5), after which
    moving or jumping cancels the guard pose. In the air every press throws a cross (no jab), and mashing repeats the
    cross. The punch keeps the jump arc
    and air steering (`_apply_air_attack_movement`), locks facing, and holds off wall slides and wall jumps until it
    ends; landing mid-punch carries on as a grounded punch, and a ledge catch ends it. Frame numbers are
    the `JAB_*`/`CROSS_*` constants.
    - `PunchHitbox` (Area2D, mask = layer 2 "enemies") has a `Jab` and a `Cross` shape that are enabled only on
      each punch's active frames (1-2) and mirrored with facing. A hit emits `punch_landed(body, hit)`; nothing
      listens yet.
  - **Crouch, roll and slide** all swap the 12×28 body box for a `crouch_height` (14px) one (`_set_low()`), so a
    one-tile (16px) gap can be crawled, rolled or slid through. The crouch art is ~20px tall, so the head overlaps a
    low ceiling a little. Standing up waits for room (`_can_stand()`, a 1px-narrower standing box): in a tunnel the
    player stays crouched with Down released until they're out. `_find_ledge()` always tests the standing box.
    - **Crouch:** Down on the ground in plain movement (`_update_crouch()`). Down plus a direction crawls at
      `crawl_speed` (45px/s). Plays `crouch_idle`/`crouch_walk`. No punches or attach from a crouch.
    - **Roll** (A while crouched: Down held, or trapped low in a tunnel): on the ground only, a fixed burst at `roll_speed` (140px/s) for `roll_duration`
      (0.35s, about 3 tiles) in the held direction (facing if none). The `roll` sheet is stretched to the duration.
      A jump cancels it, and running off an edge ends it.
    - **Slide:** A on the ground while moving (a direction held, or speed above `run_anim_threshold`); A standing
      still does nothing. Starts at `slide_speed` (150px/s, about 3 tiles), or `sprint_slide_speed` (180px/s, about
      4 tiles) at sprint pace (sprint held and faster than `max_speed`), in the held direction (else the way it's
      moving), and bleeds off at `slide_friction` (240px/s²), ending under `slide_end_speed` into a crouch
      (or standing, if Down isn't held and there's room). Plays `slide`. A jump cancels it and keeps the speed.
    - A dash windup cuts off a roll or slide. A wall run only starts from standing height.
  - **Ability flags:** `can_dash`, `can_dive`, `can_wall_jump`, `can_ledge_grab`, `can_climb` and `can_wall_run` are the hooks for staff upgrades.
- `levels/test_room.tscn` (the main scene) is a movement sandbox.
  - `test_room.gd` sets the camera limits and respawns the player after a fall into the pit.
  - **Names** (shown in-game and in the editor as `Label`s under the `Labels` node, so the user can point at things
    by name): the room is split by a dividing line of two columns, A2 (rising from the floor) and B1 (hanging from
    the ceiling), with the wall-jump shaft between them.
    - **Room A** (left of the line) contains the pit, two columns and four blocks:
      - **A1**, just past the pit (columns 30-31, y 256-352). A green `Ladder` (a `GripSurface` with `drains_stamina`
        off) covers its whole left face.
      - **A2**, the tall column (columns 41-42). A red `GripSurface` covers its left face from halfway up to the top
        (y 96-208), for practising a jump across to a climb from the floating block beside it (A6).
      - **A3**, the floor step (columns 8-11, 4×2, sitting on the floor).
      - **A4**, **A5** and **A6**, the floating 2×2 blocks, left to right (columns 13-14, 18-19 and 35-36; tops at
        y 256, 192 and 192).
    - **Room B** (right of the line, columns 49-94; the camera limits run to x 1536) is reached through a 2-tile
      doorway at the foot of B1, level with the raised ledge. It has a long sprint runway and **B2**, a thin column
      hanging from the ceiling (columns 82-84), over a 1-tile-tall roll/crawl tunnel. B2 reaches the top of the room,
      so the tunnel can't be jumped over. One-tile gaps break the painter's 2-tile rule below, so the tiles around
      them may draw a little rough.
      - **B3**, a `MovableBlock` in the middle of room B (starts at x 1152, on the floor). Its label is a child of
        the block, so the name moves with it (it isn't under `Labels`).
    - Columns and blocks share one numbering per room. Columns were numbered first, then blocks, each left to
      right. Anything new takes the next free number in its room (A7, B4...); existing names never shift.
- `levels/cave_tileset.tres` is the TileSet. Solid tiles get full 16×16 collision.
- `levels/cave_tile_painter.gd` (`@tool` TileMapLayer) autotiles an ASCII `layout` (`#` solid, `.` air).
  Press "Rebuild From Layout" in the Inspector to regenerate it. Layout rules:
  - air gaps of at least 2 tiles
  - free-floating blocks exactly 2×2
  - walkable tops on even rows
- **Input actions:** `move_left`/`move_right`, `move_up`, `crouch`, `jump`, `sprint`, `dash`, `grab`, `attack` and `inventory`. `dash` covers the dash, dive, roll and slide; which one fires depends on Down and the ground. There is no separate `roll` action.
  - Keyboard: arrows or WASD to move (Up/W climbs, Down/S crouches), Space to jump, Shift to sprint, Z to punch, C to slide on the ground or dash in the air (Down+C rolls on the ground and dives in the air), X to grab.
  - Gamepad:
    - Move: d-pad or left stick. The d-pad is the primary way the player plays, so up/down on it climb and
      crouch.
    - Jump: button 0 (B). Attack: button 2 (Y). Grab: RB (button 10). Sprint: ZR (trigger axis 5). Dash: button 1 (A), which slides on the ground (rolls with Down) and dashes in the air (dives with Down). X and ZL are free.
    - Stick up/down maps to `move_up`/`crouch`. Crouch doubles as Down, so it must never share a button with `dash`, or every air dash would dive and every slide would roll.
    - Inventory: Minus (button 4, "back") or I. Nothing uses it yet.
    - The map (d-pad up in the GDD) needs a new button now that the d-pad moves.
  - Godot reads joypad buttons by **position** (Xbox layout), not by the label printed on them. On a Switch
    Pro controller, button 0 (bottom) is B and button 1 (right) is A.
  - Interact has no button yet; X (button 3) is free. It is unassigned until a new button is picked.

## Conventions
- GDScript with static typing (`var x: float`, `:=`, typed function signatures). Tunables are `@export`.
- snake_case for files, folders, functions and variables. PascalCase for node names and `class_name`.
- Comment the *why* (feel and design intent), matching the style in `player_controller.gd`.
- Add new input actions to `project.godot`'s Input Map. Never hardcode keys.
- Docs live in `docs/` (has `.gdignore`, so Godot skips it).
