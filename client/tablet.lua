-- Driver Tablet UI controls for qbx_taxijob

local nuiReadyTablet = false

-- Handshake for tablet
RegisterNUICallback('tablet:ready', function(_, cb)
    nuiReadyTablet = true
    cb('ok')
end)

-- Open/close via command
RegisterCommand('drivertablet', function(source, args, raw)
    -- Validate player job via qbx_core export for consistency
    local player = exports.qbx_core:GetPlayerData()
    if not player or player.job.name ~= 'taxi' then
        exports.qbx_core:Notify('Taxi drivers only', 'error')
        return
    end
    
    -- Fetch accepted ride data from server before opening tablet
    local acceptedRide = lib.callback.await('qbx_taxijob:server:GetDriverAcceptedRide', false)
    
    SendNUIMessage({ 
        action = 'openDriverTablet', 
        toggle = true,
        acceptedRide = acceptedRide -- nil if no accepted ride
    })
    SetNuiFocus(true, true)
end, false)

-- NUI -> client actions
RegisterNUICallback('tablet:close', function(_, cb)
    SendNUIMessage({ action = 'openDriverTablet', toggle = false })
    SetNuiFocus(false, false)
    cb('ok')
end)

-- React side posts fetch("https://resource/closeDriverTablet") when closing; mirror behavior
RegisterNUICallback('closeDriverTablet', function(_, cb)
    SendNUIMessage({ action = 'openDriverTablet', toggle = false })
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Check if ride can be started (all conditions met)
RegisterNUICallback('tablet:checkCanStartRide', function(_, cb)
    -- Check if player is in vehicle
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if vehicle == 0 then
        cb({ canStart = false, reason = 'Not in vehicle' })
        return
    end
    
    -- Check if player is driver
    if GetPedInVehicleSeat(vehicle, -1) ~= ped then
        cb({ canStart = false, reason = 'Not in driver seat' })
        return
    end
    
    -- All client-side checks passed (server will validate passenger presence)
    cb({ canStart = true, reason = 'Ready' })
end)

RegisterNUICallback('tablet:startRide', function(_, cb)
    -- Call server validation and start ride (synchronous)
    local result = lib.callback.await('qbx_taxijob:server:TabletStartRide', false)
    
    -- Return result to UI so it knows whether to transition
    cb(result or { success = false, message = 'Server error' })
end)

RegisterNUICallback('tablet:endRide', function(_, cb)
    -- Get fare from meter before triggering end ride
    local fareData = exports.qbx_taxijob:GetMeterFare()
    
    print('[qbx_taxijob] [tablet:endRide] Got fare data from meter:', json.encode(fareData))
    
    TriggerEvent('qbx_taxijob:client:EndRideCollectFare')
    
    -- Return fare data to tablet
    local response = { 
        success = true, 
        fare = fareData.currentFare or 0,
        distance = fareData.distanceTraveled or 0
    }
    
    print('[qbx_taxijob] [tablet:endRide] Sending response to UI:', json.encode(response))
    
    cb(response)
end)

-- Get driver statistics
RegisterNUICallback('driver:getStats', function(_, cb)
    print('[qbx_taxijob] [driver:getStats] Fetching driver statistics from server')
    
    local stats = lib.callback.await('qbx_taxijob:server:GetDriverStats', false)
    
    if stats then
        print('[qbx_taxijob] [driver:getStats] Received stats:', json.encode(stats))
        cb(stats)
    else
        print('[qbx_taxijob] [driver:getStats] Failed to fetch stats')
        cb({ error = 'Failed to fetch stats' })
    end
end)
