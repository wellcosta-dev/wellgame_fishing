-- Nearby fishing sync: bobber + remote rod + shared tip offset

local remoteFishers = {}
local pending = nil

local function tipOff()
    return Config.RodTipOffset or vector3(0.0, 0.0, 2.9)
end

local function getTipFromRod(rod, ped)
    if rod and DoesEntityExist(rod) then
        local off = tipOff()
        local tip = GetOffsetFromEntityInWorldCoords(rod, off.x, off.y, off.z)
        if tip and tip.x then return tip.x, tip.y, tip.z end
    end
    if ped and DoesEntityExist(ped) then
        local bone = GetPedBoneIndex(ped, 18905)
        local hand = GetWorldPositionOfEntityBone(ped, bone)
        local forward = GetEntityForwardVector(ped)
        local tip = hand + forward * 2.5 + vector3(0.0, 0.0, 1.2)
        return tip.x, tip.y, tip.z
    end
    return 0.0, 0.0, 0.0
end

local function drawMultiLine(rx, ry, rz, floatX, floatY, floatZ, lineColor)
    local dist = #(vector3(rx, ry, rz) - vector3(floatX, floatY, floatZ))
    if dist < 0.05 or dist > 200.0 then return end
    local r, g, b = 173, 176, 151
    if lineColor and lineColor[1] then r, g, b = lineColor[1], lineColor[2], lineColor[3] end
    local segs = math.max(10, math.min(40, math.ceil(dist / 2.5)))
    local prevX, prevY, prevZ = rx, ry, rz
    for i = 1, segs do
        local t = i / segs
        local x = rx + (floatX - rx) * t
        local y = ry + (floatY - ry) * t
        local z = rz + (floatZ - rz) * t - 0.8 * 4.0 * t * (1.0 - t)
        DrawLine(prevX, prevY, prevZ, x, y, z, r, g, b, 150)
        prevX, prevY, prevZ = x, y, z
    end
end

local function ensureRemoteRod(r, ped)
    if r.rod and DoesEntityExist(r.rod) then
        if not IsEntityAttachedToEntity(r.rod, ped) then
            local a = Config.RodAttach or {}
            AttachEntityToEntity(r.rod, ped, GetPedBoneIndex(ped, a.bone or 18905),
                (a.pos and a.pos.x) or 0.1, (a.pos and a.pos.y) or 0.05, (a.pos and a.pos.z) or 0.0,
                (a.rot and a.rot.x) or 80.0, (a.rot and a.rot.y) or 120.0, (a.rot and a.rot.z) or 160.0,
                true, true, false, true, 1, true)
        end
        return
    end
    local model = Config.RodProp or `prop_fishing_rod_01`
    RequestModel(model)
    local t = GetGameTimer() + 1500
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(0) end
    if not HasModelLoaded(model) then return end
    local c = GetEntityCoords(ped)
    r.rod = CreateObject(model, c.x, c.y, c.z, false, false, false)
    SetEntityCollision(r.rod, false, false)
    local a = Config.RodAttach or {}
    AttachEntityToEntity(r.rod, ped, GetPedBoneIndex(ped, a.bone or 18905),
        (a.pos and a.pos.x) or 0.1, (a.pos and a.pos.y) or 0.05, (a.pos and a.pos.z) or 0.0,
        (a.rot and a.rot.x) or 80.0, (a.rot and a.rot.y) or 120.0, (a.rot and a.rot.z) or 160.0,
        true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(model)
end

local function clearRemote(sid)
    local r = remoteFishers[sid]
    if r then
        if r.bobber and DoesEntityExist(r.bobber) then DeleteObject(r.bobber) end
        if r.rod and DoesEntityExist(r.rod) then
            DetachEntity(r.rod, true, true)
            DeleteObject(r.rod)
        end
    end
    remoteFishers[sid] = nil
end

AddEventHandler('wellgame_fishing:client:localSyncClear', function()
    pending = nil
    TriggerServerEvent('wellgame_fishing:server:syncState', { mode = 'idle', floatPos = nil })
end)

AddEventHandler('wellgame_fishing:client:localSyncPush', function(payload)
    pending = payload
end)

CreateThread(function()
    while true do
        Wait(Config.SyncIntervalMs or 250)
        if pending then
            TriggerServerEvent('wellgame_fishing:server:syncState', pending)
            pending = nil
        end
    end
end)

RegisterNetEvent('wellgame_fishing:client:remoteSync', function(serverId, payload)
    local myId = GetPlayerServerId(PlayerId())
    if serverId == myId then return end

    if not payload or not payload.mode or payload.mode == 'idle' then
        clearRemote(serverId)
        return
    end

    local ped = GetPlayerPed(GetPlayerFromServerId(serverId))
    if ped == 0 or not DoesEntityExist(ped) then
        clearRemote(serverId)
        return
    end

    local myCoords = GetEntityCoords(PlayerPedId())
    local theirCoords = GetEntityCoords(ped)
    if #(myCoords - theirCoords) > (Config.SyncRange or 80.0) then
        clearRemote(serverId)
        return
    end

    local r = remoteFishers[serverId] or {}
    r.mode = payload.mode
    r.lineLength = payload.lineLength
    r.line = payload.line
    r.target = payload.floatPos
    ensureRemoteRod(r, ped)
    remoteFishers[serverId] = r

    if payload.floatPos and payload.floatPos[1] then
        local x, y, z = payload.floatPos[1], payload.floatPos[2], payload.floatPos[3]
        if not r.bobber or not DoesEntityExist(r.bobber) then
            local model = Config.BobberProp or `prop_golf_ball`
            RequestModel(model)
            local t = GetGameTimer() + 1500
            while not HasModelLoaded(model) and GetGameTimer() < t do Wait(0) end
            if HasModelLoaded(model) then
                r.bobber = CreateObject(model, x, y, z, false, false, false)
                SetEntityCollision(r.bobber, false, false)
                FreezeEntityPosition(r.bobber, true)
                SetModelAsNoLongerNeeded(model)
            end
        end
        if r.bobber and DoesEntityExist(r.bobber) then
            local cur = GetEntityCoords(r.bobber)
            local nx = cur.x + (x - cur.x) * 0.35
            local ny = cur.y + (y - cur.y) * 0.35
            local nz = cur.z + (z - cur.z) * 0.35
            SetEntityCoordsNoOffset(r.bobber, nx, ny, nz, false, false, false)
            local tipX, tipY, tipZ = getTipFromRod(r.rod, ped)
            drawMultiLine(tipX, tipY, tipZ, nx, ny, nz, payload.line)
        end
        remoteFishers[serverId] = r
    end
end)

CreateThread(function()
    while true do
        local sleep = 500
        for sid, r in pairs(remoteFishers) do
            if r.bobber and DoesEntityExist(r.bobber) and r.target then
                sleep = 0
                local ped = GetPlayerPed(GetPlayerFromServerId(sid))
                if ped ~= 0 then
                    ensureRemoteRod(r, ped)
                    local cur = GetEntityCoords(r.bobber)
                    local x = cur.x + (r.target[1] - cur.x) * 0.15
                    local y = cur.y + (r.target[2] - cur.y) * 0.15
                    local z = cur.z + (r.target[3] - cur.z) * 0.15
                    SetEntityCoordsNoOffset(r.bobber, x, y, z, false, false, false)
                    local tipX, tipY, tipZ = getTipFromRod(r.rod, ped)
                    drawMultiLine(tipX, tipY, tipZ, x, y, z, r.line)
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for sid in pairs(remoteFishers) do clearRemote(sid) end
end)
