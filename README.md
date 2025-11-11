## Overview
Lightweight taxi job resource for QBox. Adds NPC fares, a meter UI, polyzones for pickup/dropoff and an on-duty/off-duty toggle for taxi drivers.

## Installation
1. Place this resource in your server's `resources` folder (for example: `resources/[qbx]/qbx_taxijob`).
2. Ensure dependencies (ox_lib / lib and qbx_core) are installed and started before this resource.
3. Add `ensure qbx_taxijob` to your `server.cfg` or start the resource manually.
4. Build the NUI (React) once to generate the files under `html/dist`.

### Build the NUI (React)
The NUI is built with Vite and served from `html/dist` (see `fxmanifest.lua` `ui_page`). If `html/dist/index.html` is missing, FiveM can display a black screen.

On Windows (cmd.exe):

```
cd /d "f:\Fivem Server\server_files\resources\qbx_taxijob\html"
npm install
npm run build
```

This will create `html/dist` with the compiled assets. A minimal placeholder is included to prevent black screen until you build, but the meter UI will not function until the build is completed.

## Usage
- Toggle duty (client-side event):
	- TriggerEvent('qb-taxijob:client:ToggleDuty')
	- This will switch your on-duty state and show a notification: "You are Onduty in Taxijob" or "You are Offduty in Taxijob".

2-3 line doc for the Toggle Duty trigger
- TriggerEvent('qb-taxijob:client:ToggleDuty') toggles the player's taxi duty state. When toggled on it enables garage, blip and NPC interactions; toggling off removes those and blocks starting missions. Notifications are shown on toggle.

## Notes
- The resource respects `config.client` options: `debugPoly` (show zone debug), `useBlips` (main taxi blip) and `useTarget` (ox_target usage).
- If you want server-side duty sync or localized toggle messages, I can add those in a follow-up.
 - We no longer use the legacy hard-coded `html/meter.html`, `meter.css`, `meter.js`. Do not reference or restore those files. The React NUI implements the same actions (`openMeter`, `toggleMeter`, `updateMeter`, `resetMeter`) and callback (`enableMeter`).
