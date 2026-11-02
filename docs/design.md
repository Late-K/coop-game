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
### Surface
Two personnel (or units) wake in a sealed facility and must cooperate over radio to reach each other and get out.

### Meta hook — "asymmetric truth"
Because the game is networked, it can show each player a *different* version of the same thing (a sign, a body, a door count, a voice on the radio).
- Early: pure puzzle design ("read me what your screen says").
- Later: contradictions that aren't puzzles. The game is lying to one of them.
- Final layer: do they trust each other, the game, or themselves — and what is "the facility"?

## Visual style
PS1 / low-poly retro: low-res render (~480×270) upscaled with nearest filtering, vertex snapping, dithering, limited palette, heavy fog.

## Tech
- Godot 4.7, GDScript, Jolt physics.
- Host-authoritative listen server, 2 peers. ENet for development, GodotSteam for release.
- Voice: Discord while prototyping; in-game radio voice later (milestone M5).

## Roadmap
- **M0** Pre-production: this doc + paper-prototype 2–3 radio puzzles with a friend.
- **M1** Networked greybox: host/join, two players moving in 3rd person, disconnect handling. ← *current*
- **M2** Interaction + perspective: interactables, 1st-person terminals, one cross-player puzzle.
- **M3** Survival core: health, 6-slot inventory, item tube, one gun, one enemy, save room.
- **M4** Vertical slice (20–30 min) + PS1 visual pass + playtests.
- **M5** Steam lobbies + in-game radio voice.
