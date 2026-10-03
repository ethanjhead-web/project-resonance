# Resonance — Game Design Document

*(working title — other candidates: Cadence, Ballad, Cadenza, Cymatica)*

## 1. Elevator Pitch

A pixel-art 2D metroidvania about a boy who inherits his grandfather's staff — part walking stick, part flute, part weapon — and must relearn the songs that once kept the world's curses at bay. Movement and platforming lead the experience, punctuated by large boss fights and environmental puzzles, in the spirit of *Hollow Knight*, *Celeste*, *Fez*, *Tunic*, and *Rain World*. The core hook: the instrument that heals the land is also the key to every hidden secret, and the shapes those songs make in the world are a language the player has to learn by ear and by eye, never by text.

## 2. Inspirations & References

**Gameplay:** Ocarina of Time, Breath of the Wild, Shadow of the Colossus, Prince of Persia, God of War, Hollow Knight, Celeste, Fez, Tunic, Rain World, Cocoon

**Mood/Music:** Ocarina of Time intro, Hyper Light Drifter (Disasterpiece score), AlkaKrab tracks — *Unexplored Fields*, *Looters at the Port*, *Battle of the Skies / Epic Quest*, *Emptiness of Life*

**Music Genre:** Chill Synth / Chill and Nostalgic Synthwave / Chillwave / Retrowave.

**Artists to keep in mind:**

* (music) Emil Rottmayer — https://linktr.ee/emilrottmayer

## 3. Visual Style

* Primary: pixel art sidescroller, similar to *Celeste*
* Penusbmic Pixel Art — https://penusbmic.itch.io/
* Alternate direction under consideration: low-poly elevated third-person, similar to *Cocoon*
* Title font: Alder Road (Typeverything) — sophisticated yet decaying/crumbling, matching the world's fall from grace

## 4. World & Story

### Premise

The player character has only his grandfather left — mother, father, siblings have all left or died. The grandfather is seen throughout the intro walking with a staff. After a short tutorial (jump, climb, crawl, kick, punch) confined to the home village, the grandfather is revealed to be dying. He hands over the staff, explaining cryptically that it's "much more than a walking stick." The new long-jump it grants is the literal and thematic key that lets the player leave home — there's no family left to keep him there.

### Opening scene

Fade in on *Unexplored Fields* (AlkaKrab). Character sits on a tree branch/rock, gazing at the distant White City, hair and scarf in the wind, sand blowing. A seamless transition carries the player from this cinematic into the first playable area as the character climbs down and the camera pulls back. To the left, a small animal hums a tune on a branch — the player can't copy it yet (no staff, no knowledge that copying tunes does anything). This is the first cymatic/musical secret in the game, planted before the player has any tools to understand it.

### Villain's motive

Every temple carries a curse that drains energy and resources from its region and reroutes them to the White City's central pillar. Entering each dungeon is about severing that drain and weakening the White City's hold.

### The White City (allegory for Washington, D.C.)

Sophisticated, clean, undamaged — in stark contrast to the decaying regions around it. A gleaming white pillar (echoing the Washington Monument) rises above the clouds at its center. The city's baths and fountains are full and beautiful. Its people are largely religious zealots devoted to the pillar's "church," disconnected from the suffering their prosperity causes, and often not even aware their comfort *is* the cause. Some surrounding-region residents share this faith; a few see the truth but are powerless to act.

The market and approach to the pillar are safe; the interior turns hostile with guards and traps.

**Final boss:** fought atop a shallow pool at the pillar's peak. The antagonist floats above the player, visible only through his reflection in the water — moonlight forms a "halo" behind his head, inverting the usual sun-halo iconography associated with holiness.

## 5. World Map & Regions

Entire map is a concentric circular cymatic shape.

**Possible names:** Cymatica, Cymatia, Cymalia, Cymillia, Cymilla

### Desert / Barren Sea / Sunken Ship *(starting region)*

Once a prosperous sea port, now a desolate expanse — the largest region in the game. Sunken ship, sand-swallowed lighthouse, and a wind-inflated balloon for long-distance desert travel are its landmarks. Peaceful but inhospitable; sparsely populated; sandstorms; a visible galaxy at night.

* **Music:** Distant Horizons
* **Hazards:** quicksand/sandpits, duneslides ("snowboarding" down large dunes), sand caverns/prisons
* **Temple:** the Sunken Ship. Final boss has the ship sinking into the sand in real time — the player retraces every room just cleared, but a newly-earned ability (possibly staff-teleport) changes how those rooms are traversed the second time. Open question: should this be the *last* of the three elemental temples, for a full-circle structure?

