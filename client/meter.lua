-- Meter UI and related threads for qb_taxijob

-- Acquire cache from ox_lib if available
---@diagnostic disable: undefined-global
if not cache and lib and lib.player then
    cache = lib.player
end
-- locale is provided by ox_lib via global; guard so we don't break if missing
locale = locale or function(key) return key end

local nuiReady = false -- set true after initial handshake to avoid sending messages too early

-- Handshake callback from NUI (React) to mark readiness
RegisterNUICallback('ping', function(_, cb)
    nuiReady = true
    cb('ok')
end)

RegisterNetEvent('qb-taxi:client:toggleMeter', function()
    if cache.vehicle then
        if whitelistedVehicle() then
            if not meterIsOpen and isDriver() then
                if not nuiReady then
                    -- Defer opening until NUI is ready; small retry loop
                    CreateThread(function()
                        local attempts = 0
                        while not nuiReady and attempts < 25 do -- ~2.5s max
                            attempts = attempts + 1
                            Wait(100)
                        end
                        if nuiReady and not meterIsOpen then
                            SendNUIMessage({
                                action = 'openMeter',
                                toggle = true,
                                meterData = config.meter
                            })
                            meterIsOpen = true
                        elseif not nuiReady then
                            exports.qbx_core:Notify('Meter UI not ready', 'error')
                        end
                    end)
                    return
                end
                SendNUIMessage({
                    action = 'openMeter',
                    toggle = true,
                    meterData = config.meter
                })
                meterIsOpen = true
                startVehicleCheckThread() -- Start vehicle check only when meter opens
            else
                if not nuiReady then
                    exports.qbx_core:Notify('Meter UI not ready', 'error')
                    return
                end
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
        if not nuiReady then
            exports.qbx_core:Notify('Meter UI not ready', 'error')
            return
        end
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
    if not meterActive then 
        resetMeter()
    else
        startFareThread() -- Start fare calculation only when meter is active
    end
    lastLocation = GetEntityCoords(cache.ped)
    cb('ok')
end)

RegisterNUICallback('hideMouse', function(_, cb)
    SetNuiFocus(false, false)
    mouseActive = false
    cb('ok')
end)

-- Threads - OPTIMIZED: Only run when meter is active
local fareThread = nil
local vehicleCheckThread = nil

local function startFareThread()
    if fareThread then return end
    print('[qbx_taxijob] [startFareThread] Starting fare calculation thread')
    fareThread = CreateThread(function()
        while meterActive do
            Wait(2000)
            calculateFareAmount()
        end
        print('[qbx_taxijob] [startFareThread] Thread stopped')
        fareThread = nil
    end)
end

local function startVehicleCheckThread()
    if vehicleCheckThread then return end
    print('[qbx_taxijob] [startVehicleCheckThread] Starting vehicle check thread')
    vehicleCheckThread = CreateThread(function()
        while meterIsOpen do
            if cache and not cache.vehicle then
                SendNUIMessage({
                    action = 'openMeter',
                    toggle = false
                })
                meterIsOpen = false
                meterActive = false
                break
            end
            Wait(500) -- Increased from 200ms to 500ms - less critical check
        end
        print('[qbx_taxijob] [startVehicleCheckThread] Thread stopped')
        vehicleCheckThread = nil
    end)
end

-- Start ride meter safely (idempotent): ensure open, then enable
RegisterNetEvent('qbx_taxijob:client:StartRideMeter', function()
    print('[qbx_taxijob] [StartRideMeter] Event triggered')
    
    if not cache or not cache.vehicle then 
        print('[qbx_taxijob] [StartRideMeter] Not in vehicle')
        return 
    end
    if not isDriver() then 
        print('[qbx_taxijob] [StartRideMeter] Not driver')
        return 
    end
    if not whitelistedVehicle() then 
        print('[qbx_taxijob] [StartRideMeter] Not whitelisted vehicle')
        return 
    end
    if not nuiReady then
        print('[qbx_taxijob] [StartRideMeter] NUI not ready')
        exports.qbx_core:Notify('Meter UI not ready', 'error')
        return
    end
    
    -- If meter not open, open it first
    if not meterIsOpen then
        print('[qbx_taxijob] [StartRideMeter] Opening meter and starting')
        SendNUIMessage({
            action = 'openMeter',
            toggle = true,
            meterData = config.meter,
            meterStarted = true  -- Pass the started state directly
        })
        meterIsOpen = true
        meterActive = true
        startVehicleCheckThread()
        startFareThread()
        lastLocation = GetEntityCoords(cache.ped)
        print(('[qbx_taxijob] [StartRideMeter] Meter opened and started. meterActive=%s, lastLocation=%s'):format(tostring(meterActive), tostring(lastLocation)))
    else
        -- Meter already open, just ensure it's running
        print('[qbx_taxijob] [StartRideMeter] Meter already open, setting running')
        SendNUIMessage({
            action = 'setMeterRunning',
            running = true
        })
        meterActive = true
        startFareThread()
        print(('[qbx_taxijob] [StartRideMeter] Meter set to running. meterActive=%s'):format(tostring(meterActive)))
    end
end)

-- Collect current fare, stop/reset meter, and send to server to end ride
RegisterNetEvent('qbx_taxijob:client:EndRideCollectFare', function()
    local fare = 0
    if type(meterData) == 'table' and type(meterData.currentFare) == 'number' then
        fare = meterData.currentFare
    end
    print(('[qbx_taxijob] [EndRideCollectFare] Collected fare: $%.2f'):format(fare))
    TriggerServerEvent('qb-taxijob:server:EndRide', fare)
    if meterIsOpen then
        TriggerEvent('qb-taxi:client:toggleMeter')
        meterActive = false
        if nuiReady then
            SendNUIMessage({ action = 'resetMeter' })
        end
    end
end)

-- Export to get current meter fare data
exports('GetMeterFare', function()
    local fare = (type(meterData) == 'table' and type(meterData.currentFare) == 'number') and meterData.currentFare or 0
    local distance = (type(meterData) == 'table' and type(meterData.distanceTraveled) == 'number') and meterData.distanceTraveled or 0
    
    print(('[qbx_taxijob] [GetMeterFare] Returning fare: %.2f, distance: %.2f'):format(fare, distance))
    print(('[qbx_taxijob] [GetMeterFare] meterData table: %s'):format(json.encode(meterData)))
    
    return {
        currentFare = fare,
        distanceTraveled = distance
    }
end)
