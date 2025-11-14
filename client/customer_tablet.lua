-- Customer Tablet UI controls for qbx_taxijob

local nuiReadyCustomer = false
local customerTabletOpen = false
---@diagnostic disable: undefined-global
local lib = lib

-- Optional ready handshake (React can post this later if needed)
RegisterNUICallback('customerTablet:ready', function(_, cb)
    nuiReadyCustomer = true
    cb('ok')
end)

-- Fetch and send driver data to NUI (DEFINED FIRST before being called)
local function updateOnlineDrivers()
    if not customerTabletOpen then return end
    
    print('[qbx_taxijob] [CLIENT] Requesting online drivers from server...')
    local drivers = lib.callback.await('qbx_taxijob:server:GetOnlineDrivers', false)
    
    if drivers then
        print(('[qbx_taxijob] [CLIENT] Received %d drivers from server'):format(#drivers))
        for i, driver in ipairs(drivers) do
            print(('  [%d] %s - %s away, %s ETA'):format(i, driver.name, driver.distance, driver.eta))
        end
        
        SendNUIMessage({
            action = 'updateOnlineDrivers',
            drivers = drivers
        })
        print('[qbx_taxijob] [CLIENT] Sent driver data to NUI')
    else
        print('[qbx_taxijob] [CLIENT] No driver data received from server')
    end
end

-- Command to open customer tablet for any player (no job restriction)
RegisterCommand('customertablet', function()
    local playerData = exports.qbx_core:GetPlayerData()
    if not playerData then return end
    
    -- Get customer profile data
    local customerProfile = {
        name = (playerData.charinfo.firstname or 'John') .. ' ' .. (playerData.charinfo.lastname or 'Doe'),
        phone = playerData.charinfo.phone or 'N/A',
        citizenid = playerData.citizenid
    }
    
    customerTabletOpen = true
    -- Fetch autopay preference from server
    local autoPay = lib.callback.await('qbx_taxijob:server:GetAutoPayPreference', false) or false
    SendNUIMessage({ 
        action = 'openCustomerTablet', 
        toggle = true,
        customerProfile = customerProfile,
        autopayEnabled = autoPay
    })
    SetNuiFocus(true, true)
    
    -- Fetch drivers ONLY when tablet opens (not continuous polling)
    print('[qbx_taxijob] [CLIENT] Customer tablet opened, fetching drivers once...')
    updateOnlineDrivers()
end, false)
-- NUI: get autopay preference (used by React to sync initial toggle)
RegisterNUICallback('customer:getAutopay', function(_, cb)
    local autoPay = lib.callback.await('qbx_taxijob:server:GetAutoPayPreference', false) or false
    cb({ enabled = autoPay })
end)

-- NUI: set autopay preference and persist to DB
RegisterNUICallback('customer:setAutopay', function(data, cb)
    local enabled = data and data.enabled or false
    TriggerServerEvent('qbx_taxijob:server:SetAutoPayPreference', enabled)
    cb('ok')
end)

-- Close handlers from React (new + legacy naming for flexibility)
RegisterNUICallback('customerTablet:close', function(_, cb)
    customerTabletOpen = false
    SendNUIMessage({ action = 'openCustomerTablet', toggle = false })
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('closeCustomerTablet', function(_, cb)
    customerTabletOpen = false
    SendNUIMessage({ action = 'openCustomerTablet', toggle = false })
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Server can trigger immediate update when driver status changes (efficient - only on duty toggle)
RegisterNetEvent('qbx_taxijob:client:UpdateOnlineDrivers', function()
    print('[qbx_taxijob] [CLIENT] Received UpdateOnlineDrivers event from server (driver duty changed)')
    if customerTabletOpen then
        print('[qbx_taxijob] [CLIENT] Tablet is open, auto-updating driver list...')
        updateOnlineDrivers()
    else
        print('[qbx_taxijob] [CLIENT] Tablet is closed, ignoring update')
    end
end)

-- Handle ride assignment (driver accepted)
RegisterNetEvent('qb-taxijob:client:RideAssigned', function(requesterSrc, driverSrc, driverName, coords)
    if customerTabletOpen then
        SendNUIMessage({
            action = 'rideAccepted',
            driverName = tostring(driverName or 'Driver'),
            driverSrc = tonumber(driverSrc) or 0
        })
    end
    exports.qbx_core:Notify(('Driver %s is on the way to your location'):format(driverName or 'a driver'), 'success')
    
    -- Handle existing blip system (from bookings.lua)
    CurrentAssignedDriver = driverSrc
    if coords then
        if RequesterPickupBlip then RemoveBlip(RequesterPickupBlip); RequesterPickupBlip = nil end
        RequesterPickupBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(RequesterPickupBlip, 1)
        SetBlipColour(RequesterPickupBlip, 3)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Pickup Location')
        EndTextCommandSetBlipName(RequesterPickupBlip)
    end
end)

-- Handle all drivers busy
RegisterNetEvent('qbx_taxijob:client:AllDriversBusy', function()
    if customerTabletOpen then
        SendNUIMessage({
            action = 'rideRejected',
            reason = 'all_busy'
        })
    end
    exports.qbx_core:Notify('All drivers are busy right now. Please try again later.', 'error')
end)

-- Handle ride completed (driver ended the ride)
RegisterNetEvent('qbx_taxijob:client:RideCompleted', function(data)
    local fare = data.fare or 0
    local paid = data.paid or false
    local driverName = data.driverName or 'Driver'
    
    print(('[qbx_taxijob] [CLIENT] Ride completed notification received - Fare: $%.2f, Paid: %s'):format(fare, tostring(paid)))
    print(('[qbx_taxijob] [CLIENT] Customer tablet open: %s'):format(tostring(customerTabletOpen)))
    
    -- ALWAYS send to NUI regardless of tablet open state
    -- This ensures the state is updated even if customer opens tablet after ride ends
    SendNUIMessage({
        action = 'rideCompleted',
        fare = fare,
        paid = paid,
        driverName = driverName,
        driverCid = data.driverCid,
        rideId = data.rideId
    })
    print('[qbx_taxijob] [CLIENT] Sent ride completed to NUI (will update when tablet opens if not already open)')
    
    -- Show notification to customer
    exports.qbx_core:Notify(('Ride completed! Fare: $%.2f - Open your tablet to pay'):format(fare), 'inform')
end)

-- Book ride callback - now fully functional
RegisterNUICallback('customer:bookRide', function(data, cb)
    local pickupLocation = data.pickupLocation or 'Current Location'
    local message = data.message or ''
    
    -- Get player coordinates
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local coords = {
        x = tonumber(string.format('%.2f', pos.x)),
        y = tonumber(string.format('%.2f', pos.y)),
        z = tonumber(string.format('%.2f', pos.z))
    }
    
    -- Trigger the existing server booking system
    TriggerServerEvent('qb-taxijob:server:BookRide', message, coords)
    
    exports.qbx_core:Notify('Ride requested. Waiting for drivers to respond...', 'inform')
    
    cb('ok')
end)

-- Payment confirmation from customer tablet UI
RegisterNUICallback('customer:confirmPayment', function(data, cb)
    local paymentMethod = data.method or 'debit'  -- 'debit' or 'cash'
    local confirmed = data.confirmed or false
    
    print(('[qbx_taxijob] [CLIENT] Payment confirmation received - Method: %s, Confirmed: %s'):format(paymentMethod, tostring(confirmed)))
    
    -- Send confirmation to server
    TriggerServerEvent('qbx_taxijob:server:ProcessPayment', {
        method = paymentMethod,
        confirmed = confirmed
    })
    
    cb('ok')
end)

-- Receive payment processed result from server and forward to NUI
RegisterNetEvent('qbx_taxijob:client:PaymentProcessed', function(result)
    local paid = result and result.paid or false
    local amount = result and result.amount or 0
    local method = result and result.method or 'debit'
    SendNUIMessage({
        action = 'paymentProcessed',
        paid = paid,
        amount = amount,
        method = method
    })
end)

-- Submit review from customer tablet UI
RegisterNUICallback('customer:submitReview', function(data, cb)
    local driverCid = data.driverCid
    local rideId = data.rideId
    local rating = tonumber(data.rating) or 5
    local comment = data.comment or ''
    
    print(('[qbx_taxijob] [CLIENT] Review submission - Driver: %s, Rating: %d, Comment: %s'):format(
        tostring(driverCid), rating, comment
    ))
    
    -- Send review to server
    local result = lib.callback.await('qbx_taxijob:server:SubmitReview', false, {
        driverCid = driverCid,
        rideId = rideId,
        rating = rating,
        comment = comment
    })
    
    if result and result.success then
        exports.qbx_core:Notify('Thank you for your feedback!', 'success')
        cb({success = true})
    else
        exports.qbx_core:Notify('Failed to submit review', 'error')
        cb({success = false})
    end
end)

-- Safety: if resource restarts while focus stuck, ensure focus off
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        SetNuiFocus(false, false)
    end
end)
