local QBCore = exports['qb-core']:GetCoreObject()
local sellOpen = false
local sellSlot = nil
local sellPhase = nil -- 'confirm' | 'fadein' | 'game' | 'fadeout' | nil
local sellMin = 0
local sellMax = 0

-- v4 SPACE minigame (client-driven)
local sellGameP = 0.0
local sellGameSpeed = 1.0
local sellHolding = false
local sellDidHold = false
local sellGraph = {}
local sellFadeA = 0.0 -- 0..1 bar visibility/interactivity ramp (v4: fishSellA, 1s in/out)

local function closeSellUi()
    sellOpen = false
    sellPhase = nil
    sellSlot = nil
    sellHolding = false
    sellDidHold = false
    sellFadeA = 0.0
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeSell' })
    if GetResourceState('wellgame_controls') == 'started' then
        exports['wellgame_controls']:toggleAllControls(true, 'wellgame_fishing_sell')
    end
end

local function buildSellGraph()
    sellGraph = {}
    for i = 0, 1, 0.1 do
        sellGraph[#sellGraph + 1] = {
            math.min(1, i + 0.025 * math.random()),
            math.min(1, math.max(0, i + (math.random() * 2 - 1) * 0.025)),
        }
    end
    sellGraph[#sellGraph + 1] = { 1, 1 }
end

local function sampleSellGraph(rawP)
    for i = 1, #sellGraph do
        if rawP <= sellGraph[i][1] then
            local lastP = sellGraph[i - 1] and sellGraph[i - 1][1] or 0
            local lastS = sellGraph[i - 1] and sellGraph[i - 1][2] or 0
            local span = sellGraph[i][1] - lastP
            if span <= 0 then return sellGraph[i][2] end
            return ((rawP - lastP) / span) * (sellGraph[i][2] - lastS) + lastS
        end
    end
    return 1.0
end

local function easeInOutQuad(t)
    if t < 0.5 then return 2 * t * t end
    return 1 - ((-2 * t + 2) ^ 2) / 2
end

local function sellQuality()
    local warped = easeInOutQuad(sampleSellGraph(sellGameP))
    return 1 - math.abs(warped - 0.5) * 2, warped
end

local sellFinalQuality = 0.0

--- Freezes the result and starts the ~1s fade-out (v4: fishSellA ramping back to 0
--- before completeFishSelling actually fires) instead of finalizing instantly.
local function beginSellFadeOut()
    if sellPhase ~= 'game' or not sellSlot then
        closeSellUi()
        return
    end
    local quality = select(1, sellQuality())
    -- ha sosem tartotta a SPACE-t, középre eső default helyett gyenge ár (vagy megszakítás)
    if not sellDidHold then
        quality = 0.0
    end
    sellFinalQuality = quality
    sellPhase = 'fadeout'
end

local function finishSellGame()
    local slot = sellSlot
    local quality = sellFinalQuality
    closeSellUi()
    if slot then
        TriggerServerEvent('wellgame_fishing:server:sellFish', slot, quality)
    end
end

RegisterNetEvent('wellgame_fishing:client:trySell', function(slot, itemName)
    if sellOpen then return end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local near = false
    for i = 1, #Config.Dropoffs do
        local d = Config.Dropoffs[i].coords
        if #(coords - vector3(d.x, d.y, d.z)) <= (Config.DropoffRadius or 3.5) + 1.5 then
            near = true
            break
        end
    end
    if not near then
        QBCore.Functions.Notify('A hal eladásához menj a felvásárlóhoz.', 'primary')
        return
    end

    local key, ft = GetFishTypeByItem(itemName)
    if not ft or not ft.price then return end

    local items = QBCore.Functions.GetPlayerData().items or {}
    local item = nil
    for _, it in pairs(items) do
        if it and (it.slot == slot) then item = it break end
    end
    local weight = tonumber(item and item.info and item.info.weight) or RandomFishWeight(key)
    local length = tonumber(item and item.info and item.info.length) or CalculateFishLength(key, weight)
    local from = math.floor(ft.price * weight * 0.7 * (Config.EconomyScale or 1.0))
    local to = math.floor(ft.price * weight * 1.0 * (Config.EconomyScale or 1.0))

    sellOpen = true
    sellPhase = 'confirm'
    sellSlot = slot
    sellMin = from
    sellMax = to
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openSellConfirm',
        data = {
            name = ft.name,
            weight = weight,
            length = length,
            minPrice = from,
            maxPrice = to,
        },
    })
