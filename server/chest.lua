local QBCore = exports['qb-core']:GetCoreObject()

local function rollChest()
    local rewards = Config.ChestRewards or {}
    local total = 0
    for i = 1, #rewards do
        total = total + rewards[i].weight
    end
    if total <= 0 then return nil end
    local roll = math.random(1, total)
    local cur = 0
    for i = 1, #rewards do
        cur = cur + rewards[i].weight
        if roll <= cur then return rewards[i] end
    end
    return rewards[1]
end

local function openChest(src, slot)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local item = exports['qb-inventory']:GetItemBySlot(src, slot)
    if not item or item.name ~= Config.ChestItem then return end
    if not exports['qb-inventory']:RemoveItem(src, Config.ChestItem, 1, slot) then return end
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.ChestItem], 'remove')

    local reward = rollChest()
    if not reward then
        exports['qb-inventory']:AddItem(src, Config.ChestItem, 1)
        TriggerClientEvent('QBCore:Notify', src, 'A láda üres volt — visszakerült.', 'error')
        return
    end
    if reward.money then
        local money = math.floor(reward.money * (Config.EconomyScale or 1.0))
        Player.Functions.AddMoney('cash', money, 'fishing-chest')
        TriggerClientEvent('QBCore:Notify', src, ('A ládából %s$ került elő.'):format(money), 'success')
    elseif reward.item then
        local amount = reward.amount or 1
        if exports['qb-inventory']:AddItem(src, reward.item, amount) then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[reward.item], 'add')
            local label = QBCore.Shared.Items[reward.item] and QBCore.Shared.Items[reward.item].label or reward.item
            TriggerClientEvent('QBCore:Notify', src, ('A ládából %sx %s került elő.'):format(amount, label), 'success')
        else
            exports['qb-inventory']:AddItem(src, Config.ChestItem, 1)
            TriggerClientEvent('QBCore:Notify', src, 'Nincs hely — a láda visszakerült.', 'error')
        end
    end
end

RegisterNetEvent('wellgame_fishing:server:openChest', function(slot)
    openChest(source, tonumber(slot))
end)
