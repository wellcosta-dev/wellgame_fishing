local QBCore = exports['qb-core']:GetCoreObject()

local STARTER_KIT_ID = 'starterkit'

local function shopCatalogPrice(itemName)
    local shops = Config.BaitshopItems or {}
    for i = 1, #shops do
        if shops[i].item == itemName then
            return math.floor(tonumber(shops[i].price) or 0)
        end
    end
    return 0
end

-- Adds one item to inventory + does the manual PlayerData/NUI sync this fork needs
-- (exports['qb-inventory']:AddItem already calls SetPlayerData internally, but the extra
-- push here matches the already-proven pattern from the sell flow — cheap and harmless).
local function deliverItem(src, Player, itemName)
    if not exports['qb-inventory']:AddItem(src, itemName, 1) then
        return false
    end
    local items = {}
    for slot, it in pairs(Player.PlayerData.items or {}) do
        items[slot] = it
    end
    Player.Functions.SetPlayerData('items', items)
    TriggerClientEvent('qb-inventory:client:updateInventory', src)
    TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'add', 1)
    return true
end

local function isNearShop(coords)
    for i = 1, #(Config.Baitshops or {}) do
        local c = Config.Baitshops[i].coords
        if #(coords - vector3(c.x, c.y, c.z)) <= 4.0 then return true end
    end
    for i = 1, #Config.Dropoffs do
        local c = Config.Dropoffs[i].coords
        if #(coords - vector3(c.x, c.y, c.z)) <= (Config.DropoffRadius or 3.5) + 2.0 then return true end
    end
    return false
end

RegisterNetEvent('wellgame_fishing:server:buyShopItem', function(itemName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    itemName = tostring(itemName or '')
    if itemName == '' then return end

    local price = shopCatalogPrice(itemName)
    if price < 1 then return end

    if not isNearShop(GetEntityCoords(GetPlayerPed(src))) then
        TriggerClientEvent('QBCore:Notify', src, 'Nem vagy a boltban.', 'error')
        return
    end

    local isStarterKit = itemName == STARTER_KIT_ID
    if not isStarterKit and not QBCore.Shared.Items[itemName] then return end

    if Player.PlayerData.money.cash < price then
        TriggerClientEvent('QBCore:Notify', src, 'Nincs elég készpénzed.', 'error')
        return
    end

    if not Player.Functions.RemoveMoney('cash', price, 'fishing-baitshop') then return end

    if isStarterKit then
        local kitItems = (Config.StarterKit and Config.StarterKit.items) or {}
        local delivered = {}
        local failed = false
        for i = 1, #kitItems do
            if deliverItem(src, Player, kitItems[i]) then
                delivered[#delivered + 1] = kitItems[i]
            else
                failed = true
                break
            end
        end
        if failed then
            -- couldn't fit the whole kit — take back what we managed to hand over and refund
            for i = 1, #delivered do
                exports['qb-inventory']:RemoveItem(src, delivered[i], 1)
            end
            Player.Functions.AddMoney('cash', price, 'fishing-baitshop-refund')
            TriggerClientEvent('QBCore:Notify', src, 'Nincs elég hely a kezdőcsomaghoz.', 'error')
            return
        end
        TriggerClientEvent('QBCore:Notify', src, ('Megvetted a kezdőcsomagot (%s$)'):format(price), 'success')
    else
        if not deliverItem(src, Player, itemName) then
            Player.Functions.AddMoney('cash', price, 'fishing-baitshop-refund')
            TriggerClientEvent('QBCore:Notify', src, 'Nincs hely az inventoryban.', 'error')
            return
        end
        TriggerClientEvent('QBCore:Notify', src, ('Megvetted: %s (%s$)'):format(QBCore.Shared.Items[itemName].label or itemName, price), 'success')
    end

    local cash = Player.Functions.GetMoney('cash') or 0
    TriggerClientEvent('wellgame_fishing:client:shopBought', src, cash)
end)