end)

RegisterNUICallback('sellStartGame', function(_, cb)
    cb('ok')
    if not sellOpen or sellPhase ~= 'confirm' or not sellSlot then return end

    sellPhase = 'fadein'
    sellFadeA = 0.0001
    sellGameP = 0.0
    sellHolding = false
    sellDidHold = false
    -- Középutas tempó: v4 alapja (~1.0) túl gyors volt, az első lassítás (~0.4) túl lassú lett
    sellGameSpeed = 0.65 + (math.random() * 2 - 1) * 0.12
    buildSellGraph()

    SetNuiFocus(false, false) -- SPACE a játékból jön (IsDisabledControl)
    if GetResourceState('wellgame_controls') == 'started' then
        exports['wellgame_controls']:toggleAllControls(false, 'wellgame_fishing_sell')
    end

    QBCore.Functions.Notify('Tartsd lenyomva a SPACE-t, majd engedd fel a megfelelő árnál.', 'primary', 5500)
    SendNUIMessage({
        action = 'startSellGame',
        data = {
            minPrice = sellMin,
            maxPrice = sellMax,
        },
    })
end)

RegisterNUICallback('sellCancel', function(_, cb)
    closeSellUi()
    cb('ok')
end)

-- Minigame loop: SPACE (22) hold/release — v4, plusz ~1s fade-in/fade-out (fishSellA)
CreateThread(function()
    local last = GetGameTimer()
    while true do
        if sellPhase == 'fadein' or sellPhase == 'game' or sellPhase == 'fadeout' then
            local now = GetGameTimer()
            local dt = math.min(0.05, (now - last) / 1000.0)
            last = now

            DisableControlAction(0, 22, true) -- SPACE / jump
            DisableControlAction(0, 200, true) -- pause

            if sellPhase == 'fadein' then
                sellFadeA = math.min(1.0, sellFadeA + dt)
                local quality, warped = sellQuality()
                SendNUIMessage({
                    action = 'updateSellGame',
                    data = { progress = warped, quality = quality, minPrice = sellMin, maxPrice = sellMax, alpha = sellFadeA },
                })
                if sellFadeA >= 1.0 then
                    sellPhase = 'game'
                end
            elseif sellPhase == 'game' then
                local space = IsDisabledControlPressed(0, 22) or IsControlPressed(0, 22)
                if space then
                    if not sellHolding then
                        sellHolding = true
                        sellDidHold = true
                    end
                    sellGameP = math.min(1.0, sellGameP + dt * sellGameSpeed)
                    local quality, warped = sellQuality()
                    SendNUIMessage({
                        action = 'updateSellGame',
                        data = { progress = warped, quality = quality, minPrice = sellMin, maxPrice = sellMax, alpha = 1.0 },
                    })
                    if sellGameP >= 1.0 then
                        beginSellFadeOut()
                    end
                else
                    if sellHolding then
                        -- felengedte a SPACE-t → fade-out, majd lezárás
                        beginSellFadeOut()
                    end
                end
            elseif sellPhase == 'fadeout' then
                sellFadeA = math.max(0.0, sellFadeA - dt)
                local quality, warped = sellQuality()
                SendNUIMessage({
                    action = 'updateSellGame',
                    data = { progress = warped, quality = quality, minPrice = sellMin, maxPrice = sellMax, alpha = sellFadeA },
                })
                if sellFadeA <= 0.0 then
                    finishSellGame()
                end
            end
            Wait(0)
        else
            last = GetGameTimer()
            Wait(200)
        end
    end
end)

RegisterNetEvent('wellgame_fishing:client:sellChat', function(fishName, priceText)
    TriggerEvent('chat:addMessage', {
        template = '<div style="padding:2px 0;"><span style="color:#319ad7;">[Wellcosta - Horgászat]:</span> <span style="color:#ffffff;">Sikeresen eladtál egy {0}.</span></div>',
        args = { tostring(fishName or 'halat') },
    })
    TriggerEvent('chat:addMessage', {
        template = '<div style="padding:2px 0;"><span style="color:#ffffff;">Ezért kaptál </span><span style="color:#3cb882;">{0} $-t</span><span style="color:#ffffff;">.</span></div>',
        args = { tostring(priceText or '0') },
    })
end)