### Old Forest / Dark Woods / Swamp / Ziggurat

Formerly lush and green, now black-barked and gnarled, stripped of vegetation — deliberately horror-inflected. Mesoamerican-style architecture culminates in a volcano/ziggurat temple.

* **Music:** Looters at the Port
* **Hazards:** falling tree limbs (platforming hazard)
* **Temple:** Ziggurat / Volcano

### Mountains / Ice World / Mine

* **Hazards:** bottomless pits, ice-slide hazards, Mario-style crushing pillars
* **Temple:** a mine, themed around mineral resources
* **Music:** Battle of the Skies / Epic Quest (final boss)

### Central Hub — White City / Main Pillar

See World & Story above.

* **Hazards:** spike traps, spinning blades, armed guards
* **Final boss beats:** "Power of Fear" (pre-boss chamber) → "Hiding in the Darkness" (confrontation)

### Spirit Plain

Reached after each temple boss is defeated; the staff is upgraded here with a new divine ability used to escape the temple.

A yellow/pink/purple gradient makes sky and ground indistinguishable. Functions as the game's fast-travel hub — once a dungeon and its holy sites are unlocked, the Spirit Plain connects them all.

Possibly moving psychedelic cymatic patterns similar to the cymatik.app.

*(Reference image from the original doc: a cymatic pattern — save it to `docs/design/references/` if needed.)*

To enter the Spirit Plain, you must play the associated song for that region at the holy spot — chromatic aberration becomes more pronounced upon playing the holy melody until eventually taking over the entire screen.

Use church symbology/imagery — stained glass and ancient architecture cymatic designs.

* **Music:** Emptiness of Life

### Connecting environments

The transitional spaces between regions are the game's platforming/survival core, styled heavily after *Rain World*. Hazards include hostile creatures, platforming challenges, and the environment itself turning lethal on a timer (desert heat at midday, mountain cold at night, forest flooding in heavy rain). Once a region's temple is beaten, its home turf becomes safe and its resident culture's "plague-handling" ways take over — but the connecting routes between regions stay dangerous throughout the game. First pass through a connector is about survival; after the relevant boss falls, certain secrets in that same space open up and the return trip is about exploration instead.

## 6. Core Gameplay Systems

### The staff

The central mechanic: one tool that is simultaneously a melee weapon, a throwable (sticks in walls for platforming, can be called back or left until you leave the room), a pole-vault for charge-jumps, and — when held via RB — a flute. It converts contexts instantly: combat, traversal, and music all run through the same object, so upgrading it upgrades everything the player can do.

**Upgrade path:** throw → magic pulse on thrown staff (possible air dash alongside) → teleport-to-staff → possible "crystal dash" (Hollow Knight-style). Each temple's entry point is sealed behind the specific upgrade earned in the previous one — map and armor help, but only the divine ability is a hard requirement.

### Combat

Concentrated mainly in temples and boss fights. Each region teaches a distinct fighting style or ability tied to its temple, expanding combat options as new regions open.

#### Boss Fights

Each boss fight is divided into two distinct sections — the fight and the escape. Combat and then platforming. Hollow Knight and then Ori.

### Traversal & movement

Climbing and wall-shimmying (Fez-inspired), crouch-to-crawl, hold-crouch-to-sit, charge jump (staff required), air dash, and eventually teleport-to-thrown-staff. Between-region routes emphasize this system hardest.

**Prototyped (test room):**
- **Dash.** A horizontal dash of about 3 tiles with gravity suspended, in the Hollow Knight style. The player gets one air dash per jump, refilled on the ground or a wall.
- **Wall slide and wall jump.** Holding toward a wall slows the fall, and jumping kicks off the wall (Celeste/Hollow Knight). Wall jumping wasn't in the original list. It's in as a feel test, and whether it stays as a base move, becomes an upgrade, or gets folded into Fez-style climbing is still open.
- **Ability gating.** Both are behind ability flags on the player, so either can become a staff upgrade.

### Music & Secrets

Certain areas play an audible tune. Copying it on the flute reveals a secret — never explained in text. Clues found on one screen frequently answer riddles on another. This is the load-bearing mechanic that the cymatics system (Section 8) builds directly on top of.

### World Map / Cartographer

There is no traditional map. A cartographer, visited between expeditions, slowly fills in a large blank map behind his counter as the player reports back on explored areas — the player never personally holds a map, since canvas and ink are scarce. This keeps players engaged with the world rather than the UI and reinforces that preparation matters.

