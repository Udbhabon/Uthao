-- NPC mission related functionality for qb_taxijob

function getDeliveryLocation()
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
            local targetCoords = vec3(sharedConfig.npcLocations.deliverLocations[NpcData.CurrentDeliver].x, sharedConfig.npcLocations.deliverLocations[NpcData.CurrentDeliver].y, sharedConfig.npcLocations.deliverLocations[NpcData.CurrentDeliver].z)
            while true do
                local pos = GetEntityCoords(cache.ped)
                local dist = #(pos - targetCoords)
                
                if dist < 20 then
                    Wait(1) -- Only wait 1ms when drawing markers (needs frame-perfect rendering)
                    DrawMarker(2, targetCoords.x, targetCoords.y, targetCoords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 255, 255, 255, 255, false, false, 0, true, nil, nil, false)
                    if dist < 5 then
                        qbx.drawText3d({text = locale('info.drop_off_npc'), coords = sharedConfig.npcLocations.deliverLocations[NpcData.CurrentDeliver].xyz})
                        if IsControlJustPressed(0, 38) then
                            -- ensure NPC properly leaves the vehicle (retry/clear tasks if needed)
                            local function ensurePedLeavesVehicle(ped, veh)
                                TaskLeaveVehicle(ped, veh, 0)
                                Wait(800)
                                local tries = 0
                                while IsPedInAnyVehicle(ped, false) and tries < 4 do
                                    ClearPedTasksImmediately(ped)
                                    Wait(250)
                                    TaskLeaveVehicle(ped, veh, 0)
                                    Wait(500)
                                    tries = tries + 1
                                end
                            end
                            ensurePedLeavesVehicle(NpcData.Npc, cache.vehicle)
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
                else
                    Wait(500) -- Far away - check less frequently
                end
            end
        end)
    end
end

function callNpcPoly()
    CreateThread(function()
        while not NpcData.NpcTaken do
            Wait(100) -- Check key press every 100ms instead of every frame
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
                    break
                end
            end
        end
    end)
end

function onEnterCallZone()
    if whitelistedVehicle() and not isInsidePickupZone and not NpcData.NpcTaken then
        isInsidePickupZone = true
        lib.showTextUI(locale('info.call_npc'), {position = 'left-center'})
        callNpcPoly()
    end
end

function onExitCallZone()
    lib.hideTextUI()
    isInsidePickupZone = false
end

function onEnterDropZone()
    if whitelistedVehicle() and not isInsideDropZone and NpcData.NpcTaken then
        isInsideDropZone = true
        lib.showTextUI(locale('info.drop_off_npc'), {position = 'left-center'})
        dropNpcPoly()
    end
end

function onExitDropZone()
    lib.hideTextUI()
    isInsideDropZone = false
end

function createNpcPickUpLocation()
    zone = lib.zones.box({
        coords = config.pzLocations.takeLocations[NpcData.CurrentNpc].coord,
        size = vec3(config.pzLocations.takeLocations[NpcData.CurrentNpc].height, config.pzLocations.takeLocations[NpcData.CurrentNpc].width, (config.pzLocations.takeLocations[NpcData.CurrentNpc].maxZ - config.pzLocations.takeLocations[NpcData.CurrentNpc].minZ)),
        rotation = config.pzLocations.takeLocations[NpcData.CurrentNpc].heading,
        debug = config.debugPoly,
        onEnter = onEnterCallZone,
        onExit = onExitCallZone
    })
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
            Wait(100) -- Check key press every 100ms instead of every frame
            if isInsideDropZone then
                        if IsControlJustPressed(0, 38) then
                    lib.hideTextUI()
                    local veh = cache.vehicle
                    -- try to reliably remove NPC from vehicle
                    local function ensurePedLeavesVehicle(ped, veh)
                        TaskLeaveVehicle(ped, veh, 0)
                        Wait(800)
                        local tries = 0
                        while IsPedInAnyVehicle(ped, false) and tries < 4 do
                            ClearPedTasksImmediately(ped)
                            Wait(250)
                            TaskLeaveVehicle(ped, veh, 0)
                            Wait(500)
                            tries = tries + 1
                        end
                    end
                    ensurePedLeavesVehicle(NpcData.Npc, veh)
                    Wait(100)
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
        end
    end)
end

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

            if config.useTarget then
                createNpcPickUpLocation()
            end

            NpcData.NpcBlip = AddBlipForCoord(sharedConfig.npcLocations.takeLocations[NpcData.CurrentNpc].x, sharedConfig.npcLocations.takeLocations[NpcData.CurrentNpc].y, sharedConfig.npcLocations.takeLocations[NpcData.CurrentNpc].z)
            SetBlipColour(NpcData.NpcBlip, 3)
            SetBlipRoute(NpcData.NpcBlip, true)
            SetBlipRouteColour(NpcData.NpcBlip, 3)
            NpcData.LastNpc = NpcData.CurrentNpc
            NpcData.Active = true

            if not config.useTarget then
                CreateThread(function()
                    local targetCoords = vec3(sharedConfig.npcLocations.takeLocations[NpcData.CurrentNpc].x, sharedConfig.npcLocations.takeLocations[NpcData.CurrentNpc].y, sharedConfig.npcLocations.takeLocations[NpcData.CurrentNpc].z)
                    while not NpcData.NpcTaken do
                        local pos = GetEntityCoords(cache.ped)
                        local dist = #(pos - targetCoords)

                        if dist < 20 then
                            Wait(1) -- Only wait 1ms when drawing markers (needs frame-perfect rendering)
                            DrawMarker(2, targetCoords.x, targetCoords.y, targetCoords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 255, 255, 255, 255, false, false, 0, true, nil, nil, false)

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
                                    break
                                end
                            end
                        else
                            Wait(500) -- Far away - check less frequently
                        end
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
