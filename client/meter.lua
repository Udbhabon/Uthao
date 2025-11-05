-- Meter UI and related threads for qb_taxijob

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

-- Start ride meter safely (idempotent): ensure open, then enable
RegisterNetEvent('qbx_taxijob:client:StartRideMeter', function()
    if not cache or not cache.vehicle then return end
    if not isDriver() then return end
    if not whitelistedVehicle() then return end
    if not meterIsOpen then
        TriggerEvent('qb-taxi:client:toggleMeter')
        Wait(100)
    end
    TriggerEvent('qb-taxi:client:enableMeter')
end)

-- Collect current fare, stop/reset meter, and send to server to end ride
RegisterNetEvent('qbx_taxijob:client:EndRideCollectFare', function()
    local fare = 0
    if type(meterData) == 'table' and type(meterData.currentFare) == 'number' then
        fare = meterData.currentFare
    end
    TriggerServerEvent('qb-taxijob:server:EndRide', fare)
    if meterIsOpen then
        TriggerEvent('qb-taxi:client:toggleMeter')
        meterActive = false
        SendNUIMessage({ action = 'resetMeter' })
    end
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
