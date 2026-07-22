-- Server-side MP sync broadcast

local lastBroadcast = {} -- [src] = ms via os.clock

AddEventHandler('wellgame_fishing:server:broadcastSync', function(src, data)
    local now = os.clock() * 1000
    if data ~= nil and lastBroadcast[src] and (now - lastBroadcast[src]) < ((Config.SyncIntervalMs or 250) * 0.5) then
        return
    end
    lastBroadcast[src] = now

    local payload = nil
    if data then
        local lineRgb = data.lineColor
        if not lineRgb and data.line and Config.LineColors[data.line] then
            local c = Config.LineColors[data.line]
            lineRgb = { c[1], c[2], c[3] }
        end
        payload = {
            mode = data.mode,
            floatPos = data.floatPos,
            lineLength = data.lineLength,
            spindleGear = data.spindleGear,
            fish = data.syncFish or data.fish,
            line = lineRgb,
            throwForce = data.throwForce,
        }
    end

    local ped = GetPlayerPed(src)
    local coords = nil
    if ped ~= 0 then
        coords = GetEntityCoords(ped)
    end
    local range = Config.SyncRange or 80.0

    for _, playerId in ipairs(GetPlayers()) do
        local tid = tonumber(playerId)
        if tid and tid ~= src then
            if not coords then
                TriggerClientEvent('wellgame_fishing:client:remoteSync', tid, src, nil)
            else
                local tped = GetPlayerPed(tid)
                if tped ~= 0 then
                    local tc = GetEntityCoords(tped)
                    if #(coords - tc) <= range then
                        TriggerClientEvent('wellgame_fishing:client:remoteSync', tid, src, payload)
                    end
                end
            end
        end
    end
end)

RegisterNetEvent('wellgame_fishing:server:standState', function(payload)
    local src = source
    if type(payload) ~= 'table' then return end
    for _, playerId in ipairs(GetPlayers()) do
        local tid = tonumber(playerId)
        if tid and tid ~= src then
            TriggerClientEvent('wellgame_fishing:client:remoteStand', tid, payload)
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastBroadcast[src] = nil
    TriggerEvent('wellgame_fishing:server:broadcastSync', src, nil)
end)
