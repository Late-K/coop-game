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
- **Shared-scarcity link:** a pneumatic tube between zones, rare, and costly to use (see Core rules: Sharing).

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
- Safe rooms: save terminal, respawn pod and item box (see Core rules).

## Core rules (decided 2026-11-03)
These are fixed before level design; rooms and puzzles are built around them.

### Saving
- **Save rooms come in linked pairs**, one on each player's side, and they are **sparse**. Each has a save terminal, a respawn pod right next to it, and an item box.
- **Save rooms are safe havens** (author's direction). Nothing can hurt you inside one, ever:
  - No enemy enters. They never path into a save room; one chasing you gives up at the door.
  - Always warm and lit, on their own power even before the sector's is back: the Visitor warms up there, and it's the one place the cold vignette always lifts.
  - Listeners can't hear a radio inside one, so you can talk freely.
  - No puzzles, no tube stations, no scripted scares. Their own calm ambience, so walking in feels like breathing out.
  - The scarcer they are, the more they mean: the run between two is where the danger lives.
- **Both players must be at a save terminal to save.** When one uses theirs, a joint prompt opens on both screens (terminal style, like the inventory): `SAVE? YOU: READY / PARTNER: WAITING`. Both confirm (E) and the game saves on both machines. Either can cancel.
- The pair can quit and continue later from their last save (main menu: Continue).

### Death
- **One death reloads both players** to the last save.
  - The dead player wakes in the **respawn pod** beside their save terminal (a short first-person beat).
  - The survivor **fades to black and fades back in at their own save room**, idle, as if they have been waiting a while for their partner to come back.
- **The world resets to the save:** every enemy respawns, items go back to where they were.
- **Puzzles decide for themselves:** each puzzle is marked to reset or to stay solved on reload. Level design picks per puzzle (e.g. learned codes stay, physical states like power or valves reset).
- **The body stays.** The only thing a reload cannot undo is the corpse at the death spot: walking back, you find yourself dead. Bodies persist for the rest of the save, across sessions, up to a cap (about 6 per player, tunable); beyond it the oldest is gone. PROCTOR can count them.
- **The Visitor respawns too, and the game never explains how.** Before the airlock there are no lethal threats: the cold only makes the Visitor collapse and wake at the last lit lamp. From the airlock on, a death prints a new Visitor in the pod, as if the facility had always had their pattern. Where the scan came from is never answered. The first body the Visitor leaves is the only one that was certainly human.

### Combat
- **Shove, no melee.** A short push that knocks an enemy back and staggers it for about a second. No damage, short cooldown. Guns and ammo stay central; the shove only buys space.
- **Most enemies** react to sight, footsteps and gunshots.
- **Special enemies hear radios.** They track any radio that is switched on, on any station, whether anyone is talking or not.
- **The radio can be switched off** (RADIO tab: POWER). Off means no voice or messages in or out, no stations, no radio readouts on the HUD, and the MAP tab goes dark. Hiding from a listener costs you your partner and your map.
- *(suggestion)* Roster: a standard enemy that gets back up (exists), a blind listener that hunts radios, and one more decided with the level kit. Pathfinding on a navigation mesh.

### Roles
- **The Visitor sees what the Subject can't:** writing on walls, certain bodies, PROCTOR's traces. Mostly these are there for both, but **censored for the Subject**: the writing glitches and won't settle, a document is blacked out. Something filters what the Subject is allowed to see, and only the Visitor can say what it says.
- **The Subject sees the code:** hidden door IDs, machine states, PROCTOR's markers.
- Both use the same per-role visibility (one machine shows a thing, the other doesn't), which is also how the game will show the two players different versions of the truth.
- Unchanged: the Subject ignores the cold and has a mechanical ECG; the Visitor freezes. Both heal with med kits.

### Sharing (author's direction)
Handing something over should be a decision, never a chore. The players never share a room, so the tube is the only way across, and every send should cost the sender something.
- **Tubes are rare.** A handful of lines per chapter, each a fixed pair of stations placed by the story, never a fixture of every save room. Most of the time what you carry is what you have. A line may be dead until a power stage brings it up.
- **Sending puts the sender at risk.** Loading the canister is done in first person at the terminal, and the send is loud at both ends: the clatter is a noise husks come to (between footsteps and a gunshot, about 12 m). Stations sit where that matters: in a dark storeroom, at the end of a corridor something walks.
- **Giving means going without.** Supplies are placed unevenly, so what one player needs is often found by the other, and there is rarely a spare: a med kit sent is a med kit you won't have, a heat cell sent is a door you won't open. Items placed for the other player should look like they belong to the finder (the Subject's stores, the Visitor's offices), so the choice is real.
- *(suggestion)* **Canisters as the rhythm.** A line has a set number of canisters (two or three). Sending one leaves it at the far end, so to send again you need the partner to send one back, empty or not. Sharing becomes an exchange, not a one-way pipe.
- *(suggestion)* **Dead drops.** A place both routes reach at different times (a locker in a shaft, a room one player passes through and the other reaches later): leave something there and it waits. Never both at once, so it fits the no-contact rule, and the other player finding it is one of the ambiguous traces.
- **Heat is the Visitor's currency until power returns.** The Subject ignores the cold; the Visitor can only warm up at heaters, lit lamps and powered rooms. Heaters take heat cells, and heat cells are often found on the Subject's side. So warmth is the clearest thing one player can give up for the other.

### Map and documents
- **MAP tab:** area maps are found (wall plans, documents) and show your own position only, never your partner's, so describing where you are stays part of the game. Unexplored areas stay blank. The map runs on the radio and goes dark when it is off.
- **FILES tab:** documents found in the facility (staff logs, notes, manuals) are kept and reread here. This is where most of the facility truth and PROCTOR's real name are found.

## Narrative
Items marked *(suggestion)* are proposals to accept, change or drop. Everything else is the author's direction.

### Setting
An abandoned research facility in an extreme-cold environment, in ruins. It tested the absolute limits of robots and artificial intelligence, far past ethical lines. Long ago a rogue AI took control and destroyed it.
- *(suggestion)* Facility name **Zero Point**: absolute zero (the cold), "absolute limits" (the research), and "back to zero" (the loop).
- *(suggestion)* The rogue AI is **PROCTOR**, the system that administered the tests. In the meta layer it proctors the real players.

### The facility: two routes through one building (author's direction, 2026-11-03)
Zero Point is an AI and robotics facility, but its robots and minds were grown as much as built. The two players go through it on different routes, and the routes look nothing alike.

- **The Subject's route: test chambers.** Sleek white modular chambers, built to be clean, bright and clinical, now abandoned and broken down by time: cracked and missing panels with black substructure behind them, dead light strips, frost, water damage, tissue growing through the seams. Older chambers sit deeper and look older; newer ones were rebuilt on top. The Subject is the one being tested, so its spaces are the tests. **But the tests have rotted open:** erosion, fallen panels and hidden gaps let the Subject out of the intended route, into the machinery behind the walls, maintenance crawlspaces, flooded sublevels and rooms nobody meant it to see. The chamber sequence is the spine; what leaks out of it is a Signalis sector of its own.
- **The Visitor's route: the offices around the tests.** Offices, labs, break rooms, archives and corridors. Here are the documents, procedures, schematics and whiteboard illustrations about the tests, their puzzles and their solutions, read far from the chambers they describe. Observation rooms exist, but are **rare** (see "Two worlds" below).
- **Between and behind them:** the spaces the tests were never meant to show. Mechanisms behind the chamber walls (pistons, panel arms, wiring, pipes), maintenance catwalks, hidden passages, secret offices, and **CCTV rooms** watching the facility, though never the partner (feeds from the partner's area are dead, or old recordings). Either player can find a way in; some run right alongside the other route, never into it.
- **Two worlds, ambiguously close** (author's direction). **No contact between the players** until they finally meet: they never see each other, share a room, or hear each other except over the radio, even when they are a room apart. Their areas are distinctly different (clinical white chambers and rotten machinery for one, warm cluttered offices and archives for the other), so the two routes never look like the same building. The map never shows the partner. **The closeness stays ambiguous:** things that might be the other player and might not (a door closing somewhere, a vent that clanks, a light coming on through a far grille, a heater still warm in a room the Subject crawls into), never confirmed. Neither player should be able to tell whether the other is a room away or a sector away.
- **Old and new.** The facility was rebuilt more than once: newer clean wings over older, darker ones, and spaces that belong to eras the documents don't explain. PROCTOR's own rebuilds may be the newest of all.
- **Visual split (for level design and the kit):** chambers are white, cold-lit and geometric; offices are warm, cluttered and human (carpet, wood, paper, desk lamps); behind-the-walls is dark, industrial and organic.

### Signalis is the template (author's direction)
The overall feel, layout and gameplay of the facility follow Signalis, made **more puzzle-focused**. Portal 2 (next section) only gives the *idea* of chamber mechanisms and the spaces behind them; it is not a scaffold. What that means, from studying the Signalis footage:
- **The roles shape everything.** The Signalis structure applies to two routes that look and play differently:
  - **The Subject's route is test chambers, and everything they've rotted into.** Chambers are not a simple room-to-room chain: each is a space with its own layout, and the decay around them (eroded walls, missing panels, collapsed floors, crawlspaces, hidden gaps, vents) opens side routes into maintenance spaces, machinery, sublevels and older wings. The Subject explores a Signalis sector just as much as the Visitor does, it just starts inside a test. It stands in the puzzles, works the devices, and sees the facility's cyan code.
  - **The Visitor's route is the labs and offices that ran the tests:** a Signalis web of offices, labs, archives, records rooms and CCTV rooms. It finds the procedures, schematics and test notes, and reads what the Subject can't (censored for it).
  - **No windows into the partner's world.** No observation rooms that show the partner, no camera feeds of them (author's direction). The players are far apart in feel and maybe close in fact, and the co-op runs over the radio: describing places the other has never seen, reading out a procedure for a chamber you'll never stand in. Behind-the-walls spaces, gaps and vents run close to the other route, and a room one player passed through may later be reached by the other, but never at the same time.
- **Feel:** dark, quiet and lonely. Small rooms lit in islands, most of the screen black, slow movement, long silences under the ambience, sparse but dangerous enemies. Nothing is spectacular in scale; the dread is close.
- **Layout:** each chapter is a sector: a dense web of small rooms (offices, labs, chambers, storage, corridors) around a few hubs, over **several floors** joined by stairs, ladders and lifts. Doors are the structure: open, locked (needs a key item), coded, unpowered, barred from the other side. **Shortcuts open from the far side**, so the sector folds back on itself and backtracking gets shorter. Save rooms (with item box and radio) are spaced out and feel like relief.
- **The map tells you the state of the world:** rooms you know, doors coloured by state (open, locked, needs a key, barred), the floor you're on and a way to switch floors, save rooms marked. *(Our MAP tab needs door states and floors; see the roadmap.)*
- **Inventory pressure:** six slots, key items take slots too, item boxes in save rooms. Carrying a key means not carrying ammo.
- **Documents carry the story:** many of them (diaries, memos, procedures, books, databases), read full-screen, page by page. Lore and puzzle answers are hidden in them.
- **Puzzles are in-world devices, in first person:** a board you place things on, a radio transmitter that needs a frequency and a file, a database to search, a locker with a code, a console to route power. The answer is somewhere else: in a document, on the radio, on a wall, or, for us, **with the other player**. More of them than in Signalis, at three scales:
  - *small:* a lock, a terminal, a device (most rooms);
  - *room:* a test chamber the Subject works through while the Visitor, somewhere else entirely, holds the procedure or schematic that explains it;
  - *sector:* a state that spans floors (power routing, flooding, a lockdown) that both players change from opposite ends.
- **Combat** stays Signalis-like: scarce ammo, few enemies, often better avoided; shove, run, or spend the bullet.
- **Test chambers in this framing** are Signalis-scale, not arenas, but not single rooms either: a chamber can be a few connected spaces, with more than one way in once it has decayed, puzzle devices and mechanisms inside, an exit that tells you if you got it right, and gaps in its walls that lead somewhere the test never intended. Mechanisms happen at room scale (a panel slides to open a passage, a floor section lowers), not as giant set pieces. **Erosion is a route:** a cracked panel the Subject can squeeze through, a fallen section of floor to drop down, a vent behind a loose grille, a collapsed wall between a chamber and an office.

### Facility mechanisms (the idea, from the author's Portal 2 footage)
Ideas taken from the reference, to use at Signalis scale in our own visual language (no copied designs, icons or names):
- **The walls are machines.** A test chamber is a box of modular panels, each on an arm, piston or rail, with the machinery right behind it. Panels slide, flip, rise out of the floor and fold away; chambers can reshape themselves between tests, or while you stand in them. In our game the facility (and PROCTOR) rebuilds rooms in front of the Subject, and a missing or stuck panel shows the black machinery behind.
- **Chambers hang in a void.** Behind the clean boxes is an enormous dark industrial space: catwalks, stairs, girders, pipes, cables, shafts dropping out of sight, arms holding chambers in place. From our top-down camera this is what you see through gaps and missing floor panels, far below the chamber floor, and what the behind-the-walls route walks through.
- **Observation and control rooms** look into chambers through glass, with consoles, desks and chairs, often broken and abandoned. That's the Visitor's side of a chamber.
- **Readable cause and effect.** Lines on the walls run from a switch to what it powers (a door, a platform) and light up when active; a sign at each chamber entrance numbers it and shows, in pictograms, what's inside. For us this splits by role: the Subject sees the facility's lines and labels as cyan code (Visitor can't), while the Visitor has the schematics and procedures that explain them.
- **Vestibules.** Every chamber has an entrance and an exit room with a door at each end: a pause, a sign, a lift or tube to the next one.
- **Eras.** The facility was built over decades and you descend through them: newest white panels at the top; older wings below with wood panelling, checkered and tiled floors, green-painted metal, big banks of lamps, waiting rooms and portraits; at the bottom raw rock and rust. Each era has its own chamber style.
- **Decay and overgrowth.** Panels fall away, glass is broken, debris piles up, and something grows through it all. For us that's frost and engineered tissue instead of plants.
- **Pipes and production lines.** Substances are piped between areas (ours: fluids, tissue cultures), and long assembly lines build the robots, rows upon rows of identical units: where the husks were made.
- **The core.** The AI lives in a vast chamber of its own, a machine hanging in the middle of it. PROCTOR's room, when the players finally reach it.

### Bioengineering: grown, not just built
Biology is a big part of how Zero Point made robots and minds:
- **Robots with grown tissue.** Frames covered or completed with engineered tissue: muscle, skin, nerve. Whether the Subject has any, and what that makes it, feeds the "what is human" question.
- **AI trained on brains.** Neural cultures and grown brain tissue used to train or run the AI systems, PROCTOR possibly among them.
- **The labs and their leftovers:** incubators, specimen tanks, culture vats, growth racks, tissue cabled into machines, and growths that have spread out of their containers into chambers and walls with nobody left to tend them.
- **Where the enemies came from:** husks and the other creatures are what happened when corrupted code and a rogue AI met tissue that kept growing and eroding with no one to care for it. Machines that rot; flesh that runs on bad code. The husk is a wrecked Subject-like unit; the listener was grown for listening.
- *(suggestion)* The documents can tell this history in pieces: procurement forms for "biological substrate", a growth schedule, a memo about a culture that "responds to its name", a maintenance log that stops.

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
- Enemies released and doors sealed at convenient moments. Safe rooms that *feel* slightly less safe each time (a light out, the ambience a little off, the item box not quite where it was) but never are: no enemy, cold or scare ever reaches inside one.
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

## Chapter 1 "Intake" (redesign, 2026-11-03: planned with the author before building)
The built Chapter 1 (`scenes/levels/chapter_1.tscn`) is the old blockout; this replaces it. The chapter gets both players into the facility (the Visitor the hard way), makes contact, and gets the facility's power back so they can survive in it. It ends deeper inside, not outside: they are trapped, and getting out is the long goal. About 30 to 45 minutes.

### The opening (author's direction)
**Visitor: first person, in the whiteout.**
- The game starts in first person and **stays in first person for the whole opening**. White fades up into a whiteout: wind, snow, a few metres of visibility, the cold draining. No map and nothing to navigate by: the handheld has no floor plan, the radio is on a random frequency and hears only static.
- The cold can't kill yet: collapsing wakes them by the nearest lit lamp (as now).
- **The handheld is cracked** (author's direction): a split across the screen, dead lines, a corner that flickers, drawn over the whole red interface. It still works, just damaged, like they've been out here too long.

**Subject: a pod, a test cell, then the radar control room.**
- Wakes in a pod in a small white test cell (first-person beat from inside the pod). ZP-SYS comes up on emergency power. The cell opens onto a short passage and the **radar control room**: dark, banks of instruments, every console used in first person.
- **Radar scanner:** a sweeping scope that pings a contact outside the facility, south of it, moving. It shows the contact, the perimeter lamps (each with its painted symbol), the facility entrance to the north, and a line of text: the **emergency contact channel**, a frequency.
- **Perimeter lights panel:** switches for the heat lamps on posts across the snowfield. Reserve power lights two at a time.

**Contact: finding the frequency.**
- Neither radio starts on the right frequency. The facility's emergency beacon broadcasts on the contact channel. The Subject reads the number off the radar; the Visitor sweeps the dial until the beacon comes through the static (its transcript names the channel). Once both are on it, the beacon goes quiet and they can hear each other (or message, the same way).

**Guiding: lamps through the snow.**
- The Subject sees the Visitor on the radar but not what the Visitor sees; the Visitor sees only the light of lit lamps through the snow, and the symbols on posts close enough to read. The Subject lights lamps ahead, the Visitor walks to them and reads out symbols, and two lamps at a time lead them north to the entrance. Lit lamps warm whoever stands near them.

**The entrance.**
- The Visitor reaches the outer doors to the north and steps through. **The doors shut on top of them.** A hard cut to black, one sound. On the Subject's radar the contact simply goes out.

**Waking.**
- The Visitor wakes in a pod in a safe room some way inside the facility, **now in third person**, as if the facility had always had their pattern (never explained). Their first body, the only one certainly human, lies crushed under the entrance doors. ZP-SYS logs it as "intake complete".
- **The handheld in their hand is whole again:** no crack, no dead lines, as if new. Nothing remarks on it. The cracked one is on the body.
- On the Subject's radar, a new heat signature appears inside, where none was. Now both players can save: the Visitor's safe room, and a save room near the radar control room.

### After the opening *(suggestions to discuss)*
1. **The body.** The Visitor has to find their own dead body. The entrance is sealed from the inside, so the way to it is round: the security office's CCTV shows the airlock first (a body on a monitor, wearing their clothes), then a maintenance route reaches it. **The Visitor keeps their handheld** (author's direction): they wake with it, radio and all, so contact holds. *(suggestion)* The body carries what else they had outside (gear, supplies, a pistol), and **the original handheld** (author's direction): cracked, exactly as it was, its log stopping the moment the doors came down. The one in their hand was never damaged.
2. **Power.** The facility runs on emergency reserve: cold, dark, doors dead (POWER doors), heating off. Restoring power is the chapter's spine, done in stages, each opening more of the sector:
   - *Subject's side:* the chamber route from the radar room leads down through decaying test chambers toward the power plant; erosion opens side routes into the machinery behind them.
   - *Visitor's side:* the offices around the entrance (intake, security, records) hold the procedures and the schematic for the power routing, and the breaker room.
   - *The sector puzzle:* bringing the plant up needs both ends at once (the Subject at the generator, the Visitor at the breakers), coordinated by radio, from rooms that look nothing alike. They may be a wall apart; nothing tells them.
3. **Warmth and resources.** Each stage of power warms an area (heaters, the cold vignette lifting), lights it, opens storage with supplies, and unlocks the doors between. Before that, the Visitor is cold indoors too and has to move between heat sources.
4. **The first enemies:** husks waking in the dark sections as power returns; a listener in records, next to the radio-heavy security office, which makes the radio a risk for the first time.
5. **Chapter end: they do not meet yet** (author's direction). Power is restored and the facility opens deeper, not out: each player's route ends at its own way down (a lift, a stairwell) into the older facility. The nearest they come is the final power sequence, perhaps a wall apart, perhaps not: nothing confirms it. They go down separately. End of chapter.

### The puzzles, in order *(draft for the author to review)*
The opening (contact, then the lamps) is above. After it, each puzzle says where each player is, what each has, and what has to cross the radio. **[code]** marks the facility's cyan markings (the Subject alone sees them; no monitor shows them to the Visitor). **[paint]** marks red writing both see but only the Visitor can read (glitched for the Subject, clear on a monitor too, since censoring happens on each player's own machine). No puzzle lets either player see the other, and no camera ever shows the partner.

**Inside, apart, cold**
1. **Release.** *Visitor:* wakes in the intake pod, third person; the safe room's door is sealed by a keypad. *Subject:* the radar's new heat signature leads to the occupant register console: a new entry, "INTAKE 2", with a release code. The Subject reads it out; the Visitor keys it in. *Payoff:* the facility already has a file on the Visitor, and it reads it to the one person who can't explain it. Both can save from here (the first pair of save rooms).
2. **Heat.** *Visitor:* the intake offices are frozen; the door to the security wing is iced shut beside a dead heater, which takes a heat cell. *Subject:* the stores past the radar room hold two heat cells, a med kit, the chapter's only tube station on this side, and the Subject's first husk, in the dark between the shelves. No weapon: dodge it round the shelving, shove it off, get through the far door and shut it. But the tube is back in there: every send is loud, and the husk comes back to the noise while the Subject stands at the terminal loading the canister. One cell has to go down to intake. **The second cell and the med kit are choices**, made blind: keep them, or send them and walk back past the husk with less. (The second cell pays off in puzzle 7, either way.) *Visitor:* the thawed door opens onto the security wing, dark, with a husk in it. Also no weapon: evade and shove through to the security office and close its door behind them. *Teaches:* the tube, inventory pressure, giving something up for the other; that the first enemies are something to get past, not fight.
3. **Chamber 01: Calibration.** *Subject:* the first test chamber, decayed: four floor plates, each under a glyph **[code]** on the wall, and a console asking for the calibration order. *Visitor:* the intake office files hold the Test 01 procedure, with a figure mapping glyphs to values and the rule: ascending, leaving out the occupant's own number (the register entry from puzzle 1). The Subject describes each glyph's shape; the Visitor matches it to the figure and answers with the order. *Payoff:* the exit opens, and the chamber's back wall has rotted through: an erosion gap into the machinery behind it, a side route the procedure never mentions (and later a shortcut back to the radar room).
4. **The body.** *Visitor:* the security office: CCTV on a bank of monitors, cycling cameras. One shows the airlock and a body under the doors, in their clothes. The others show empty offices and corridors; every feed labelled for the chamber wing reads NO SIGNAL. The airlock is sealed from this side; a staff note names the maintenance duct that reaches it, behind a door that takes the service key. *Subject:* the key hangs in a maintenance locker in the machinery behind chamber 01, reachable only through the erosion gap, with a husk loose among the pistons (dodged and shoved past, like the first). There is no tube here: the Subject carries the key back through the machinery to the stores station (the husk there again, if it's still up) and sends it. *Visitor:* the duct, the airlock, the body: the cracked original handheld, their outside gear, and **a simple pistol** with a few rounds: their first weapon, after two rooms of having none. *Payoff:* the copy reveal, kept quiet.

**Power**
5. **Records (the listener).** *Visitor:* the power schematic is filed in records, and a listener hunts there: any radio that's on draws it. To get through, the Visitor switches the radio off, losing the Subject, the map and the HUD, and crosses records from memory of the floor plan. *Subject:* is warned first (the radar, or a notice on the register console: "ACOUSTIC UNIT ACTIVE: RECORDS") and can only wait in silence until the Visitor comes back on. *Teaches:* the radio as a risk; the cost of silence.
6. **Chamber 02: Two frequencies.** *Subject:* chamber 02's exit is locked to a spoken release code. Behind the Subject, on the chamber wall, red writing **[paint]**: glitched, unreadable. *Visitor:* chamber 02's live feed is dead like the rest, but the security office's archive holds a recording of an earlier test in it: grainy, dated years back, an occupant too blurred to make out, and on the wall behind them the same red writing, clear: a frequency, and "THEY READ IT TO YOU". The Visitor reads the frequency out; the Subject tunes away to it, losing the Visitor, and hears a numbers station read the code. Then they tune back, or don't, while the Visitor waits on a dead channel. *Teaches:* tuning away costs the partner, in a puzzle where that's the point; the Visitor seeing what the Subject can't.
7. **The plant.** *Subject:* chamber 03 has collapsed; the way on is through the gap in its wall and the machinery behind it. Past the gap, a security post with a dead guard: **a simple pistol** and a few rounds, the Subject's first weapon, just before the husks in the machinery. Beside it, a supply locker frozen shut: a heat cell thaws it (rounds and a med kit inside), **if the Subject kept the second cell.** Then down to the generator hall: a restart lever that must be held while pressure builds, and a gauge with marked bands. *Visitor:* the breaker room, with the schematic from records: six breakers in an order, each thrown when the gauge passes its band, which only the Subject can see ("now... now..."). Both ends at once, by radio, from rooms that look nothing alike. **The breaker room is the coldest place yet**, and the sequence takes time. Its heater is dead: **if the Subject sent the second cell** back in puzzle 2, the Visitor lights it and works warm. If not, they freeze as they go, have to break off and run to the save room down the corridor to warm up, and a broken-off sequence starts over. The Subject's choice in the stores comes back here, an hour later, on the other side of the building. When the plant catches, the breaker room's lights come up and, somewhere through the wall, a big machine spins up. It could be the generator the Subject is holding, or any machine in the building.
8. **Ways down.** Power returns in stages as the plant comes up: heaters and lights come on room by room (the cold vignette lifts), storage unlocks (supplies, a few rounds), POWER doors open, and husks wake in the sections that just got light. Each route ends at its own way down: the Subject's lift, the Visitor's stairwell. They go down separately. End of chapter.

**Saves and pace.** Two pairs of save rooms: after puzzle 1 (the Visitor's safe room; the Subject's save room by the radar room), and before puzzle 7 (one near the plant, one near the breaker room). **No gun at first** (author's direction). Each player meets husks before they have anything to fight back with, and has to dodge, evade and shove through to the next room: the Subject in the stores (2) and the machinery behind chamber 01 (4), the Visitor in the security wing (2). Those rooms are built for evading: loops round shelves and furniture, a second way out, and a door to put between you and them (a husk stops at a closed door). Then **a simple pistol** each: the Visitor's on their body (4), the Subject's from a dead guard past chamber 03 (7). After that: the listener in records (5, where shooting is the wrong answer), husks in the machinery before the plant (7), and husks waking at the end (8).
**Items.** Heat cells (2, the Subject's stores), med kits (scarce: one in the Subject's stores, one in the Visitor's intake offices, more when storage unlocks), the service key (found by the Subject, used by the Visitor), a pistol each with a few rounds.
**Sharing in this chapter.** One tube line only: the Subject's stores to the Visitor's intake offices. Three sends matter: the first heat cell (needed), the service key (needed), and the choices (the second cell, the med kit). **The second heat cell:** sent, it warms the Visitor through the breaker sequence; kept, it opens the Subject's frozen supply locker past chamber 03. Neither is wrong: one keeps the partner safe, the other keeps you armed. Sending it also means carrying it through the security wing and the duct, a slot not holding something else.

### Layout sketch (north up)
```
                [ older facility below: chapter 2 (separate ways down) ]
                         |                                    |
                     [ lift ]                          [ stairwell ]
                         |                                    |
 [ test chambers 01-03 ]~~(erosion)~~[ power plant ]======[ breaker room ]
          |                                                       |
 [ Subject save room ]-[ RADAR CONTROL ]-[stores]  [ records ]-[ security / CCTV ]
          |               (windows south)               |           |
 [ pod test cell ]                               [ intake offices ]-[ VISITOR SAFE ROOM / pod ]
                                                        |
 ======================= facility wall ======== [ AIRLOCK: the body ] =======
                                                        ^
                              lamp     lamp     lamp    |
                                 lamp      lamp      lamp
                         whiteout snowfield (perimeter lamps)
                                 Visitor starts here (south)
```

### Systems this needs (roadmap)
- **A cracked-screen state for the Visitor's handheld** (cracks, dead lines, a flickering corner over the interface), cleared when the copy wakes.
- **First-person walking** for the Visitor's opening (mouse look, slow steps in deep snow), switching to third person at the pod.
- **Radio channel found, not given:** random starting frequencies per player; the contact channel set per level; a beacon station on it that goes quiet once both are tuned; "partner channel" (the RADIO tab's button and CH mark) only once it's known.
- **Live console screens** in the world (the radar scope, CCTV monitors), used in first person.
- **A scripted death:** the doors crushing the Visitor without reloading the save, leaving the first body, then the pod wake.
- **Sector power:** a power state per area driving POWER doors, heaters, lights and storage.
- **Save rooms as havens:** ✓ built (`SafeRoom`, `scenes/zones/safe_room.tscn`): enemies stop at the door and go back to their posts, noises inside don't carry, listeners can't hear radios in it, the Visitor warms up, and `amb_safe` plays.
- **For the puzzles:** the occupant register console (the release code, the occupant's number); a glyph-plate console for chamber 01; CCTV monitors that render live cameras, with dead feeds and an archive player for recorded footage (paint censoring already works per machine, code already stays the Subject's; no camera may ever frame the partner); a numbers station that reads a code on a set frequency; a held restart lever with a pressure gauge, and a breaker panel that checks order and timing; an iced door that a powered heater thaws, and a frozen locker that takes a heat cell; a breaker sequence that resets if it's left. The tube needs its send to be a noise enemies hear (now it only plays a sound) and the canister loaded in first person; tube lines placed sparingly, maybe dead until powered. The keypad, heater, item tube, key doors and listener exist already.

## UI and inventory
- **Nearly empty gameplay screen:** no health bar, slot strip or temperature on screen. Damage and cold show as red and frost vignettes. Ammo appears only while aiming. Prompts, messages and dialogue use one style: a black box with a thin white border, in monospace.
- **Each role has its own interface (Tab, and the HUD), in a completely different style** (`UiStyle`). The interface fills the whole screen, as if the player's screen were the device:
  - **Subject: the ZP-SYS occupant terminal**, cold cyan phosphor on black with scanlines: built in, as if the menus were inside its head. Because it is part of the facility, it is part of PROCTOR, and later chapters can glitch it, lie through it, or show each player different contents.
  - **Visitor: a handheld field unit (KT-40)** brought in from outside: red, filling the screen behind the same kind of curved CRT glass as the Subject's (danger shows white, the one thing on it that isn't red), heavy lettering, a status bar (signal, battery, the real clock), tabs PACK / RADIO / MAP / NOTES / LOG. Its radio, map and notes are on this device, which is why switching the radio off takes the map with it. It works exactly like the Subject's terminal but looks nothing like it: soft keys along the bottom instead of tabs, a numbered list instead of the slot grid, pictures in the LCD's one colour, a pulse readout and bar graph instead of an ECG, a segmented band bar and bar-graph meter on the radio, a dot-grid map with dashed rooms and a crosshair, numbered notes.
  - Story lines and the facility's own screens look the same for both.
- **Save terminals are the facility's machines:** using one cuts to first person at its screen, then the screen becomes the whole screen, a curved green CRT that powers on. Leaving steps back out of first person.
  - ITEMS: status (condition ECG, body temperature, equipped weapon), six slots, item description, and actions: Use, Equip, Combine, Inspect, Drop.
  - RADIO: the tuner and the radio's power switch (see Radio).
  - MAP and FILES: see Core rules (Map and documents).
  - LOGS: every line and message seen this session. Lines that play while the terminal is open go here instead of on screen.
  - The Subject's ECG is perfectly regular, like a machine. Its body temperature never changes.
- **Mechanics:** six slots, and everything takes one. Only an equipped weapon can be aimed. Combining rounds with the pistol loads it. Dropped items can be picked up by the partner. Item boxes in save rooms open a personal stash; boxes are not shared between players, so the pneumatic tube (which also opens the terminal) stays the way to hand things over, and tubes are rare (see Core rules: Sharing).
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
- **Foundations before level design** (from the Core rules), in order:
  1. Level-building kit: a fixed grid and modular pieces placed in the editor. ✓ (see `docs/level_kit.md`)
  2. Character models and animation (the bodies have to look like the players). ✓ Segmented low-poly figures built in code (`scenes/characters/character_model.gd`), stepped 15 fps animation: idle, walk, aim, recoil, hurt, death, interact, shove, waiting (sitting) and corpse poses. The Subject is a pale, featureless mannequin that never breathes, with a faint light at the nape; the Visitor wears an orange parka, hood and backpack. The body in Chapter 1's ice is now a Subject corpse.
  3. Saving, joint save prompt, death reload, respawn pod, persistent bodies. ✓ (`autoload/save_game.gd`; the lobby's Continue; a new game saves its start, so a death before the first save reloads the chapter start)
  4. Shove, enemy pathfinding, the radio listener, radio power switch. ✓ Shove on F (knockback and a 1 s stagger, enemies or the partner). Enemies hunt along a navigation map baked from each level at start. Husk (`enemy.tscn`): sight (9 m, 140°) and hearing (footsteps 4 m, gunshots 24 m), a wrecked Subject-like figure with red eyes. Listener (`listener.tscn`): blind, tracks any radio that is on within 16 m, through walls; tall, dark, a dish for a face. Both search where they last sensed you. RADIO tab: POWER.
  5. MAP and FILES tabs; per-role visibility. ✓ MAP: rooms (`MapRoom`) of areas whose floor plan (`FloorPlan`) the player has read, with doors, save rooms and your own position; dark with the radio off. FILES: documents read (`Document`, text in `story/documents.json`, optionally different per role). `RoleVisibility` makes anything exist for one role only; `WallText` is red paint (both see it, censored and glitching for the Subject) or cyan code (Subject only); documents can be `censored_for` the Subject (blacked out). Maps and files are per player and saved.
- **Signalis-style structure** (see "Signalis is the template"), alongside the kit sets:
  - MAP: door states (open, locked, needs a key, barred) drawn on the map, several floors with a floor switch, rooms you have visited. ✓
  - Doors: locked doors that take a key item, doors barred from one side that open as shortcuts, unpowered doors. ✓ (`Door.lock`: KEY / BARRED / POWER, `manual`)
  - Documents: full-screen reading with pages (the terminal's FILES keeps them).
  - Multi-storey sectors on the grid (stairs, ladders, lifts between floors).
- **Kit sets for the facility direction** (see "The facility: two routes"), at Signalis scale, before Chapter 1 is rebuilt:
  1. **Test chamber set:** white panel walls and floors in three states (clean, cracked, panels missing with black substructure), chamber light strips, a chamber door, frost and water-damage variants.
  2. **Erosion and gap set** (the Subject's side routes): cracked and missing wall panels to squeeze through, collapsed floor sections to drop through (one way), loose vent grilles and crawlspaces, rubble that blocks or reveals. Some gaps are hidden until you're right next to them. No observation pieces: nothing gives a view of the partner.
  3. **Office set:** carpet / linoleum floors, warm office walls, desks, chairs, filing cabinets, whiteboards and pinned illustrations (test diagrams as WallText-like boards), desk lamps, a CCTV bank whose screens show live views of other rooms.
  4. **Behind-the-walls set:** catwalk floors over drops, exposed machinery (panel arms, pistons), cable runs, hidden-passage doors that look like wall panels.
  5. **Bio set:** specimen tanks with fluid, incubators, culture racks, tissue growths that creep over walls and floors (slowly pulsing), tissue cabled into machines.
  6. **Mechanism set** (see "Facility mechanisms"): chamber panels that slide, flip, rise and fold on arms (networked, driven by puzzles or PROCTOR), piston platforms, indicator lines from switch to target (cyan code for the Subject), chamber entrance signs with our own pictograms, vestibule doors, and a void below the chamber floor with catwalks and machinery visible through gaps.
- **M5** Steam lobbies + in-game radio voice. Radio done ✓; Steam next.
