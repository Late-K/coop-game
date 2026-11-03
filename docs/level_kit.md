# Level kit

How levels are built. Everything snaps to one grid, so rooms, doors and props fit together and read the same from the top-down camera. The sample level shows every piece in use: run it with `-- --host --level=kit` (or open `scenes/levels/kit_sample.tscn`).

## Starting a level
1. In the FileSystem dock, right-click `scenes/levels/level_template.tscn` → **New Inherited Scene**, and save it as `scenes/levels/<name>.tscn`. (Or duplicate the template.)
2. Set the root's `chapter_title`, `intro_lines`, `ambience` and `footsteps`.
3. Add the scene to `LevelSpawner`'s spawnable scenes in `scenes/main.tscn`, and to how `main.gd` picks the level.

The template already has every node `Level` needs: WorldEnvironment (the facility look), LevelGrid, Doors, Lights, Props, CameraZones, Zones, Story, Placements, World/WorldSpawner, SpawnPoints (Subject, Visitor), Players/PlayerSpawner.

## The grid
| Measure | Value |
|---|---|
| Cell | 1 m × 1 m, one storey (2.5 m) high |
| Floor level | y = 0 (storey n at n × 2.5 m) |
| Wall height | 2.5 m (the ceiling line) |
| Wall thickness | at least 1 cell |
| Door opening | 3 cells (door.tscn is 3 m wide) |
| Corridor | at least 3 cells; **east–west corridors at least 4** (see camera) |
| Typical room | 8–14 cells a side (fits one camera framing) |

## Painting architecture (LevelGrid)
Select **LevelGrid** and paint from the palette (the GridMap editor). Floor 0 is ground level.
- **Floors** where people walk, **walls** where the building is solid. Leave everything else empty.
- Empty cells become black mass at runtime: the outside of the building, and anything not painted. So rooms read as hollows carved out of black, like Chapter 1, and the outside faces of walls never show. There are no pits for now (an empty cell inside a room is solid black).
- Indoor cells get a ceiling automatically, seen only in first person. Snow floors are outdoors: no ceiling, and no black mass within 3 cells of them.
- **Low pieces** (1 m tall) are counters, ledges and railings. They replace the floor under them.

