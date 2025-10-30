-- Legacy backup of client/main.lua
-- This file is an exact copy of the original monolithic client script kept as a backup.
-- The resource now uses modularized client files instead. If anything breaks, restore this file to client/main.lua.

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

-- used for polyzones
local isInsidePickupZone = false
local isInsideDropZone = false

local meterData = {
    fareAmount = 6,
    currentFare = 0,
    distanceTraveled = 0
}

local NpcData = {
    Active = false,
    CurrentNpc = nil,
    LastNpc = nil,
    CurrentDeliver = nil,
    LastDeliver = nil,
    Npc = nil,
    NpcBlip = nil,
    DeliveryBlip = nil,
    NpcTaken = false,
    NpcDelivered = false,
    CountDown = 180
}

local taxiPed = nil
local onDuty = false -- track whether player is on duty for taxi job
local taxiBlip = nil -- store main taxi blip so we can remove it when off-duty
-- Blip auto-clear token to avoid race between multiple schedules
local BlipAutoClearToken = 0
local function scheduleClearBlipsAfter(seconds)
    BlipAutoClearToken = BlipAutoClearToken + 1
    local token = BlipAutoClearToken
    CreateThread(function()
        Wait((seconds or config.blipDissepiartime or 30) * 1000)
        if BlipAutoClearToken == token then
            TriggerEvent('qb-taxijob:client:ClearRideBlips')
        end
    end)
end

local function resetNpcTask()
    NpcData = {
        Active = false,
        CurrentNpc = nil,
        LastNpc = nil,
        CurrentDeliver = nil,
        LastDeliver = nil,
        Npc = nil,
        NpcBlip = nil,
        DeliveryBlip = nil,
        NpcTaken = false,
        NpcDelivered = false
    }
end

local function resetMeter()
    meterData = {
        fareAmount = 6,
        currentFare = 0,
        distanceTraveled = 0
    }
end

local function whitelistedVehicle()
    if not cache.vehicle then return false end

    local veh = GetEntityModel(cache.vehicle)
    local retval = false

    for i = 1, #config.allowedVehicles, 1 do
        if veh == joaat(config.allowedVehicles[i].model) then
            retval = true
            break
        end
    end

    -- keep legacy hard-coded allowance for dynasty (use joaat to avoid backtick syntax)
    if not retval and veh == joaat('dynasty') then
        retval = true
    end

    -- If still not whitelisted, check if the current vehicle is a player-owned vehicle by plate
    if not retval then
        local plate = GetVehicleNumberPlateText(cache.vehicle) or ''
        if plate ~= '' then
            local ok = lib.callback.await('qb-taxijob:server:DoesPlateExist', false, plate)
            if ok then retval = true end
        end
    end

    return retval
end

local function isDriver()
    return cache.seat == -1
end

local zone
local delieveryZone

local function enumerateEntitiesWithinDistance(entities, isPlayerEntities, coords, maxDistance)
    local nearbyEntities = {}
    if coords then
        coords = vec3(coords.x, coords.y, coords.z)
    else
        coords = GetEntityCoords(cache.ped)
    end
    for k, entity in pairs(entities) do
        local distance = #(coords - GetEntityCoords(entity))
        if distance <= maxDistance then
            nearbyEntities[#nearbyEntities + 1] = isPlayerEntities and k or entity
        end
    end
    return nearbyEntities
end

local function getVehiclesInArea(coords, maxDistance) -- Vehicle inspection in designated area
    return enumerateEntitiesWithinDistance(GetGamePool('CVehicle'), false, coords, maxDistance)
end

local function isSpawnPointClear(coords, maxDistance) -- Check the spawn point to see if it's empty or not:
    return #getVehiclesInArea(coords, maxDistance) == 0
end

local function getVehicleSpawnPoint()
    local near = nil
    local distance = 10000
    for k, v in pairs(config.cabSpawns) do
        if isSpawnPointClear(vec3(v.x, v.y, v.z), 2.5) then
            local pos = GetEntityCoords(cache.ped)
            local cur_distance = #(pos - vec3(v.x, v.y, v.z))
            if cur_distance < distance then
                distance = cur_distance
                near = k
            end
        end
    end
    return near
end

local function calculateFareAmount()
    if meterIsOpen and meterActive then
        local startPos = lastLocation
        local newPos = GetEntityCoords(cache.ped)
        if startPos ~= newPos then
            local newDistance = #(startPos - newPos)
            lastLocation = newPos

            meterData['distanceTraveled'] += (newDistance / 1609)

            local fareAmount = 0

            if (config.meter.useGpsPrice) and pickupLocation and dropOffLocation then
                local distanceBetweenPickupAndDropoff = CalculateTravelDistanceBetweenPoints(pickupLocation.x, pickupLocation.y, pickupLocation.z, dropOffLocation.x, dropOffLocation.y, dropOffLocation.z) / 1609 -- Convert to miles
                fareAmount =  (distanceBetweenPickupAndDropoff * config.meter.defaultPrice) + config.meter.startingPrice
            else 
                fareAmount = ((meterData['distanceTraveled']) * config.meter.defaultPrice) + config.meter.startingPrice
            end

            meterData['currentFare'] = math.floor(fareAmount)


            SendNUIMessage({
                action = 'updateMeter',
                meterData = meterData
            })
        end
    end
end
