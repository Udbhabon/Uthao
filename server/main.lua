local sharedConfig = require 'config.shared'
local ITEMS = exports.ox_inventory:Items()
-- attempt to read client config for shared constants (fallback to defaults)
local okClientCfg, clientConfig = pcall(require, 'config.client')
if not okClientCfg then clientConfig = nil end

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
                    if QbxTaxiDB then QbxTaxiDB.updateDriverStatusFromPlayer(player, true) end
                    print(('[qbx_taxijob] [DEBUG] Duty ON: src=%d name=%s cid=%s job=%s'):format(pid, pname, cid, jobname))
                else
                    print(('[qbx_taxijob] [DEBUG] Duty ON attempt rejected: src=%d name=%s cid=%s job=%s'):format(pid, pname, cid, jobname))
                end
            else
                dutyState[pid] = false
                TriggerClientEvent('qb-taxijob:client:SetDuty', pid, false)
                if QbxTaxiDB then QbxTaxiDB.updateDriverStatusFromPlayer(player, false) end
                print(('[qbx_taxijob] [DEBUG] Duty OFF: src=%d name=%s cid=%s job=%s'):format(pid, pname, cid, jobname))
            end
        end
end)

-- Cleanup when player disconnects
AddEventHandler('playerDropped', function(reason)
    local src = source
    dutyState[src] = nil
    local p = exports.qbx_core and exports.qbx_core:GetPlayer(src) or nil
    if p and QbxTaxiDB then QbxTaxiDB.updateDriverStatusFromPlayer(p, false) end
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

    -- update server-side duty state so server has an authoritative list for alerts
    if state then
        dutyState[src] = true
        print(('[qbx_taxijob] [PLAYER TOGGLE] ON  -> src=%d name=%s cid=%s job=%s coords=[%s]'):format(src, pname, cid, jobname, coordsStr))
    else
        dutyState[src] = false
        print(('[qbx_taxijob] [PLAYER TOGGLE] OFF -> src=%d name=%s cid=%s job=%s coords=[%s]'):format(src, pname, cid, jobname, coordsStr))
    end
end)


-- Ride booking: pending requests and handlers
local pendingRequests = {}
-- active assignments: driverSrc -> { requester = src, coords = coords }
local activeAssignments = {}
local assignedRequester = {}

-- Server: player requests a ride
RegisterNetEvent('qb-taxijob:server:BookRide', function(message, coords)
    local src = source
    if not src then return end
    local reqId = tostring(os.time()) .. '-' .. tostring(math.random(1000, 9999))
    local req = {
        id = reqId,
        requester = src,
        coords = coords or {},
        message = message or '',
        assigned = false,
        created = os.time()
    }
    pendingRequests[reqId] = req

    if QbxTaxiDB then
        local requesterPlayer = exports.qbx_core and exports.qbx_core:GetPlayer(src) or nil
        if requesterPlayer then QbxTaxiDB.createRide(reqId, requesterPlayer, coords, message) end
    end

    -- find on-duty drivers
    local drivers = {}
    for k, v in pairs(dutyState) do
        if v == true then table.insert(drivers, k) end
    end

    if #drivers == 0 then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1[qbx_taxijob]', 'No taxi drivers are currently on duty.' } })
        pendingRequests[reqId] = nil
        return
    end

    -- Notify all on-duty drivers
    for _, dsrc in ipairs(drivers) do
        local requesterPlayer = exports.qbx_core and exports.qbx_core:GetPlayer(src) or nil
        local rname = 'unknown'
        if requesterPlayer and requesterPlayer.PlayerData and requesterPlayer.PlayerData.charinfo then
            local ci = requesterPlayer.PlayerData.charinfo
            rname = (ci.firstname and ci.lastname) and (ci.firstname .. ' ' .. ci.lastname) or (requesterPlayer.PlayerData.name or 'unknown')
        end
        TriggerClientEvent('qb-taxijob:client:IncomingRideRequest', dsrc, reqId, rname, req.coords, req.message)
    end

    -- Timeout: if no one accepts within 25 seconds, notify requester
    SetTimeout(25000, function()
        local r = pendingRequests[reqId]
        if r and not r.assigned then
            TriggerClientEvent('chat:addMessage', r.requester, { args = { '^1[qbx_taxijob]', 'No drivers accepted your ride request.' } })
            pendingRequests[reqId] = nil
        end
    end)
end)