Once the cartographer has been visited, the in-field map button zooms out 25–50% (scaling with room size) and points toward points of interest. Direction can come two ways: the staff hums louder as the player faces the correct heading (player character stops and listens), or the player plays a tune that sends a guiding light toward the next objective — again, never explicitly explained.

### Survival & Environment

Preparation for the next journey (Rain World-inspired) matters as much as the journey itself — hazards and hostile creatures are the real threat, and the cartographer marks rough climate zones so gear can be prepared ahead of time. Each biome has its own pacing: the desert is slow and methodical (a deliberate on-ramp for movement mechanics), and tempo rises with each subsequent region.

Rest points (oases) let the player sit, enjoy the view, slowly regain health, and optionally play music for a special reward. Once a region's curse is lifted, its home turf becomes fully restful and opens new paths — mirroring the traditional metroidvania "new tool unlocks new areas" beat, but tied to curing the land instead of items alone.

### Resources & Crafting

Materials gathered in the field are brought to a biome's armorer/blacksmith to build gear suited to that biome's climate. Deliberately cross-wired: the materials needed to survive a given temple's environment are found in *other* regions, not the one surrounding that temple, to encourage exploring out of sequence. Entering a temple without the right gear is technically possible but sharply reduces health/magic, rather than hard-blocking the player.

### Equipment

Hollow Knight-style charm slots ("notches") on a necklace or bracelet, offering platforming and combat perks.

### Clothing

Breath of the Wild/Ocarina-style outfit swaps tied to climate — red tunic for cold, blue for heat, etc.

### Dialogue & Language

Minimal text throughout (Hyper Light Drifter-style), except in the home desert region. Each surrounding region has its own language; the White City has its own tongue but is also home to speakers of multiple languages, reflecting its role as the political/cultural center.

## 7. Controls

| Button | Action |
| ----- | ----- |
| A | Interact |
| B | Jump |
| X | Throw staff / recall staff |
| Y | Attack |
| LB | *(unassigned)* |
| RB (hold) | Instrument mode — X + Y + B + A play notes while held |
| ZL | Crouch |
| ZR | Dash |
| D-pad Up | Map |
| D-pad Down | Inventory |

## 8. Sound-Shape System — Cymatics & Chladni Patterns as a World Language

This section proposes a concrete answer to "how do the game's songs make secrets," using cymatics (the visual patterns sound produces in a vibrating medium) and Chladni figures (the classic nodal-line patterns a single resonant frequency traces on a plate) as the actual visual grammar of the game's hidden-secret system.

### Why it fits this design specifically

The existing design already treats music as the mechanism for both revealing secrets and healing the land, and already commits to teaching everything non-verbally, the way *Fez* and *Tunic* do. Cymatics gives that idea a visual body: instead of secrets being triggered by an invisible check against a memorized melody, the *shape* a tune would make becomes a real, seeable object in the world — carved into ruins, woven into tapestries, mosaicked into temple floors, frosted onto ice walls. The player isn't memorizing notes; they're learning to recognize shapes, the same way *Tunic* players learn to recognize a made-up alphabet purely by exposure.

It also gives the villain thematic teeth for free. A single sustained tone on a plate produces a clean, rigid, perfectly symmetric figure. A chord — several tones at once — produces something denser, less symmetric, more alive. That difference maps directly onto this story's core conflict: the White City's pillar is (in-fiction) a single perfect, unchanging tone imposed on the world, draining everything into that same flat frequency. The grandfather's staff — and by extension the player's growing repertoire of melodies — represents the opposite: many notes together, imperfect, changing, alive. Cymatics gives you a way to *show* that conflict on screen rather than state it.

### Mechanic 1 — Frozen shapes as clues

Ruins, stained glass, floor mosaics, and tapestries throughout the world carry static cymatic figures — the kind of nodal-line drawings in the reference sheet (crosses, curved lattices, layered grids, increasingly dense lace patterns). Each one is the "frozen" pattern of a specific note or chord. Finding one and then reproducing its corresponding notes on the staff-flute unlocks whatever it's guarding: a door, a bridge, a cave-in that clears, a hidden room.

* Complexity communicates value without a word of text. A simple cross or X pattern (a single note, or two notes at a simple ratio like an octave or a fifth) gates a minor secret — an item cache, a shortcut. A dense, lace-like pattern (a full chord, several notes at once) gates something major — a whole hidden area, a late-game shortcut between regions. Players learn this hierarchy the same way they learn any unspoken game grammar: by testing it and seeing what they get.
* The starting humming-animal scene is the natural tutorial for this, made visual instead of purely audible: the first time the player is near a hummed tune (even before they have the staff), a faint ripple or dust pattern could stir in the sand nearby — a single-note Chladni figure the player has no tool to act on yet, planting the idea that sound and shape are connected long before the mechanic is explained.

