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

local function getDeliveryLocation()
    NpcData.CurrentDeliver = math.random(1, #sharedConfig.npcLocations.deliverLocations)
    if NpcData.LastDeliver then
        while NpcData.LastDeliver ~= NpcData.CurrentDeliver do
            NpcData.CurrentDeliver = math.random(1, #sharedConfig.npcLocations.deliverLocations)
        end
    end

    if NpcData.DeliveryBlip then
        RemoveBlip(NpcData.DeliveryBlip)
    end
    NpcData.DeliveryBlip = AddBlipForCoord(sharedConfig.npcLocations.deliverLocations[NpcData.CurrentDeliver].x, sharedConfig.npcLocations.deliverLocations[NpcData.CurrentDeliver].y, sharedConfig.npcLocations.deliverLocations[NpcData.CurrentDeliver].z)
    SetBlipColour(NpcData.DeliveryBlip, 3)
    SetBlipRoute(NpcData.DeliveryBlip, true)
    SetBlipRouteColour(NpcData.DeliveryBlip, 3)
    NpcData.LastDeliver = NpcData.CurrentDeliver
    if not config.useTarget then -- added checks to disable distance checking if polyzone option is used
        CreateThread(function()
            while true do
                local pos = GetEntityCoords(cache.ped)
                local dist = #(pos - vec3(sharedConfig.npcLocations.deliverLocations[NpcData.CurrentDeliver].x, sharedConfig.npcLocations.deliverLocations[NpcData.CurrentDeliver].y, sharedConfig.npcLocations.deliverLocations[NpcData.CurrentDeliver].z))
                if dist < 20 then
                    DrawMarker(2, sharedConfig.npcLocations.deliverLocations[NpcData.CurrentDeliver].x, sharedConfig.npcLocations.deliverLocations[NpcData.CurrentDeliver].y, sharedConfig.npcLocations.deliverLocations[NpcData.CurrentDeliver].z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 255, 255, 255, 255, false, false, 0, true, nil, nil, false)
                    if dist < 5 then
                        qbx.drawText3d({text = locale('info.drop_off_npc'), coords = sharedConfig.npcLocations.deliverLocations[NpcData.CurrentDeliver].xyz})
                        if IsControlJustPressed(0, 38) then
                            TaskLeaveVehicle(NpcData.Npc, cache.vehicle, 0)
                            SetEntityAsMissionEntity(NpcData.Npc, false, true)
                            SetEntityAsNoLongerNeeded(NpcData.Npc)
                            local targetCoords = sharedConfig.npcLocations.takeLocations[NpcData.LastNpc]
                            TaskGoStraightToCoord(NpcData.Npc, targetCoords.x, targetCoords.y, targetCoords.z, 1.0, -1, 0.0, 0.0)
                            SendNUIMessage({
                                action = 'toggleMeter'
                            })
                            TriggerServerEvent('qb-taxi:server:NpcPay', meterData.currentFare)
                            meterActive = false
                            SendNUIMessage({
                                action = 'resetMeter'
                            })

                            pickupLocation, pickupLocation = nil, nil

                            exports.qbx_core:Notify(locale('info.person_was_dropped_off'), 'success')
                            if NpcData.DeliveryBlip then
                                RemoveBlip(NpcData.DeliveryBlip)
                            end
                            local RemovePed = function(p)
                                SetTimeout(60000, function()
                                    DeletePed(p)
                                end)
                            end
                            RemovePed(NpcData.Npc)
                            resetNpcTask()
                            break
                        end
                    end
                end
                Wait(0)
            end
        end)
    end
end

local function callNpcPoly()
    CreateThread(function()
        while not NpcData.NpcTaken do
            if isInsidePickupZone then
                if IsControlJustPressed(0, 38) then
                    lib.hideTextUI()
                    local veh = cache.vehicle
                    local maxSeats, freeSeat = GetVehicleMaxNumberOfPassengers(veh), 0

                    for i= maxSeats - 1, 0, -1 do
                        if IsVehicleSeatFree(veh, i) then
                            freeSeat = i
                            break
                        end
                    end

                    meterIsOpen = true
                    meterActive = true

                    lastLocation = GetEntityCoords(cache.ped)
                    SendNUIMessage({
                        action = 'openMeter',
                        toggle = true,
                        meterData = config.meter
                    })
                    SendNUIMessage({
                        action = 'toggleMeter'
                    })
                    ClearPedTasksImmediately(NpcData.Npc)
                    FreezeEntityPosition(NpcData.Npc, false)
                    TaskEnterVehicle(NpcData.Npc, veh, -1, freeSeat, 1.0, 0)
                    exports.qbx_core:Notify(locale('info.go_to_location'), 'inform')
                    if NpcData.NpcBlip then
                        RemoveBlip(NpcData.NpcBlip)
                    end
                    getDeliveryLocation()
                    NpcData.NpcTaken = true
                    createNpcDelieveryLocation()
                    zone:remove()
                    lib.hideTextUI()
                end
            end
            Wait(0)
        end
    end)
end

local function onEnterCallZone()
    if whitelistedVehicle() and not isInsidePickupZone and not NpcData.NpcTaken then
        isInsidePickupZone = true
        lib.showTextUI(locale('info.call_npc'), {position = 'left-center'})
        callNpcPoly()
    end
end

local function onExitCallZone()
    lib.hideTextUI()
    isInsidePickupZone = false
end

local function createNpcPickUpLocation()
    zone = lib.zones.box({
        coords = config.pzLocations.takeLocations[NpcData.CurrentNpc].coord,
        size = vec3(config.pzLocations.takeLocations[NpcData.CurrentNpc].height, config.pzLocations.takeLocations[NpcData.CurrentNpc].width, (config.pzLocations.takeLocations[NpcData.CurrentNpc].maxZ - config.pzLocations.takeLocations[NpcData.CurrentNpc].minZ)),
        rotation = config.pzLocations.takeLocations[NpcData.CurrentNpc].heading,
        debug = config.debugPoly,
        onEnter = onEnterCallZone,
        onExit = onExitCallZone
    })
end

-- Duty management
local function removeLocationsBlip()
    if taxiBlip ~= nil then
        RemoveBlip(taxiBlip)
        taxiBlip = nil
    end
end

local function setDuty(state, noNotify)
    if state == onDuty then return end
    if state then
        if QBX.PlayerData.job.name ~= 'taxi' then
            exports.qbx_core:Notify('You are not a taxi driver', 'error')
            return
        end
        onDuty = true
        if type(setupGarageZone) == 'function' then pcall(setupGarageZone) end
        if type(setupTaxiParkingZone) == 'function' then pcall(setupTaxiParkingZone) end
        if type(setLocationsBlip) == 'function' then pcall(setLocationsBlip) end
        if not noNotify then exports.qbx_core:Notify('You are now on duty', 'success') end
    else
        -- Prevent going off duty during active tasks
        if NpcData.Active or NpcData.NpcTaken then
            exports.qbx_core:Notify('Cannot go off duty during an active NPC mission', 'error')
            return
        end
        if meterIsOpen or meterActive then
            exports.qbx_core:Notify('Cannot go off duty while the meter is open or active', 'error')
            return
        end

        onDuty = false
        if type(destroyGarageZone) == 'function' then pcall(destroyGarageZone) end
        if type(destroyTaxiParkingZone) == 'function' then pcall(destroyTaxiParkingZone) end
        if type(removeLocationsBlip) == 'function' then pcall(removeLocationsBlip) end
        if not noNotify then exports.qbx_core:Notify('You are now off duty', 'inform') end
    end
end



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

local function onEnterDropZone()
    if whitelistedVehicle() and not isInsideDropZone and NpcData.NpcTaken then
        isInsideDropZone = true
        lib.showTextUI(locale('info.drop_off_npc'), {position = 'left-center'})
        dropNpcPoly()
    end
end

local function onExitDropZone()
    lib.hideTextUI()
    isInsideDropZone = false

end

function createNpcDelieveryLocation()
    delieveryZone = lib.zones.box({
        coords = config.pzLocations.dropLocations[NpcData.CurrentDeliver].coord,
        size = vec3(config.pzLocations.dropLocations[NpcData.CurrentDeliver].height, config.pzLocations.dropLocations[NpcData.CurrentDeliver].width, (config.pzLocations.dropLocations[NpcData.CurrentDeliver].maxZ - config.pzLocations.dropLocations[NpcData.CurrentDeliver].minZ)),
        rotation = config.pzLocations.dropLocations[NpcData.CurrentDeliver].heading,
        debug = config.debugPoly,
        onEnter = onEnterDropZone,
        onExit = onExitDropZone
    })
end

function dropNpcPoly()
    CreateThread(function()
        while NpcData.NpcTaken do
            if isInsideDropZone then
                if IsControlJustPressed(0, 38) then
                    lib.hideTextUI()
                    local veh = cache.vehicle
                    TaskLeaveVehicle(NpcData.Npc, veh, 0)
                    Wait(1000)
                    SetVehicleDoorShut(veh, 3, false)
                    SetEntityAsMissionEntity(NpcData.Npc, false, true)
                    SetEntityAsNoLongerNeeded(NpcData.Npc)
                    local targetCoords = sharedConfig.npcLocations.takeLocations[NpcData.LastNpc]
                    TaskGoStraightToCoord(NpcData.Npc, targetCoords.x, targetCoords.y, targetCoords.z, 1.0, -1, 0.0, 0.0)
                    SendNUIMessage({
                        action = 'toggleMeter'
                    })
                    TriggerServerEvent('qb-taxi:server:NpcPay', meterData.currentFare)
                    meterActive = false
                    SendNUIMessage({
                        action = 'resetMeter'
                    })
                    exports.qbx_core:Notify(locale('info.person_was_dropped_off'), 'success')
                    if NpcData.DeliveryBlip ~= nil then
                        RemoveBlip(NpcData.DeliveryBlip)
                    end
                    local RemovePed = function(p)
                        SetTimeout(60000, function()
                            DeletePed(p)
                        end)
                    end
                    RemovePed(NpcData.Npc)
                    resetNpcTask()
                    delieveryZone:remove()
                    lib.hideTextUI()
                    break
                end
            end
            Wait(0)
        end
    end)
end

local function setLocationsBlip()
    if not config.useBlips then return end
    if taxiBlip ~= nil then return end
    taxiBlip = AddBlipForCoord(config.locations.main.coords.x, config.locations.main.coords.y, config.locations.main.coords.z)
    SetBlipSprite(taxiBlip, 198)
    SetBlipDisplay(taxiBlip, 4)
    SetBlipScale(taxiBlip, 0.6)
    SetBlipAsShortRange(taxiBlip, true)
    SetBlipColour(taxiBlip, 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(locale('info.blip_name'))
    EndTextCommandSetBlipName(taxiBlip)
end

local function taxiGarage()
    if not onDuty then
        exports.qbx_core:Notify('You must be on duty to access the taxi garage', 'error')
        return
    end

    local registeredMenu = {
        id = 'garages_depotlist',
        title = locale('menu.taxi_menu_header'),
        options = {}
    }
    local options = {}
    for _, v in pairs(config.allowedVehicles) do

        options[#options + 1] = {
            title = v.label,
            event = 'qb-taxi:client:TakeVehicle',
            args = {model = v.model},
            icon = 'fa-solid fa-taxi'
        }
    end

    registeredMenu['options'] = options
    lib.registerContext(registeredMenu)
    lib.showContext('garages_depotlist')
end

local function setupGarageZone()
    if config.useTarget then
        lib.requestModel(`a_m_m_indian_01`)
        taxiPed = CreatePed(3, `a_m_m_indian_01`, 894.93, -179.12, 74.7 - 1.0, 237.09, false, true)
        SetModelAsNoLongerNeeded(`a_m_m_indian_01`)
        SetBlockingOfNonTemporaryEvents(taxiPed, true)
        FreezeEntityPosition(taxiPed, true)
        SetEntityInvincible(taxiPed, true)
        exports.ox_target:addLocalEntity(taxiPed, {
            {
                type = 'client',
                event = 'qb-taxijob:client:requestcab',
                icon = 'fa-solid fa-taxi',
                label = locale('info.request_taxi_target'),
                job = 'taxi',
            }
        })
    else
        local function onEnter()
            if not cache.vehicle then
                lib.showTextUI(locale('info.request_taxi'))
            end
        end

        local function onExit()
            lib.hideTextUI()
        end

        local function inside()
            if IsControlJustPressed(0, 38) then
                lib.hideTextUI()
                taxiGarage()
                return
            end
        end

        garageZone = lib.zones.box({
            coords = config.locations.garage.coords,
            size = vec3(1.6, 4.0, 2.8),
            rotation = 328.5,
            debug = config.debugPoly,
            inside = inside,
            onEnter = onEnter,
            onExit = onExit
        })
    end
end

local function destroyGarageZone()
    if not garageZone then return end

    garageZone:remove()
    garageZone = nil
end

function setupTaxiParkingZone()
        taxiParkingZone = lib.zones.box({
        coords = vec3(config.locations.main.coords.x, config.locations.main.coords.y, config.locations.main.coords.z),
        size = vec3(4.0, 4.0, 4.0),
        rotation = 55,
        debug = config.debugPoly,
        inside = function()
            if QBX.PlayerData.job.name ~= 'taxi' then return end
            if not onDuty then
                exports.qbx_core:Notify('You are off duty', 'error')
                return
            end
            if IsControlJustPressed(0, 38) then
                if whitelistedVehicle() then
                    if meterIsOpen then
                        TriggerEvent('qb-taxi:client:toggleMeter')
                        meterActive = false
                    end
                    DeleteVehicle(cache.vehicle)
                    exports.qbx_core:Notify(locale('info.taxi_returned'), 'success')
                end
            end
        end,
        onEnter = function()
            lib.showTextUI(locale('info.vehicle_parking'))
        end,
        onExit = function()
            lib.hideTextUI()
        end
    })
end

local function destroyTaxiParkingZone()
    if not taxiParkingZone then return end

    taxiParkingZone:remove()
    taxiParkingZone = nil
end

RegisterNetEvent('qb-taxi:client:TakeVehicle', function(data)
    if not onDuty then
        exports.qbx_core:Notify('You must be on duty to take a taxi', 'error')
        return
    end
    local SpawnPoint = getVehicleSpawnPoint()
    if SpawnPoint then
        local coords = config.cabSpawns[SpawnPoint]
        local CanSpawn = isSpawnPointClear(coords, 2.0)
        if CanSpawn then
            local netId = lib.callback.await('qb-taxi:server:spawnTaxi', false, data.model, coords)
            local veh = NetToVeh(netId)
            SetVehicleFuelLevel(veh, 100.0)
            SetVehicleEngineOn(veh, true, true, false)
        else
            exports.qbx_core:Notify(locale('info.no_spawn_point'), 'error')
        end
    else
        exports.qbx_core:Notify(locale('info.no_spawn_point'), 'error')
        return
    end
end)

-- Events
RegisterNetEvent('qb-taxi:client:DoTaxiNpc', function()
    if not onDuty then
        exports.qbx_core:Notify('You must be on duty to start an NPC mission', 'error')
        return
    end

    if whitelistedVehicle() then
        if not NpcData.Active then
            NpcData.CurrentNpc = math.random(1, #sharedConfig.npcLocations.takeLocations)
            if NpcData.LastNpc ~= nil then
                while NpcData.LastNpc ~= NpcData.CurrentNpc do
                    NpcData.CurrentNpc = math.random(1, #sharedConfig.npcLocations.takeLocations)
                end
            end

            local Gender = math.random(1, #config.npcSkins)
            local PedSkin = math.random(1, #config.npcSkins[Gender])
            local model = GetHashKey(config.npcSkins[Gender][PedSkin])
            lib.requestModel(model)
            NpcData.Npc = CreatePed(3, model, sharedConfig.npcLocations.takeLocations[NpcData.CurrentNpc].x, sharedConfig.npcLocations.takeLocations[NpcData.CurrentNpc].y, sharedConfig.npcLocations.takeLocations[NpcData.CurrentNpc].z - 0.98, sharedConfig.npcLocations.takeLocations[NpcData.CurrentNpc].w, true, true)
            SetModelAsNoLongerNeeded(model)
            PlaceObjectOnGroundProperly(NpcData.Npc)
            FreezeEntityPosition(NpcData.Npc, true)
            if NpcData.NpcBlip ~= nil then
                RemoveBlip(NpcData.NpcBlip)
            end
            exports.qbx_core:Notify(locale('info.npc_on_gps'), 'success')

            -- added checks to disable distance checking if polyzone option is used
            if config.useTarget then
                createNpcPickUpLocation()
            end

            NpcData.NpcBlip = AddBlipForCoord(sharedConfig.npcLocations.takeLocations[NpcData.CurrentNpc].x, sharedConfig.npcLocations.takeLocations[NpcData.CurrentNpc].y, sharedConfig.npcLocations.takeLocations[NpcData.CurrentNpc].z)
            SetBlipColour(NpcData.NpcBlip, 3)
            SetBlipRoute(NpcData.NpcBlip, true)
            SetBlipRouteColour(NpcData.NpcBlip, 3)
            NpcData.LastNpc = NpcData.CurrentNpc
            NpcData.Active = true

            -- added checks to disable distance checking if polyzone option is used
            if not config.useTarget then
                CreateThread(function()
                    while not NpcData.NpcTaken do

                        local pos = GetEntityCoords(cache.ped)
                        local dist = #(pos - vec3(sharedConfig.npcLocations.takeLocations[NpcData.CurrentNpc].x, sharedConfig.npcLocations.takeLocations[NpcData.CurrentNpc].y, sharedConfig.npcLocations.takeLocations[NpcData.CurrentNpc].z))

                        if dist < 20 then
                            DrawMarker(2, sharedConfig.npcLocations.takeLocations[NpcData.CurrentNpc].x, sharedConfig.npcLocations.takeLocations[NpcData.CurrentNpc].y, sharedConfig.npcLocations.takeLocations[NpcData.CurrentNpc].z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 255, 255, 255, 255, false, false, 0, true, nil, nil, false)

                            if dist < 5 then
                                qbx.drawText3d({text = locale('info.call_npc'), coords = sharedConfig.npcLocations.takeLocations[NpcData.CurrentNpc].xyz})
                                if IsControlJustPressed(0, 38) then
                                    local maxSeats, freeSeat = GetVehicleMaxNumberOfPassengers(cache.vehicle), 0

                                    for i=maxSeats - 1, 0, -1 do
                                        if IsVehicleSeatFree(cache.vehicle, i) then
                                            freeSeat = i
                                            break
                                        end
                                    end

                                    pickupLocation = GetEntityCoords(cache.ped)

                                    meterIsOpen = true
                                    meterActive = true
                                    lastLocation = GetEntityCoords(cache.ped)
                                    SendNUIMessage({
                                        action = 'openMeter',
                                        toggle = true,
                                        meterData = config.meter
                                    })
                                    SendNUIMessage({
                                        action = 'toggleMeter'
                                    })
                                    ClearPedTasksImmediately(NpcData.Npc)
                                    FreezeEntityPosition(NpcData.Npc, false)
                                    TaskEnterVehicle(NpcData.Npc, cache.vehicle, -1, freeSeat, 1.0, 0)
                                    exports.qbx_core:Notify(locale('info.go_to_location'), 'inform')
                                    if NpcData.NpcBlip ~= nil then
                                        RemoveBlip(NpcData.NpcBlip)
                                    end
                                    getDeliveryLocation()
                                    dropOffLocation = config.pzLocations.dropLocations[NpcData.CurrentDeliver].coord.xyz
                                    NpcData.NpcTaken = true
                                end
                            end
                        end

                        Wait(0)
                    end
                end)
            end
        else
            exports.qbx_core:Notify(locale('error.already_mission'), 'error')
        end
    else
        exports.qbx_core:Notify(locale('error.not_in_taxi'), 'error')
    end
end)

RegisterNetEvent('qb-taxi:client:toggleMeter', function()
    if cache.vehicle then
        if whitelistedVehicle() then
            if not meterIsOpen and isDriver() then
                SendNUIMessage({
                    action = 'openMeter',
                    toggle = true,
                    meterData = config.meter
                })
                meterIsOpen = true
            else
                SendNUIMessage({
                    action = 'openMeter',
                    toggle = false
                })
                meterIsOpen = false
            end
        else
            exports.qbx_core:Notify(locale('error.missing_meter'), 'error')
        end
    else
        exports.qbx_core:Notify(locale('error.no_vehicle'), 'error')
    end
end)

RegisterNetEvent('qb-taxi:client:enableMeter', function()
    if meterIsOpen then
        SendNUIMessage({
            action = 'toggleMeter'
        })
    else
        exports.qbx_core:Notify(locale('error.not_active_meter'), 'error')
    end
end)

RegisterNetEvent('qb-taxi:client:toggleMuis', function()
    Wait(400)
    if meterIsOpen then
        if not mouseActive then
            SetNuiFocus(true, true)
            mouseActive = true
        end
    else
        exports.qbx_core:Notify(locale('error.no_meter_sight'), 'error')
    end
end)

RegisterNetEvent('qb-taxijob:client:requestcab', function()
    taxiGarage()
end)

-- NUI Callbacks

RegisterNUICallback('enableMeter', function(data, cb)
    meterActive = data.enabled
    if not meterActive then resetMeter() end
    lastLocation = GetEntityCoords(cache.ped)
    cb('ok')
end)

RegisterNUICallback('hideMouse', function(_, cb)
    SetNuiFocus(false, false)
    mouseActive = false
    cb('ok')
end)

-- Threads
CreateThread(function()
    while true do
        Wait(2000)
        calculateFareAmount()
    end
end)

CreateThread(function()
    while true do
        if not cache.vehicle then
            if meterIsOpen then
                SendNUIMessage({
                    action = 'openMeter',
                    toggle = false
                })
                meterIsOpen = false
            end
        end
        Wait(200)
    end
end)

local function init()
    if QBX.PlayerData.job.name == 'taxi' then
        setupGarageZone()
        setupTaxiParkingZone()
        setLocationsBlip()
    end
end

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    destroyGarageZone()
    destroyTaxiParkingZone()
    init()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    isLoggedIn = true
    -- default to on-duty for players who have the taxi job to preserve previous behaviour
    onDuty = (QBX.PlayerData.job.name == 'taxi')
    init()
end)

-- Events to control duty state
RegisterNetEvent('qb-taxijob:client:SetDuty', function(state)
    setDuty(state)
end)

RegisterNetEvent('qb-taxijob:client:ToggleDuty', function()
    local newState = not onDuty
    -- suppress default notification from setDuty and send custom messages below
    setDuty(newState, true)
    -- inform the server so it can log/debug duty changes centrally (include player coords)
    do
        local ped = PlayerPedId()
        local c = GetEntityCoords(ped)
        local coords = { x = tonumber(string.format('%.2f', c.x)), y = tonumber(string.format('%.2f', c.y)), z = tonumber(string.format('%.2f', c.z)) }
        TriggerServerEvent('qb-taxijob:server:PlayerToggledDuty', newState, coords)
    end
    if newState then
        exports.qbx_core:Notify('You are Onduty in Taxijob', 'success')
    else
        exports.qbx_core:Notify('You are Offduty in Taxijob', 'inform')
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    isLoggedIn = false
end)

CreateThread(function()
    if not isLoggedIn then return end
    init()
end)


-- Plate check result from server
RegisterNetEvent('qb-taxijob:client:CheckPlateResult', function(plate, exists)
    print(('[qbx_taxijob] Server check: Plate=%s | playerVehicle=%s'):format(tostring(plate), tostring(exists)))
end)

-- Add a quick command to check current vehicle plate ownership and print debug to F8
RegisterCommand('checkplate', function()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        print('[qbx_taxijob] Not in a vehicle')
        return
    end

    local veh = GetVehiclePedIsIn(ped, false)
    local plate = GetVehicleNumberPlateText(veh) or ''

    -- Ask server to check the plate (server wrapper uses qbx_vehicles export)
    TriggerServerEvent('qb-taxijob:server:CheckPlate', plate)

    -- If the export is available client-side, call it directly as well for immediate feedback
    -- Attempt client-side export safely (many servers expose this export server-side only)
    if exports and exports.qbx_vehicles then
        local ok, res = pcall(function()
            return exports.qbx_vehicles:DoesPlayerVehiclePlateExist(plate)
        end)
        if ok then
            print(('[qbx_taxijob] Client export: Plate=%s | playerVehicle=%s'):format(tostring(plate), tostring(res)))
        else
            print('[qbx_taxijob] Client export not available (server-only). Using server check instead.')
        end
    end
end, false)