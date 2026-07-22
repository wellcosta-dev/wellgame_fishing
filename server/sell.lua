local QBCore = exports['qb-core']:GetCoreObject()

local function formatMoney(n)
    n = math.floor(tonumber(n) or 0)
    local neg = n < 0
    local s = tostring(math.abs(n))
    local parts = {}
    while #s > 3 do
        parts[#parts + 1] = s:sub(-3)
        s = s:sub(1, #s - 3)
    end
    if #s > 0 then parts[#parts + 1] = s end
    local out = {}
    for i = #parts, 1, -1 do
        out[#out + 1] = parts[i]
    end
    local formatted = table.concat(out, ' ')
    if neg then formatted = '-' .. formatted end
    return formatted
end

local function sameName(a, b)
    return a and b and tostring(a):lower() == tostring(b):lower()
end

local function wipeKey(items, key)
    if key == nil or not items then return end
    items[key] = nil
    local n = tonumber(key)
    if n ~= nil then items[n] = nil end
    items[tostring(key)] = nil
end

--- Minden egyező példányt kiszed (név + opcionális slot), szám/string kulcsokkal.
local function purgeFish(items, itemName, slot)
    if type(items) ~= 'table' then return 0 end
    slot = tonumber(slot)
    local removed = 0
    local toWipe = {}

    for key, invItem in pairs(items) do
        if invItem and sameName(invItem.name, itemName) then
            local itemSlot = tonumber(invItem.slot) or tonumber(key)
            if slot == nil or itemSlot == slot or tonumber(key) == slot then
                toWipe[#toWipe + 1] = key
            end
        end
    end

    if slot ~= nil then
        toWipe[#toWipe + 1] = slot
        toWipe[#toWipe + 1] = tostring(slot)
    end

    for i = 1, #toWipe do
        if items[toWipe[i]] ~= nil then
            removed = removed + 1
        end
        wipeKey(items, toWipe[i])
    end

    return removed
end

local function countFish(items, itemName, slot)
    if type(items) ~= 'table' then return 0 end
    slot = tonumber(slot)
    local n = 0
    for key, invItem in pairs(items) do
        if invItem and sameName(invItem.name, itemName) then
            local itemSlot = tonumber(invItem.slot) or tonumber(key)
            if slot == nil or itemSlot == slot or tonumber(key) == slot then
                n = n + 1
            end
        end
    end
    return n
end

local function applyItems(Player, items)
    -- In-place + új ref (Mindkettő: qb-inventory broken SetPlayerData és Functions sync)
    Player.PlayerData.items = items
    Player.Functions.SetPlayerData('items', items)
end

RegisterNetEvent('wellgame_fishing:server:sellFish', function(slot, slider)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    slider = math.max(0.0, math.min(1.0, tonumber(slider) or 0.5))
    slot = tonumber(slot)

    if FishingSellCooldownOk and not FishingSellCooldownOk(src) then
        TriggerClientEvent('QBCore:Notify', src, 'Várj egy kicsit az eladások között.', 'error')
        return
    end

    local items = Player.PlayerData.items
    if type(items) ~= 'table' then
        TriggerClientEvent('QBCore:Notify', src, 'A hal már nincs nálad.', 'error')
        return
    end

    -- Item felderítés slot alapján (szám/string kulcs)
    local item = nil
    if slot ~= nil then
        item = items[slot] or items[tostring(slot)]
    end
    if not item then
        for key, invItem in pairs(items) do
            if invItem and (slot == nil or tonumber(invItem.slot) == slot or tonumber(key) == slot) then
                local _, ftCheck = GetFishTypeByItem(invItem.name)
                if ftCheck and ftCheck.sellableFish then
                    item = invItem
                    if slot == nil then slot = tonumber(invItem.slot) or tonumber(key) end
                    break
                end
            end
        end
    end
    if not item or not item.name then
        TriggerClientEvent('QBCore:Notify', src, 'A hal már nincs nálad.', 'error')
        return
    end

    local itemName = item.name
    local fishKey, ft = GetFishTypeByItem(itemName)
    if not ft or not ft.sellableFish or not ft.price then
        TriggerClientEvent('QBCore:Notify', src, 'Ezt nem lehet eladni itt.', 'error')
        return
    end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local near = false
    for i = 1, #Config.Dropoffs do
        local d = Config.Dropoffs[i].coords
        if #(coords - vector3(d.x, d.y, d.z)) <= (Config.DropoffRadius or 3.5) + 1.0 then
            near = true
            break
        end
    end
    if not near then
        TriggerClientEvent('QBCore:Notify', src, 'Nem vagy a felvásárlónál.', 'error')
        return
    end

    local weight = tonumber(item.info and item.info.weight) or RandomFishWeight(fishKey)
    local scale = Config.EconomyScale or 1.0
    local from = math.floor(ft.price * weight * 0.7 * scale)
    local to = math.floor(ft.price * weight * 1.0 * scale)
    local price = math.floor(from + (to - from) * slider)
    if price < 1 then price = 1 end

    -- 1) In-place purge a valódi PlayerData.items táblán
    local before = countFish(Player.PlayerData.items, itemName, slot)
    local purged = purgeFish(Player.PlayerData.items, itemName, slot)
    local after = countFish(Player.PlayerData.items, itemName, slot)

    if before < 1 or after > 0 or purged < 1 then
        -- 2) Új tábla építése a megmaradt itemekből (kizárva a halat)
        local rebuilt = {}
        for key, invItem in pairs(Player.PlayerData.items or {}) do
            if invItem and not (sameName(invItem.name, itemName) and (slot == nil or tonumber(invItem.slot) == slot or tonumber(key) == slot)) then
                local slotKey = tonumber(invItem.slot) or tonumber(key) or key
                rebuilt[slotKey] = invItem
                rebuilt[slotKey].slot = slotKey
            end
        end
        applyItems(Player, rebuilt)
        after = countFish(Player.PlayerData.items, itemName, slot)
    else
        applyItems(Player, Player.PlayerData.items)
    end

    if countFish(Player.PlayerData.items, itemName, slot) > 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Nem sikerült elvenni a halat az inventoryból.', 'error')
        print(('[wellgame_fishing] SELL REMOVE FAILED src=%s item=%s slot=%s before=%s after=%s'):format(
            tostring(src), tostring(itemName), tostring(slot), tostring(before), tostring(after)
        ))
        return
    end

    -- qb-inventory export is (ha él), de a fenti purge a forrás
    pcall(function()
        exports['qb-inventory']:RemoveItem(src, itemName, 1, slot or false, 'wellgame_fishing:sell')
    end)

    Player.Functions.AddMoney('cash', price, 'fish-sell')

    -- Kliens sync: QBCore items + inventory NUI
    TriggerClientEvent('wellgame_fishing:client:forceInvItems', src, Player.PlayerData.items)
    TriggerClientEvent('qb-inventory:client:updateInventory', src)
    pcall(function()
        exports['qb-inventory']:SaveInventory(src)
    end)

    local itemInfo = QBCore.Shared.Items[itemName]
    if itemInfo then
        TriggerClientEvent('qb-inventory:client:ItemBox', src, itemInfo, 'remove', 1)
    end

    local priceText = formatMoney(price)
    TriggerClientEvent('QBCore:Notify', src, ('Eladtad a %s — %s$'):format(ft.nameEx, priceText), 'success')
    TriggerClientEvent('wellgame_fishing:client:sellChat', src, ft.nameEx, priceText)
    TriggerClientEvent('wellgame_fishing:client:sellStandPreview', src, weight)
end)
