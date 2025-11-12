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
    
    -- Notify all customers with tablet open that driver list changed
    SetTimeout(100, function()
        TriggerClientEvent('qbx_taxijob:client:UpdateOnlineDrivers', -1)
    end)
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
            TriggerClientEvent('qbx_taxijob:client:AllDriversBusy', r.requester)
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

    -- Track driver responses
    if not req.responses then
        req.responses = {}
    end
    req.responses[src] = accept

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
        -- declined; check if all drivers have responded
        local totalDrivers = 0
        local totalResponses = 0
        
        for driverSrc, onDuty in pairs(dutyState) do
            if onDuty then
                totalDrivers = totalDrivers + 1
                if req.responses[driverSrc] ~= nil then
                    totalResponses = totalResponses + 1
                end
            end
        end
        
        -- If all drivers have declined, notify customer
        if totalResponses >= totalDrivers and not req.assigned then
            TriggerClientEvent('qbx_taxijob:client:AllDriversBusy', req.requester)
            pendingRequests[reqId] = nil
        else
            TriggerClientEvent('chat:addMessage', src, { args = { '^1[qbx_taxijob]', 'You declined the ride request.' } })
        end
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

    -- Validate minimum ride time (60 seconds)
    local did = driverPlayer and driverPlayer.PlayerData and driverPlayer.PlayerData.citizenid or nil
    local ride_id = (did and QbxTaxiDB and QbxTaxiDB.driverActiveRide[did]) or nil
    if ride_id and QbxTaxiDB and QbxTaxiDB.data and QbxTaxiDB.data.rides and QbxTaxiDB.data.rides[ride_id] then
        local ride = QbxTaxiDB.data.rides[ride_id]
        if ride.start_time then
            local elapsed = os.time() - ride.start_time
            if elapsed < 60 then
                lib.notify(src, {
                    title = 'Taxi Job',
                    description = string.format('Minimum ride time not met (%d seconds remaining)', 60 - elapsed),
                    type = 'error'
                })
                return
            end
        end
    end

    -- Persist fare to ride record
    local uid = passengerPlayer and passengerPlayer.PlayerData and passengerPlayer.PlayerData.citizenid or nil
    if ride_id and QbxTaxiDB and QbxTaxiDB.data and QbxTaxiDB.data.rides and QbxTaxiDB.data.rides[ride_id] then
        QbxTaxiDB.data.rides[ride_id].fare_amount = amount
    end

    -- Complete ride and clear blips/assignment FIRST (so taxi meter stops)
    if QbxTaxiDB and driverPlayer then
        QbxTaxiDB.completeRideByDriver(driverPlayer)
    end
    activeAssignments[src] = nil
    assignedRequester[requester] = nil
    TriggerClientEvent('qb-taxijob:client:ClearRideBlips', requester)
    TriggerClientEvent('qb-taxijob:client:ClearRideBlips', src)
    
    -- Store pending payment data for customer tablet UI to handle
    if not pendingPayments then pendingPayments = {} end
    pendingPayments[requester] = {
        driverSrc = src,
        driverPlayer = driverPlayer,
        passengerPlayer = passengerPlayer,
        amount = amount,
        driverName = driverName,
        uid = uid,
        did = did,
        ride_id = ride_id,
        timestamp = os.time()
    }
    
    -- Notify passenger to show payment screen in customer tablet (not ox_lib dialog)
    TriggerClientEvent('qbx_taxijob:client:RideCompleted', requester, {
        fare = amount,
        paid = false,  -- Payment pending, not processed yet
        driverName = driverName,
        driverCid = did,  -- Driver citizen ID for review submission
        rideId = ride_id,  -- Ride ID for review submission
        awaitingPayment = true  -- Signal that payment UI should be shown
    })
    
    -- Notify driver that ride is complete, waiting for passenger payment
    TriggerClientEvent('chat:addMessage', requester, { args = { '^2[qbx_taxijob]', ('Your ride is complete. Fare: $%s'):format(tostring(amount)) } })
    TriggerClientEvent('chat:addMessage', src, { args = { '^3[qbx_taxijob]', 'Ride completed. Waiting for passenger payment...' } })
end)

