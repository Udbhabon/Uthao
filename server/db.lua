-- Simple JSON-backed store for driver duty/status, users, rides, and vehicles
-- File: server/db.lua

local RESOURCE = GetCurrentResourceName()
local DB_PATH = 'data/db.json' -- kept inside resource folder; SaveResourceFile will create/update it

---@class TaxiJsonDB
local DB = {
    data = {
        users = {},       -- [user_id=citizenid] = { user_id, name, phone_number, payment_method_id }
        drivers = {},     -- [driver_id=citizenid] = { driver_id, name, job, availability_status, location, vehicle_id, lastOn, lastOff }
        vehicles = {},    -- [vehicle_id=plate] = { vehicle_id, driver_id, vehicle_type, license_plate, model }
        rides = {},       -- [ride_id=reqId] = { ride_id, user_id, driver_id, pickup_location, dropoff_location, status, start_time, end_time, fare_amount }
        transactions = {},-- kept for future expansion
        ratings = {},     -- kept for future expansion
    },
    _dirty = false,
    _saveTimer = nil,
    driverActiveRide = {}, -- [driver_id=citizenid] = ride_id
}

local function safeDecode(raw)
    if not raw or raw == '' then return nil end
    local ok, obj = pcall(json.decode, raw)
    if ok and type(obj) == 'table' then return obj end
    print(('[qbx_taxijob] [WARNING] Failed to decode %s; starting fresh'):format(DB_PATH))
    return nil
end

local function load()
    local raw = LoadResourceFile(RESOURCE, DB_PATH)
    local obj = safeDecode(raw)
    if obj and type(obj) == 'table' then
        DB.data = obj
    else
        -- ensure table shape
        DB.data = DB.data or {
            users = {}, drivers = {}, vehicles = {}, rides = {}, transactions = {}, ratings = {},
        }
        -- write an initial file so it exists on disk
        SaveResourceFile(RESOURCE, DB_PATH, json.encode(DB.data), -1)
    end
end

local function flush()
    DB._dirty = false
    DB._saveTimer = nil
    local encoded = json.encode(DB.data)
    SaveResourceFile(RESOURCE, DB_PATH, encoded, -1)
end

local function scheduleSave()
    if DB._saveTimer then return end
    DB._dirty = true
    DB._saveTimer = SetTimeout(750, function()
        flush()
    end)
end

-- Utilities to extract IDs and names from qbx_core player
local function getCitizenId(player)
    return player and player.PlayerData and player.PlayerData.citizenid or nil
end

local function getPlayerName(player)
    if not player or not player.PlayerData then return 'unknown' end
    local ci = player.PlayerData.charinfo
    if ci and ci.firstname and ci.lastname then
        return ci.firstname .. ' ' .. ci.lastname
    end
    return player.PlayerData.name or 'unknown'
end

-- Public API

function DB.init()
    load()
    AddEventHandler('onResourceStop', function(res)
        if res ~= RESOURCE then return end
        if DB._dirty then flush() end
    end)
end

function DB.upsertUserFromPlayer(player)
    local uid = getCitizenId(player)
    if not uid then return end
    local users = DB.data.users
    users[uid] = users[uid] or { user_id = uid }
    users[uid].name = getPlayerName(player)
    scheduleSave()
end

-- availability_status: 'off' | 'available' | 'busy'
function DB.updateDriverStatusFromPlayer(player, onDuty)
    local did = getCitizenId(player)
    if not did then return end
    local drivers = DB.data.drivers
    drivers[did] = drivers[did] or { driver_id = did }
    local now = os.time()
    drivers[did].name = getPlayerName(player)
    drivers[did].job = player.PlayerData and player.PlayerData.job and player.PlayerData.job.name or 'unknown'
    drivers[did].availability_status = onDuty and 'available' or 'off'
    if onDuty then drivers[did].lastOn = now else drivers[did].lastOff = now end
    -- best-effort location
    local ped = GetPlayerPed(player.PlayerData and player.PlayerData.source or 0)
    if ped and ped ~= 0 then
        local c = GetEntityCoords(ped)
        drivers[did].location = { x = c.x, y = c.y, z = c.z }
    end
    scheduleSave()
end

function DB.assignVehicleToDriver(player, plate, model)
    local did = getCitizenId(player)
    if not did or not plate then return end
    local vehicles = DB.data.vehicles
    vehicles[plate] = vehicles[plate] or { vehicle_id = plate }
    vehicles[plate].driver_id = did
    vehicles[plate].license_plate = plate
    vehicles[plate].model = model
    vehicles[plate].vehicle_type = 'sedan' -- unknown; placeholder
    local drivers = DB.data.drivers
    drivers[did] = drivers[did] or { driver_id = did }
    drivers[did].vehicle_id = plate
    scheduleSave()
end

function DB.createRide(ride_id, requesterPlayer, pickup, message)
    if not ride_id then return end
    local uid = getCitizenId(requesterPlayer)
    if not uid then return end
    DB.upsertUserFromPlayer(requesterPlayer)
    local rides = DB.data.rides
    rides[ride_id] = {
        ride_id = ride_id,
        user_id = uid,
        driver_id = nil,
        pickup_location = pickup and { x = pickup.x, y = pickup.y, z = pickup.z } or nil,
        dropoff_location = nil,
        status = 'booked',
        start_time = nil,
        end_time = nil,
        fare_amount = nil,
        note = message or '',
    }
    scheduleSave()
end

function DB.acceptRide(ride_id, driverPlayer)
    if not ride_id then return end
    local rides = DB.data.rides
    local r = rides[ride_id]
    if not r then return end
    local did = getCitizenId(driverPlayer)
    if not did then return end
    DB.updateDriverStatusFromPlayer(driverPlayer, true)
    r.driver_id = did
    r.status = 'accepted'
    DB.driverActiveRide[did] = ride_id
    -- mark driver busy
    local drivers = DB.data.drivers
    drivers[did] = drivers[did] or { driver_id = did }
    drivers[did].availability_status = 'busy'
    scheduleSave()
end

function DB.markInProgressByDriver(driverPlayer)
    local did = getCitizenId(driverPlayer)
    if not did then return end
    local ride_id = DB.driverActiveRide[did]
    if not ride_id then return end
    local r = DB.data.rides[ride_id]
    if not r then return end
    if r.status ~= 'in-progress' then
        r.status = 'in-progress'
        r.start_time = os.time()
        scheduleSave()
    end
end

function DB.completeRideByDriver(driverPlayer)
    local did = getCitizenId(driverPlayer)
    if not did then return end
    local ride_id = DB.driverActiveRide[did]
    if ride_id then
        local r = DB.data.rides[ride_id]
        if r then
            r.status = 'completed'
            r.end_time = os.time()
        end
    end
    DB.driverActiveRide[did] = nil
    -- driver back to available if still on duty
    local drivers = DB.data.drivers
    drivers[did] = drivers[did] or { driver_id = did }
    if drivers[did].availability_status ~= 'off' then
        drivers[did].availability_status = 'available'
    end
    scheduleSave()
end

-- Expose globally for use in server/main.lua without require
QbxTaxiDB = DB
DB.init()
