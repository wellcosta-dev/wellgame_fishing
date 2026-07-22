local QBCore = exports['qb-core']:GetCoreObject()
local logOpen = false

local function closeFishLog()
    if not logOpen then return end
    logOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeFishLog' })
end

local function openFishLog()
    if logOpen then return end
    QBCore.Functions.TriggerCallback('wellgame_fishing:server:getLog', function(rows, level)
        logOpen = true
        SetNuiFocus(true, true)

        local species = {}
        for key, ft in pairs(FishTypes) do
            species[#species + 1] = {
                key = key,
                name = ft.name,
                class = ft.class or 'Common',
                nonAlive = ft.nonAlive == true,
                sellableFish = ft.sellableFish == true,
            }
        end

        local prog = Config.Progression or {}
        SendNUIMessage({
            action = 'openFishLog',
            species = species,
            caught = rows or {},
            level = level or 1,
            maxLevel = prog.maxLevel or 30,
            catchesPerLevel = prog.catchesPerLevel or 15,
        })
    end)
end

RegisterCommand('fishlog', function() openFishLog() end, false)
RegisterKeyMapping('fishlog', 'Horgásznapló megnyitása', 'keyboard', 'F7')

RegisterNUICallback('closeFishLog', function(_, cb)
    closeFishLog()
    cb('ok')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    closeFishLog()
end)
