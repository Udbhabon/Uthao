## Quick instructions for AI coding agents

This repository is a FiveM resource implementing a taxi job for the QBX / qb-core ecosystem. The goal of this file is to provide concise, actionable context so an AI agent can be productive immediately.

- Project layout (important):
  - `fxmanifest.lua` – resource manifest, dependencies, and provided exports/UI.
  - `client/` – client-side Lua modules. Entry: `client/main.lua` which `require`s modular files (`client.state`, `client.npc`, `client.garage`, `client.meter`, `client.bookings`, `client.init`).
  - `server/` – server code. Primary logic and authoritative state (e.g., `server/main.lua`).
  - `config/` – configuration (e.g., `config/client.lua`, `config/shared.lua`) with feature toggles and location lists.
  - `html/` – UI for the meter (ui_page). Files used by the resource: `meter.html`, `meter.js`, `meter.css`.
  - `locales/` – translation JSON files used by ox_lib locale exports.

- Big-picture architecture / data flow:
  - Classic FiveM split: client holds UI and local interactions, server holds authoritative duty state, pending ride requests and assignment logic.
  - Client modules are loaded dynamically by `client/main.lua` using `require`. Keep new client code as modules under `client/` to follow existing structure.
  - Events are the primary communication mechanism: examples:
    - Client -> Server: `qb-taxijob:server:BookRide`, `qb-taxijob:server:PlayerToggledDuty`, `qb-taxijob:server:DriverLocation`.
    - Server -> Client: `qb-taxijob:client:IncomingRideRequest`, `qb-taxijob:client:SetDuty`, `qb-taxijob:client:RideAssigned`.
  - There are some mixed prefixes (`qb-taxijob` and `qb-taxi`) — preserve exact event names when changing code.

- Critical integration points and external dependencies:
  - `qbx_core` (declared dependency in `fxmanifest.lua`): use `exports.qbx_core:GetPlayer(source)` to resolve player objects.
  - `ox_lib` / `ox_target` / `ox_inventory` exports are used. Check `fxmanifest.lua` and server code for which exports are referenced (e.g., `exports.ox_inventory:Items()`).
  - Vehicle spawning uses `qbx.spawnVehicle` (via exports) and `vehiclekeys` export to set owner plate.
  - UI is served via `ui_page 'html/meter.html'`; client code interacts with it via NUI messages (see `client/meter.lua`).

- Project-specific conventions and patterns:
  - Files in `client/` are modular and `require`d by `client/main.lua`. Follow that require pattern and register globals under `Taxi = Taxi or {}` if you need shared client state.
  - Server authoritative tables are plain Lua tables keyed by `source` (player ID). Example: `dutyState[src] = true` in `server/main.lua`.
  - Use `lib.callback.register` for synchronous callbacks consumed by clients (see `qb-taxijob:server:DoesPlateExist` and `qb-taxi:server:spawnTaxi`).
  - Logging uses plain `print()` with a consistent prefix like `[qbx_taxijob]` or `[qbx_taxijob] [DEBUG]` — continue this for consistency.
  - Timeouts are set with `SetTimeout(ms, fn)` (server-side). When adding timed cleanup, mirror the existing pattern and make timeout values configurable in `config/client.lua` where appropriate.

- Examples to reference when making edits:
  - Toggle duty pattern (client ⇄ server): clients call `TriggerEvent('qb-taxijob:client:ToggleDuty')`; server listens to `QBCore:Server:SetDuty` and emits `qb-taxijob:client:SetDuty` to update the player.
  - Ride request flow: `qb-taxijob:server:BookRide` builds a request id, stores in `pendingRequests`, notifies drivers, uses `SetTimeout` to expire the request.
  - Plate check and vehicle spawn examples: `lib.callback.register('qb-taxi:server:spawnTaxi', ...)` and `lib.callback.register('qb-taxijob:server:DoesPlateExist', ...)`.

- Debugging and common dev workflows:
  - To reload the resource from the server console: `refresh` and then `restart qbx_taxijob` (client/main.lua prints this hint on failure).
  - Server-side debug prints are already present. Add `print(('[qbx_taxijob] ...'):format(...))` statements for quick logging.
  - If changing UI, update `ui_page` and add files under `html/` and bump `files` in `fxmanifest.lua`.
  - Ensure `qbx_core` and other dependencies are started before this resource (manifest `dependency 'qbx_core'`).

- Small gotchas observed in the codebase (be conservative when changing):
  - Event name prefixes are not uniform (`qb-taxijob` vs `qb-taxi`). When refactoring, keep existing names to avoid breaking clients/servers unless you update all call sites.
  - Server expects `player.PlayerData` structure from `qbx_core`. New server logic should defensively check for nil player data (see existing checks).
  - Config values are required by both client and server. Use `require 'config.shared'` or `require 'config.client'` pattern as used now.

- How to extend safely (contract):
  - Inputs: client events typically send tables (coords = {x,y,z}) or simple primitives (reqId string, bool). Check server handlers for exact shapes.
  - Outputs: server uses `TriggerClientEvent(event, target, ...)` to notify clients. Maintain same argument ordering.
  - Error modes: missing player / missing exports – follow existing defensive prints and early returns.

If anything here is unclear or you'd like me to expand a section (for example, add a short list of common editing tests or example unit-style checks), tell me which part and I'll update the file.
