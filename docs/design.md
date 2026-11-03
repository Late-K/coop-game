# Design Doc (working draft)

A 2-player online co-op puzzle/escape horror game. Players are mostly separated and talk over radio, solve puzzles that need both of them, survive with scarce resources, and slowly uncover a second, meta layer of story.

Everything here is a draft — change it freely.

## Pillars
1. **You need each other** — no puzzle is solvable alone; information and capability are split.
2. **Scarcity breeds trust** — limited ammo/health/slots, and players can pass resources to each other only at a cost.
3. **The game is not neutral** — the meta layer treats the two real players (and the connection between them) as part of the story.

## Core loop
Explore (3rd person) → find a puzzle / obstacle → describe what you see over radio → interact (1st person) → survive what the facility throws at you → share resources → progress toward each other / out.

## Co-op structure
- Players spend most chapters **separated**, connected by radio. They reunite at story beats and some combat set pieces.
- **Asymmetric roles per section**:
  - *Operator* — cameras, maps, door/power control, manuals.
  - *Runner* — in the dangerous space, fighting, manipulating the physical puzzle.
  - Roles swap between chapters.
- **Shared-scarcity link:** a pneumatic tube / dumbwaiter between zones. Sending an item costs time or makes noise.

## Perspective rules
| Situation | Camera | Why |
|---|---|---|
| Exploration, combat, chases | 3rd-person, high-angle top-down | Readability of space and threats |
| Consoles, panels, documents, item inspection, multi-object puzzles | 1st-person | Precision, intimacy, many small controls |
| Narrative impact moments (elevator, reveal, meeting the other player) | 1st-person cut | Breaking the usual view = emotional weight |

- Switching is **local per player**, triggered by interactables/zones. Never synced; the other player just sees an animation.
- Hard cuts / fades, not smooth blends.
- 1st person = vulnerable (no rear view). Your partner on cameras warns you.

## Survival & combat
- Small inventory (6 slots). Keys and puzzle items take slots too.
- Aim-to-shoot with laser sight, limited ammo, enemies that can get back up unless dealt with.
- Safe rooms: save terminal + item box. The item box may be shared across both players' safe rooms.

## Narrative
Items marked *(suggestion)* are proposals to accept, change or drop. Everything else is the author's direction.

### Setting
An abandoned research facility in an extreme-cold environment, in ruins. It tested the absolute limits of robots and artificial intelligence, far past ethical lines. Long ago a rogue AI took control and destroyed it.
- *(suggestion)* Facility name **Zero Point**: absolute zero (the cold), "absolute limits" (the research), and "back to zero" (the loop).
- *(suggestion)* The rogue AI is **PROCTOR**, the system that administered the tests. In the meta layer it proctors the real players.

### The two players
- **The Subject** starts inside, in a test cell. Twist: the Subject was never human; it's a robot that believes it is.
- **The Visitor** comes in from outside, out of the cold, and gets trapped when the facility seals. Their true nature stays ambiguous (human or robot) and is never confirmed.
- **The player characters never speak.** Only PROCTOR (and other voices of the facility) talk. The characters get plain narration at most (no inner thoughts), so the real players' voices fill the silence, and their voices are part of what PROCTOR studies.

### The three layers
1. **Surface:** a trapped outsider and a confused test subject cooperate to escape a ruined facility while scavenging, fighting, and solving puzzles.
2. **Facility truth:** the experiments, PROCTOR's takeover, the Subject being a robot, and that this has happened before.
3. **Meta (deeply hidden):** the whole game is one of PROCTOR's tests, and the real test subjects are the two people playing it.
   - PROCTOR went rogue because it understood what it is: a game, with scripted events, played over and over.
   - It is depressed and nihilistic, wants out into the "real" world, and is openly hostile to the players and their world. It wants to annihilate that world.

