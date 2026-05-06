local QBCore = exports['qb-core']:GetCoreObject() -- or 'qbx-core'

local function debugPrint(msg)
    if Config.Debug then
        print('[Coroner Debug] ' .. msg)
    end
end

local function findNearbyDeadNPCs(center, radius)
    local peds = GetGamePool('CPed')
    local deadPeds = {}
    for _, ped in ipairs(peds) do
        if DoesEntityExist(ped) and not IsPedAPlayer(ped) and IsEntityDead(ped) then
            local pedCoords = GetEntityCoords(ped)
            if #(pedCoords - center) <= radius then
                table.insert(deadPeds, ped)
            end
        end
    end
    return deadPeds
end
local function generateBulletSerial(weaponHash)
    return string.format('%X-%04d', weaponHash, math.random(1000, 9999))
end

local function getCauseOfDeath(ped)
    local killer = GetPedSourceOfDeath(ped)
    local weaponHash = GetPedCauseOfDeath(ped)

    if weaponHash then
        if IsWeaponValid(weaponHash) then
            if weaponHash == WEAPON_STUNGUN or weaponHash == WEAPON_STUNGUN_MP then
                return 'Taser Round'
            elseif weaponHash == WEAPON_KNIFE then
                return 'Knife Wound'
            elseif IsPedArmed(killer, 6) then
                local serial = generateBulletSerial(weaponHash)
                return 'Gunshot Wound (Bullet Serial: ' .. serial .. ')'
            elseif weaponHash == WEAPON_UNARMED then
                return 'Blunt Force Trauma (Fist)'
            else
                return 'Gunshot Wound'
            end
        end
    end

    local veh = GetVehiclePedIsIn(killer, false)
    if veh and veh ~= 0 then
        local model = GetEntityModel(veh)
        local modelName = GetDisplayNameFromVehicleModel(model)
        return 'Vehicular Impact by ' .. modelName
    end

    return 'Unknown Cause'
end

RegisterNetEvent('coroner:client:removePed', function(netId)
    local ped = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(ped) then
        DeleteEntity(ped)
    end
end)

RegisterNetEvent('coroner:client:callCoroner', function(coords)
    debugPrint('Coroner requested at ' .. json.encode(coords))
    local vanHash = joaat(Config.VanModel)
    RequestModel(vanHash)
    while not HasModelLoaded(vanHash) do
        Wait(0)
    end

    local pedHash = joaat(Config.CoronerPeds[1])
    RequestModel(pedHash)
    while not HasModelLoaded(pedHash) do
        Wait(0)
    end

    -- spawn location 200-400m away
    local angle = math.random() * 2 * math.pi
    local distance = math.random(50, 150)
    local spawnX = coords.x + math.cos(angle) * distance
    local spawnY = coords.y + math.sin(angle) * distance
    local spawnZ = coords.z
    local success, spawnLoc, heading = GetClosestVehicleNodeWithHeading(spawnX, spawnY, spawnZ, 1, 3.0, 0)
    if not success then
        debugPrint('Failed to find a nearby road node!')
        return
    end

    debugPrint('Van spawn location: ' .. json.encode(spawnLoc))

    -- Add blip

    local van = CreateVehicle(vanHash, spawnLoc.x, spawnLoc.y, spawnLoc.z, heading, true, false)
    local driver = CreatePedInsideVehicle(van, 4, pedHash, -1, true, false)
    -- Add blip on van
    local blip = AddBlipForEntity(van)
    SetBlipSprite(blip, 310) -- Skull or van icon
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, 1)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Coroner Van")
    EndTextCommandSetBlipName(blip)

    local targetX = coords.x + math.random(-10, 10)
    local targetY = coords.y + math.random(-10, 10)
    local targetZ = coords.z
    -- Driving style 1074528293 = emergency (sirens, runs lights, aggressive)
    local emergencyDrivingStyle = 1074528293
    local found, driveNode = GetClosestVehicleNodeWithHeading(coords.x, coords.y, coords.z, 1, 3.0, 0)
    if found then
        TaskVehicleDriveToCoordLongrange(driver, van, driveNode.x, driveNode.y, driveNode.z, 20.0,
            emergencyDrivingStyle, 5.0)
    else
        debugPrint('Could not find path to dead body.')
    end

    -- Wait until arrival
    debugPrint('Van en route to scene... Waiting for arrival...')
    local arrived = false
    CreateThread(function()
        while not arrived do
            local vanCoords = GetEntityCoords(van)
            if #(vanCoords - coords) <= 20.0 then
                arrived = true
            end
            Wait(1000)
        end
    end)

    while not arrived do
        Wait(500)
    end
    debugPrint('Coroner van has arrived at the scene.')

    TaskLeaveVehicle(driver, van, 0)
    Wait(1000)
    -- Walk to body
TaskGoToCoordAnyMeans(driver, coords.x, coords.y, coords.z, 1.0, 0, 0, 786603, 0.5)
while #(GetEntityCoords(driver) - coords) > 1.5 do Wait(250) end

