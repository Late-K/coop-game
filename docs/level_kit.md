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

Interactive pieces live with their systems: doors (`scenes/props/door.tscn`, in **Doors**, centred in the wall cell at y = 1.25; it spans Z, so turn it 90° in north/south walls), save terminal, item box, heater, item tube, keypads, monitors.

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
- **TemperatureZone**: cold areas. **StoryTrigger** and **ExamineSpot** (Story): lines and narration.
- **Placements**: anything created or destroyed during play (pickups, enemies). The server re-spawns them for both players.

## Rebuilding the kit
After changing textures or pieces (from the project root):
```
python tools/generate_textures.py
godot --headless --path . --import
godot --headless -s tools/build_kit.gd
godot --headless --path . res://tools/build_kit_sample.tscn
```
`build_kit.gd` writes the materials (`kit/materials/`), the grid pieces (`kit/kit_library.tres`) and the two environments. The last line rebuilds the sample level.
