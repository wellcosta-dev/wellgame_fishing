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

RegisterNetEvent('wellgame_fishing:server:sellFish', function(slot, slider)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    slider = tonumber(slider) or 0.5
    slider = math.max(0.0, math.min(1.0, slider))

    if FishingSellCooldownOk and not FishingSellCooldownOk(src) then return end

    local item = Player.Functions.GetItemBySlot(slot)
    if not item then return end
    local key, ft = GetFishTypeByItem(item.name)
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

    local weight = tonumber(item.info and item.info.weight) or RandomFishWeight(key)
    local scale = Config.EconomyScale or 1.0
    local from = math.floor(ft.price * weight * 0.7 * scale)
    local to = math.floor(ft.price * weight * 1.0 * scale)
    local price = math.floor(from + (to - from) * slider)
    if price < 1 then price = 1 end

    if Player.Functions.RemoveItem(item.name, 1, slot) then
        Player.Functions.AddMoney('cash', price, 'fish-sell')
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item.name], 'remove')
        local priceText = formatMoney(price)
        TriggerClientEvent('QBCore:Notify', src, ('Eladtad a %s — %s$'):format(ft.nameEx, priceText), 'success')
        TriggerClientEvent('wellgame_fishing:client:sellChat', src, ft.nameEx, priceText)
        TriggerClientEvent('wellgame_fishing:client:sellStandPreview', src, weight)
    end
end)
