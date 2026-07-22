-- Sell stand fish preview + tournament board NUI

local QBCore = exports['qb-core']:GetCoreObject()
local standFish = nil
local standActive = false

local function deleteStandFish()
    if standFish and DoesEntityExist(standFish) then
        DeleteObject(standFish)
    end
    standFish = nil
end

local function nearestDropoff(coords)
    local best, bestD = nil, 9999.0
    for i = 1, #Config.Dropoffs do
        local c = Config.Dropoffs[i].coords
        local d = #(coords - vector3(c.x, c.y, c.z))
        if d < bestD then
            bestD = d
            best = Config.Dropoffs[i]
        end
    end
    return best, bestD
end

RegisterNetEvent('wellgame_fishing:client:sellStandPreview', function(weight)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local drop, dist = nearestDropoff(coords)
    if not drop or dist > (Config.DropoffRadius or 3.5) + 2.0 then return end

    deleteStandFish()
    local c = drop.coords
    local model = Config.FishPreviewProp or `prop_cs_steak`
    RequestModel(model)
    local t = GetGameTimer() + 2000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(0) end
    if not HasModelLoaded(model) then return end

    standFish = CreateObject(model, c.x, c.y, c.z + 0.95, false, false, false)
    FreezeEntityPosition(standFish, true)
    SetEntityCollision(standFish, false, false)
    SetModelAsNoLongerNeeded(model)
    standActive = true

    SendNUIMessage({ action = 'playSound', file = 'fishweight.wav', volume = 0.55 })

    CreateThread(function()
        Wait(3500)
        deleteStandFish()
        standActive = false
    end)
end)

-- Csendes élő frissítés (minden fogás után) — nincs chat spam, csak a világtérbeli
-- tábla (client/main.lua) és a már nyitva lévő NUI overlay adatai frissülnek.
local lastTournamentActive = false
local lastTournamentTop = {}
RegisterNetEvent('wellgame_fishing:client:tournamentBoard', function(payload)
    if type(payload) ~= 'table' then return end
    lastTournamentActive = payload.active == true
    lastTournamentTop = payload.top or {}
    SendNUIMessage({ action = 'tournamentBoard', data = lastTournamentTop })
end)
exports('GetTournamentTop', function() return lastTournamentTop end)
exports('IsTournamentActive', function() return lastTournamentActive end)

CreateThread(function()
    Wait(1000) -- kis késleltetés, hogy a szerver session/QBCore biztosan készen álljon
    TriggerServerEvent('wellgame_fishing:server:requestTournamentState')
end)

-- Explicit lekérdezés (/fishtournament board, start, stop) — chat log + NUI overlay felugrik.
RegisterNetEvent('wellgame_fishing:client:tournamentBoardShow', function(payload)
    if type(payload) ~= 'table' then return end
    lastTournamentActive = payload.active == true
    local top = payload.top or {}
    lastTournamentTop = top
    local lines = { '=== Horgászverseny Top ===' }
    for i = 1, #top do
        local r = top[i]
        lines[#lines + 1] = ('%d. %s — %.1f kg (%s)'):format(i, r.name or '?', r.weight or 0, r.fish or '?')
    end
    if #top == 0 then lines[#lines + 1] = 'Még nincs eredmény.' end
    TriggerEvent('chat:addMessage', {
        color = { 6, 182, 212 },
        multiline = true,
        args = { 'Wellcosta - Horgászat', table.concat(lines, '\n') },
    })
    SendNUIMessage({ action = 'tournamentBoard', data = top })
    SendNUIMessage({ action = 'tournamentBoardShow' })
end)

-- Self-rank (v4: sendFishingTournamentRanking) — csak akkor jön, ha a játékos a topN-en kívül van.
RegisterNetEvent('wellgame_fishing:client:tournamentSelfRank', function(payload)
    if type(payload) ~= 'table' or not payload.rank then return end
    QBCore.Functions.Notify(
        ('Horgászverseny: a(z) %d. helyen állsz (%.1f kg összesen).'):format(payload.rank, payload.weight or 0),
        'primary', 5000
    )
end)

-- Győzelmi ünneplés a verseny lezárásakor (v4: gotFishingEventWin — a v4-ben sosem lett triggerelve,
-- itt a szerver ténylegesen meghívja, amikor a verseny véget ér).
RegisterNetEvent('wellgame_fishing:client:tournamentWin', function(payload)
    if type(payload) ~= 'table' then return end
    SendNUIMessage({ action = 'tournamentWin', data = payload })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    deleteStandFish()
end)
