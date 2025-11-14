-- Booking and live-blip code for qb_taxijob

RegisterNetEvent('qb-taxijob:client:CheckPlateResult', function(plate, exists)
    print(('[qbx_taxijob] Server check: Plate=%s | playerVehicle=%s'):format(tostring(plate), tostring(exists)))
end)

RegisterCommand('checkplate', function()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        print('[qbx_taxijob] Not in a vehicle')
        return
    end

    local veh = GetVehiclePedIsIn(ped, false)
    local plate = GetVehicleNumberPlateText(veh) or ''

    TriggerServerEvent('qb-taxijob:server:CheckPlate', plate)

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

RegisterCommand('bookride', function(_, args)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local coords = { x = tonumber(string.format('%.2f', pos.x)), y = tonumber(string.format('%.2f', pos.y)), z = tonumber(string.format('%.2f', pos.z)) }
    local msg = nil
    if args and #args > 0 then
        msg = table.concat(args, ' ')
    end
    TriggerServerEvent('qb-taxijob:server:BookRide', msg, coords)
    exports.qbx_core:Notify('Ride requested. Waiting for drivers to respond...', 'inform')
end, false)

RegisterNetEvent('qb-taxijob:client:IncomingRideRequest', function(reqId, requesterName, coords, message)
    local coordStr = 'unknown'
    if coords and coords.x and coords.y and coords.z then
        coordStr = string.format('%.2f, %.2f, %.2f', coords.x, coords.y, coords.z)
    end

    local content = ('Pickup: %s  \nRequester: %s'):format(coordStr, requesterName or 'unknown')
    if message and message ~= '' then
        content = content .. ('\nMessage: %s'):format(message)
    end

    local accepted = false
    if lib and type(lib.alertDialog) == 'function' then
        local res = lib.alertDialog({
            header = 'Incoming Ride Request',
            content = content,
            centered = true,
            cancel = true,
            labels = { confirm = 'Accept', cancel = 'Decline' }
        })
        accepted = (res == 'confirm')
    else
        exports.qbx_core:Notify('Incoming ride request: ' .. (requesterName or 'Someone') .. ' — use /acceptride to accept (not implemented)', 'inform')
        accepted = false
    end
    TriggerServerEvent('qb-taxijob:server:RespondRideRequest', reqId, accepted)
    if accepted then
        exports.qbx_core:Notify('You accepted the ride request', 'success')
    else
        exports.qbx_core:Notify('You declined the ride request', 'inform')
    end
end)

-- Driver: show pickup blip and start sending periodic location updates to server
DriverPickupBlip = nil
DriverUpdateThread = nil
RegisterNetEvent('qb-taxijob:client:ShowPickupBlip', function(pickupCoords)
    if DriverPickupBlip then RemoveBlip(DriverPickupBlip); DriverPickupBlip = nil end
    DriverPickupBlip = AddBlipForCoord(pickupCoords.x, pickupCoords.y, pickupCoords.z)
    SetBlipSprite(DriverPickupBlip, 198)
    SetBlipColour(DriverPickupBlip, 5)
    SetBlipRoute(DriverPickupBlip, true)

    if DriverUpdateThread then return end
    DriverUpdateThread = CreateThread(function()
        while DriverPickupBlip and DoesBlipExist(DriverPickupBlip) do
            Wait(2000) -- Increased from 1000ms to 2000ms - location updates don't need to be every second
            local ped = PlayerPedId()
            if not ped then break end
            local pos = GetEntityCoords(ped)
            local coords = { x = tonumber(string.format('%.2f', pos.x)), y = tonumber(string.format('%.2f', pos.y)), z = tonumber(string.format('%.2f', pos.z)) }
            TriggerServerEvent('qb-taxijob:server:DriverLocation', coords)
        end
        DriverUpdateThread = nil
    end)
    scheduleClearBlipsAfter(config.blipDissepiartime or 30)
end)


-- Requester: receive realtime driver location updates and show moving blip
DriverMovingBlip = nil
RegisterNetEvent('qb-taxijob:client:DriverLocationUpdate', function(driverSrc, coords)
    if not coords or not coords.x then return end
    if not DriverMovingBlip then
        DriverMovingBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(DriverMovingBlip, 56)
        SetBlipColour(DriverMovingBlip, 2)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Driver')
        EndTextCommandSetBlipName(DriverMovingBlip)
    else
        if DoesBlipExist(DriverMovingBlip) then
            SetBlipCoords(DriverMovingBlip, coords.x, coords.y, coords.z)
        else
            DriverMovingBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
        end
    end
end)


RegisterNetEvent('qb-taxijob:client:ClearRideBlips', function()
    print('[qbx_taxijob] Clearing ride blips')
    if DriverPickupBlip and DoesBlipExist(DriverPickupBlip) then RemoveBlip(DriverPickupBlip); DriverPickupBlip = nil end
    if RequesterPickupBlip and DoesBlipExist(RequesterPickupBlip) then RemoveBlip(RequesterPickupBlip); RequesterPickupBlip = nil end
    if DriverMovingBlip and DoesBlipExist(DriverMovingBlip) then RemoveBlip(DriverMovingBlip); DriverMovingBlip = nil end
end)


RegisterNetEvent('qb-taxijob:client:RideAssigned', function(requesterSrc, driverSrc, driverName, coords, modelHash, plate)
    exports.qbx_core:Notify(('Driver %s is on the way to your location'):format(driverName or 'a driver'), 'success')
    CurrentAssignedDriver = driverSrc
    if coords then
        if RequesterPickupBlip then RemoveBlip(RequesterPickupBlip); RequesterPickupBlip = nil end
        RequesterPickupBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(RequesterPickupBlip, 1)
        SetBlipColour(RequesterPickupBlip, 3)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Pickup Location')
        EndTextCommandSetBlipName(RequesterPickupBlip)
        scheduleClearBlipsAfter(config.blipDissepiartime or 30)
    end
end)
