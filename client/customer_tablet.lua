-- Customer Tablet UI controls for qbx_taxijob

local nuiReadyCustomer = false
local customerTabletOpen = false
local driverUpdateThread = nil

-- Optional ready handshake (React can post this later if needed)
RegisterNUICallback('customerTablet:ready', function(_, cb)
    nuiReadyCustomer = true
    cb('ok')
end)

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
    SendNUIMessage({ 
        action = 'openCustomerTablet', 
        toggle = true,
        customerProfile = customerProfile
    })
    SetNuiFocus(true, true)
    
    -- Start polling for driver updates
    startDriverUpdates()
end, false)

-- Close handlers from React (new + legacy naming for flexibility)
RegisterNUICallback('customerTablet:close', function(_, cb)
    customerTabletOpen = false
    SendNUIMessage({ action = 'openCustomerTablet', toggle = false })
    SetNuiFocus(false, false)
    
    -- Stop polling
    if driverUpdateThread then
        driverUpdateThread = nil
    end
    
    cb('ok')
end)

RegisterNUICallback('closeCustomerTablet', function(_, cb)
    customerTabletOpen = false
    SendNUIMessage({ action = 'openCustomerTablet', toggle = false })
    SetNuiFocus(false, false)
    
    -- Stop polling
    if driverUpdateThread then
        driverUpdateThread = nil
    end
    
    cb('ok')
end)

-- Fetch and send driver data to NUI
local function updateOnlineDrivers()
    if not customerTabletOpen then return end
    
    local drivers = lib.callback.await('qbx_taxijob:server:GetOnlineDrivers', false)
    if drivers then
        SendNUIMessage({
            action = 'updateOnlineDrivers',
            drivers = drivers
        })
    end
end

-- Start periodic updates
function startDriverUpdates()
    -- Initial update
    updateOnlineDrivers()
    
    -- Start polling thread (every 5 seconds)
    if driverUpdateThread then return end
    
    driverUpdateThread = true
    CreateThread(function()
        while customerTabletOpen and driverUpdateThread do
            Wait(5000) -- 5 second polling interval
            updateOnlineDrivers()
        end
        driverUpdateThread = nil
    end)
end

-- Server can trigger immediate update when driver status changes
RegisterNetEvent('qbx_taxijob:client:UpdateOnlineDrivers', function()
    if customerTabletOpen then
        updateOnlineDrivers()
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

-- Safety: if resource restarts while focus stuck, ensure focus off
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        SetNuiFocus(false, false)
    end
end)
