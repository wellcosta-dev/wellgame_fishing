local QBCore = exports['qb-core']:GetCoreObject()

local function shopPrice(base)
    return math.floor((tonumber(base) or 0) * (Config.EconomyScale or 1.0))
end

RegisterNetEvent('wellgame_fishing:server:buyShopItem', function(itemName, price)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    itemName = tostring(itemName or '')
    price = math.floor(tonumber(price) or 0)
    if price < 1 or itemName == '' then return end

    local allowed = false
    local expected = 0
    local shops = Config.BaitshopItems or {}
    for i = 1, #shops do
        if shops[i].item == itemName then
            expected = shopPrice(shops[i].price)
            if price == expected then
                allowed = true
            end
            break
        end
    end
    if not allowed then return end
    price = expected

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local near = false
    for i = 1, #(Config.Baitshops or {}) do
        local c = Config.Baitshops[i].coords
        if #(coords - vector3(c.x, c.y, c.z)) <= 4.0 then
            near = true
            break
        end
    end
    for i = 1, #Config.Dropoffs do
        local c = Config.Dropoffs[i].coords
        if #(coords - vector3(c.x, c.y, c.z)) <= (Config.DropoffRadius or 3.5) + 2.0 then
            near = true
            break
        end
    end
    if not near then
        TriggerClientEvent('QBCore:Notify', src, 'Nem vagy a boltban.', 'error')
        return
    end

    if not QBCore.Shared.Items[itemName] then return end
    if Player.PlayerData.money.cash < price then
        TriggerClientEvent('QBCore:Notify', src, 'Nincs elég készpénzed.', 'error')
        return
    end
    if Player.Functions.RemoveMoney('cash', price, 'fishing-baitshop') then
        if Player.Functions.AddItem(itemName, 1, false, {}) then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'add')
            TriggerClientEvent('QBCore:Notify', src, ('Megvetted: %s (%s$)'):format(QBCore.Shared.Items[itemName].label or itemName, price), 'success')
        else
            Player.Functions.AddMoney('cash', price, 'fishing-baitshop-refund')
            TriggerClientEvent('QBCore:Notify', src, 'Nincs hely az inventoryban.', 'error')
        end
    end
end)
