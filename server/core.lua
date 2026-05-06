QBCore = exports['qb-core']:GetCoreObject()

local function debugPrint(msg)
    if Config.Debug then
        print('[Coroner Debug] ' .. msg)
    end
end


RegisterNetEvent('coroner:server:giveReport', function(coords, cause, location)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local timestamp = os.date('%Y-%m-%d %H:%M:%S')

    local metadata = {
        cause = cause or 'Unknown',
        location = location,
        timestamp = timestamp,
        description = table.concat({
            "**Coroners Report**",
            "Cause of Death: " .. cause,
            "Location: " .. location,
            "Time of Report: " .. timestamp,
        }, "\n")
    }

    debugPrint(('Giving report to player %s at %s'):format(src, location))
    exports.ox_inventory:AddItem(src, Config.ReportItem, 1, metadata)

    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Coroner Report',
        description = 'You received a coroner report.',
        type = 'inform'
    })
end)

RegisterNetEvent('coroner:server:removePed', function(netId)
    TriggerClientEvent('coroner:client:removePed', -1, netId)
end)
