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
B jump (down+B held charges a higher jump, fired on release) · Y attack (punch) · RB grab/climb/attach (hold) · A dashes (on the ground only while moving; down+A rolls, or slides straight out of a sprint), down+A dives in the air · ZR hold to sprint · R3 turn round on a rope · staff throw/recall needs a new button · X and ZL unassigned · hold RB for instrument mode (X/Y/B/A play notes; RB is grab for now, so one of the two must move before the instrument is built) ·
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
  - **Dash** (`dash` action, A): in the air, or on the ground while moving (a direction held, or speed above
    `run_anim_threshold`), where it's the same dash, wind-up included (`_try_start_ground_move()`). A standing still
    does nothing; crouched (or with Down) it rolls, or slides straight out of a sprint (see below). A ground dash spends `has_air_dash` and an air ability (see **Air ability limit** below), but the ground refills both at once. Y always punches, sprint held or not. A dash with sprint held flows
    straight into a sprint. Left or right only, and left or right has
    to be held; neutral or Up does nothing (and doesn't spend the air dash). After it ends (however it ends) there's a `dash_cooldown` (0.8s)
    before the next one: the timer is set on the press but only counts down once the wind-up and dash are over,
    so ground dashes can't chain back to back. A refill diamond clears it. The dash glow drains with the
    cooldown (`_update_tint()` lerps on `dash_cooldown_timer / dash_cooldown`), so it's the readiness indicator: back
    to normal exactly when the next dash is ready. It moves at 300px/s for 0.15s
    (about 45px) with gravity off, and the player gets one air dash per trip through the air (within the air ability limit). A **sprint dash** (at sprint pace, `air_sprint`, which in the air means a sprinting
    takeoff, with sprint still held, settled on the press as `dash_is_sprint`) lasts
    `sprint_dash_duration` (0.2s, about 60px) instead.
    - **Wind-up:** both the dash and the dive start with `ability_windup_time` (0.2s) of hanging still: the sprite
      freezes on its current frame (`speed_scale = 0`) and brightens toward `ability_windup_glow`, which
      then holds at full for the whole dash or dive, and stays on in the air while the dash can't be used (`!_can_air_dash()`:
      spent, or the air ability limit reached) until it's refilled (landing or a diamond), then fades back over `ability_glow_fade_time`. It's a stand-in
      for a power-up animation. The direction, cooldown and air dash are settled on the press.
    - **Dive** (Desolate Dive): dash with straight down held in the air (`can_dive`) drops at `dive_speed`
      (480px/s) until landing, with no steering, then holds the feet for `dive_land_time` (0.8s) frozen on
      `land`'s deepest crouch (frame 0), then plays the rest of `land` to stand up (movement cancels it). Down
      with a side held is still a sideways dash. Air-only, once per trip through the air (`has_air_dive`), and it counts toward the air ability limit.
    - **Air ability limit:** the charged jump, the air dash and the dive each work once per trip through the air
      (`has_air_dash`, `has_air_dive`, and the charged jump only starts from the ground anyway), and
      `max_air_abilities` (`@export_range(1, 3)`, 3 for now) caps how many chain before landing, counted in
      `air_abilities_used` (`_has_air_ability_left()`). At 1 a charged jump spends the trip; at 2 it can go into a dash
      (or a dash into a dive); at 3 all three. It's the staff upgrade hook: start low, raise it. A ground dash spends a
      use too, refilled at once. Only the ground resets everything (not a wall slide, climb, ledge hang or rope); a
      refill diamond gives back the dash and one use.
    - **Hard landing:** a fall of at least `hard_land_height` (220px, just under column A6's 224px) gets the
      dive's landing recovery (`dive_land_timer`, held crouch then stand-up) without the glow. The fall is measured from
      `fall_peak_y`, the highest point since anything last held the player up (floor, wall slide, climb, ledge hang or
      wall run), so sliding down a tall wall doesn't count. It also ends an air punch.
    - It ends early on hitting a wall (`get_real_velocity()`). The exit runs at `max_speed` (sprint speed if sprint is
      still held), with no vertical speed.
    - On a wall slide, climb or wall run (`_held_wall_side()`), a dash only fires with away from the wall held;
      toward it does nothing (and doesn't spend the air dash).
    - **Sprint:** holding `sprint` (ZR) runs at `sprint_multiplier` (1.5x) `max_speed` while a direction
      is held. In the air it only applies if the player left the ground at sprint pace (`air_sprint`), and
      the button still has to be held; it can't be picked up mid-air. A dash with sprint held exits sideways at sprint speed, and the run cycle speeds up to match.
    - A jump cancels the dash.
  - **Refill and bounce diamonds:** a `RefillDiamond` (`levels/refill_diamond.gd`, an Area2D, drawn as a 20px yellow
    diamond with a `glyph` inside) polls its overlapping bodies and calls the player's `touch_diamond(launch)`. If it's
    taken, the diamond vanishes for `respawn_time` (5s, a faint outline while gone), bursting as it goes: it swells to
    `pop_scale` (2x) with an ease-out while fading out over `pop_time` (0.4s), drawn in `_draw()` with `draw_set_transform()`
    so the hitbox isn't scaled. A plain one (`%`) is only taken while
    the dash can't be used (`_can_air_dash()` false: spent, or the air ability limit reached), so it's passed through
    otherwise; a `launch` one (`&`) is always taken. Either refills the dash, gives back one air ability use (not all
    of them) and clears `dash_cooldown_timer`; the dash glow then fades back to normal. Not taken on a
    ledge or rope. A refill touched any way but a dash (falling, drifting, jumping into it) doesn't pause or interrupt
    anything. Dashing into it (`dash_timer` > 0) is a slingshot: the same freeze as a launch, then
    `diamond_shot_pending` fires a dash in `dash_direction` lasting `dash_duration * diamond_shot_length` (2.0, about
    90px) through the normal dash code (gravity off, wall stops it, jump cancels it), with the air dash still
    refilled after. A launch holds the player
    still for `diamond_freeze_time` (0.8s, `_process_diamond_freeze()`, an early return like the ledge hang, sprite
    frozen), cutting off whatever they were doing (like the dash wind-up), then sets `velocity.y` to
    `jump_velocity * sqrt(diamond_launch_height)` (2.0: twice a full jump's height, v² = 2gh) and sets `is_launched`,
    which stops a jump release cutting it short until the player starts falling.
    None are placed in the test room right now (removed while their positions get worked out); the code is all still live.
  - **Wall slide and wall jump:** the slide caps the fall at `wall_slide_speed` (80px/s) while holding toward a wall. The jump
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
    - Jump presses during the climb are dropped (not buffered). When it ends, the player counts as grounded
      (coyote refilled, wall coyote and the wall-jump lock cleared), so the next jump is a plain ground jump.
  - **Attach** (`is_attached`): a fresh `grab` press on the ground, facing any wall at the hands (`_is_wall_at_hands`),
    holds on to it for as long as grab is held. A fresh press only, so grab held while walking along a wall doesn't
    stick the player to it. The feet stay planted and facing is
    locked to the wall: neutral plays `push_idle`, toward plays `push`, away plays `pull`. Against a plain wall it's
    pose-only. Against a **`MovableBlock`** (`levels/movable_block.gd`, a 32×64 AnimatableBody2D on the world layer,
    drawn like a painter-built 2-wide column (block-art caps top and bottom, side-wall bricks between) plus a blue bar on each side face) toward pushes and away pulls at `push_speed`
    (44px/s): the block moves first via `slide()` and the player follows exactly as far as it went, so the hands stay
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
      layer 3 "grip", drawn as a green strip) can be climbed. `_grip_at_hands()` returns the one at the hand
      probe's end point, so the area has to straddle the wall face. Slides, wall jumps, wall runs and ledge grabs
      still work on any wall.
    - **Grab:** hold `grab` facing a grip surface while not rising. From the ground it also needs Up (pressed from
      an attach). Back on the ground with no Up held, the climb ends, into an attach if grab is still held. Starting and
      staying on both need the wall level with the hands (`_is_wall_at_hands`), and the feet don't matter.
      Feet-only contact (hands above the top) never grabs, so the hands never grip air; near the top, grab
      catches the ledge instead. The lower part of a small floating block can be grabbed from below, and a
      climb down continues until the player hangs by the arms from the bottom edge. The wall slide still
      needs head and feet (`_is_wall_full_height`).
    - **Moving:** Up climbs at 60px/s with the climb cycle; Down slides at `wall_slide_speed` (80px/s) with the
      frame frozen (a slide, not a climb, the same on ladders and ropes); holding still clings.
    - **No stamina** for now: a climb lasts as long as grab is held. (A Celeste-style stamina bar and the
      free-to-climb ladder variant were removed; bring them back from git history if wanted.)
    - **Jump:** every jump while climbing is a wall jump, whatever direction is held. There is deliberately no
      Celeste-style climb jump (straight up the wall); the game aims to be more rhythmic than Celeste.
    - **Top of the wall:** climbing up hands off to the ledge hang.
  - **Rope swing:** a `SwingRope` (`levels/swing_rope.gd`, an Area2D on physics layer 4 "rope" with a segment
    shape, drawn as a line) hangs `length` px from its position. It owns its swing (`angle`, `angular_velocity`) and
    settles on its own under `free_damping` when nobody holds it.
    - **Catch:** grab held in the air (rising or falling), with the rope inside `rope_catch_size` around the hands
      (`_try_catch_rope()`), anywhere along it. The swing starts at once from the rope's own angular velocity plus the
      player's velocity across the rope (the tangent component, over the hold distance), so a dash in swings hard and a
      jump up from below barely moves it. It's capped at what a full pump would give (`_cap_swing()`), so a fast catch
      can't loop over the anchor. The air dash is not refilled (a dash spent reaching the rope stays spent until landing). The buffered jump is cleared so it doesn't fire straight
      off the rope. The hands use `ledge_hand_offset`. Facing is fixed except for `turn` (R3 / F), which swaps the
      player to the other side of the rope if there's room for the body there.
    - **Animation** (`_update_swing_animation()`, after the swing moves), first match wins: `ledge_hang` in the release
      window (`_in_release_window()`: on the side the player faces, going out or coming back, in the outer
      third of a full swing (from `rope_max_angle` / 3 out to `rope_max_angle`, 20-60°, the same on every rope), on a swing at least
      `rope_release_min_swing` (50°) high, which the height cap only allows in the lowest quarter of the rope); the climb sheet cycling climbing up the rope, frozen on its current frame sliding down; then single
      held frames (`_hold_frame()`): `pull` frame `ROPE_PULL_FRAME` (2) while holding away from facing, else `climb` frame 0. The sprite leans with the rope
      (`_tilt_sprite()`, rotation `-angle` about the hands, so they stay on it); the 12×28 body box stays upright. A
      plain release straightens it at `rope_tilt_return_speed`, and a jump off snaps it upright for the somersault.
    - **Swing** (`_process_swing()`, an early return like the ledge hang): a pendulum from the anchor to the hands
      using the player's `gravity`. Holding the way it's already swinging pumps it (`rope_pump_accel`, 88) until its
      energy reaches the height cap (`_swing_max_angle()`): `rope_max_angle` (60°) holding the rope's end, shrinking
      evenly to `rope_top_max_angle` (20°) at `rope_min_hold`, so higher up is a tighter swing that can't throw as wide.
      Holding against it brakes (`rope_brake_accel`, 176, twice the pump, so steadying the rope is quicker than swinging it up);
      both are for a rope `rope_pump_reference_length` (168px) long and scale inversely with length (`_rope_length_scale()`),
      so a longer rope takes more passes to pump up: a 168px rope reaches full height after three back-and-forth swings of
      well-timed pumping (six sweeps; a 104px rope takes about two);
      `rope_damping` bleeds a little off. The pump has to follow the swing: once a pass has been spent pushing toward a
      side, that side won't pump again until the other way is pressed (`pump_spent_side`), so holding one direction
      pumps once and then slowly dies under the brake. Starting from still isn't a turn, so the push that starts the
      swing belongs to its first pass. Hanging still at the bottom, any direction starts it. Up climbs the hands along the rope (except in the release window, while `ledge_hang` shows)
      at `rope_climb_speed` and Down slides them at `wall_slide_speed`, leaving the swing alone: the pendulum always runs on the rope's full length (`_swing_length()`), not the hold, so the tempo is the same wherever the player holds on and climbing never speeds or pumps the swing (a real shortening pendulum did both, whipping a still rope into a frantic swing near the top). The hold only sets the height cap (which stops the pump, not the swing: a climb never cuts a big swing down to it) and how fast the hands move. Only the pump adds height. Hitting something stops it dead.
    - **Release:** letting go of grab drops with the swing's velocity. So does sliding down off the end of the rope, even with grab held (plus the slide speed along the rope). A jump adds `rope_jump_boost` (at least that
      much upward) and multiplies the sideways speed by `rope_jump_carry` (1.2), plus `rope_window_jump_boost` (120px/s) toward
      facing if it's in the release window, locks air steering for `rope_release_lock_time` via `wall_jump_lock_timer`, and turns to face the
      launch. It plays `air_spin` (the pack's somersault, 6 frames at 18fps, once through; `is_air_spinning`)
      until it finishes, the player lands, or another state takes the sprite. The rope just let go of is ignored for `rope_regrab_delay` after either (`rope_regrab_rope`); other ropes can be caught at once, so routes chain rope to rope. No dash or punch from the rope.
  - **Wall run:** sprinting into a wall on the ground (speed at least `wall_run_min_speed`, 152px/s, with sprint held
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
  - **Crouch, roll and slide** all swap the 12×28 body box for a `crouch_height` (12px) one (`_set_low()`), so a
    one-tile (16px) gap can be crawled, rolled or slid through. The crouch art is ~20px tall, so the head overlaps a
    low ceiling a little. Standing up waits for room (`_can_stand()`, a 1px-narrower standing box): in a tunnel the
    player stays crouched with Down released until they're out. `_find_ledge()` always tests the standing box.
    - **Crouch:** Down on the ground in plain movement (`_update_crouch()`). Down plus a direction crawls at
      `crawl_speed` (44px/s). Plays `crouch_idle`/`crouch_walk`. No punches or attach from a crouch.
    - **Roll** (A while crouched: Down held, or trapped low in a tunnel): on the ground only, a fixed burst at
      `roll_speed` (140px/s) for `roll_duration` (0.35s, about 3 tiles) in the held direction (facing if none). The `roll` sheet is stretched to the duration. A jump cancels it, and running off an edge ends it.
    - **Slide:** Down+A (or A while crouched) within `slide_sprint_window` (0.2s) of last being at sprint pace on the
      ground (`slide_window_timer`, refreshed while `air_sprint` is true, sprint held and faster than `max_speed`, but not
      by a dash or the slide itself); otherwise it's the roll, so a crawl or walk never slides. Starts at `slide_speed`
      (180px/s, about 4 tiles) in the held direction (else the way it's moving), and bleeds off at `slide_friction` (240px/s²), ending under `slide_end_speed` into a crouch
      (or standing, if Down isn't held and there's room). Plays `slide`.
    - **Slide jump** (`_slide_jump()`): a jump during the slide, or within `coyote_time` of sliding off a ledge
      (`slide_coyote_timer`), is a low long jump (cuttable): `slide_jump_height` (0.6) of a normal jump's height, with
      `slide_jump_boost` (120px/s) added to the slide's speed (about 138px on the flat from a full 212px/s slide, against
      114 at normal height). It plays `air_spin` and sets `is_carrying_momentum`:
      in the air, `_apply_movement()` doesn't ease the speed back to run speed while forward is held, or brake it while
      nothing is held; only steering against it slows it. It lasts until landing; any other jump (`_consume_jump()`
      clears it), a dash or dive windup, a climb, ledge grab, rope catch or diamond freeze also clears it.
    - **Under a low ceiling** (low box and `_can_stand()` false, e.g. the tunnel under C1) jump does nothing: the
      press isn't buffered and any buffered press is dropped, so there's no hop into the ceiling, no charge, and no
      jump cancel of a roll or slide.
    - **Charged jump** (`can_charge_jump`): jump pressed with Down held on the ground (`is_crouching`, and Down
      itself held) starts `is_charging_jump` (never in a tunnel: see below). After the press only
      jump needs holding; the charge keeps the crouch (and the low box) itself. The player is planted (skids out like a
      punch, `_apply_jump_charge()`), with no dash, punch, attach or climb. Releasing jump fires it. A release before
      `charged_jump_min_time` (0.15s) is a plain jump that doesn't spend an air ability; past it, the jump counts as
      one, and the height grows evenly from a normal full jump at `charged_jump_min_time` to `charged_jump_max_height`
      (2x) at `charged_jump_time` (1.6s), as `jump_velocity * sqrt(multiple)`. It sets `is_launched`, so it can't be cut short. The sprite holds `crouch_idle` frame
      `CHARGE_CROUCH_FRAME` (3, the lowest head) and brightens toward `ability_windup_glow` over the charge. Once
      full it pulses smoothly down toward `charged_jump_flash_color` (normal colour) and back every
      `charged_jump_flash_period` (0.5s, 2 a second, under the 3-a-second photosensitivity limit) until released.
      Brighter than the glow barely shows (it already saturates the sprite), hence the dip. After takeoff the glow
      fades from wherever it had got to. Losing the floor cancels it.
    - A dash windup cuts off a roll or slide. (A standing roll was tried and replaced by the ground dash; it's in git history.) A wall run only starts from standing height.
  - **Slope slide** (`SlideSlope`, `levels/slide_slope.gd`): a `@tool` StaticBody2D right triangle on the world
    layer, origin at the top-left of its bounding box, with `size` (px) and `downhill` (`LEFT`/`RIGHT`, the way the
    slope runs down; `RIGHT` puts the upright side on the left). Its collision is a CollisionPolygon2D built in code.
    Drawn as a filled triangle with a bright edge and ticks across the slope, so it reads by shape as well as colour.
    The upright side and base are plain wall and floor/ceiling. Slopes must be 45° or shallower, or they count as
    walls, not floor.
    - Touching the slope (`_slide_slope_normal()`, from this frame's slide collisions, so a landing slides at once)
      starts `is_slope_sliding` unless a dash or windup is running (it slides once that ends). It cancels a dive, a
      hard landing's recovery, a roll, slide, charge or punch. The body keeps the standing box (the low box on a
      slope would read as trapped, and jump would do nothing).
    - **Running up:** on a slope no steeper than `slope_max_run_up_angle` (40°), holding the uphill direction (and not
      already sliding) is plain movement, not a slide: `_apply_movement()` eases the target speed to
      `slope_uphill_speed_multiplier` (0.8) of the run or sprint. Let go (or hold downhill) and the slide takes over.
      Jumping is a normal ground jump. The sprite drops onto the slope (`_lean_on_slope(false)`, upright) so the feet
      don't float. Steeper slopes (C2, C3) can't be run up:
      `_steep_slope_ahead()` stops the run flush at their foot in `_apply_movement()`, like a wall, and `_is_wall()`
      counts their face as a wall on the ground (so the push plays) but never in the air (no wall slide or wall jump
      off a slope).
    - `_apply_slope_slide()`: a constant `slope_slide_speed` (180px/s) straight down the slope, plus
      `SLOPE_STICK_SPEED` into it so the slope is reported every frame. Nothing held steers it, and no dash, punch,
      attach, climb or crouch starts. It counts as ground (coyote, air dash and air abilities refill).
    - Jump kicks off at right angles to the slope (`_slope_kick()`): `slope_normal * slope_kick_speed` (340: on a
      45° slope a full jump's 240 up and 240 out; the slide's own speed isn't added, so it's the same push every time),
      steering locked for `slope_kick_lock_time` (0.15s) via
      `wall_jump_lock_timer`, and `air_spin` via `_start_air_spin()` (shared with the rope jump). It's cuttable like
      any jump. Sliding off the end into the air keeps the slide's velocity, and a jump within `coyote_time`
      (`slope_coyote_timer`) still kicks off the slope. Reaching flat ground carries on into the ground slide
      (`is_sliding`) at `slope_slide_speed`, which bleeds it off.
    - Plays `slide`, tilted to the slope about the feet (`_lean_on_slope()`) and dropped by half the box width times
      the slope, since the upright box rests on its uphill corner. It straightens afterwards at
      `rope_tilt_return_speed`.
  - **Ability flags:** `can_dash`, `can_dive`, `can_wall_jump`, `can_ledge_grab`, `can_climb`, `can_wall_run` and `can_charge_jump` are the hooks for staff upgrades, along with `max_air_abilities` (1-3).
- `levels/test_room.tscn` (the main scene) is a movement sandbox.
  - `test_room.gd` sets the camera limits and respawns the player after a fall into the pit.
  - **Names** (shown in-game and in the editor as `Label`s under the `Labels` node, so the user can point at things
    by name): the room is split by a dividing line of two columns, A6 (rising from the floor) and B1 (hanging from
    the ceiling), with the wall-jump shaft between them. Columns and blocks share one sequence per room, numbered
    left to right. Every room is 40 tiles (640px) wide inside, measured between the faces of the walls or columns
    that bound it (room A runs from the left wall's face at x 16 to A6's at x 656). Room titles are centred in that
    span.
    - **Room A** (left of the line) contains the pit and:
      - **A1**, the floor step (columns 8-11, 4×2, sitting on the floor).
      - **A2** and **A3**, floating 2×2 blocks (columns 13-14 and 18-19; tops at y 256 and 192).
      - **A4**, the column just past the pit (columns 30-31, y 256-352). A `GripSurface` named `Ladder` covers its
        whole left face.
      - **A5**, a floating 2×2 block (columns 35-36, top at y 192).
      - **A6**, the tall column (columns 41-42). A `GripSurface` covers its left face from halfway up to the top
        (y 96-208), for practising a jump across to a climb from A5.
    - **Room B** (columns 49-88, between B1 and C1) is reached through a 2-tile doorway at the foot of B1, level
      with the raised ledge. It has a long sprint runway and:
      - A rope-to-rope practice line between B1 and C1: step, rope, rope, step. The two ropes split the 640px
        between B1's right face (x 784) and C1's left face (x 1424) into equal thirds, rounded to whole pixels
        (213, 214, 213). Rope labels sit beside the knot, under `Labels`.
      - **B2** and **B6**, one floating 2×2 step per side (columns 53-54 and 83-84, tops at y 192), 4 tiles out from
        B1's and C1's faces. The top is out of reach from the floor, even with a ledge grab (a jump gets the hands to
        about y 217; the grab needs them within 8px of the top). Standing on B4 (top y 256) the hands reach about
        y 153, so a jump from it lands on a step outright.
      - **B3** and **B5**, `SwingRope`s (150px, ends at y 166) at x 997 and 1211 (`SwingRopeLeft`/`SwingRopeRight`).
      - **B4**, a `MovableBlock` (starts at x 1104, the middle of the room, on the floor), numbered by its starting
        spot. Its label is a child of the block, so the name moves with it (it isn't under `Labels`).
    - **Room C** (columns 92-131, between C1 and the right wall at column 132; the camera limits run to x 2128) is
      a slide-slope playground, with a floor level with room B's. Climb C1's right face, jump across to C2, slide
      or kick down to C3, then on to the floor. C2-C4 are `SlideSlope`s (`SlideSlopeC2` etc.), labelled inside
      their bottom corner under `Labels`.
      - **C1**, a thin column hanging from the ceiling (columns 89-91), over a 1-tile-tall roll/crawl tunnel, so
        room C is reached by rolling or crawling under it. It reaches the top of the room, so the tunnel can't be
        jumped over. A `GripSurface` named `C1Grip` covers its right face from the tunnel's top to the ceiling
        (y 16-304). One-tile gaps break the painter's 2-tile rule below, so the tiles around them may draw a
        little rough.
      - **C2**, a 4×4-tile (64px) 45° slope running down to the right, 3 tiles out from C1 (x 1520-1584,
        y 96-160), 80px below the ceiling so there's room to jump across from the wall.
      - **C3**, the same, lower and further right (x 1680-1744, y 192-256).
      - **C4**, a 6×4-tile (about 34°) slope on the floor running down to the left (x 1776-1872, y 256-320), 2 tiles
        past C3's tip, so a kick from anywhere on C3's upper half (holding right) lands on it. Shallow enough to run
        up (holding right), at 0.8 of the pace; let go and it slides back. Its top is 64px up, low enough to jump onto from the
        floor beside it.
    - Names stay in left-to-right order: something new is numbered by its position and anything after it shifts up
      one. Tell the user whenever an existing name changes.
- `levels/cave_tileset.tres` is the TileSet. Solid tiles get full 16×16 collision.
- `levels/cave_tile_painter.gd` (`@tool` TileMapLayer) autotiles an ASCII `layout` (`#` solid, `.` air).
  Press "Rebuild From Layout" in the Inspector to regenerate it. Layout rules:
  - air gaps of at least 2 tiles
  - free-floating blocks exactly 2×2
  - walkable tops on even rows
- **Input actions:** `move_left`/`move_right`, `move_up`, `crouch`, `jump`, `sprint`, `dash`, `grab`, `attack`, `turn` and `inventory`. `dash` covers the dash, dive, roll and slide; which one fires depends on Down, sprint and the ground. There is no separate `roll` action.
  - Keyboard: arrows or WASD to move (Up/W climbs, Down/S crouches), Space to jump (hold with Down to charge), Shift to sprint, Z to punch, C to dash (on the ground only while moving; Down+C rolls on the ground, or slides straight out of a sprint, and dives in the air), X to grab, F to turn round on a rope.
  - Gamepad:
    - Move: d-pad or left stick. The d-pad is the primary way the player plays, so up/down on it climb and
      crouch.
    - Jump: button 0 (B). Attack: button 2 (Y). Grab: RB (button 10). Sprint: ZR (trigger axis 5). Dash: button 1 (A), which dashes in the air and on the ground while moving (with Down: rolls on the ground, or slides straight out of a sprint; dives in the air). Turn (on a rope): R3 (button 8, right stick click). X and ZL are free.
    - Stick up/down maps to `move_up`/`crouch`. Crouch doubles as Down, so it must never share a button with `dash`, or every air dash would dive and every ground dash would roll.
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