-- Server: drivers respond to a request
RegisterNetEvent('qb-taxijob:server:RespondRideRequest', function(reqId, accept)
    local src = source
    if not src or not reqId then return end
    local req = pendingRequests[reqId]
    if not req then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1[qbx_taxijob]', 'This ride request is no longer available.' } })
        return
    end

    if accept then
        if req.assigned then
            -- someone already accepted
            TriggerClientEvent('chat:addMessage', src, { args = { '^1[qbx_taxijob]', 'Ride already taken by another driver.' } })
            return
        end
        req.assigned = src
        pendingRequests[reqId] = nil
        activeAssignments[src] = { requester = req.requester, coords = req.coords }
        assignedRequester[req.requester] = src
        -- schedule server-side forced cleanup in case client timers fail
        local blipTime = (clientConfig and clientConfig.blipDissepiartime) or 30
        SetTimeout((blipTime or 30) * 1000, function()
            -- only clear if assignment still exists
            if activeAssignments[src] and activeAssignments[src].requester == req.requester then
                activeAssignments[src] = nil
                assignedRequester[req.requester] = nil
                TriggerClientEvent('qb-taxijob:client:ClearRideBlips', req.requester)
                TriggerClientEvent('qb-taxijob:client:ClearRideBlips', src)
                print(('[qbx_taxijob] Auto-cleared ride assignment %s after %d seconds'):format(reqId, blipTime))
            end
        end)

        -- notify requester and all drivers
        local driverPlayer = exports.qbx_core and exports.qbx_core:GetPlayer(src) or nil
        local dname = 'unknown'
        if driverPlayer and driverPlayer.PlayerData and driverPlayer.PlayerData.charinfo then
            local ci = driverPlayer.PlayerData.charinfo
            dname = (ci.firstname and ci.lastname) and (ci.firstname .. ' ' .. ci.lastname) or (driverPlayer.PlayerData.name or 'unknown')
        end

        if QbxTaxiDB and driverPlayer then QbxTaxiDB.acceptRide(reqId, driverPlayer) end

    TriggerClientEvent('chat:addMessage', req.requester, { args = { '^2[qbx_taxijob]', ('%s accepted your ride.'):format(dname) } })
    TriggerClientEvent('qb-taxijob:client:RideAssigned', req.requester, src, dname, req.coords)
    -- instruct driver to show pickup blip and start location updates
    TriggerClientEvent('qb-taxijob:client:ShowPickupBlip', src, req.coords)

        -- inform other drivers that it was taken
        for k, v in pairs(dutyState) do
            if v == true and k ~= src then
                TriggerClientEvent('chat:addMessage', k, { args = { '^1[qbx_taxijob]', ('Ride request taken by %s'):format(dname) } })
            end
        end
    else
        -- declined; simple feedback
        TriggerClientEvent('chat:addMessage', src, { args = { '^1[qbx_taxijob]', 'You declined the ride request.' } })
    end
end)


-- Driver location relay: drivers send periodic updates which are relayed to the assigned requester
RegisterNetEvent('qb-taxijob:server:DriverLocation', function(coords)
    local src = source
    if not src or not coords then return end
    local assign = activeAssignments[src]
    if not assign then return end
    local requester = assign.requester
    -- relay to requester so they can update the driver blip in realtime
    TriggerClientEvent('qb-taxijob:client:DriverLocationUpdate', requester, src, coords)
end)


