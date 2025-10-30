-- Garage and parking zones for qb_taxijob

function setLocationsBlip()
    if not config.useBlips then return end
    if taxiBlip ~= nil then return end
    taxiBlip = AddBlipForCoord(config.locations.main.coords.x, config.locations.main.coords.y, config.locations.main.coords.z)
    SetBlipSprite(taxiBlip, 198)
    SetBlipDisplay(taxiBlip, 4)
    SetBlipScale(taxiBlip, 0.6)
    SetBlipAsShortRange(taxiBlip, true)
    SetBlipColour(taxiBlip, 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(locale('info.blip_name'))
    EndTextCommandSetBlipName(taxiBlip)
end

function taxiGarage()
    if not onDuty then
        exports.qbx_core:Notify('You must be on duty to access the taxi garage', 'error')
        return
    end

    local registeredMenu = {
        id = 'garages_depotlist',
        title = locale('menu.taxi_menu_header'),
        options = {}
    }
    local options = {}
    for _, v in pairs(config.allowedVehicles) do

        options[#options + 1] = {
            title = v.label,
            event = 'qb-taxi:client:TakeVehicle',
            args = {model = v.model},
            icon = 'fa-solid fa-taxi'
        }
    end

    registeredMenu['options'] = options
    lib.registerContext(registeredMenu)
    lib.showContext('garages_depotlist')
end

function setupGarageZone()
    if config.useTarget then
        lib.requestModel(`a_m_m_indian_01`)
        taxiPed = CreatePed(3, `a_m_m_indian_01`, 894.93, -179.12, 74.7 - 1.0, 237.09, false, true)
        SetModelAsNoLongerNeeded(`a_m_m_indian_01`)
        SetBlockingOfNonTemporaryEvents(taxiPed, true)
        FreezeEntityPosition(taxiPed, true)
        SetEntityInvincible(taxiPed, true)
        exports.ox_target:addLocalEntity(taxiPed, {
            {
                type = 'client',
                event = 'qb-taxijob:client:requestcab',
                icon = 'fa-solid fa-taxi',
                label = locale('info.request_taxi_target'),
                job = 'taxi',
            }
        })
    else
        local function onEnter()
            if not cache.vehicle then
                lib.showTextUI(locale('info.request_taxi'))
            end
        end

        local function onExit()
            lib.hideTextUI()
        end

        local function inside()
            if IsControlJustPressed(0, 38) then
                lib.hideTextUI()
                taxiGarage()
                return
            end
        end

        garageZone = lib.zones.box({
            coords = config.locations.garage.coords,
            size = vec3(1.6, 4.0, 2.8),
            rotation = 328.5,
            debug = config.debugPoly,
            inside = inside,
            onEnter = onEnter,
            onExit = onExit
        })
    end
end

function destroyGarageZone()
    if not garageZone then return end

    garageZone:remove()
    garageZone = nil
end

function setupTaxiParkingZone()
    taxiParkingZone = lib.zones.box({
        coords = vec3(config.locations.main.coords.x, config.locations.main.coords.y, config.locations.main.coords.z),
        size = vec3(4.0, 4.0, 4.0),
        rotation = 55,
        debug = config.debugPoly,
        inside = function()
            if QBX.PlayerData.job.name ~= 'taxi' then return end
            if not onDuty then
                exports.qbx_core:Notify('You are off duty', 'error')
                return
            end
            if IsControlJustPressed(0, 38) then
                if whitelistedVehicle() then
                    if meterIsOpen then
                        TriggerEvent('qb-taxi:client:toggleMeter')
                        meterActive = false
                    end
                    DeleteVehicle(cache.vehicle)
                    exports.qbx_core:Notify(locale('info.taxi_returned'), 'success')
                end
            end
        end,
        onEnter = function()
            lib.showTextUI(locale('info.vehicle_parking'))
        end,
        onExit = function()
            lib.hideTextUI()
        end
    })
end

function destroyTaxiParkingZone()
    if not taxiParkingZone then return end

    taxiParkingZone:remove()
    taxiParkingZone = nil
end

RegisterNetEvent('qb-taxi:client:TakeVehicle', function(data)
    if not onDuty then
        exports.qbx_core:Notify('You must be on duty to take a taxi', 'error')
        return
    end
    local SpawnPoint = getVehicleSpawnPoint()
    if SpawnPoint then
        local coords = config.cabSpawns[SpawnPoint]
        local CanSpawn = isSpawnPointClear(coords, 2.0)
        if CanSpawn then
            local netId = lib.callback.await('qb-taxi:server:spawnTaxi', false, data.model, coords)
            local veh = NetToVeh(netId)
            SetVehicleFuelLevel(veh, 100.0)
            SetVehicleEngineOn(veh, true, true, false)
        else
            exports.qbx_core:Notify(locale('info.no_spawn_point'), 'error')
        end
    else
        exports.qbx_core:Notify(locale('info.no_spawn_point'), 'error')
        return
    end
end)
