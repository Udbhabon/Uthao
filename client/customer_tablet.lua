-- Customer Tablet UI controls for qbx_taxijob
-- Non-functional placeholder: opens/closes React NUI, releases focus properly.

local nuiReadyCustomer = false

-- Optional ready handshake (React can post this later if needed)
RegisterNUICallback('customerTablet:ready', function(_, cb)
    nuiReadyCustomer = true
    cb('ok')
end)

-- Command to open customer tablet for any player (no job restriction)
RegisterCommand('customertablet', function()
    SendNUIMessage({ action = 'openCustomerTablet', toggle = true })
    SetNuiFocus(true, true)
end, false)

-- Close handlers from React (new + legacy naming for flexibility)
RegisterNUICallback('customerTablet:close', function(_, cb)
    SendNUIMessage({ action = 'openCustomerTablet', toggle = false })
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('closeCustomerTablet', function(_, cb)
    SendNUIMessage({ action = 'openCustomerTablet', toggle = false })
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Safety: if resource restarts while focus stuck, ensure focus off
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        SetNuiFocus(false, false)
    end
end)