### Mechanic 2 — Live resonance chambers

Certain rooms contain a physical medium — sand on a metal floor, dust in a still chamber, a shallow reflecting pool (which also ties neatly into the White City's water/reflection motifs) — that visibly reorganizes into a Chladni figure in real time as the player plays. This is the CymaScope idea made diegetic: rather than reading a symbol and answering it from memory, the player is actively sculpting the shape by choosing which notes to hold, and has to watch the medium respond to know if they're getting closer. It turns some puzzles into a feedback loop instead of a lookup, which suits a rhythm-based instrument far better than a static answer key.

* These rooms are a natural home for the more elaborate, multi-note puzzles — since only chords (not single notes) produce the dense, interference-heavy patterns, a live chamber puzzle can require the player to add notes one at a time and watch the pattern change, rather than just "play the right four notes in the right order."
* A late-game or optional charm ("resonance lens," or similar) could let the player see faint cymatic overlays on the world at all times — an accessibility/hint option for players who want it, without changing the base experience for players who'd rather puzzle it out cold.

### Mechanic 3 — Regional sigils

Each region's healing melody (learned after its boss falls) could be assigned its own signature chord, and therefore its own signature shape — visually distinct per biome to reinforce their identities non-verbally:

* **Desert:** wide, wavy, dune-like nodal lines — slow, low intervals
* **Forest:** jagged, asymmetric, broken lattice — dissonant intervals, reflecting the corrupted "gnarled" trees
* **Mountain/ice:** crystalline, sharply symmetric — clean fifths and octaves, echoing ice geometry
* **White City:** an unnervingly perfect mandala — the villain's "single true tone," rigid where every other region's shape is a little irregular

Once several regional melodies are learned, a late-game puzzle or the final confrontation itself could require playing them together — visually resolving into a combined pattern that overwrites or shatters the pillar's flawless mandala. That gives the final boss a natural, screen-readable climax: the player's accumulated, imperfect chord visibly breaking the villain's single perfect tone, without a line of dialogue needed to explain what's happening.

### Mechanic 4 — Music rearranges platforms

Playing the staff rearranges platforms. Solving puzzles requires you to play the right notes in the right order so that platforms arrange in ways that help you complete the room. E.g.

* Waterfalls that you can distort with sound (and then freeze) to create platforms.
* Gnarled tree branches that rearrange to different frequencies
* Rocks/boulders that move to the music
* Sand that rearranges to the staff music

### Worked example

* A simple perfect-fifth interval (two notes, a clean ratio) produces a plain crossed or diamond figure — early game, hidden in a desert ruin wall, guarding a minor resource cache. The player only needs two notes they'd have learned very early.
* A full three-note chord (the region's healing melody, once learned) produces a denser, layered figure — placed on a locked door partway through the Ziggurat, guarding a shortcut back to the Spirit Plain. This is only solvable after the player has actually learned that region's full melody, which naturally paces when this secret becomes available without any explicit gating text.
* Final boss fight is structured in a way that there are openings to play the staff, which weakens him and makes the fight somewhat easier. If you know the regional songs, then you can play these in the determined sections to damage the boss — similar to Breath of the Wild temple completions taking overall damage off the final boss, however, much more integrated into the fight. Not just one damage chunk taken off early, but available openings to damage at certain points during the fight IF you are keen to notice.

### Design caveats worth deciding early

* Should cymatic secrets ever gate *required* critical-path progress, or should they stay strictly optional (extra lore, shortcuts, cosmetic rewards)? Given the "never explicitly explained" philosophy already in the design, keeping them optional avoids a scenario where a player gets stuck without realizing a puzzle system exists at all.
* How forgiving should note-matching be? A tight tolerance rewards precision but risks frustrating players who are close but not exact; a loose tolerance keeps the puzzle-solving feeling closer to "recognize the shape" than "hit the exact input," which fits the non-verbal design goal better.

## 9. Open Design Questions

* Should the Sunken Ship actually be the last of the three elemental temples, for a full-circle structure?
* Should the resources needed for a given temple's climate be found in regions *other* than the one surrounding that temple (to encourage out-of-order exploration), as currently proposed?
* Should cymatic/Chladni secrets ever gate critical-path progress, or remain strictly optional?