-- Process payment from customer tablet UI (replaces ox_lib ConfirmFare callback)
RegisterNetEvent('qbx_taxijob:server:ProcessPayment', function(data)
    local src = source
    local method = data.method or 'debit'
    local confirmed = data.confirmed or false
    
    print(('[qbx_taxijob] [SERVER] ProcessPayment from %d - Method: %s, Confirmed: %s'):format(src, method, tostring(confirmed)))
    
    -- Get pending payment data
    if not pendingPayments then pendingPayments = {} end
    local payment = pendingPayments[src]
    
    if not payment then
        print(('[qbx_taxijob] [SERVER] No pending payment found for passenger %d'):format(src))
        return
    end
    
    -- Clean up old pending payments (older than 5 minutes)
    for passengerSrc, p in pairs(pendingPayments) do
        if os.time() - p.timestamp > 300 then
            pendingPayments[passengerSrc] = nil
            print(('[qbx_taxijob] [SERVER] Cleaned up expired payment for passenger %d'):format(passengerSrc))
        end
    end
    
    local driverSrc = payment.driverSrc
    local driverPlayer = payment.driverPlayer
    local passengerPlayer = payment.passengerPlayer
    local amount = payment.amount
    local driverName = payment.driverName
    local uid = payment.uid
    local did = payment.did
    local ride_id = payment.ride_id
    
    -- Attempt payment if confirmed and valid players
    local paid = false
    if confirmed and driverPlayer and passengerPlayer and amount > 0 then
        local pOK = false
        
        -- Use cash or bank based on method selection
        local account = (method == 'cash') and 'cash' or 'bank'
        
        if passengerPlayer.Functions and passengerPlayer.Functions.RemoveMoney then
            pOK = passengerPlayer.Functions.RemoveMoney(account, amount, 'taxi-fare')
        end
        
        if pOK then
            paid = true
            if driverPlayer.Functions and driverPlayer.Functions.AddMoney then
                driverPlayer.Functions.AddMoney('bank', amount, 'taxi-fare-received')
            end
            if QbxTaxiDB and uid and did and ride_id then
                QbxTaxiDB.addTransaction(uid, did, ride_id, amount, 'paid')
            end
            
            -- Notify both parties of successful payment
            TriggerClientEvent('chat:addMessage', src, { args = { '^2[qbx_taxijob]', 'Payment processed successfully.' } })
            TriggerClientEvent('chat:addMessage', driverSrc, { args = { '^2[qbx_taxijob]', ('Fare received: $%s'):format(tostring(amount)) } })
            
            lib.notify(src, {
                title = 'Payment Successful',
                description = string.format('$%.2f paid via %s', amount, method == 'cash' and 'Cash' or 'Debit Card'),
                type = 'success'
            })
            
            lib.notify(driverSrc, {
                title = 'Payment Received',
                description = string.format('$%.2f from %s', amount, passengerPlayer.PlayerData.charinfo.firstname or 'Passenger'),
                type = 'success'
            })
        else
            -- Payment failed
            if QbxTaxiDB and uid and did and ride_id then
                QbxTaxiDB.addTransaction(uid, did, ride_id, amount, 'failed')
            end
            
            TriggerClientEvent('chat:addMessage', src, { args = { '^1[qbx_taxijob]', 'Payment failed - insufficient funds.' } })
            TriggerClientEvent('chat:addMessage', driverSrc, { args = { '^1[qbx_taxijob]', 'Passenger payment failed.' } })
            
            lib.notify(src, {
                title = 'Payment Failed',
                description = 'Insufficient funds in your account',
                type = 'error'
            })
        end
    elseif not confirmed then
        -- Payment cancelled by passenger
        TriggerClientEvent('chat:addMessage', src, { args = { '^3[qbx_taxijob]', 'Payment cancelled.' } })
        TriggerClientEvent('chat:addMessage', driverSrc, { args = { '^3[qbx_taxijob]', 'Passenger cancelled payment.' } })
        
        if QbxTaxiDB and uid and did and ride_id then
            QbxTaxiDB.addTransaction(uid, did, ride_id, amount, 'cancelled')
        end
    end
    
    -- Clean up pending payment
    pendingPayments[src] = nil
    
    -- Update passenger UI with payment result
    TriggerClientEvent('qbx_taxijob:client:PaymentProcessed', src, {
        paid = paid,
        amount = amount,
        method = method
    })
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

-- Shared function for starting a ride (used by both command and tablet)
local function startRideLogic(src)
    local driver = exports.qbx_core and exports.qbx_core:GetPlayer(src) or nil
    if not driver then return false, 'Driver not found' end
    if not driver.PlayerData or not driver.PlayerData.job or driver.PlayerData.job.name ~= 'taxi' then
        return false, 'Only taxi drivers can start rides'
    end
    if not dutyState[src] then
        return false, 'You must be on duty to start a ride'
    end

    local ped = GetPlayerPed(src)
    if not DoesEntityExist(ped) then return false, 'Invalid ped' end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        return false, 'You must be seated in a vehicle'
    end
    if GetPedInVehicleSeat(veh, -1) ~= ped then
        return false, 'You must be the driver'
    end
    local model = GetEntityModel(veh)
    if not isAllowedVehicleModel(model) then
        return false, 'This is not an allowed taxi vehicle'
    end

    if not QbxTaxiDB then
        return false, 'Ride DB unavailable'
    end

    local did = driver.PlayerData.citizenid
    local ride_id = QbxTaxiDB.driverActiveRide[did]
    if not ride_id then
        return false, 'No accepted ride found to start'
    end
    local ride = QbxTaxiDB.data.rides[ride_id]
    if not ride then
        return false, 'Ride not found'
    end
    if ride.status ~= 'accepted' and ride.status ~= 'in-progress' then
        return false, 'Ride is not ready to start'
    end

    local passengerSource = findSourceByCitizenId(ride.user_id)
    if not passengerSource then
        return false, 'Passenger not online or not found'
    end
    local pPed = GetPlayerPed(passengerSource)
    if GetVehiclePedIsIn(pPed, false) ~= veh then
        return false, 'Passenger is not in your vehicle'
    end

    -- Mark in-progress
    QbxTaxiDB.markInProgressByDriver(driver)

    -- Clear pickup/driver blips for both
    TriggerClientEvent('qb-taxijob:client:ClearRideBlips', src)
    TriggerClientEvent('qb-taxijob:client:ClearRideBlips', passengerSource)

    -- Start the meter on driver screen
    TriggerClientEvent('qbx_taxijob:client:StartRideMeter', src)

    local dname = 'unknown'
    if driver and driver.PlayerData and driver.PlayerData.charinfo then
        local ci = driver.PlayerData.charinfo
        dname = (ci.firstname and ci.lastname) and (ci.firstname .. ' ' .. ci.lastname) or (driver.PlayerData.name or 'unknown')
    end
    TriggerClientEvent('chat:addMessage', passengerSource, { args = { '^2[qbx_taxijob]', ('Your ride with %s has started.'):format(dname) } })
    
    return true, 'Ride started. Meter running.'
end

-- Command: /startride (driver-only). Starts ride when passenger is seated with driver in an allowed vehicle.
RegisterCommand('startride', function(src)
    if src == 0 then
        print('[qbx_taxijob] /startride cannot be run from console')
        return
    end
    
    local success, message = startRideLogic(src)
    if success then
        TriggerClientEvent('chat:addMessage', src, { args = { '^2[qbx_taxijob]', message } })
    else
        TriggerClientEvent('chat:addMessage', src, { args = { '^1[qbx_taxijob]', message } })
    end
end, false)

-- Callback: Tablet start ride (same logic as /startride command, returns success status)
lib.callback.register('qbx_taxijob:server:TabletStartRide', function(source)
    local src = source
    if not src then return { success = false, message = 'Invalid source' } end
    
    local success, message = startRideLogic(src)
    
    -- Send notification
    if success then
        lib.notify(src, {
            title = 'Taxi Job',
            description = message,
            type = 'success'
        })
    else
        lib.notify(src, {
            title = 'Taxi Job',
            description = message,
            type = 'error'
        })
    end
    
    -- Return status to UI
    return { success = success, message = message }
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

-- Callback: Get list of online drivers for customer tablet
lib.callback.register('qbx_taxijob:server:GetOnlineDrivers', function(source)
    local drivers = {}
    local customerCoords = GetEntityCoords(GetPlayerPed(source))
    
    print(('[qbx_taxijob] [DEBUG] GetOnlineDrivers called by source=%d'):format(source))
    print(('[qbx_taxijob] [DEBUG] dutyState table contents:'))
    for src, duty in pairs(dutyState) do
        print(('  src=%d duty=%s'):format(src, tostring(duty)))
    end
    
    -- Iterate through all online drivers
    for driverSource, onDuty in pairs(dutyState) do
        if onDuty and GetPlayerPing(driverSource) > 0 then
            local player = exports.qbx_core:GetPlayer(driverSource)
            if player and player.PlayerData then
                local driverPed = GetPlayerPed(driverSource)
                local driverCoords = GetEntityCoords(driverPed)
                local distance = #(customerCoords - driverCoords)
                
                -- Get vehicle info (server-side doesn't have GetDisplayNameFromVehicleModel)
                local vehicle = GetVehiclePedIsIn(driverPed, false)
                local vehicleModel = 'Taxi'
                if vehicle ~= 0 then
                    -- Just use generic "Taxi" for now - model names require client-side native
                    vehicleModel = 'Taxi Vehicle'
                end
                
                -- Calculate distance in miles and ETA
                local distanceMi = distance * 0.000621371 -- meters to miles
                local etaMinutes = math.ceil(distance / 447) -- assuming ~30 mph average speed (447 m/min)
                
                -- Get driver name
                local firstName = player.PlayerData.charinfo.firstname or 'John'
                local lastName = player.PlayerData.charinfo.lastname or 'Doe'
                
                table.insert(drivers, {
                    id = driverSource,
                    name = firstName .. ' ' .. lastName,
                    rating = 4.8, -- TODO: Get from database
                    distance = string.format('%.1f mi', distanceMi),
                    eta = string.format('%d min', etaMinutes),
                    vehicle = vehicleModel,
                    carType = 'economy', -- TODO: Determine from vehicle class
                    coords = {x = driverCoords.x, y = driverCoords.y, z = driverCoords.z}
                })
                print(('[qbx_taxijob] [DEBUG] Added driver: %s (src=%d) distance=%s eta=%s'):format(firstName .. ' ' .. lastName, driverSource, string.format('%.1f mi', distanceMi), string.format('%d min', etaMinutes)))
            end
        end
    end
    
    print(('[qbx_taxijob] [DEBUG] Returning %d drivers to customer'):format(#drivers))
    return drivers
end)

-- Callback: Get driver's currently accepted ride
lib.callback.register('qbx_taxijob:server:GetDriverAcceptedRide', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then 
        print(('[qbx_taxijob] [ERROR] GetDriverAcceptedRide: Invalid player source %s'):format(source))
        return nil 
    end
    
    local driverCitizenId = player.PlayerData.citizenid
    if not QbxTaxiDB or not QbxTaxiDB.driverActiveRide then
        print(('[qbx_taxijob] [ERROR] QbxTaxiDB not available'):format())
        return nil
    end
    
    -- Check if driver has an active ride
    local rideId = QbxTaxiDB.driverActiveRide[driverCitizenId]
    if not rideId then
        print(('[qbx_taxijob] [DEBUG] No active ride for driver %s'):format(driverCitizenId))
        return nil
    end
    
    -- Get the ride data
    local ride = QbxTaxiDB.data.rides[rideId]
    if not ride then
        print(('[qbx_taxijob] [ERROR] Ride %s not found for driver %s'):format(rideId, driverCitizenId))
        return nil
    end
    
    -- Only return if status is 'accepted' (not in-progress or completed)
    if ride.status ~= 'accepted' then
        print(('[qbx_taxijob] [DEBUG] Ride %s status is %s, not accepted'):format(rideId, ride.status))
        return nil
    end
    
    -- Get passenger info
    local passenger = QbxTaxiDB.data.users[ride.user_id]
    local passengerName = passenger and passenger.name or 'Unknown Passenger'
    
    -- Get driver's current location for distance calculation
    local driverPed = GetPlayerPed(source)
    local driverCoords = GetEntityCoords(driverPed)
    local pickupLoc = ride.pickup_location
    local distance = 0
    local distanceMi = '0.0 mi'
    
    if pickupLoc and pickupLoc.x and pickupLoc.y and pickupLoc.z then
        local pickup = vector3(pickupLoc.x, pickupLoc.y, pickupLoc.z)
        distance = #(driverCoords - pickup)
        distanceMi = string.format('%.1f mi', distance * 0.000621371)
    end
    
    -- Get vehicle info
    local vehicle = GetVehiclePedIsIn(driverPed, false)
    local vehicleModel = 'Taxi Vehicle'
    local vehiclePlate = 'UNKNOWN'
    if vehicle ~= 0 then
        vehiclePlate = GetVehicleNumberPlateText(vehicle) or 'UNKNOWN'
        -- Model name requires client-side native, keep generic
    end
    
    -- Format pickup location as address (simplified)
    local pickupAddress = 'Unknown Location'
    if pickupLoc then
        pickupAddress = string.format('%.0f, %.0f Street', pickupLoc.x, pickupLoc.y)
    end
    
    -- Build response object matching React UI expectations
    local rideData = {
        id = rideId,
        passenger = passengerName,
        rating = 4.5, -- TODO: Get from ratings table
        pickup = pickupAddress,
        pickupCoords = pickupLoc,
        pickupDistance = distanceMi,
        destination = ride.dropoff_location and string.format('%.0f, %.0f Street', ride.dropoff_location.x, ride.dropoff_location.y) or 'Not Set',
        fare = ride.fare_amount or 0,
        status = ride.status,
        note = ride.note or '',
        vehicle = vehicleModel,
        vehiclePlate = vehiclePlate,
        avatar = 'https://avatar.iran.liara.run/public/' .. (math.random(1, 2) == 1 and 'boy' or 'girl')
    }
    
    print(('[qbx_taxijob] [DEBUG] Returning accepted ride %s for driver %s (passenger: %s)'):format(rideId, driverCitizenId, passengerName))
    return rideData
end)

-- Callback: Submit review for completed ride
lib.callback.register('qbx_taxijob:server:SubmitReview', function(source, data)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then
        print(('[qbx_taxijob] [ERROR] SubmitReview: Invalid player source %s'):format(source))
        return {success = false, message = 'Invalid player'}
    end
    
    local passengerCid = player.PlayerData.citizenid
    local driverCid = data.driverCid
    local rideId = data.rideId
    local rating = tonumber(data.rating) or 5
    local comment = data.comment or ''
    
    if not driverCid or not rideId then
        return {success = false, message = 'Missing required data'}
    end
    
    -- Validate rating
    if rating < 1 or rating > 5 then
        return {success = false, message = 'Rating must be between 1 and 5'}
    end
    
    -- Add review to database
    if QbxTaxiDB and QbxTaxiDB.addReview then
        local reviewId = QbxTaxiDB.addReview(passengerCid, driverCid, rideId, rating, comment)
        
        print(('[qbx_taxijob] [SERVER] Review submitted: %d stars for driver %s (ride: %s)'):format(rating, driverCid, rideId))
        
        return {
            success = true,
            reviewId = reviewId,
            message = 'Review submitted successfully'
        }
    end
    
    return {success = false, message = 'Database error'}
end)

-- Callback: Get driver statistics and reviews
lib.callback.register('qbx_taxijob:server:GetDriverStats', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then
        print(('[qbx_taxijob] [ERROR] GetDriverStats: Invalid player source %s'):format(source))
        return nil
    end
    
    local driverCid = player.PlayerData.citizenid
    
    if not QbxTaxiDB then
        return nil
    end
    
    -- Get driver stats
    local stats = QbxTaxiDB.getDriverStats and QbxTaxiDB.getDriverStats(driverCid) or {
        total_reviews = 0,
        average_rating = 0,
        ratings_breakdown = {[1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0}
    }
    
    -- Get recent reviews (last 10)
    local reviews = QbxTaxiDB.getDriverReviews and QbxTaxiDB.getDriverReviews(driverCid, 10) or {}
    
    -- Enrich reviews with passenger names
    for _, review in ipairs(reviews) do
        review.passengerName = QbxTaxiDB.getPassengerName and QbxTaxiDB.getPassengerName(review.user_id) or 'Unknown'
    end
    
    -- Calculate completed rides count
    local completedRides = 0
    if QbxTaxiDB.data and QbxTaxiDB.data.rides then
        for _, ride in pairs(QbxTaxiDB.data.rides) do
            if ride.driver_id == driverCid and ride.status == 'completed' then
                completedRides = completedRides + 1
            end
        end
    end
    
    -- Calculate today's earnings
    local todayEarnings = 0
    local todayStart = os.time() - (os.time() % 86400) -- midnight today
    if QbxTaxiDB.data and QbxTaxiDB.data.transactions then
        for _, tx in ipairs(QbxTaxiDB.data.transactions) do
            if tx.driver_id == driverCid and tx.payment_status == 'paid' and tx.ts >= todayStart then
                todayEarnings = todayEarnings + (tx.amount or 0)
            end
        end
    end
    
    print(('[qbx_taxijob] [DEBUG] Driver stats for %s: %.2f rating, %d reviews, %d rides'):format(
        driverCid, stats.average_rating, stats.total_reviews, completedRides
    ))
    
    return {
        rating = stats.average_rating,
        totalReviews = stats.total_reviews,
        totalRides = completedRides,
        todayEarnings = todayEarnings,
        ratingsBreakdown = stats.ratings_breakdown,
        recentReviews = reviews
    }
end)

