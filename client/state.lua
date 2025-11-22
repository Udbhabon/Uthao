-- Shared state and helpers for qb_taxijob
config = require 'config.client'
sharedConfig = require 'config.shared'
isLoggedIn = LocalPlayer.state.isLoggedIn
meterIsOpen = false
meterActive = false
lastLocation = nil
mouseActive = false
garageZone, taxiParkingZone = nil, nil
pickupLocation, dropOffLocation = nil, nil

-- used for polyzones
isInsidePickupZone = false
isInsideDropZone = false

meterData = {
    fareAmount = 6,
    currentFare = 0,
    distanceTraveled = 0
}

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
    NpcDelivered = false,
    CountDown = 180
}

taxiPed = nil
onDuty = false -- track whether player is on duty for taxi job
taxiBlip = nil -- store main taxi blip so we can remove it when off-duty

BlipAutoClearToken = 0
function scheduleClearBlipsAfter(seconds)
    BlipAutoClearToken = BlipAutoClearToken + 1
    local token = BlipAutoClearToken
    CreateThread(function()
        Wait((seconds or config.blipDissepiartime or 30) * 1000)
        if BlipAutoClearToken == token then
            TriggerEvent('qb-taxijob:client:ClearRideBlips')
        end
    end)
end

function resetNpcTask()
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

function resetMeter()
    meterData = {
        fareAmount = 6,
        currentFare = 0,
        distanceTraveled = 0
    }
end

function whitelistedVehicle()
    if not cache.vehicle then return false end

    local veh = GetEntityModel(cache.vehicle)
    local retval = false

    for i = 1, #config.allowedVehicles, 1 do
        if veh == joaat(config.allowedVehicles[i].model) then
            retval = true
            break
        end
    end

    if not retval and veh == joaat('dynasty') then
        retval = true
    end

    if not retval then
        local plate = GetVehicleNumberPlateText(cache.vehicle) or ''
        if plate ~= '' then
            local ok = lib.callback.await('qb-taxijob:server:DoesPlateExist', false, plate)
            if ok then retval = true end
        end
    end

    return retval
end

function isDriver()
    return cache.seat == -1
end

zone = nil
delieveryZone = nil

function enumerateEntitiesWithinDistance(entities, isPlayerEntities, coords, maxDistance)
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

function getVehiclesInArea(coords, maxDistance) -- Vehicle inspection in designated area
    return enumerateEntitiesWithinDistance(GetGamePool('CVehicle'), false, coords, maxDistance)
end

function isSpawnPointClear(coords, maxDistance) -- Check the spawn point to see if it's empty or not:
    return #getVehiclesInArea(coords, maxDistance) == 0
end

function getVehicleSpawnPoint()
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

function calculateFareAmount()
    if meterIsOpen and meterActive then
        local startPos = lastLocation
        local newPos = GetEntityCoords(cache.ped)
        if startPos ~= newPos then
            local newDistance = #(startPos - newPos)
            lastLocation = newPos

            meterData['distanceTraveled'] = meterData['distanceTraveled'] + (newDistance / 1609)

            local fareAmount = 0

            if (config.meter.useGpsPrice) and pickupLocation and dropOffLocation then
                local distanceBetweenPickupAndDropoff = CalculateTravelDistanceBetweenPoints(pickupLocation.x, pickupLocation.y, pickupLocation.z, dropOffLocation.x, dropOffLocation.y, dropOffLocation.z) / 1609 -- Convert to miles
                fareAmount =  (distanceBetweenPickupAndDropoff * config.meter.defaultPrice) + config.meter.startingPrice
            else 
                fareAmount = ((meterData['distanceTraveled']) * config.meter.defaultPrice) + config.meter.startingPrice
            end

            meterData['currentFare'] = math.floor(fareAmount)
            
            -- Get vehicle speed (convert to km/h)
            local veh = cache.vehicle
            local speed = 0
            if veh and veh ~= 0 then
                speed = math.floor(GetEntitySpeed(veh) * 3.6) -- Convert m/s to km/h
            end
            
            print(('[qbx_taxijob] [calculateFareAmount] Distance: %.2f mi, Fare: $%d, Speed: %d km/h'):format(meterData['distanceTraveled'], meterData['currentFare'], speed))

            SendNUIMessage({
                action = 'updateMeter',
                meterData = meterData,
                speed = speed
            })
            
            -- Broadcast to server for passenger sync (if driver has active ride)
            TriggerServerEvent('qbx_taxijob:server:MeterUpdate', meterData, speed)
        end
    else
        if not meterIsOpen then
            -- print('[qbx_taxijob] [calculateFareAmount] Meter not open')
        end
        if not meterActive then
            -- print('[qbx_taxijob] [calculateFareAmount] Meter not active')
        end
    end
end

function removeLocationsBlip()
    if taxiBlip ~= nil then
        RemoveBlip(taxiBlip)
        taxiBlip = nil
    end
end

function setDuty(state, noNotify)
    if state == onDuty then return end
    if state then
        if QBX.PlayerData.job.name ~= 'taxi' then
            exports.qbx_core:Notify('You are not a taxi driver', 'error')
            return
        end
        onDuty = true
        -- Zones and blips are created during job-based init; don't re-create on duty toggle
        if not noNotify then exports.qbx_core:Notify('You are now on duty', 'success') end
    else
        if NpcData.Active or NpcData.NpcTaken then
            exports.qbx_core:Notify('Cannot go off duty during an active NPC mission', 'error')
            return
        end
        if meterIsOpen or meterActive then
            exports.qbx_core:Notify('Cannot go off duty while the meter is open or active', 'error')
            return
        end

        onDuty = false
        -- Keep zones and blips; they are global access points and already gate actions by onDuty
        if not noNotify then exports.qbx_core:Notify('You are now off duty', 'inform') end
    end
end