-- Optional: driver can signal ride complete to clear assignment and remove blips
RegisterNetEvent('qb-taxijob:server:EndRide', function(fare)
    local src = source
    local assign = activeAssignments[src]
    if not assign then return end
    local requester = assign.requester
    local driverPlayer = exports.qbx_core and exports.qbx_core:GetPlayer(src) or nil
    local passengerPlayer = exports.qbx_core and exports.qbx_core:GetPlayer(requester) or nil
    local amount = tonumber(fare) or 0
    local driverName = 'Driver'
    if driverPlayer and driverPlayer.PlayerData and driverPlayer.PlayerData.charinfo then
        local ci = driverPlayer.PlayerData.charinfo
        driverName = (ci.firstname and ci.lastname) and (ci.firstname .. ' ' .. ci.lastname) or (driverPlayer.PlayerData.name or 'Driver')
    end

    -- Persist fare to ride record first
    local did = driverPlayer and driverPlayer.PlayerData and driverPlayer.PlayerData.citizenid or nil
    local uid = passengerPlayer and passengerPlayer.PlayerData and passengerPlayer.PlayerData.citizenid or nil
    local ride_id = (did and QbxTaxiDB and QbxTaxiDB.driverActiveRide[did]) or nil
    if ride_id and QbxTaxiDB and QbxTaxiDB.data and QbxTaxiDB.data.rides and QbxTaxiDB.data.rides[ride_id] then
        QbxTaxiDB.data.rides[ride_id].fare_amount = amount
    end

    -- Ask passenger to confirm payment
    local confirmed = true
    if passengerPlayer and amount > 0 then
        confirmed = lib.callback.await('qbx_taxijob:client:ConfirmFare', passengerPlayer.PlayerData.source, amount, driverName)
    end

    -- Attempt payment if confirmed and valid players
    local paid = false
    if confirmed and driverPlayer and passengerPlayer and amount > 0 then
        local pOK = false
        if passengerPlayer.Functions and passengerPlayer.Functions.RemoveMoney then
            pOK = passengerPlayer.Functions.RemoveMoney('bank', amount)
        end
        if pOK then
            paid = true
            if driverPlayer.Functions and driverPlayer.Functions.AddMoney then
                driverPlayer.Functions.AddMoney('bank', amount)
            end
            if QbxTaxiDB and uid and did and ride_id then
                QbxTaxiDB.addTransaction(uid, did, ride_id, amount, 'paid')
            end
        else
            if QbxTaxiDB and uid and did and ride_id then
                QbxTaxiDB.addTransaction(uid, did, ride_id, amount, 'failed')
            end
        end
    end

    -- Complete ride and clear blips/assignment
    if QbxTaxiDB and driverPlayer then
        QbxTaxiDB.completeRideByDriver(driverPlayer)
    end
    activeAssignments[src] = nil
    assignedRequester[requester] = nil
    TriggerClientEvent('qb-taxijob:client:ClearRideBlips', requester)
    TriggerClientEvent('qb-taxijob:client:ClearRideBlips', src)

    -- Notify both sides
    if amount > 0 then
        TriggerClientEvent('chat:addMessage', requester, { args = { '^2[qbx_taxijob]', ('Your ride is complete. Fare: $%s'):format(tostring(amount)) } })
        if paid then
            TriggerClientEvent('chat:addMessage', requester, { args = { '^2[qbx_taxijob]', 'Payment processed.' } })
            TriggerClientEvent('chat:addMessage', src, { args = { '^2[qbx_taxijob]', ('Ride completed. Fare received: $%s'):format(tostring(amount)) } })
        else
            TriggerClientEvent('chat:addMessage', requester, { args = { '^1[qbx_taxijob]', 'Payment failed or canceled.' } })
            TriggerClientEvent('chat:addMessage', src, { args = { '^1[qbx_taxijob]', 'Passenger payment failed or canceled.' } })
        end
    else
        TriggerClientEvent('chat:addMessage', requester, { args = { '^2[qbx_taxijob]', 'Your ride is complete.' } })
        TriggerClientEvent('chat:addMessage', src, { args = { '^2[qbx_taxijob]', 'Ride completed.' } })
    end
end)

-- Driver command to end ride: asks client to submit fare and stop meter
RegisterCommand('endride', function(src)
    if src == 0 then
        print('[qbx_taxijob] /endride cannot be run from console')
        return
    end
    local assign = activeAssignments[src]
    if not assign then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1[qbx_taxijob]', 'No active ride to end.' } })
        return
    end
    TriggerClientEvent('qbx_taxijob:client:EndRideCollectFare', src)
end, false)

