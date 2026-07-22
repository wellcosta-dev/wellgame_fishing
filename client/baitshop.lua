-- Baitshop client — modern NUI (nem qb-menu)

local QBCore = exports['qb-core']:GetCoreObject()
local shopObjs = {}
local shopOpen = false

local function buildShopCatalog()
    local items = {}
    local list = Config.BaitshopItems or {}
    for i = 1, #list do
        local it = list[i]
        local shared = QBCore.Shared.Items[it.item]
        items[#items + 1] = {
            item = it.item,
            label = it.label or (shared and shared.label) or it.item,
            price = math.floor(tonumber(it.price) or 0),
            category = it.category or 'all',
            desc = it.desc or (shared and shared.description) or '',
            image = it.image or (shared and shared.image) or 'fishing_rod_1.png',
        }
    end
    return items
end

local function closeBaitshop()
    if not shopOpen then return end
    shopOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeShop' })
    if GetResourceState('wellgame_controls') == 'started' then
        exports['wellgame_controls']:toggleAllControls(true, 'wellgame_fishing_shop')
    end
end

local function openBaitshop()
    if shopOpen then return end
    shopOpen = true
    SetNuiFocus(true, true)
    if GetResourceState('wellgame_controls') == 'started' then
        exports['wellgame_controls']:toggleAllControls(false, 'wellgame_fishing_shop')
    end
    SendNUIMessage({
        action = 'openShop',
        data = {
            title = 'Horgászbolt',
            brand = 'WELLCOSTA',
            categories = Config.BaitshopCategories or { { id = 'all', label = 'Összes' } },
            items = buildShopCatalog(),
            cash = (QBCore.Functions.GetPlayerData().money and QBCore.Functions.GetPlayerData().money.cash) or 0,
        },
    })
end

RegisterNUICallback('shopClose', function(_, cb)
    closeBaitshop()
    cb('ok')
end)

RegisterNUICallback('shopBuy', function(data, cb)
    cb('ok')
    if not shopOpen then return end
    local item = data and data.item
    if type(item) ~= 'string' or item == '' then return end
    TriggerServerEvent('wellgame_fishing:server:buyShopItem', item)
end)

RegisterNetEvent('wellgame_fishing:client:shopBought', function(cash)
    if not shopOpen then return end
    SendNUIMessage({
        action = 'shopCash',
        cash = tonumber(cash) or 0,
    })
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
                exports['qb-core']:DrawText('[E] Horgászbolt', 'left')
                if IsControlJustPressed(0, 38) then
                    exports['qb-core']:HideText()
                    openBaitshop()
                end
                break
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    closeBaitshop()
    for i = 1, #shopObjs do
        if DoesEntityExist(shopObjs[i]) then DeleteObject(shopObjs[i]) end
    end
end)