| id | Piece | Use |
|---|---|---|
| 0 | floor_tiles | Labs, living areas (Chapter 1's floor) |
| 1 | floor_grate | Corridors, service areas |
| 2 | floor_concrete | Storage, maintenance |
| 3 | floor_hazard | Thresholds, doorways, danger edges |
| 4 | floor_snow | Outdoors |
| 10 | wall_panel | Painted facility walls (Chapter 1's walls) |
| 11 | wall_concrete | Service and structural areas |
| 12 | wall_lab | Tiled labs and medical rooms |
| 13 | wall_ice | Outdoor walls, frozen areas |
| 20 | low_concrete | Concrete ledges, low walls |
| 21 | low_panel | Counters, consoles |

Ids never change, so painted levels keep working when the kit is rebuilt.

## Props (`scenes/kit/props/`)
Drag into **Props**; place at floor level (y = 0). All face +Z (south, toward the camera) unless turned.

| Prop | Size | Notes |
|---|---|---|
| crate | 1 × 1 × 1 | Solid; stacks (put one at y = 1) |
| barrel | 0.7 Ø × 1 | Solid |
| shelf | 2 × 0.5 × 2 | Solid; back against a wall |
| desk | 1.6 × 0.8 | Solid; glowing terminal screen |
| lockers | 1.8 × 0.5 × 2 | Solid; back against a wall |
| pipes | 2 m run | Near the ceiling along a wall; tile them every 2 m |
| vent | 1 m grille | Back against a wall face |
| debris | small | Walk-through decoration |

Interactive pieces live with their systems: doors (`scenes/props/door.tscn`, in **Doors**, centred in the wall cell at y = 1.25; it spans Z, so turn it 90° in north/south walls; set `lock` to KEY with a `key_item`, BARRED with the `barred_side` it opens from, or POWER for a puzzle to call `set_powered`, and `manual` for a plain door players open by hand; locked doors show on the MAP), save terminal, item box, heater, item tube, keypads, monitors.

## Light
- **ceiling_light** (omni) and **wall_lamp** (spot aimed down and south). Both show a glowing fixture in the light's colour. To change colour, energy or range: right-click the instance → *Editable Children*, then select its Light. `flicker` makes a failing lamp.
- **One key lamp per room**, hung on the far (north) wall or over a doorway, so the fixture is in view and shadows fall toward the camera. Let corners stay dark.
- Cold white-blue for service areas, warm for living areas, red only for alarms and PROCTOR.
- The facility look is `kit/facility_environment.tres` (very low ambient: unlit means black). Outdoors uses `kit/whiteout_environment.tres` through an EnvironmentZone.

## Camera
- The camera looks down at 60° from the south. **A south wall hides about 1.4 m of floor behind it**, so keep anything important (items, switches, enemies) out of that strip, and make east–west corridors at least 4 cells wide.
- **One camera zone per room:** drag `scenes/kit/camera_zone.tscn` into **CameraZones**, centre it on the room, *Editable Children*, and size its box to the room. The camera distance is worked out from the box, so the whole room fits on screen.
- Corridors get no zone: the camera follows the player.

## Zones and story
- **EnvironmentZone** (Zones): look, ambience, footsteps and radio interference per area (the sample's Yard).
- **TemperatureZone**: cold areas. **SafeRoom**: a save room's haven (see Saving and dying). **StoryTrigger** and **ExamineSpot** (Story): lines and narration.
- **Placements**: anything created or destroyed during play (pickups, enemies). The server re-spawns them for both players.

## Maps, documents and things only one player sees
- **MapRoom** (`scenes/map/map_room.gd`, under **Story**): one per room and corridor, a rectangle `size` metres across with a short `label`, an `area` id and its `floor` (0 = ground; the MAP shows one floor at a time, Up/Down to change). Rooms a player has been in are drawn brighter. It draws its outline on the floor in the editor.
- **FloorPlan** (`scenes/map/floor_plan.tscn`): a plan on a wall, facing into the room. Reading it puts its `area` on that player's MAP (never the partner's). One plan per area; put it near the area's entrance or in its save room.
- **Document** (`scenes/story/document.tscn`): a paper on a desk or floor with a `doc_id` from `story/documents.json` (`title`, and `text`, or `subject` / `visitor` for a different text per role). Reading opens it in FILES.
- **RoleVisibility** (`scenes/story/role_visibility.gd`): add as a child of anything to make it exist for one role only (`visible_to`); on the other machine it is hidden and can't be used. Works on documents, floor plans, props, bodies.
- **WallText** (`scenes/story/wall_text.tscn`): `paint` (red writing: both see it, but `censored_for` the Subject by default, so it glitches for them and only the Visitor can read it) or `code` (the facility's cyan markings: always the Subject's alone, clear to it and not there at all for the Visitor; `visible_to` and `censored_for` only apply to paint), with `message` and `letter_size` in metres. The camera reads **north walls and floors**; east and west walls are edge-on. Floor writing wants letters about 0.45 m tall; code on a wall is a glint from above, readable up close.
- **Censored documents:** `"censored_for": "subject"` in `story/documents.json` blacks a document out for the Subject (the title stays).

## Enemies
- Put enemies under **Placements**: `scenes/enemies/enemy.tscn` (the husk) or `listener.tscn`. Their senses are exports on the root: sight range and angle, hearing, radio range, speed, health, damage.
- **The navigation map bakes itself** at level start from the grid's floors, CSG and props. Doors count as open: an enemy walks up to a closed door and stops there. Props (crates, shelves) are obstacles.
- Players make noise: footsteps carry 4 m, gunshots 24 m. A husk that hears one comes to look, and after searching (or losing someone) walks back to where it was placed, its post; a listener tracks any radio that's on within 16 m, so place listeners where switching the radio off (losing the partner and the map) is the price of getting past.

## Saving and dying
- **Save rooms come in pairs**, one on each player's side, and sparse. Each needs `scenes/props/save_terminal.tscn` (terminal plus respawn pod): give it **1.2 m clear to its right** for the pod and about **1.5 m in front**, back against a wall. An item box nearby.
- **Save rooms are safe havens:** put `scenes/zones/safe_room.tscn` in **Zones** over every save room (*Editable Children*, size its box to the room's floor, not the doorway). Inside one, enemies never walk in (they stop in the doorway), give up on anyone who reaches it and wander back to their post, ignore noises made inside, and listeners can't hear a radio there; the Visitor warms up (`warmth_rate`, beating any cold zone), and it plays `amb_safe`. Light it warm (a warm key lamp), and keep out puzzles, tube stations and scares. The sample's lab is one.
- **Anything with state that a reload must put back** joins the `saved` group and has `save_state() -> Variant`, `load_state(state)` (applied on both machines, instantly: the screen is black) and an exported `keep_on_reload`. Doors, the heater, code puzzles, the beacon network and story triggers already do. Set `keep_on_reload` per puzzle: on means a death does not undo it (a learned code), off means it resets (power, valves, lamps).
- Pickups and enemies under **Placements** reset automatically.
- **EnvironmentZone `lethal = false`** marks places where nothing can kill yet (Chapter 1's whiteout): dying there is a collapse, waking by the nearest lit beacon lamp (or the role's start), with no reload.

## Rebuilding the kit
After changing textures or pieces (from the project root):
```
python tools/generate_textures.py
godot --headless --path . --import
godot --headless -s tools/build_kit.gd
godot --headless --path . res://tools/build_kit_sample.tscn
```
`build_kit.gd` writes the materials (`kit/materials/`), the grid pieces (`kit/kit_library.tres`) and the two environments. The last line rebuilds the sample level.