-- Helper: find player source by citizenid
local function findSourceByCitizenId(citizenid)
    for _, id in ipairs(GetPlayers()) do
        local p = exports.qbx_core and exports.qbx_core:GetPlayer(tonumber(id)) or nil
        if p and p.PlayerData and p.PlayerData.citizenid == citizenid then
            return tonumber(id)
        end
    end
    return nil
end

-- Helper: allowed vehicle model check using client config if available
local function isAllowedVehicleModel(modelHash)
    local cfg = clientConfig
    if not cfg or not cfg.allowedVehicles then return true end -- be permissive if config missing
    for _, v in ipairs(cfg.allowedVehicles) do
        if modelHash == joaat(v.model) then return true end
    end
    return false
end

-- Command: /startride (driver-only). Starts ride when passenger is seated with driver in an allowed vehicle.
RegisterCommand('startride', function(src)
    if src == 0 then
        print('[qbx_taxijob] /startride cannot be run from console')
        return
    end
    local driver = exports.qbx_core and exports.qbx_core:GetPlayer(src) or nil
    if not driver then return end
    if not driver.PlayerData or not driver.PlayerData.job or driver.PlayerData.job.name ~= 'taxi' then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1[qbx_taxijob]', 'Only taxi drivers can start rides.' } })
        return
    end
    if not dutyState[src] then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1[qbx_taxijob]', 'You must be on duty to start a ride.' } })
        return
    end

    local ped = GetPlayerPed(src)
    if not DoesEntityExist(ped) then return end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1[qbx_taxijob]', 'You must be seated in a vehicle.' } })
        return
    end
    if GetPedInVehicleSeat(veh, -1) ~= ped then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1[qbx_taxijob]', 'You must be the driver.' } })
        return
    end
    local model = GetEntityModel(veh)
    if not isAllowedVehicleModel(model) then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1[qbx_taxijob]', 'This is not an allowed taxi vehicle.' } })
        return
    end

    if not QbxTaxiDB then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1[qbx_taxijob]', 'Ride DB unavailable.' } })
        return
    end

    local did = driver.PlayerData.citizenid
    local ride_id = QbxTaxiDB.driverActiveRide[did]
    if not ride_id then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1[qbx_taxijob]', 'No accepted ride found to start.' } })
        return
    end
    local ride = QbxTaxiDB.data.rides[ride_id]
    if not ride then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1[qbx_taxijob]', 'Ride not found.' } })
        return
    end
    if ride.status ~= 'accepted' and ride.status ~= 'in-progress' then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1[qbx_taxijob]', 'Ride is not ready to start.' } })
        return
    end

    local passengerSource = findSourceByCitizenId(ride.user_id)
    if not passengerSource then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1[qbx_taxijob]', 'Passenger not online or not found.' } })
        return
    end
    local pPed = GetPlayerPed(passengerSource)
    if GetVehiclePedIsIn(pPed, false) ~= veh then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1[qbx_taxijob]', 'Passenger is not in your vehicle.' } })
        return
    end

    -- Mark in-progress
    QbxTaxiDB.markInProgressByDriver(driver)

    -- Clear pickup/driver blips for both
    TriggerClientEvent('qb-taxijob:client:ClearRideBlips', src)
    TriggerClientEvent('qb-taxijob:client:ClearRideBlips', passengerSource)

    -- Start the meter on driver screen
    TriggerClientEvent('qbx_taxijob:client:StartRideMeter', src)

    TriggerClientEvent('chat:addMessage', src, { args = { '^2[qbx_taxijob]', 'Ride started. Meter running.' } })
    local dname = 'unknown'
    if driver and driver.PlayerData and driver.PlayerData.charinfo then
        local ci = driver.PlayerData.charinfo
        dname = (ci.firstname and ci.lastname) and (ci.firstname .. ' ' .. ci.lastname) or (driver.PlayerData.name or 'unknown')
    end
    TriggerClientEvent('chat:addMessage', passengerSource, { args = { '^2[qbx_taxijob]', ('Your ride with %s has started.'):format(dname) } })
end, false)

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
    if QbxTaxiDB then
        local p = exports.qbx_core and exports.qbx_core:GetPlayer(source) or nil
        if p then QbxTaxiDB.assignVehicleToDriver(p, plate, model) end
    end
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