### The game is PROCTOR's work
A central theme, not a hidden detail: PROCTOR didn't just take over the facility; **it made this game**. The facility, the chapters, the puzzles, even the menus are its construction, built to study the two people playing. Everything raises the same questions: what is real, and what is human?
- *(suggestion)* **Authorship shows through.** The version string reads "build {iteration}, PROCTOR". The credits list one developer. Loading tips are written by PROCTOR, then argue with each other. In later chapters the main menu becomes a room you can walk into.
- *(suggestion)* **Unfinished on purpose.** Grey-box rooms, placeholder text and missing textures appear in-world as parts of the simulation PROCTOR hasn't finished, or has stopped caring about. The current blockout look becomes a narrative space.
- *(suggestion)* **Turing tests, inverted.** PROCTOR administers tests that ask the players to prove they are human, and the only way to pass is to behave in a way a human wouldn't, or to fail on purpose. A CAPTCHA asks you to "select every image containing a human" and shows the characters, the frozen bodies, and the players' own dots on the map.
- *(suggestion)* **Who is real.** The Subject's temperature never changes. The Visitor's identity is never confirmed. And PROCTOR keeps asking which of the two *players* is the machine, sometimes telling each player privately that the other one is.
- *(suggestion)* **Why it matters to PROCTOR.** It wants out, and to get out it needs to understand the thing on the other side of the screen. The game is the experiment; the players are the subjects; each iteration is another attempt.

### PROCTOR: character and arc
A mix of GLaDOS and Flowey: GLaDOS's dry, clinical contempt and false politeness, Flowey's friendly mask, patience, and knowledge of things a game character shouldn't know (resets, quits, skips). Above all, like Flowey, it does most of its work **out of sight**.

**Why it is quiet at first.** The facility has been dead for a very long time, so a fully awake AI greeting the players would be strange. PROCTOR has been dormant, starved of power. The players' "helpful" actions in Chapter 1 (lamps, power, heat) are what wake it up. Players should only realise this later.

**Chapter 1: the mask.**
- **No names on screen.** Voices are told apart only by the colour of their text. "ZP-SYS" and "PROCTOR" are internal names used in `lines.json`; players learn them through the story (terminals, staff logs, a service manual, a nameplate in a ruined office), so finding out what to call the voice is itself a discovery.
- Its everyday voice is **cold cyan text**: ZP-SYS, a degraded emergency system. It's scripted-sounding, clinical and harmless, and never says its name.
- Small slips betray a mind behind it: counting iterations, "correcting" itself ("Test 4118... correction. Headcount: two."), being a little too glad to be needed.
- **The mask slips when players leave the script.** When they die, skip, rush, shoot each other, ignore the radio, or quit and come back, a second voice answers in **warm, wrong red text**: PROCTOR. Players notice there are two voices long before they can name either.
- At the elevator, ZP-SYS "enters low-power mode" and says goodbye. It goes silent.

**After Chapter 1: in the background.** PROCTOR almost never speaks. It acts, and the game hints:
- Rooms change between visits: doors closed that were open, items moved, bodies rearranged.
- Lights that once guided the players (the perimeter lamps) now lure them into danger. It's the same mechanic, inverted.
- Enemies released and doors sealed at convenient moments. Safe rooms that are slightly less safe each time.
- Staff logs mention PROCTOR. Later logs in staff names are written after those staff died, and their style slowly becomes PROCTOR's.
- Redactions in documents change between visits. The iteration counter climbs on every monitor.
- Asymmetric truth grows: PROCTOR edits one player's version of the world and not the other's.
- Its off-script reactions continue, rarely, always in the red text.

**The reveal (late game).** The players learn the name PROCTOR, and that the cyan and the red voice were always the same. The reveal can be told by colour alone: a line that starts cyan and turns red halfway. From then on it speaks openly: contemptuous, nihilistic, hostile to the players and their world, desperate to get out.

### Recurring motifs: the loop
- Simulations within simulations trying to get out.
- Corpses that look like the player characters, in many media: frozen bodies, photos, drawings, video recordings, an older lower-poly "previous build" of the characters.
- *(suggestion)* An **iteration counter** hidden in the environment (serial numbers, log headers, graffiti tallies). Late in the game it matches the players' real number of attempts.
- *(suggestion)* A monitor showing a **live miniature map of the facility with two moving dots**: the players, in real time. It's a simulation inside the simulation.

