local QBCore = exports['qb-core']:GetCoreObject()

local fishingChestRewards = {
    { weight = 8, money = 150 },
    { weight = 6, money = 200 },
    { weight = 4, money = 350 },
    { weight = 3, money = 500 },
    { weight = 2, money = 750 },
    { weight = 1, money = 1200 },
    { weight = 12, item = 'fishing_bait', amount = 2 },
    { weight = 8, item = 'fishing_bait', amount = 4 },
    { weight = 6, item = 'fishing_line_1', amount = 1 },
    { weight = 5, item = 'fishing_line_3', amount = 1 },
    { weight = 4, item = 'fishing_line_4', amount = 1 },
    { weight = 3, item = 'fishing_line_6', amount = 1 },
    { weight = 2, item = 'fishing_line_7', amount = 1 },
    { weight = 5, item = 'fishing_float_1', amount = 1 },
    { weight = 4, item = 'fishing_float_2', amount = 1 },
    { weight = 3, item = 'fishing_float_3', amount = 1 },
    { weight = 2, item = 'fishing_float_4', amount = 1 },
    { weight = 4, item = 'fishing_goldchain', amount = 1 },
    { weight = 2, item = 'fishing_rod_2', amount = 1 },
    { weight = 1, item = 'fishing_rod_3', amount = 1 },
    { weight = 3, item = 'fishing_seerod_5000', amount = 1 },
    { weight = 2, item = 'fishing_seerod_6000', amount = 1 },
}

local function rollChest()
    local total = 0
    for i = 1, #fishingChestRewards do
        total = total + fishingChestRewards[i].weight
    end
    local roll = math.random(1, total)
    local cur = 0
    for i = 1, #fishingChestRewards do
        cur = cur + fishingChestRewards[i].weight
        if roll <= cur then return fishingChestRewards[i] end
    end
    return fishingChestRewards[1]
end

local function openChest(src, slot)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local item = Player.Functions.GetItemBySlot(slot)
    if not item or item.name ~= Config.ChestItem then return end
    if not Player.Functions.RemoveItem(Config.ChestItem, 1, slot) then return end
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.ChestItem], 'remove')

    local reward = rollChest()
    if reward.money then
        local money = math.floor(reward.money * (Config.EconomyScale or 1.0))
        Player.Functions.AddMoney('cash', money, 'fishing-chest')
        TriggerClientEvent('QBCore:Notify', src, ('A ládából %s$ került elő.'):format(money), 'success')
    elseif reward.item then
        local amount = reward.amount or 1
        if Player.Functions.AddItem(reward.item, amount, false, {}) then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[reward.item], 'add')
            local label = QBCore.Shared.Items[reward.item] and QBCore.Shared.Items[reward.item].label or reward.item
            TriggerClientEvent('QBCore:Notify', src, ('A ládából %sx %s került elő.'):format(amount, label), 'success')
        else
            Player.Functions.AddItem(Config.ChestItem, 1)
            TriggerClientEvent('QBCore:Notify', src, 'Nincs hely — a láda visszakerült.', 'error')
        end
    end
end

RegisterNetEvent('wellgame_fishing:server:openChest', function(slot)
    openChest(source, tonumber(slot))
end)
