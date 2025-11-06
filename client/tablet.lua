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
    SendNUIMessage({ action = 'openDriverTablet', toggle = true })
    SetNuiFocus(true, true)
end, false)

-- NUI -> client actions
RegisterNUICallback('tablet:close', function(_, cb)
    SendNUIMessage({ action = 'openDriverTablet', toggle = false })
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('tablet:startRide', function(_, cb)
    -- Start ride uses our consolidated event
    TriggerEvent('qbx_taxijob:client:StartRideMeter')
    cb('ok')
end)

RegisterNUICallback('tablet:endRide', function(_, cb)
    TriggerEvent('qbx_taxijob:client:EndRideCollectFare')
    cb('ok')
end)
