-- Baitshop + denied zone helpers (client)

local QBCore = exports['qb-core']:GetCoreObject()
local shopObjs = {}

local function openBaitshop()
    local items = Config.BaitshopItems or {}
    local scale = Config.EconomyScale or 1.0
    local menu = {
        { header = 'Horgász felszerelés', isMenuHeader = true },
    }
    for i = 1, #items do
        local it = items[i]
        local price = math.floor((it.price or 0) * scale)
        menu[#menu + 1] = {
            header = it.label or it.item,
            txt = ('Ár: %s $'):format(price),
            params = {
                event = 'wellgame_fishing:client:buyShopItem',
                args = { item = it.item, price = price },
            },
        }
    end
    menu[#menu + 1] = { header = 'Bezárás', params = { event = 'qb-menu:client:closeMenu' } }
    exports['qb-menu']:openMenu(menu)
end

RegisterNetEvent('wellgame_fishing:client:buyShopItem', function(data)
    if type(data) ~= 'table' or not data.item then return end
    TriggerServerEvent('wellgame_fishing:server:buyShopItem', data.item, data.price)
end)

CreateThread(function()
    local shops = Config.Baitshops or {}
    for i = 1, #shops do
        local s = shops[i]
        local model = s.model or `prop_tool_bench02`
        RequestModel(model)
        local t = GetGameTimer() + 3000
        while not HasModelLoaded(model) and GetGameTimer() < t do Wait(10) end
        if HasModelLoaded(model) then
            local c = s.coords
            local obj = CreateObject(model, c.x, c.y, c.z - 1.0, false, false, false)
            SetEntityHeading(obj, c.w or 0.0)
            FreezeEntityPosition(obj, true)
            shopObjs[#shopObjs + 1] = obj
            SetModelAsNoLongerNeeded(model)

            if GetResourceState('qb-target') == 'started' then
                exports['qb-target']:AddTargetEntity(obj, {
                    options = {
                        {
                            icon = 'fas fa-fish',
                            label = s.label or 'Horgászbolt',
                            action = function()
                                openBaitshop()
                            end,
                        },
                    },
                    distance = 2.5,
                })
            end
        end
    end
end)

-- Proximity fallback without qb-target
CreateThread(function()
    if GetResourceState('qb-target') == 'started' then return end
    while true do
        local sleep = 1000
        local coords = GetEntityCoords(PlayerPedId())
        local shops = Config.Baitshops or {}
        for i = 1, #shops do
            local c = shops[i].coords
            if #(coords - vector3(c.x, c.y, c.z)) < 2.0 then
                sleep = 0
                exports['qb-core']:DrawText('[E] Horgász felszerelés', 'left')
                if IsControlJustPressed(0, 38) then
                    exports['qb-core']:HideText()
                    openBaitshop()
                end
                break
            end
        end
        if sleep ~= 0 then
            -- hide only when leaving; cheap no-op if already hidden
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for i = 1, #shopObjs do
        if DoesEntityExist(shopObjs[i]) then DeleteObject(shopObjs[i]) end
    end
end)