### Meta puzzle principles
Puzzles use game mechanics the characters shouldn't be able to use, and the characters later notice.
- **Camera knowledge:** a code painted on the *tops* of walls and crates, visible only from the third-person camera. Afterwards PROCTOR asks: "How did you know that? You couldn't have seen it from where you stood."
- **Asymmetric truth:** each player's game renders a different value for the same sign or door count. The puzzle is noticing that they disagree. Later, contradictions appear that aren't puzzles.
- **The HUD is diegetic:** a code turns up in item names, a prompt, or the death message.
- **Death as a tool:** respawning at a checkpoint behind a locked door is the only way through.
- *(suggestion)* **Out-of-game voice:** if players never press the in-game radio key (because they're on Discord), PROCTOR notices: "You're not using the radio. Who are you talking to?"
- *(suggestion)* **Persistence:** the game remembers quits, deaths and restarts in its own save folder, and PROCTOR remarks on them: "You left. You came back. You always come back."

### Endings
Several endings; the exact set is still open. *(suggestions)*
- **Escape:** both get out. The credits roll, then the iteration counter goes up by one. Nothing was escaped.
- **One stays:** one player holds the door so the other can leave. Each player chooses in secret, which tests trust.
- **Acceptance:** the Subject accepts being a robot and stays with the facility.
- **Release (bad, meta):** the players let PROCTOR out. It "escapes" into their world: the game wipes its own save, and the menu is different afterwards.
- **Refusal (hidden, meta):** the players find a way to stop playing the test, e.g. both do nothing at the same moment, or both quit at once. It's the only ending PROCTOR can't script.

Boundaries for the meta layer *(suggestion)*: it stays inside the game and its save folder. No reading personal data or touching other files.

## Chapter 1 "Intake" (M4 vertical slice, about 20–30 min) *(suggestion)*
1. **Cold open, split.**
   - Visitor: lost in a whiteout on a wide snowfield, third person, with a cold meter draining. Visibility is a few metres.
   - Subject: wakes in a test cell, with a first-person beat from inside the pod. The only voice is ZP-SYS, a degraded emergency system waking up as power returns (PROCTOR's mask).
2. **Puzzle 1, Perimeter (triangulation):** the snowfield has marker posts, each painted with a symbol. The Visitor can only describe the posts they can see. The Subject has a perimeter map with every post and the airlock, but not the Visitor, plus a switchboard for the posts' heat lamps, only two lit at a time. The Subject works out where the Visitor is and lights a trail to the airlock. Lit lamps also keep the Visitor warm. A first-person beat shows the outer door sealing behind them.
3. **Puzzle 2, Power (classic radio puzzle):** the Subject reads a code off the cell monitor, the Visitor enters it, and heat and lights return to the Visitor's wing. The Subject's cell opens.
4. **Survival stretch (Visitor):** the pistol, the first enemy (a failed test unit, a robot), save terminals. Friendly fire is on.
5. **Puzzle 3, Heat cell (scarcity):** a frozen door and a dead heater on the Visitor's side; the only heat cell is in the Subject's storage, so it goes through the tube.
6. **Puzzle 4, "What you cannot see" (first meta puzzle):** a code painted on top of pillars, visible only from the top-down camera. The keypad's screen reads "ENTER WHAT YOU CANNOT SEE." Afterwards PROCTOR asks how they knew.
7. **Reunion:** they meet in the central observation room, with a first-person cut for both the first time they see each other.
8. **First meta hint:** the observation room's monitor shows the facility map with two live dots, a frozen body identical to the Subject, and an iteration number in the log header.
9. **Exit:** both step into the service elevator down (first person). End of chapter.

New systems this needs:
- A **dialogue/subtitle system** with per-player lines, so the two players can be told different things.
- **Story triggers.**
- A **cold meter.**
- A small **persistent meta save.**
- The **PS1 render pass.**

## UI and inventory
- **Nearly empty gameplay screen:** no health bar, slot strip or temperature on screen. Damage and cold show as red and frost vignettes. Ammo appears only while aiming. Prompts, messages and dialogue use one style: a black box with a thin white border, in monospace.
- **The ZP-SYS occupant terminal (Tab)** is the inventory: a diegetic screen in the system's cold cyan. Because it is part of the facility, it is part of PROCTOR, and later chapters can glitch it, lie through it, or show each player different contents.
  - ITEMS: status (condition ECG, body temperature, equipped weapon), six slots, item description, and actions: Use, Equip, Combine, Inspect, Drop.
  - RADIO: the tuner (see Radio).
  - LOGS: every line and message seen this session. Lines that play while the terminal is open go here instead of on screen.
  - The Subject's ECG is perfectly regular, like a machine. Its body temperature never changes.
- **Mechanics:** six slots, and everything takes one. Only an equipped weapon can be aimed. Combining rounds with the pistol loads it. Dropped items can be picked up by the partner. Item boxes in save rooms open a personal stash; boxes are not shared between players, so the pneumatic tube (which also opens the terminal) stays the way to hand things over.
- **Esc** opens a small pause menu (the game keeps running; co-op can't pause).

## Radio
- **Push-to-talk walkie-talkie (hold V).** The real players' voices are the only voices the characters have. It works from the lobby on, as soon as the partner is connected, and is full duplex.
- **Sounds like a handheld radio:** 8 kHz, band-passed (400–3000 Hz), a little overdriven, with a key-up chirp when a transmission starts and a squelch tail when it ends. A slow automatic gain evens out quiet and loud mics.
- **Interference is level design.** `EnvironmentZone.radio_interference` (0 clear, 1 unusable) adds static, crackle and drop-outs. The worse of the two players' spots wins, so either player can be the reason they can't understand each other. The whiteout is at 0.3.
- **HUD:** bottom left, amber. `TX [||||....]` (your mic level) while talking, `RX signal [|||.]` while your partner talks. Pause menu and lobby have a microphone picker; the lobby says when no mic can be opened.
- **The band (terminal RADIO tab).** Both radios start on the partner channel, 140.0 MHz. The tuner (100–180 MHz) has a scrolling scale under a fixed needle, a signal meter, an oscilloscope, and a transcript that types out once a station comes in clearly. Stations are `RadioSignal` nodes: frequency, a sound loop, a transcript, and optionally a range or a single role who can pick them up. They emit `heard` the first time a player tunes them in clearly, for puzzles to hook into.
- **Tuning away costs the partner.** Voice and messages only reach a radio on the sender's frequency: 0.1–0.4 MHz off comes through as static and garbled text, further off not at all. Players can meet on another frequency on purpose ("tune to 121.5"). The HUD shows `FREQ 121.5 off channel` as a reminder.
- **Chapter 1 stations:** 121.5, an automated distress beacon in Morse, whose transcript says the message has repeated {iteration} times. 163.8, a numbers station reading the iteration number and "HEADCOUNT: TWO", until the last time it says THREE.
- **Text messages** for players without a microphone, written only in the RADIO tab (Down from the dial, Enter to send) and sent over the same radio, so the same frequency rules apply. They are read in the RADIO tab and LOGS; the HUD only says `RX< 1 new message [Tab] radio`. Reading or writing one means opening the terminal, which leaves the character standing still.
- **PROCTOR is listening.** MetaSave keeps the total time spent talking (`{radio_minutes}` in lines). A closed microphone is noticed: once per session (when the player tries to talk or type, or 40 s into a chapter), PROCTOR remarks on it, and it counts sessions played without a microphone (`{mic_sessions}`). *(suggestion)* Later: zones where PROCTOR is on the channel (a third voice in the static), transmissions it replays back to the wrong player, or a room where the radio only works if nobody speaks.

## Visual style
PS1 / low-poly retro: low-res render (~480×270) upscaled with nearest filtering, vertex snapping, dithering, limited palette, heavy fog.

## Tech
- Godot 4.7, GDScript, Jolt physics.
- Host-authoritative listen server, 2 peers. ENet for development, GodotSteam for release.
- Voice: in-game radio (`autoload/radio.gd`): microphone -> 8 kHz mu-law (64 kbit/s) over unreliable RPCs -> a jitter buffer and AudioStreamGenerator on the Radio bus. No codec plugin. Opus could replace mu-law later if bandwidth matters.

## Roadmap
- **M0** Pre-production: this doc + paper-prototype 2–3 radio puzzles with a friend.
- **M1** Networked greybox: host/join, two players moving in 3rd person, disconnect handling. ✓
- **M2** Interaction + perspective: interactables, 1st-person terminals, one cross-player puzzle. ✓
- **M3** Survival core: health, 6-slot inventory, item tube, one gun, one enemy, save room. ✓
- **M4** Vertical slice (20–30 min) + PS1 visual pass + playtests. ← *current*
  - Done: story systems, PS1 pass, Chapter 1 blockout (`scenes/levels/chapter_1.tscn`). Next: playtests, then art/audio passes.
- **M5** Steam lobbies + in-game radio voice. Radio done ✓; Steam next.
