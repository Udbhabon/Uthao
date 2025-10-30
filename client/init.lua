-- Initialization and high-level event wiring for qb_taxijob

RegisterNetEvent('qb-taxijob:client:requestcab', function()
    taxiGarage()
end)

local function init()
    if QBX.PlayerData.job.name == 'taxi' then
        setupGarageZone()
        setupTaxiParkingZone()
        setLocationsBlip()
    end
end

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    destroyGarageZone()
    destroyTaxiParkingZone()
    init()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    isLoggedIn = true
    onDuty = (QBX.PlayerData.job.name == 'taxi')
    init()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    isLoggedIn = false
end)

RegisterNetEvent('qb-taxijob:client:SetDuty', function(state)
    setDuty(state)
end)

RegisterNetEvent('qb-taxijob:client:ToggleDuty', function()
    local newState = not onDuty
    setDuty(newState, true)
    do
        local ped = PlayerPedId()
        local c = GetEntityCoords(ped)
        local coords = { x = tonumber(string.format('%.2f', c.x)), y = tonumber(string.format('%.2f', c.y)), z = tonumber(string.format('%.2f', c.z)) }
        TriggerServerEvent('qb-taxijob:server:PlayerToggledDuty', newState, coords)
    end
    if newState then
        exports.qbx_core:Notify('You are Onduty in Taxijob', 'success')
    else
        exports.qbx_core:Notify('You are Offduty in Taxijob', 'inform')
    end
end)

CreateThread(function()
    if not isLoggedIn then return end
    init()
end)
