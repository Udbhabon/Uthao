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

-- Book ride callback
RegisterNUICallback('customer:bookRide', function(data, cb)
    local driverId = data.driverId
    if not driverId then
        cb('error')
        return
    end
    
    -- TODO: Implement ride booking logic with existing server system
    -- TriggerServerEvent('qbx_taxijob:server:BookRideWithDriver', driverId)
    
    lib.notify({
        title = 'Taxi Job',
        description = 'Ride booking system coming soon',
        type = 'info'
    })
    
    cb('ok')
end)

-- Safety: if resource restarts while focus stuck, ensure focus off
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        SetNuiFocus(false, false)
    end
end)
