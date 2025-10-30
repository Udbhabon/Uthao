-- Variables
local config = require 'config.client'
local sharedConfig = require 'config.shared'
local isLoggedIn = LocalPlayer.state.isLoggedIn
local meterIsOpen = false
local meterActive = false
local lastLocation = nil
local mouseActive = false
local garageZone, taxiParkingZone = nil, nil
local pickupLocation, dropOffLocation = nil, nil

-- Loader: require modular client pieces for qb_taxijob

-- Expose a shared Taxi table for modules if desired (keeps namespace compatibility)
Taxi = Taxi or {}

-- Load core state first (globals used by other modules)
local ok, err = pcall(function()
	require 'client.state'
	-- Load functional modules
	require 'client.npc'
	require 'client.garage'
	require 'client.meter'
	require 'client.bookings'
	require 'client.init'
end)
if not ok then
	print(('^1[qbx_taxijob] failed to load client modules: %s^7'):format(tostring(err)))
	print('^3Hint:^7 Ensure the resource was restarted after updating files (server console: refresh && restart qbx_taxijob)')
end