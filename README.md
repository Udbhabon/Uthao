# qbx_taxijob
Taxi Job For Qbox

## Overview
Lightweight taxi job resource for QBox. Adds NPC fares, a meter UI, polyzones for pickup/dropoff and an on-duty/off-duty toggle for taxi drivers.

## Installation
1. Place this resource in your server's `resources` folder (for example: `resources/[qbx]/qbx_taxijob`).
2. Ensure dependencies (ox_lib / lib and qbx_core) are installed and started before this resource.
3. Add `ensure qbx_taxijob` to your `server.cfg` or start the resource manually.

## Usage
- Toggle duty (client-side event):
	- TriggerEvent('qb-taxijob:client:ToggleDuty')
	- This will switch your on-duty state and show a notification: "You are Onduty in Taxijob" or "You are Offduty in Taxijob".

2-3 line doc for the Toggle Duty trigger
- TriggerEvent('qb-taxijob:client:ToggleDuty') toggles the player's taxi duty state. When toggled on it enables garage, blip and NPC interactions; toggling off removes those and blocks starting missions. Notifications are shown on toggle.

## Notes
- The resource respects `config.client` options: `debugPoly` (show zone debug), `useBlips` (main taxi blip) and `useTarget` (ox_target usage).
- If you want server-side duty sync or localized toggle messages, I can add those in a follow-up.
