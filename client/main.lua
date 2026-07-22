local QBCore = exports['qb-core']:GetCoreObject()

local npcTags = {}

-- Dropoff blips + peds
CreateThread(function()
    for i = 1, #Config.Dropoffs do
        local d = Config.Dropoffs[i]
        local c = d.coords
        local blip = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(blip, 68)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.75)
        SetBlipColour(blip, 3)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(d.label or 'Horgászbolt')
        EndTextCommandSetBlipName(blip)

        local model = `a_m_m_farmer_01`
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(10) end
        local ped = CreatePed(0, model, c.x, c.y, c.z - 1.0, c.w, false, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        SetModelAsNoLongerNeeded(model)

        if d.npcName then
            npcTags[#npcTags + 1] = {
                ped = ped,
                name = d.npcName,
                role = d.npcRole or 'Hal felvásárló',
            }
        end
    end
end)

-- Felvásárló NPC névtábla (wellgame-nametag stílushoz igazítva)
CreateThread(function()
    local maxD = Config.NpcTagDistance or 20.0
    local fadeStart = Config.NpcTagFadeStart or 0.6

    while true do
        local camCoords = GetFinalRenderedCamCoord()
        local tags = {}

        for i = 1, #npcTags do
            local t = npcTags[i]
            if DoesEntityExist(t.ped) then
                local headCoords = GetPedBoneCoords(t.ped, 31086, 0.0, 0.0, 0.0)
                local tagZ = headCoords.z + 0.42
                local dist = #(camCoords - vector3(headCoords.x, headCoords.y, tagZ))

                if dist <= maxD then
                    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(headCoords.x, headCoords.y, tagZ)
                    if onScreen then
                        local p = dist / maxD
                        local scale = math.max(0.35, 1.0 - p * 0.7)
                        local alpha = 1.0
                        if p > fadeStart then
                            alpha = math.max(0.0, 1.0 - (p - fadeStart) / (1.0 - fadeStart))
                        end
                        if alpha > 0.02 then
                            tags[#tags + 1] = {
                                id = i,
                                name = t.name,
                                role = t.role or 'Hal felvásárló',
                                x = sx,
                                y = sy,
                                scale = scale,
                                alpha = alpha,
                            }
                        end
                    end
                end
            end
        end

        SendNUIMessage({ action = 'updateNpcTags', tags = tags })
        Wait(#tags > 0 and 0 or 400)
    end
end)

-- Horgászverseny élő tábla a felvásárlóknál (v4: in-world tournament monitor screens —
-- itt egy világtér-vetített NUI panel adja vissza ugyanezt a funkciót DUI/render-target nélkül)
CreateThread(function()
    local maxD = (Config.Tournament and Config.Tournament.liveBoardDistance) or 15.0
    local n = (Config.Tournament and Config.Tournament.liveBoardN) or 5
    local wasShowing = false
    local resName = GetCurrentResourceName()

    while true do
        local sleep = 1000
        local showing = false
        local active = exports[resName]:IsTournamentActive()

        if active then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local nearest, nearestD = nil, 9999.0
            for i = 1, #Config.Dropoffs do
                local c = Config.Dropoffs[i].coords
                local d = #(coords - vector3(c.x, c.y, c.z))
                if d < nearestD then
                    nearestD = d
                    nearest = Config.Dropoffs[i]
                end
            end

            if nearest and nearestD <= maxD then
                local c = nearest.coords
                local onScreen, sx, sy = GetScreenCoordFromWorldCoord(c.x, c.y, c.z + 2.6)
                if onScreen then
                    sleep = 0
                    showing = true
                    local top = exports[resName]:GetTournamentTop()
                    local rows = {}
                    for i = 1, math.min(n, #top) do
                        rows[i] = { rank = i, name = top[i].name, weight = top[i].weight }
                    end
                    local alpha = math.max(0.0, 1.0 - (nearestD / maxD))
                    SendNUIMessage({
                        action = 'updateTournamentLive',
                        data = { x = sx, y = sy, alpha = alpha, rows = rows },
                    })
                end
            end
        end

        if not showing and wasShowing then
            SendNUIMessage({ action = 'updateTournamentLive', data = nil })
        end
        wasShowing = showing
        Wait(sleep)
    end
end)

-- Optional baitshop props moved to client/baitshop.lua

-- Közelség: értesítés + DrawText a felvásárlónál
CreateThread(function()
    local shown = false
    local notified = false
    local radius = (Config.DropoffRadius or 3.5) + 1.5
    local hint = '[I] Inventory → használd a halat az eladáshoz'

    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local near = false
        local label = 'Horgászbolt'

        for i = 1, #Config.Dropoffs do
            local d = Config.Dropoffs[i]
            local c = d.coords
            if #(coords - vector3(c.x, c.y, c.z)) <= radius then
                near = true
                label = d.label or label
                break
            end
        end

        if near then
            sleep = 0
            if not shown then
                shown = true
                exports['qb-core']:DrawText(hint, 'left')
            end
            if not notified then
                notified = true
                QBCore.Functions.Notify(
                    ('%s — Hal eladásához nyisd az inventoryt (I), és használd a halat.'):format(label),
                    'primary',
                    5500
                )
            end
        else
            if shown then
                shown = false
                exports['qb-core']:HideText()
            end
            notified = false
        end

        Wait(sleep)
    end
end)

RegisterCommand('fishinghelp', function()
    QBCore.Functions.Notify('1) Damil + úszó felszerelése a botra (használd az itemeket)', 'primary')
    Wait(50)
    QBCore.Functions.Notify('2) Bot használata → RMB cél, LMB tölt/dob (ballisztikus úszó)', 'primary')
    Wait(50)
    QBCore.Functions.Notify('3) Kapáskor görgő le = horog / behúzás · Shift/Ctrl fokozat', 'primary')
end, false)

-- Hide fishing NUI while dashboard (or other fullscreen hubs) is open
AddEventHandler('wellgame_dashboard:setHudHidden', function(hidden)
    if hidden then
        SendNUIMessage({ action = 'hideHud' })
        SendNUIMessage({ action = 'gotFish', state = false })
    end
end)
