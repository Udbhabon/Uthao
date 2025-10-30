local sharedConfig = require 'config.shared'
local ITEMS = exports.ox_inventory:Items()

local function nearTaxi(src)
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    for _, v in pairs(sharedConfig.npcLocations.deliverLocations) do
        local dist = #(coords - v.xyz)
        if dist < 20 then
            return true
        end
    end
end

-- Track duty state server-side for simple validation/sync
local dutyState = {}

-- Handler for core duty change — validate and forward to client
AddEventHandler('QBCore:Server:SetDuty', function(source, onDuty)
    local src = source
    if not src then return end
    local player = exports.qbx_core and exports.qbx_core:GetPlayer(src) or nil
    if not player then
        print("[qbx_taxijob] Could not find player for SetDuty event: " .. tostring(src))
        return
    end

        -- Only allow taxi drivers to go on-duty for this resource
        do
            local pid = src
            local cid = player.PlayerData and player.PlayerData.citizenid or 'unknown'
            local jobname = (player.PlayerData and player.PlayerData.job and player.PlayerData.job.name) or 'unknown'
            local pname = 'unknown'
            if player.PlayerData and player.PlayerData.charinfo then
                local ci = player.PlayerData.charinfo
                pname = (ci.firstname and ci.lastname) and (ci.firstname .. ' ' .. ci.lastname) or (player.PlayerData.name or 'unknown')
            else
                pname = player.PlayerData and (player.PlayerData.name or 'unknown') or 'unknown'
            end

            if onDuty then
                if jobname == 'taxi' then
                    dutyState[pid] = true
                    -- Tell the player's client to switch duty on for the taxi resource
                    TriggerClientEvent('qb-taxijob:client:SetDuty', pid, true)
                    print(('[qbx_taxijob] [DEBUG] Duty ON: src=%d name=%s cid=%s job=%s'):format(pid, pname, cid, jobname))
                else
                    print(('[qbx_taxijob] [DEBUG] Duty ON attempt rejected: src=%d name=%s cid=%s job=%s'):format(pid, pname, cid, jobname))
                end
            else
                dutyState[pid] = false
                TriggerClientEvent('qb-taxijob:client:SetDuty', pid, false)
                print(('[qbx_taxijob] [DEBUG] Duty OFF: src=%d name=%s cid=%s job=%s'):format(pid, pname, cid, jobname))
            end
        end
end)

-- Cleanup when player disconnects
AddEventHandler('playerDropped', function(reason)
    local src = source
    dutyState[src] = nil
end)


-- Server event: players in-resource may toggle duty locally (ToggleDuty). Listen and log for visibility.
RegisterNetEvent('qb-taxijob:server:PlayerToggledDuty', function(state, coords)
    local src = source
    if not src then return end
    local p = exports.qbx_core and exports.qbx_core:GetPlayer(src) or nil
    local cid = p and p.PlayerData and p.PlayerData.citizenid or 'unknown'
    local jobname = p and p.PlayerData and p.PlayerData.job and p.PlayerData.job.name or 'unknown'
    local pname = 'unknown'
    if p and p.PlayerData and p.PlayerData.charinfo then
        local ci = p.PlayerData.charinfo
        pname = (ci.firstname and ci.lastname) and (ci.firstname .. ' ' .. ci.lastname) or (p.PlayerData.name or 'unknown')
    else
        pname = p and (p.PlayerData and (p.PlayerData.name or 'unknown') or 'unknown') or 'unknown'
    end

    local coordsStr = 'unknown'
    if coords and type(coords) == 'table' and coords.x and coords.y and coords.z then
        coordsStr = string.format('%.2f, %.2f, %.2f', tonumber(coords.x), tonumber(coords.y), tonumber(coords.z))
    end

    if state then
        print(('[qbx_taxijob] [PLAYER TOGGLE] ON  -> src=%d name=%s cid=%s job=%s coords=[%s]'):format(src, pname, cid, jobname, coordsStr))
    else
        print(('[qbx_taxijob] [PLAYER TOGGLE] OFF -> src=%d name=%s cid=%s job=%s coords=[%s]'):format(src, pname, cid, jobname, coordsStr))
    end
end)

-- Server wrapper to check if a plate belongs to a player vehicle
RegisterNetEvent('qb-taxijob:server:CheckPlate', function(plate)
    local src = source
    local exists = false
    if exports and exports.qbx_vehicles and exports.qbx_vehicles.DoesPlayerVehiclePlateExist then
        exists = exports.qbx_vehicles:DoesPlayerVehiclePlateExist(plate)
    else
        print('[qbx_taxijob] qbx_vehicles export not available on server')
    end

    TriggerClientEvent('qb-taxijob:client:CheckPlateResult', src, plate, exists)
end)

-- Callback usable by clients to synchronously check plate ownership via lib.callback.await
lib.callback.register('qb-taxijob:server:DoesPlateExist', function(source, plate)
    if not plate then return false end
    local exists = false
    if exports and exports.qbx_vehicles and exports.qbx_vehicles.DoesPlayerVehiclePlateExist then
        exists = exports.qbx_vehicles:DoesPlayerVehiclePlateExist(plate)
    else
        print('[qbx_taxijob] qbx_vehicles export not available on server for DoesPlateExist')
    end
    return exists
end)

lib.callback.register('qb-taxi:server:spawnTaxi', function(source, model, coords)
    local netId, veh = qbx.spawnVehicle({
        model = model,
        spawnSource = coords,
        warp = GetPlayerPed(source --[[@as number]]),
    })

    local plate = 'TAXI' .. math.random(1000, 9999)
    SetVehicleNumberPlateText(veh, plate)
    TriggerClientEvent('vehiclekeys:client:SetOwner', source, plate)
    return netId
end)

RegisterNetEvent('qb-taxi:server:NpcPay', function(payment)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if player.PlayerData.job.name == 'taxi' then
        if nearTaxi(src) then
            local randomAmount = math.random(1, 5)
            local r1, r2 = math.random(1, 5), math.random(1, 5)
            if randomAmount == r1 or randomAmount == r2 then payment = payment + math.random(10, 20) end
            player.Functions.AddMoney('cash', payment)
            local chance = math.random(1, 100)
            if chance < 26 then
                player.Functions.AddItem('cryptostick', 1, false)
                TriggerClientEvent('inventory:client:ItemBox', src, ITEMS['cryptostick'], 'add')
            end
        else
            DropPlayer(src, 'Attempting To Exploit')
        end
    else
        DropPlayer(src, 'Attempting To Exploit')
    end
end)
