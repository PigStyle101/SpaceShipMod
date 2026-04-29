# Copilot instructions for SpaceShipMod (Factorio 2.0 + Space Age)

## Big picture architecture
- This is a Factorio mod with two execution phases:
  - **Data stage**: `data.lua` defines prototypes/recipes/tech; `data-final-fixes.lua` rewrites recipes/tech unlocks across mods.
  - **Runtime stage**: `control.lua` wires events and delegates behavior to modules.
- `SpaceShip.lua` is the runtime composition root. It creates the `SpaceShip` table/class, then extends it via module injection:
  - `spaceship/scanning.lua`
  - `spaceship/cloning.lua`
  - `spaceship/docking_ports.lua`
  - `spaceship/docking_travel.lua`
  - `spaceship/schedule.lua`
  - `spaceship/drops.lua`
  - `spaceship/entity_handlers.lua`
  - `spaceship/rendering.lua`

## Core state model (must preserve)
- Persistent state lives in global `storage` (Factorio pattern), not local module singletons.
- Primary entities:
  - `storage.spaceships[id]` = ship state (hub, floor/entity scan snapshot, schedule, docking flags, orbit, etc.).
  - `storage.docking_ports[unit_number]` = port metadata and occupancy.
  - `storage.scan_state` + `storage.scan_queue` = **single active scan** + queued scans.
- Keep references valid-aware (`entity and entity.valid`) before use; this codebase relies heavily on that guard style.

## Runtime flow to understand before editing
- Building/mining (`spaceship/entity_handlers.lua`) marks ships `scanned = false` when structure changes.
- Scans are incremental (`SpaceShip.start_scan_ship` / `continue_scan_ship`) and processed on tick (`control.lua`, every 10 ticks).
- Automation loop runs every 60 ticks (`check_automatic_behavior`, `check_waiting_ships_for_dock_availability`).
- Clone behavior is split by mode:
  - `SpaceShip.clone_ship_area_instant(...)` for docking/manual instant clone calls.
  - `SpaceShip.clone_ship_area_staged(...)` for staged/deferred departure flow.
  - Deferred clone job processing lives in `SpaceShip.process_clone_job_queue()` and cleanup in `SpaceShip.process_clone_cleanup_queue()`.
- Cleanup is staged/queued to reduce frame spikes; avoid reintroducing immediate cleanup branches unless explicitly requested.
- Travel and docking rescan after clone to refresh references.
- Do not bypass scan preconditions in takeoff/docking code; many paths depend on `reference_tile`, `floor`, `docking_port` being current.

## Project-specific conventions
- Platform naming is semantic:
  - Ship platforms end with `-ship`.
  - Station platforms end with `-station` (managed in `Stations.lua`, one station per planet).
- Dock selection persistence is by station index -> **port name** (`ship.port_records[station_index]`), not unit number.
- GUI logic is split:
  - Custom buttons/frames in `shipGui/SpaceShipGuisScript.lua`.
  - Schedule UI/events come from external `ship-gui` mod via `remote.call("ship-gui", "get_event_ids")` and `__ship-gui__.spaceship_gui.spaceship_gui`.
- User-facing diagnostics are mostly `game.print(...)`; preserve existing messaging style for debugging consistency.

## Debugging and change strategy (important)
- Prefer **debug-first fixes** over speculative fallbacks.
  - If the failure path is not obvious, add focused debug output (`game.print`) around state transitions and branch decisions.
  - Verify behavior from logs/tick flow, then implement the direct fix.
- Avoid adding fallback logic whenever possible.
  - Do not add legacy-style alternate paths “just in case” unless there is a proven compatibility requirement.
  - Keep one clear source-of-truth flow per behavior (especially cloning, docking, and automation).
- When adding temporary debug prints, keep them concise and easy to remove or gate.

## Integration points and dependencies
- Required dependencies are in `info.json`: `space-age` and `ship-gui`.
- Cross-mod compatibility logic in `data-final-fixes.lua` globally replaces `power-armor-mk2` recipe/tech references with `spaceship-armor`.
- Docking/automation interacts with Space Age platform state transitions (`on_space_platform_changed_state`).

## Developer workflow (repo-specific)
- No automated test suite is present in this repository.
- Factorio API references are available locally in `docs/prototype-api.json` and `docs/runtime-api.json`.
- If API behavior is uncertain, check those local JSON docs first, then consult official online Factorio API docs.
- Validate changes by in-game scenario testing of these sequences:
  1. Build hub + flooring + docking port -> verify scan completion.
  2. Takeoff to platform -> verify staged clone queue phases, rescan, and platform schedule behavior.
  3. Auto schedule with wait conditions -> verify departure/docking and occupied-port waiting logic.
  4. Player/cargo drop flow -> verify drop cost consumption and delayed landing processing.
- When debugging runtime behavior, inspect `game.print` output and tick-gated branches in `control.lua` first (`on_tick` clone/scan processing and 60-tick automation checks).