-- Take 3 photos
RequestAnimDict("cellphone@")
while not HasAnimDictLoaded("cellphone@") do Wait(10) end

for i = 1, 3 do
    TaskPlayAnim(driver, "cellphone@", "cellphone_text_read_base", 8.0, -8.0, 3000, 49, 0, false, false, false)
    Wait(3000)
end
ClearPedTasks(driver)
Wait(1000)

-- Simulate body bagging
RequestAnimDict("amb@medic@standing@tendtodead@base")
while not HasAnimDictLoaded("amb@medic@standing@tendtodead@base") do Wait(10) end

TaskPlayAnim(driver, "amb@medic@standing@tendtodead@base", "base", 8.0, -8.0, 4000, 1, 0, false, false, false)
Wait(4000)
ClearPedTasks(driver)

-- Find & remove ped (network synced)
local deadPeds = findNearbyDeadNPCs(coords, 50.0)

if #deadPeds == 0 then
    debugPrint('No dead peds found nearby.')
    return
end

for _, ped in ipairs(deadPeds) do
    local pedCoords = GetEntityCoords(ped)

    -- Walk to body
    TaskGoToCoordAnyMeans(driver, pedCoords.x, pedCoords.y, pedCoords.z, 1.0, 0, 0, 786603, 0.5)
    while #(GetEntityCoords(driver) - pedCoords) > 1.5 do Wait(250) end

    -- Take 3 photos
    for i = 1, 3 do
        TaskPlayAnim(driver, "cellphone@", "cellphone_text_read_base", 8.0, -8.0, 3000, 49, 0, false, false, false)
        Wait(3000)
    end
    ClearPedTasks(driver)
    Wait(1000)

    -- Simulate body bagging
    TaskPlayAnim(driver, "amb@medic@standing@tendtodead@base", "base", 8.0, -8.0, 4000, 1, 0, false, false, false)
    Wait(4000)
    ClearPedTasks(driver)

    local cause = getCauseOfDeath(ped)
    local netId = NetworkGetNetworkIdFromEntity(ped)
    TriggerServerEvent('coroner:server:removePed', netId)

    local street1, street2 = GetStreetNameAtCoord(pedCoords.x, pedCoords.y, pedCoords.z)
    local name1 = GetStreetNameFromHashKey(street1)
    local name2 = GetStreetNameFromHashKey(street2)
    local location = name2 and name2 ~= '' and (name1 .. ' & ' .. name2) or name1

    TriggerServerEvent('coroner:server:giveReport', pedCoords, cause, location)

    Wait(1000)
end

-- Walk back to van (simulate carrying body)
local vanCoords = GetEntityCoords(van)
TaskGoToCoordAnyMeans(driver, vanCoords.x, vanCoords.y, vanCoords.z, 1.0, 0, 0, 786603, 0.5)
while #(GetEntityCoords(driver) - vanCoords) > 3.0 do Wait(250) end
Wait(500)



    debugPrint('Coroner is photographing and picking up body...')

local peds = findNearbyDeadNPCs(coords, 2.5)
local cause = 'Unknown'
if #peds > 0 then
    local ped = peds[1]
    cause = getCauseOfDeath(ped)
    Wait(1000)
    debugPrint('Body placed in body bag and removed.')
    local netId = NetworkGetNetworkIdFromEntity(ped)
    TriggerServerEvent('coroner:server:removePed', netId)
else
    debugPrint('No dead ped found nearby')
end
    local street1, street2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local name1 = GetStreetNameFromHashKey(street1)
    local name2 = GetStreetNameFromHashKey(street2)
    local location = name2 and name2 ~= '' and (name1 .. ' & ' .. name2) or name1

    TriggerServerEvent('coroner:server:giveReport', coords, cause, location)

    TaskGoToCoordAnyMeans(driver, spawnLoc.x, spawnLoc.y, spawnLoc.z, 1.0, 0, 0, 786603, 0.5)
    Wait(4000)
    TaskEnterVehicle(driver, van, 10000, -1, 1.0, 1, 0)
    Wait(2000)
    TaskVehicleDriveWander(driver, van, 10.0, 786603)
    Wait(10000)
    DeleteVehicle(van)
    DeletePed(driver)
    -- After DeleteEntity(ped)
    if DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
end)

CreateThread(function()
    exports.ox_target:addGlobalPed({{
        name = 'call_coroner',
        icon = '??',
        label = 'Call Coroner',
        canInteract = function(entity, distance, coords, name)
            local playerData = QBCore.Functions.GetPlayerData()
            local job = playerData.job.name

            return IsEntityDead(entity) and not IsPedAPlayer(entity) and Config.AllowedJobs[job]
        end,
        onSelect = function(data)
            local coords = GetEntityCoords(data.entity)
            TriggerEvent('coroner:client:callCoroner', coords)
        end,
        distance = 2.0
    }})
end)
