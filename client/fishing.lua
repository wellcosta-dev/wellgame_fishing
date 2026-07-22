local QBCore = exports['qb-core']:GetCoreObject()

local function Audio()
    local ok, api = pcall(function()
        return exports[GetCurrentResourceName()]:GetAudio()
    end)
    if ok then return api end
    return nil
end

local function playSound(file, vol)
    local a = Audio()
    if a then a.OneShot(file, vol) else
        SendNUIMessage({ action = 'playSound', file = file, volume = vol or 0.5 })
    end
end

-- ---------------------------------------------------------------------------
-- Helpers inlined (lua54: no shared globals across client files)
-- ---------------------------------------------------------------------------
local WGAnim = {}
local WGFloat = {}
local WGLine = {}

local function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end

function WGAnim.Play(dict, clip, progress)
    dict = dict or (Config.FishAnims and Config.FishAnims.dict)
    clip = clip or (Config.FishAnims and Config.FishAnims.idle)
    if not dict or not clip then return false end
    if not loadAnimDict(dict) then return false end
    local ped = PlayerPedId()
    local restarted = false
    if not IsEntityPlayingAnim(ped, dict, clip, 3) then
        TaskPlayAnim(ped, dict, clip, 2.0, 2.0, -1, 1, 0.0, false, false, false)
        restarted = true
    end
    if progress ~= nil then
        local p = math.max(0.0, math.min(0.99, progress))
        SetEntityAnimCurrentTime(ped, dict, clip, p)
        SetEntityAnimSpeed(ped, dict, clip, 0.0)
    else
        SetEntityAnimSpeed(ped, dict, clip, 1.0)
    end
    return restarted
end

--- Frozen pose. upperBody=true → csak törzs/kar (flag 17), lábak nem dőlnek.
function WGAnim.PlayFrozen(dict, clip, progress, upperBody)
    dict = dict or (Config.FishAnims and Config.FishAnims.dict)
    clip = clip or (Config.FishAnims and Config.FishAnims.idle)
    if not dict or not clip then return false end
    if not loadAnimDict(dict) then return false end
    local ped = PlayerPedId()
    local a = Config.FishAnims or {}
    if a.cast and a.cast ~= clip and IsEntityPlayingAnim(ped, dict, a.cast, 3) then
        StopAnimTask(ped, dict, a.cast, 0.0)
    end

    local wantUpper = upperBody == true
    local flag = wantUpper and 17 or 1 -- 17 = loop + upper body only
    local playing = IsEntityPlayingAnim(ped, dict, clip, 3)
    local restarted = false

    -- flag váltáskor újraindítás kell (full body ↔ upper body)
    if playing and WGAnim._frozenUpper ~= wantUpper then
        StopAnimTask(ped, dict, clip, 0.0)
        playing = false
    end

    if not playing then
        TaskPlayAnim(ped, dict, clip, 8.0, -8.0, -1, flag, 0.0, false, false, false)
        restarted = true
    end
    WGAnim._frozenUpper = wantUpper

    local fallback = a.waterPoseProgress or 0.99
    local p = math.max(0.0, math.min(0.99, progress or fallback))
    SetEntityAnimCurrentTime(ped, dict, clip, p)
    SetEntityAnimSpeed(ped, dict, clip, 0.0)
    return restarted
end

function WGAnim.ProgressFromTension(throwingTension)
    local phys = Config.Physics or {}
    local base = phys.animProgressBase or 0.15
    local mul = phys.animProgressMul or 0.825
    return (tonumber(throwingTension) or 0.0) * mul + base
end

--- Cast lean: tension 0 → waterPose, tension 1 → castLeanBackProgress (szűk sáv = törzs, nem orsó).
function WGAnim.ProgressFromCastLean(throwingTension)
    local a = Config.FishAnims or {}
    local forward = a.waterPoseProgress or 0.99
    local back = a.castLeanBackProgress or 0.86
    local t = math.max(0.0, math.min(1.0, tonumber(throwingTension) or 0.0))
    local p = forward + (back - forward) * t
    return math.max(0.0, math.min(0.99, p))
end

function WGAnim.Clear()
    local ped = PlayerPedId()
    local dict = Config.FishAnims and Config.FishAnims.dict
    ClearPedTasks(ped)
    WGAnim._frozenUpper = nil
    if dict and HasAnimDictLoaded(dict) then
        local a = Config.FishAnims
        if a.idle then StopAnimTask(ped, dict, a.idle, 1.0) end
        if a.cast then StopAnimTask(ped, dict, a.cast, 1.0) end
        if a.getout then StopAnimTask(ped, dict, a.getout, 1.0) end
    end
end

local bobberObj = nil

local function loadBobberModel(model)
    if not IsModelInCdimage(model) and not IsModelValid(model) then return false end
    RequestModel(model)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(0) end
    return HasModelLoaded(model)
end

function WGFloat.Delete()
    if bobberObj and DoesEntityExist(bobberObj) then
        FreezeEntityPosition(bobberObj, false)
        SetEntityCollision(bobberObj, false, false)
        SetEntityAsMissionEntity(bobberObj, true, true)
        DeleteObject(bobberObj)
        if DoesEntityExist(bobberObj) then
            DeleteEntity(bobberObj)
        end
    end
    bobberObj = nil
end

function WGFloat.Spawn(pos, floatIndex)
    WGFloat.Delete()
    local fid = tonumber(floatIndex) or 1
    local model = (Config.BobberPropsByFloat and Config.BobberPropsByFloat[fid]) or Config.BobberProp or `prop_golf_ball`
    if not loadBobberModel(model) then return nil end
    bobberObj = CreateObject(model, pos.x, pos.y, pos.z, false, false, false)
    SetEntityAsMissionEntity(bobberObj, true, true)
    SetEntityCollision(bobberObj, false, false)
    FreezeEntityPosition(bobberObj, true)
    SetEntityVisible(bobberObj, true, false)
    SetModelAsNoLongerNeeded(model)
    return bobberObj
end

function WGFloat.SetPos(x, y, z)
    if bobberObj and DoesEntityExist(bobberObj) then
        SetEntityCoordsNoOffset(bobberObj, x, y, z, false, false, false)
    end
end

function WGFloat.SetRot(rx, ry, rz)
    if bobberObj and DoesEntityExist(bobberObj) then
        SetEntityRotation(bobberObj, rx or 0.0, ry or 0.0, rz or 0.0, 2, true)
    end
end

local cachedTipOff = nil
local cachedTipModel = nil
local tipMarker = nil

local function deleteTipMarker()
    if tipMarker and DoesEntityExist(tipMarker) then
        DetachEntity(tipMarker, true, true)
        SetEntityAsMissionEntity(tipMarker, true, true)
        DeleteObject(tipMarker)
    end
    tipMarker = nil
end

local function resolveRodTipOffset(rod)
    local model = GetEntityModel(rod)
    if Config.RodTipOffset then
        return Config.RodTipOffset
    end
    if cachedTipOff and cachedTipModel == model then
        return cachedTipOff
    end
    local minD, maxD = GetModelDimensions(model)
    if minD and maxD then
        local sx = math.abs(maxD.x - minD.x)
        local sy = math.abs(maxD.y - minD.y)
        local sz = math.abs(maxD.z - minD.z)
        local ox = (minD.x + maxD.x) * 0.5
        local oy = (minD.y + maxD.y) * 0.5
        local oz = (minD.z + maxD.z) * 0.5
        if sz >= sy and sz >= sx then
            oz = maxD.z
        elseif sy >= sx then
            oy = maxD.y
        else
            ox = maxD.x
        end
        cachedTipModel = model
        cachedTipOff = vector3(ox, oy, oz)
        return cachedTipOff
    end
    cachedTipModel = model
    cachedTipOff = vector3(0.0, 0.0, 2.9)
    return cachedTipOff
end

function WGLine.AttachTipMarker(rod)
    deleteTipMarker()
    if not rod or not DoesEntityExist(rod) then return end
    local off = resolveRodTipOffset(rod)
    local model = `prop_golf_ball`
    RequestModel(model)
    local t = GetGameTimer() + 1500
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(0) end
    if not HasModelLoaded(model) then return end
    local c = GetEntityCoords(rod)
    tipMarker = CreateObject(model, c.x, c.y, c.z, false, false, false)
    SetEntityCollision(tipMarker, false, false)
    SetEntityVisible(tipMarker, false, false)
    SetEntityAlpha(tipMarker, 0, false)
    AttachEntityToEntity(tipMarker, rod, 0, off.x, off.y, off.z, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    SetModelAsNoLongerNeeded(model)
end

function WGLine.ClearTipMarker()
    deleteTipMarker()
end

function WGLine.GetRodTip(rod, ped)
    if tipMarker and DoesEntityExist(tipMarker) then
        local tip = GetEntityCoords(tipMarker)
        return tip.x, tip.y, tip.z
    end
    if rod and DoesEntityExist(rod) then
        local off = resolveRodTipOffset(rod)
        local tip = GetOffsetFromEntityInWorldCoords(rod, off.x, off.y, off.z)
        if tip and tip.x then
            return tip.x, tip.y, tip.z
        end
    end
    if ped and DoesEntityExist(ped) then
        local bone = GetPedBoneIndex(ped, 18905)
        local hand = GetWorldPositionOfEntityBone(ped, bone)
        local forward = GetEntityForwardVector(ped)
        local tip = hand + forward * 2.5 + vector3(0.0, 0.0, 1.2)
        return tip.x, tip.y, tip.z
    end
    return nil, nil, nil
end

--- Get tip from any rod entity (for MP sync)
function WGLine.GetTipFromRod(rod, ped)
    if rod and DoesEntityExist(rod) then
        local off = resolveRodTipOffset(rod)
        local tip = GetOffsetFromEntityInWorldCoords(rod, off.x, off.y, off.z)
        if tip and tip.x then return tip.x, tip.y, tip.z end
    end
    return WGLine.GetRodTip(nil, ped)
end

function WGLine.Draw(rod, ped, floatX, floatY, floatZ, color, tens)
    local rx, ry, rz = WGLine.GetRodTip(rod, ped)
    if not rx or not floatX then return nil end
    local dist = #(vector3(rx, ry, rz) - vector3(floatX, floatY, floatZ))
    if dist < 0.05 or dist > 200.0 then return rx, ry, rz end

    local r, g, b = 173, 176, 151
    if color and color[1] then
        r, g, b = color[1], color[2], color[3]
    end
    local tNorm = math.max(0.0, math.min(1.0, tens or 0.0))
    local segs = math.max(10, math.min(40, math.ceil(dist / 2.5)))
    local sagMax = (1.0 - tNorm) * math.min(2.5, dist * 0.04)

    local prevX, prevY, prevZ = rx, ry, rz
    for i = 1, segs do
        local t = i / segs
        local x = rx + (floatX - rx) * t
        local y = ry + (floatY - ry) * t
        local z = rz + (floatZ - rz) * t
        -- parabolic sag
        local sag = sagMax * 4.0 * t * (1.0 - t)
        z = z - sag
        local found, waterZ = GetWaterHeight(x, y, math.max(rz, floatZ) + 5.0)
        local a = 170
        local rr, gg, bb = r, g, b
        if found and waterZ and z < waterZ then
            a = 70
            rr = math.floor(r * 0.5)
            gg = math.floor(g * 0.5)
            bb = math.floor(b * 0.5)
        end
        DrawLine(prevX, prevY, prevZ, x, y, z, rr, gg, bb, a)
        prevX, prevY, prevZ = x, y, z
    end
    return rx, ry, rz
end

function WGLine.DrawFromTip(rx, ry, rz, floatX, floatY, floatZ, color, tens)
    if not rx or not floatX then return end
    local dist = #(vector3(rx, ry, rz) - vector3(floatX, floatY, floatZ))
    if dist < 0.05 or dist > 200.0 then return end
    local r, g, b = 173, 176, 151
    if color and color[1] then r, g, b = color[1], color[2], color[3] end
    local tNorm = math.max(0.0, math.min(1.0, tens or 0.0))
    local segs = math.max(10, math.min(40, math.ceil(dist / 2.5)))
    local sagMax = (1.0 - tNorm) * math.min(2.5, dist * 0.04)
    local prevX, prevY, prevZ = rx, ry, rz
    for i = 1, segs do
        local t = i / segs
        local x = rx + (floatX - rx) * t
        local y = ry + (floatY - ry) * t
        local z = rz + (floatZ - rz) * t - sagMax * 4.0 * t * (1.0 - t)
        DrawLine(prevX, prevY, prevZ, x, y, z, r, g, b, 160)
        prevX, prevY, prevZ = x, y, z
    end
end

-- ---------------------------------------------------------------------------

local active = false
local rodObj = nil
local mode = 'idle'
local tension = 0.0 -- smoothed (display / snap)
local rawTension = 0.0
local casting = false
local throwingTension = 0.0
local chargeStart = 0
local gear = 1 -- UI 1–5 → spindleGear 0–4
local lineLength = 0.0
local fishWeight = 1.0
local fishKey = nil
local rodName = nil
local floatIndex = 1
local catchStartAt = 0

local floatPos = nil -- {x,y,z[,waterZ]}
local throwForce = nil -- {dx,dy,horizSpd,vertSpd}
local floatingValue = 0.0
local deepness = 2.5
local lineUnderwater = 0.0

local gearUpPressed, gearDownPressed = false, false
local lastGearChange = 0
local lineColor = { 173, 176, 151 }
local spindleRoll = 0.0
local lastPhysTick = 0
local gearUpHeld, gearDownHeld = false, false
local lineVelocity = 0.0 -- + let out, − reel in
local hudTension = 0.0
local lastReelSound = 0
local getOutStart = 0
local fishPreview = nil
local winShowcaseProp = nil
local winShowcaseCam = nil
local winShowcaseActive = false
local endWinShowcase -- forward decl: stopFishing() (defined above beginWinShowcase) needs to call this

-- Fish AI (catched)
local fishEnergy = 1.0
local fishPosition = nil
local fishTargetPosition = nil
local fishTargetVector = nil
local fishForceSwitch = 0
local fishTargetTries = 0
local fishMinimumDistance = nil
local fishVector = { 0.0, 0.0 }
local catchingForce = nil
local snapOverTime = 0.0

local VK_SHIFT, VK_CONTROL = 0x10, 0x11
local VK_LSHIFT, VK_RSHIFT = 0xA0, 0xA1
local VK_LCONTROL, VK_RCONTROL = 0xA2, 0xA3

local function playSound(file, vol)
    SendNUIMessage({ action = 'playSound', file = file, volume = vol or 0.5 })
end

local function playSound3D(file, coords, vol)
    -- NUI positional approximation; entity sounds via PlaySoundFrontend fallback
    playSound(file, vol or 0.45)
    if coords then
        -- brief splash cue at water
    end
end

local function setHud(show, data)
    SendNUIMessage({ action = show and 'showHud' or 'hideHud', data = data or {} })
end

-- 'catching' | 'catched' | false — mirrors v4's gotFishNoti/setFishingMode banner logic
local function setGotFishState(state)
    SendNUIMessage({ action = 'gotFish', state = state })
end

local function updateHud()
    if not active then return end
    SendNUIMessage({
        action = 'updateHud',
        data = {
            mode = mode,
            tension = hudTension,
            gear = gear,
            line = math.floor(lineLength),
            lineLength = lineLength,
            spindleRot = spindleRoll,
            lineColor = lineColor,
            charging = casting or (mode == 'aim' and throwingTension > 0.01),
            charge = mode == 'aim' and throwingTension or (casting and math.min(1.0, (GetGameTimer() - chargeStart) / (Config.CastChargeMs or 2000)) or 0),
            floatDepth = deepness,
            floatingValue = floatingValue,
            lineUnderwater = lineUnderwater,
        },
    })
end

local function smoothToward(current, target, rate, dt)
    return current + (target - current) * math.min(1.0, rate * dt)
end

local function rawKey(vk)
    return IsRawKeyPressed and IsRawKeyPressed(vk) or false
end

local function isShiftDown()
    return rawKey(VK_LSHIFT) or rawKey(VK_RSHIFT) or rawKey(VK_SHIFT)
        or IsDisabledControlPressed(0, 21) or IsControlPressed(0, 21)
end

local function isCtrlDown()
    return rawKey(VK_LCONTROL) or rawKey(VK_RCONTROL) or rawKey(VK_CONTROL)
        or IsDisabledControlPressed(0, 36) or IsControlPressed(0, 36)
end

local function wheelReelIn()
    return IsDisabledControlJustPressed(0, 242) or IsDisabledControlJustPressed(0, 14)
        or IsControlJustPressed(0, 242) or IsControlJustPressed(0, 14)
end

local function wheelLetOut()
    return IsDisabledControlJustPressed(0, 241) or IsDisabledControlJustPressed(0, 15)
        or IsControlJustPressed(0, 241) or IsControlJustPressed(0, 15)
end

local function spindleGear()
    return math.max(0, (gear or 1) - 1)
end

local function gearMul()
    local step = (Config.Physics and Config.Physics.gearStep) or 0.35
    return 1.0 + spindleGear() * step
end

local function deleteRod()
    WGLine.ClearTipMarker()
    if rodObj and DoesEntityExist(rodObj) then
        DetachEntity(rodObj, true, true)
        SetEntityAsMissionEntity(rodObj, true, true)
        DeleteObject(rodObj)
        if DoesEntityExist(rodObj) then DeleteEntity(rodObj) end
    end
    rodObj = nil
end

local function deleteFishPreview()
    if fishPreview and DoesEntityExist(fishPreview) then
        DetachEntity(fishPreview, true, true)
        SetEntityAsMissionEntity(fishPreview, true, true)
        DeleteObject(fishPreview)
    end
    fishPreview = nil
end

local function bindRodToHand(lean01)
    if not rodObj or not DoesEntityExist(rodObj) then return end
    local ped = PlayerPedId()
    local a = Config.RodAttach or {}
    local bone = GetPedBoneIndex(ped, a.bone or 18905)
    local p = a.pos or vector3(0.1, 0.05, 0.0)
    local r = a.rot or vector3(80.0, 120.0, 160.0)
    local lean = math.max(0.0, math.min(1.0, tonumber(lean01) or 0.0))
    local lr = a.castLeanRot or vector3(0.0, 0.0, 0.0)
    local rx = r.x + lr.x * lean
    local ry = r.y + lr.y * lean
    local rz = r.z + lr.z * lean
    AttachEntityToEntity(
        rodObj, ped, bone,
        p.x, p.y, p.z,
        rx, ry, rz,
        true, true, false, true, 1, true
    )
    SetEntityCollision(rodObj, false, false)
    WGLine.AttachTipMarker(rodObj)
end

local function playFishAnim(clip, progress)
    local dict = Config.FishAnims.dict
    WGAnim._frozenUpper = nil
    local restarted = WGAnim.Play(dict, clip, progress)
    if restarted then bindRodToHand(0.0) end
end

local function playFishAnimFrozen(clip, progress, upperBody)
    local dict = Config.FishAnims.dict
    local restarted = WGAnim.PlayFrozen(dict, clip, progress, upperBody)
    -- lean amount separately via bindRodToHand(lean) from holdCastLeanPose
    if restarted then bindRodToHand(0.0) end
end

local function ensureIdleAnim()
    local ped = PlayerPedId()
    local dict = Config.FishAnims.dict
    local idle = Config.FishAnims.idle
    if not IsEntityPlayingAnim(ped, dict, idle, 3) then
        playFishAnim(idle, nil)
    end
end

local waterPoseOn = false
local castLeanRecoverFrom = nil -- 0–1 lean amount at release
local castLeanRecoverStart = 0
local castAimYaw = nil
local castLeanFrameAmount = 0.0

local function waterPoseProgress()
    local p = (Config.FishAnims and Config.FishAnims.waterPoseProgress) or 0.99
    return math.max(0.0, math.min(0.99, p))
end

local function clearCastLeanRecover()
    castLeanRecoverFrom = nil
    castLeanRecoverStart = 0
end

local function clearWaterPoseFlag()
    waterPoseOn = false
end

--- No-op leftover (never pitch the whole ped). Clears aim yaw lock.
local function clearCastLeanPitch()
    castAimYaw = nil
end

--- Derék/törzs hátradőlés: upper-body-only idle_c (flag 17) + bot tilt.
--- SOHA SetEntityRotation a peden — az az egész testet dönti.
local function holdCastLeanPose(lean01)
    local ped = PlayerPedId()
    local dict = Config.FishAnims.dict
    local idle = Config.FishAnims.idle
    local cast = Config.FishAnims.cast
    if cast and IsEntityPlayingAnim(ped, dict, cast, 3) then
        StopAnimTask(ped, dict, cast, 0.0)
    end
    if castAimYaw == nil then
        castAimYaw = GetEntityHeading(ped)
    end
    castLeanFrameAmount = math.max(0.0, math.min(1.0, tonumber(lean01) or 0.0))
    local progress = WGAnim.ProgressFromCastLean(castLeanFrameAmount)
    -- flag 17: csak felsőtest/derék; lábak állva maradnak
    playFishAnimFrozen(idle, progress, true)
    bindRodToHand(castLeanFrameAmount)
end

local function ensureWaterPose()
    if castLeanRecoverFrom ~= nil then return end
    castLeanFrameAmount = 0.0
    local ped = PlayerPedId()
    local dict = Config.FishAnims.dict
    local idle = Config.FishAnims.idle
    local cast = Config.FishAnims.cast
    local poseP = waterPoseProgress()
    if cast and IsEntityPlayingAnim(ped, dict, cast, 3) then
        StopAnimTask(ped, dict, cast, 0.0)
        waterPoseOn = false
    end
    if waterPoseOn and IsEntityPlayingAnim(ped, dict, idle, 3) and WGAnim._frozenUpper == false then
        SetEntityAnimCurrentTime(ped, dict, idle, poseP)
        SetEntityAnimSpeed(ped, dict, idle, 0.0)
        bindRodToHand(0.0)
        return
    end
    playFishAnimFrozen(idle, poseP, false)
    bindRodToHand(0.0)
    waterPoseOn = true
end

local function startCastLeanRecover(lean01)
    castLeanRecoverFrom = math.max(0.0, math.min(1.0, tonumber(lean01) or 0.0))
    castLeanRecoverStart = GetGameTimer()
    waterPoseOn = false
end

local function updateCastLeanRecover(now)
    if castLeanRecoverFrom == nil then return false end
    local recoverMs = (Config.FishAnims and Config.FishAnims.castLeanRecoverMs) or 750
    local elapsed = now - castLeanRecoverStart
    local t = recoverMs > 0 and math.min(1.0, elapsed / recoverMs) or 1.0
    local eased = 1.0 - (1.0 - t) * (1.0 - t)
    local lean = castLeanRecoverFrom * (1.0 - eased)
    holdCastLeanPose(lean)
    if t >= 1.0 then
        clearCastLeanRecover()
        castLeanFrameAmount = 0.0
        bindRodToHand(0.0)
        ensureWaterPose()
    end
    return true
end

local function clearFishAnim()
    WGAnim.Clear()
end

local function rodModelFor(name)
    local rd = name and Config.Rods[name]
    local idx = rd and rd.index or 0
    if Config.RodPropsByIndex and Config.RodPropsByIndex[idx] then
        return Config.RodPropsByIndex[idx]
    end
    return Config.RodProp or `prop_fishing_rod_01`
end

local function attachRod()
    deleteRod()
    local ped = PlayerPedId()
    local model = rodModelFor(rodName)
    RequestModel(model)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(10) end
    if not HasModelLoaded(model) then return end
    local coords = GetEntityCoords(ped)
    rodObj = CreateObject(model, coords.x, coords.y, coords.z - 3.0, false, false, false)
    SetEntityAsMissionEntity(rodObj, true, true)
    SetEntityCollision(rodObj, false, false)
    SetEntityVisible(rodObj, true, false)
    bindRodToHand()
    SetModelAsNoLongerNeeded(model)
    playFishAnim(Config.FishAnims.idle, nil)
    bindRodToHand()
end

local function resetFightState()
    fishEnergy = 1.0
    fishPosition = nil
    fishTargetPosition = nil
    fishTargetVector = nil
    fishForceSwitch = 0
    fishTargetTries = 0
    fishMinimumDistance = nil
    fishVector = { 0.0, 0.0 }
    catchingForce = nil
    lineUnderwater = 0.0
    floatingValue = 0.0
    snapOverTime = 0.0
end

local function clearFloat()
    WGFloat.Delete()
    floatPos = nil
    throwForce = nil
end

local function stopFishing()
    active = false
    mode = 'idle'
    casting = false
    throwingTension = 0.0
    throwForce = nil
    tension = 0.0
    rawTension = 0.0
    hudTension = 0.0
    lineVelocity = 0.0
    lineLength = 0.0
    clearCastLeanRecover()
    clearCastLeanPitch()
    clearWaterPoseFlag()
    clearFloat()
    deleteFishPreview()
    resetFightState()
    deleteRod()
    clearFishAnim()
    setHud(false)
    setGotFishState(false)
    endWinShowcase()
    local a = Audio()
    if a and a.Reset then a.Reset() end
    LocalPlayer.state:set('wgFishing', false, false)
    TriggerEvent('wellgame_fishing:client:localSyncClear')
    if GetResourceState('wellgame_controls') == 'started' then
        exports['wellgame_controls']:toggleAllControls(true, 'wellgame_fishing')
    end
end

local function pointInDeniedZone(x, y)
    local zones = Config.DeniedZones
    if not zones or #zones == 0 then return false end
    for zi = 1, #zones do
        local poly = zones[zi]
        if poly and #poly >= 3 then
            local inside = false
            local j = #poly
            for i = 1, #poly do
                local xi, yi = poly[i].x, poly[i].y
                local xj, yj = poly[j].x, poly[j].y
                if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / ((yj - yi) + 0.0) + xi) then
                    inside = not inside
                end
                j = i
            end
            if inside then return true end
        end
    end
    return false
end

local function waterDepthAt(x, y, zHint)
    local found, waterZ = GetWaterHeight(x, y, (zHint or 0.0) + 10.0)
    if not found then return false, nil, nil end
    local ok, groundZ = GetGroundZFor_3dCoord(x, y, waterZ + 5.0, false)
    local gz = ok and groundZ or (waterZ - 6.5)
    local depth = waterZ - gz
    local deep = depth >= (Config.MinWaterDepth or 2.5)
    return deep, waterZ, math.max(2.5, math.min(6.5, math.floor(depth * 10) / 10))
end

local function spawnBobberAt(x, y, z)
    floatPos = { x, y, z }
    WGFloat.Spawn(vector3(x, y, z), floatIndex)
    WGFloat.SetPos(x, y, z)
end

local function beginThrow()
    if (tonumber(floatIndex) or 0) < 1 then
        QBCore.Functions.Notify('Nincs úszó a botodon — szerelj fel egyet.', 'error')
        mode = 'idle'
        casting = false
        throwingTension = 0.0
        clearCastLeanRecover()
        clearCastLeanPitch()
        clearWaterPoseFlag()
        playFishAnim(Config.FishAnims.idle, nil)
        updateHud()
        return
    end
    if throwingTension < (Config.MinCastTension or 0.25) then
        QBCore.Functions.Notify('Túl gyenge dobás.', 'error')
        mode = 'idle'
        casting = false
        throwingTension = 0.0
        clearCastLeanRecover()
        clearCastLeanPitch()
        clearWaterPoseFlag()
        playFishAnim(Config.FishAnims.idle, nil)
        updateHud()
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    if pointInDeniedZone(coords.x, coords.y) then
        QBCore.Functions.Notify('Itt tilos horgászni!', 'error')
        mode = 'idle'
        casting = false
        playFishAnim(Config.FishAnims.idle, nil)
        return
    end

    local force = throwingTension
    local leanAtRelease = math.max(0.0, math.min(1.0, force))
    -- Dobás irány: aim yaw (bot-lean nem mozgatja a pedet)
    local aimYaw = castAimYaw or GetEntityHeading(ped)
    castAimYaw = nil
    SetEntityHeading(ped, aimYaw)

    local camRot = GetGameplayCamRot(2)
    local heading = math.rad(camRot.z)
    local pedH = math.rad(aimYaw)
    -- clamp camera yaw relative to aim yaw ±45°
    local cr = heading - pedH
    while cr > math.pi do cr = cr - math.pi * 2 end
    while cr < -math.pi do cr = cr + math.pi * 2 end
    cr = math.max(-math.pi / 4, math.min(math.pi / 4, cr)) + pedH
    local dx = -math.sin(cr)
    local dy = math.cos(cr)

    local phys = Config.Physics or {}
    -- Tip egyenes botállással (lean 0), hogy ne balra induljon a dobás
    bindRodToHand(0.0)
    local tipX, tipY, tipZ = WGLine.GetRodTip(rodObj, ped)
    spawnBobberAt(tipX, tipY, tipZ + 0.15)
    throwForce = {
        dx,
        dy,
        force * (phys.throwHorizMul or 60.0),
        force * (phys.throwVertMul or 15.0),
    }
    lineLength = 0.125
    floatingValue = 0.0
    mode = 'throw'
    casting = false
    throwingTension = 0.0
    playSound('woosh.mp3', 0.55)
    local a = Audio()
    if a then a.Cast() end
    holdCastLeanPose(leanAtRelease)
    startCastLeanRecover(leanAtRelease)
    TriggerServerEvent('wellgame_fishing:server:throwStart')
    updateHud()
end

local function enterWaiting()
    mode = 'waiting'
    throwForce = nil
    throwingTension = 0.0
    local a = Audio()
    if a then a.Splash() else playSound('splash.mp3', 0.55) end
    ensureWaterPose()
    bindRodToHand()
    TriggerServerEvent('wellgame_fishing:server:cast')
    updateHud()
end

local function doSnap(tear, reason)
    TriggerServerEvent('wellgame_fishing:server:snap', tear == true)
    setGotFishState(false)
    mode = 'idle'
    casting = false
    throwingTension = 0.0
    throwForce = nil
    clearFloat()
    floatIndex = 0 -- úszó elveszett; újra fel kell szerelni
    deleteFishPreview()
    resetFightState()
    tension = 0.0
    rawTension = 0.0
    hudTension = 0.0
    lineVelocity = 0.0
    lineLength = 0.0
    deepness = 2.5
    floatingValue = 0.0
    lineUnderwater = 0.0
    local a = Audio()
    if a then a.Snap() else playSound('snap.mp3', 0.55) end
    if a and a.Reset then a.Reset() end
    clearCastLeanRecover()
    clearCastLeanPitch()
    clearWaterPoseFlag()
    playFishAnim(Config.FishAnims.idle, nil)
    TriggerEvent('wellgame_fishing:client:localSyncClear')
    updateHud()
    -- szerver küldi a wear/float infót (rodMeta + notify)
end

local function beginGetOut(withFish)
    mode = 'getout'
    setGotFishState(false)
    getOutStart = GetGameTimer()
    throwForce = nil
    -- float már nem kell a kihúzáshoz — töröld, ne maradjon ghost a parton
    clearFloat()
    local a = Audio()
    if a then a.WaterOut() else playSound('waterout.mp3', 0.5) end
    playFishAnim(Config.FishAnims.getout or Config.FishAnims.idle, nil)
    if withFish and fishKey then
        deleteFishPreview()
        local model = Config.FishPreviewProp or `prop_cs_steak`
        RequestModel(model)
        local t = GetGameTimer() + 2000
        while not HasModelLoaded(model) and GetGameTimer() < t do Wait(0) end
        if HasModelLoaded(model) then
            local ped = PlayerPedId()
            local c = GetEntityCoords(ped)
            fishPreview = CreateObject(model, c.x, c.y, c.z, false, false, false)
            AttachEntityToEntity(fishPreview, ped, GetPedBoneIndex(ped, 18905), 0.15, 0.05, 0.05, 0.0, 90.0, 0.0, true, true, false, true, 1, true)
            SetModelAsNoLongerNeeded(model)
        end
        TriggerServerEvent('wellgame_fishing:server:land')
    else
        TriggerServerEvent('wellgame_fishing:server:getoutIdle')
    end
    updateHud()
end

local function finishGetOut()
    clearFloat()
    deleteFishPreview()
    resetFightState()
    fishKey = nil
    fishWeight = 1.0
    mode = 'idle'
    tension = 0.0
    lineVelocity = 0.0
    lineLength = 0.0
    playFishAnim(Config.FishAnims.idle, nil)
    updateHud()
end

RegisterCommand('+wg_fish_gearup', function() gearUpPressed = true end, false)
RegisterCommand('-wg_fish_gearup', function() gearUpPressed = false end, false)
RegisterCommand('+wg_fish_geardown', function() gearDownPressed = true end, false)
RegisterCommand('-wg_fish_geardown', function() gearDownPressed = false end, false)
RegisterKeyMapping('+wg_fish_gearup', 'Horgászat: fokozat fel', 'keyboard', 'LSHIFT')
RegisterKeyMapping('+wg_fish_geardown', 'Horgászat: fokozat le', 'keyboard', 'LCONTROL')

local function tryGearChange(dir)
    if not active then return end
    if mode ~= 'catched' and mode ~= 'catching' and mode ~= 'waiting' then return end
    local now = GetGameTimer()
    if now - lastGearChange < 200 then return end
    local prev = gear
    gear = math.max(1, math.min(5, gear + dir))
    if gear ~= prev then
        lastGearChange = now
        local a = Audio()
        if a then a.Gear() else playSound('gear.mp3', 0.35) end
        updateHud()
        TriggerServerEvent('wellgame_fishing:server:syncState', { spindleGear = spindleGear() })
    end
end

local function pollGearKeys()
    local up = isShiftDown() or gearUpPressed
    local down = isCtrlDown() or gearDownPressed
    gearUpPressed, gearDownPressed = false, false
    if up and not gearUpHeld then tryGearChange(1) end
    if down and not gearDownHeld then tryGearChange(-1) end
    gearUpHeld, gearDownHeld = up, down
end

local function decayLineVel(dt)
    if lineVelocity == 0.0 then return end
    local phys = Config.Physics or {}
    local abs = math.abs(lineVelocity)
    local sign = lineVelocity / abs
    local decay = phys.lineVelDecay or 1.15
    local slow = math.max(decay, abs * decay)
    lineVelocity = lineVelocity - sign * slow * dt
    if (sign < 0 and lineVelocity > 0) or (sign > 0 and lineVelocity < 0) then
        lineVelocity = 0.0
    end
end

local function applyScrollImpulse()
    local phys = Config.Physics or {}
    local g = gearMul()
    local impulse = (phys.scrollImpulse or 0.25) * g
    local direct = math.max(0.0, math.min(1.0, phys.scrollDirect or 0.72))
    local velMul = phys.scrollVelMul or 1.55
    local changed = false
    if wheelReelIn() then
        -- Azonnali damilhúzás + rövid velocity follow-through (kevesebb "késleltetett" érzet)
        lineLength = math.max(0.5, lineLength - impulse * direct)
        lineVelocity = lineVelocity - impulse * (1.0 - direct) * velMul
        changed = true
    end
    if wheelLetOut() then
        lineLength = math.min(100.0, lineLength + impulse * direct)
        lineVelocity = lineVelocity + impulse * (1.0 - direct) * velMul
        changed = true
    end
    if changed then
        -- hangot a v4-szerű looping ProcessReel/ProcessSpindle kezeli (nincs one-shot spam)
    end
end

-- Events
RegisterNetEvent('wellgame_fishing:client:useRod', function(slot)
    if active then
        TriggerServerEvent('wellgame_fishing:server:stop')
        stopFishing()
        return
    end
    TriggerServerEvent('wellgame_fishing:server:start', slot)
end)

RegisterNetEvent('wellgame_fishing:client:start', function(data)
    active = true
    mode = 'idle'
    gear = 1
    lineLength = 0.0
    tension = 0.0
    rawTension = 0.0
    spindleRoll = 0.0
    lineVelocity = 0.0
    hudTension = 0.0
    throwingTension = 0.0
    casting = false
    rodName = data and data.rod
    floatIndex = data and tonumber(data.float) or 1
    resetFightState()
    clearFloat()
    LocalPlayer.state:set('wgFishing', true, false)
    local lineId = data and tonumber(data.line) or 1
    local col = Config.LineColors[lineId]
    lineColor = col and { col[1], col[2], col[3] } or { 173, 176, 151 }
    attachRod()
    setHud(true, { mode = 'idle', lineColor = lineColor })
    QBCore.Functions.Notify('Horgászbot elővéve. RMB célzás, LMB dobás. Shift/Ctrl = fokozat.', 'primary')
end)

RegisterNetEvent('wellgame_fishing:client:stop', function()
    stopFishing()
end)

RegisterNetEvent('wellgame_fishing:client:rodMeta', function(meta)
    if type(meta) ~= 'table' then return end
    floatIndex = tonumber(meta.float) or 0
    if meta.lostLine then
        QBCore.Functions.Notify('Nincs többé damil a botodon — szerelj fel újat.', 'error')
        TriggerServerEvent('wellgame_fishing:server:stop')
        stopFishing()
        return
    end
    if floatIndex < 1 then
        QBCore.Functions.Notify('Új úszót kell felszerelned, mielőtt újra dobnál.', 'primary')
    end
    local lineId = tonumber(meta.line)
    if lineId and Config.LineColors[lineId] then
        local col = Config.LineColors[lineId]
        lineColor = { col[1], col[2], col[3] }
    end
end)

RegisterNetEvent('wellgame_fishing:client:setMode', function(m, fish, weight)
    -- Don't let stale server timers yank us out of getout / idle after reel-in
    if (mode == 'getout' or mode == 'idle') and (m == 'waiting' or m == 'catching') then
        return
    end
    mode = m or 'idle'
    if fish then fishKey = fish end
    if weight then fishWeight = tonumber(weight) or 1.0 end
    if mode == 'fighting' then mode = 'catched' end
    setGotFishState(mode == 'catching' and 'catching' or mode == 'catched' and 'catched' or false)
    updateHud()
end)

RegisterNetEvent('wellgame_fishing:client:sync', function(data)
    if type(data) ~= 'table' then return end
    mode = data.mode or mode
    if mode == 'fighting' then mode = 'catched' end
    setGotFishState(mode == 'catching' and 'catching' or mode == 'catched' and 'catched' or false)
    updateHud()
end)

RegisterNetEvent('wellgame_fishing:client:bite', function(fish, weight, fishData)
    -- Ignore late bites after reel-in / snap / getout
    if not active or not floatPos then return end
    if mode ~= 'waiting' and mode ~= 'catching' then return end
    mode = 'catching'
    fishKey = fish
    fishWeight = tonumber(weight) or 1.0
    tension = 0.0
    hudTension = 0.0
    lineVelocity = 0.0
    catchingForce = nil
    floatingValue = 0.85
    lineUnderwater = 0.2
    setGotFishState('catching')
    local cls = (fishData and fishData.class) or 'Common'
    if cls == 'Legendary' then playSound('legendary.wav', 0.5)
    elseif cls == 'Epic' then playSound('epic.wav', 0.5)
    elseif cls == 'Rare' then playSound('rare.wav', 0.45)
    else playSound('common.wav', 0.4) end
    QBCore.Functions.Notify('Kapás! Görgő LE = behúzás / horogra akadatás.', 'success')
    updateHud()
end)

RegisterNetEvent('wellgame_fishing:client:fishGotAway', function()
    if mode ~= 'waiting' and mode ~= 'catching' then return end
    fishKey = nil
    fishWeight = 1.0
    catchingForce = nil
    resetFightState()
    mode = 'waiting'
    setGotFishState(false)
    updateHud()
end)

-- Win showcase: v4 had an interactive rotating 3D fish model on the catch card;
-- here we drive a real world camera + prop instead of trying to fake it in NUI.
function endWinShowcase()
    if winShowcaseCam and DoesCamExist(winShowcaseCam) then
        RenderScriptCams(false, true, 300, true, true)
        DestroyCam(winShowcaseCam, false)
    end
    winShowcaseCam = nil
    if winShowcaseProp and DoesEntityExist(winShowcaseProp) then
        SetEntityAsMissionEntity(winShowcaseProp, true, true)
        DeleteObject(winShowcaseProp)
        if DoesEntityExist(winShowcaseProp) then DeleteEntity(winShowcaseProp) end
    end
    winShowcaseProp = nil
    if winShowcaseActive then
        winShowcaseActive = false
        if GetResourceState('wellgame_controls') == 'started' then
            exports['wellgame_controls']:toggleAllControls(true, 'wellgame_fishing_win')
        end
    end
end

local function beginWinShowcase()
    endWinShowcase()
    local ped = PlayerPedId()
    local model = Config.FishPreviewProp or `prop_cs_steak`
    RequestModel(model)
    local t = GetGameTimer() + 2000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(0) end
    if not HasModelLoaded(model) then return end

    local coords = GetEntityCoords(ped)
    local fwd = GetEntityForwardVector(ped)
    local propX, propY, propZ = coords.x + fwd.x * 1.15, coords.y + fwd.y * 1.15, coords.z + 0.75

    winShowcaseProp = CreateObject(model, propX, propY, propZ, false, false, false)
    SetEntityAsMissionEntity(winShowcaseProp, true, true)
    SetEntityCollision(winShowcaseProp, false, false)
    FreezeEntityPosition(winShowcaseProp, true)
    SetModelAsNoLongerNeeded(model)

    winShowcaseCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(winShowcaseCam, coords.x + fwd.x * 0.15, coords.y + fwd.y * 0.15, coords.z + 0.85)
    PointCamAtCoord(winShowcaseCam, propX, propY, propZ)
    SetCamFov(winShowcaseCam, 30.0)
    RenderScriptCams(true, true, 350, true, true)

    winShowcaseActive = true
    if GetResourceState('wellgame_controls') == 'started' then
        exports['wellgame_controls']:toggleAllControls(false, 'wellgame_fishing_win')
    end

    CreateThread(function()
        local endAt = GetGameTimer() + 4500
        local last = GetGameTimer()
        while winShowcaseProp and DoesEntityExist(winShowcaseProp) and GetGameTimer() < endAt do
            local now = GetGameTimer()
            local dt = math.min(0.05, (now - last) / 1000.0)
            last = now
            SetEntityHeading(winShowcaseProp, (GetEntityHeading(winShowcaseProp) + 55.0 * dt) % 360.0)
            Wait(0)
        end
        endWinShowcase()
    end)
end

RegisterNetEvent('wellgame_fishing:client:catchWin', function(payload)
    SendNUIMessage({ action = 'catchWin', data = payload })
    beginWinShowcase()
    local cls = payload and payload.class or 'Common'
    if cls == 'Legendary' then playSound('legendary.wav', 0.55)
    elseif cls == 'Epic' then playSound('epic.wav', 0.5)
    else playSound('common.wav', 0.45) end
    playSound('fishout.wav', 0.4)
end)

RegisterNetEvent('wellgame_fishing:client:playSound', function(file)
    playSound(file, 0.55)
end)

RegisterNetEvent('wellgame_fishing:client:useLine', function(lineSlot)
    local items = QBCore.Functions.GetPlayerData().items or {}
    for slot, item in pairs(items) do
        if item and Config.Rods[item.name] then
            TriggerServerEvent('wellgame_fishing:server:attachLine', lineSlot, item.slot or slot)
            return
        end
    end
    QBCore.Functions.Notify('Nincs horgászbot az inventoryban.', 'error')
end)

RegisterNetEvent('wellgame_fishing:client:useFloat', function(floatSlot)
    local items = QBCore.Functions.GetPlayerData().items or {}
    for slot, item in pairs(items) do
        if item and Config.Rods[item.name] then
            TriggerServerEvent('wellgame_fishing:server:attachFloat', floatSlot, item.slot or slot)
            return
        end
    end
    QBCore.Functions.Notify('Nincs horgászbot az inventoryban.', 'error')
end)

RegisterNetEvent('wellgame_fishing:client:openChest', function(slot)
    TriggerServerEvent('wellgame_fishing:server:openChest', slot)
end)

-- Physics helpers
local function smoothTension(target, dt)
    local rate = (Config.Physics and Config.Physics.tensionSmooth) or 4.0
    if target > tension then
        tension = math.min(target, tension + rate * dt)
    elseif target < tension then
        tension = math.max(target, tension - rate * dt)
    end
end

local function pickFishTarget(rodEndX, rodEndY, waterZ)
    fishTargetTries = (fishTargetTries or 0) + 1
    if fishTargetTries > 100 then
        fishKey = nil
        beginGetOut(false)
        QBCore.Functions.Notify('Elúszott a hal!', 'error')
        return true
    end
    if not floatPos then return true end
    local minD = fishMinimumDistance or lineLength
    local d = math.random() * (150 - minD) + minD
    local ang = math.random() * math.pi / 2 - math.pi / 4
    local ped = PlayerPedId()
    local h = math.rad(GetEntityHeading(ped))
    local nx = rodEndX + math.cos(h + ang) * d
    local ny = rodEndY + math.sin(h + ang) * d
    local deep = waterDepthAt(nx, ny, waterZ or 0.0)
    if deep then
        fishTargetTries = 0
        local p = Config.Physics or {}
        fishForceSwitch = math.random() * ((p.fishForceSwitchMax or 11000) - (p.fishForceSwitchMin or 1000)) + (p.fishForceSwitchMin or 1000)
        fishTargetPosition = { nx, ny }
        if not fishPosition then
            fishPosition = { floatPos[1], floatPos[2] }
        end
        fishTargetVector = {
            nx - fishPosition[1],
            ny - fishPosition[2],
        }
    end
    return false
end

local function updateCatchedFishAI(dt, rodEndX, rodEndY, waterZ)
    if not floatPos then return true end
    if not fishMinimumDistance then
        fishMinimumDistance = lineLength
    elseif lineLength < fishMinimumDistance then
        fishMinimumDistance = lineLength
    end

    local phys = Config.Physics or {}
    local wf = math.min(1.0, (fishWeight or 1.0) / 60.0)
    local drain = phys.fishEnergyDrain or 0.0125
    local e = math.max(0.1, (fishEnergy or 1.0) - tension * (drain * (1 - wf * 0.5)) * dt)
    fishEnergy = e
    fishForceSwitch = (fishForceSwitch or 0) - dt * 1000

    if not fishPosition then
        fishPosition = { floatPos[1], floatPos[2] }
    end
    local nearTarget = false
    if fishTargetPosition then
        local dx = fishTargetPosition[1] - floatPos[1]
        local dy = fishTargetPosition[2] - floatPos[2]
        nearTarget = (dx * dx + dy * dy) < (0.25 * 0.25)
    end
    if not fishTargetPosition or fishForceSwitch <= 0 or nearTarget then
        if pickFishTarget(rodEndX, rodEndY, waterZ) or not floatPos then
            return true
        end
    end

    local fvx, fvy = 0.0, 0.0
    if fishTargetVector and fishTargetPosition and fishPosition and floatPos then
        local canEnd = true
        local step = dt / 0.5
        for axis = 1, 2 do
            local cur = fishPosition[axis]
            local tgt = fishTargetPosition[axis]
            local vec = fishTargetVector[axis]
            if cur < tgt then
                fishPosition[axis] = cur + vec * step
                if fishPosition[axis] > tgt then fishPosition[axis] = tgt else canEnd = false end
            elseif cur > tgt then
                fishPosition[axis] = cur + vec * step
                if fishPosition[axis] < tgt then fishPosition[axis] = tgt else canEnd = false end
            end
        end
        if canEnd then fishTargetVector = nil end

        fvx = fishPosition[1] - floatPos[1]
        fvy = fishPosition[2] - floatPos[2]
        local len = math.sqrt(fvx * fvx + fvy * fvy)
        if len > 0.001 then
            fvx, fvy = fvx / len, fvy / len
        end
    end

    -- v4: swim speed + resist vs tip pull direction
    local tipVx = rodEndX - floatPos[1]
    local tipVy = rodEndY - floatPos[2]
    local tipLen = math.sqrt(tipVx * tipVx + tipVy * tipVy)
    if tipLen > 0.001 then tipVx, tipVy = tipVx / tipLen, tipVy / tipLen end

    -- Súlyfaktor: kis hal is érezhetően húzzon (padló 0.45), nagy még erősebben
    local weightPull = 0.45 + 0.55 * wf
    local force = (phys.fishResist or 0.45) * weightPull * e
    local spd = ((60.0 - (fishWeight or 1.0)) / (phys.fishSwimWeightDiv or 10.0)) + (phys.fishSwimBase or 3.0)
    fvx = fvx * spd * e
    fvy = fvy * spd * e
    fvx = fvx - tipVx * force
    fvy = fvy - tipVy * force

    floatPos[1] = floatPos[1] + fvx * dt
    floatPos[2] = floatPos[2] + fvy * dt
    fishVector = { fvx, fvy }
    return false
end

-- Main loop
CreateThread(function()
    while true do
        if active then
            local ped = PlayerPedId()
            local now = GetGameTimer()
            if lastPhysTick == 0 then lastPhysTick = now end
            local dt = math.min(0.05, (now - lastPhysTick) / 1000.0)
            lastPhysTick = now
            local phys = Config.Physics or {}

            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 36, true)
            for _, c in ipairs({ 14, 15, 16, 17, 99, 100, 241, 242, 261, 262 }) do
                DisableControlAction(0, c, true)
            end

            pollGearKeys()

            -- Aim / charge — upper-body derékdőlés + bot tilt (nincs whole-body pitch)
            if IsDisabledControlPressed(0, Config.Controls.aim) and (mode == 'idle' or mode == 'aim') then
                clearWaterPoseFlag()
                clearCastLeanRecover()
                mode = 'aim'
                if IsDisabledControlJustPressed(0, Config.Controls.cast) then
                    casting = true
                    throwingTension = 0.0
                    chargeStart = now
                end
                if casting and IsDisabledControlPressed(0, Config.Controls.cast) then
                    throwingTension = math.min(1.0, throwingTension + dt / 2.0)
                    holdCastLeanPose(throwingTension)
                elseif casting and IsDisabledControlJustReleased(0, Config.Controls.cast) then
                    casting = false
                    beginThrow()
                else
                    if not casting then
                        throwingTension = math.max(0.0, throwingTension - dt / 2.0)
                    end
                    holdCastLeanPose(math.max(throwingTension, 0.0))
                end
            elseif mode == 'aim' and not IsDisabledControlPressed(0, Config.Controls.aim) then
                mode = 'idle'
                casting = false
                throwingTension = 0.0
                castLeanFrameAmount = 0.0
                clearCastLeanRecover()
                clearCastLeanPitch()
                clearWaterPoseFlag()
                playFishAnim(Config.FishAnims.idle, nil)
            elseif mode == 'throw' or mode == 'waiting' or mode == 'catching' or mode == 'catched' then
                if not updateCastLeanRecover(now) then
                    ensureWaterPose()
                end
            elseif mode == 'getout' then
                clearCastLeanRecover()
                clearCastLeanPitch()
                castLeanFrameAmount = 0.0
                local p = math.min(1.0, (now - getOutStart) / (Config.GetOutMs or 4000))
                local need = fishKey and 1.0 or 0.5
                if p >= need then
                    finishGetOut()
                end
            elseif mode == 'idle' then
                clearWaterPoseFlag()
                clearCastLeanRecover()
                clearCastLeanPitch()
                castLeanFrameAmount = 0.0
                ensureIdleAnim()
            end

            if mode ~= 'throw' and mode ~= 'waiting' and mode ~= 'catching' and mode ~= 'catched' then
                -- Mute once (audio API throttles duplicates)
                local au = Audio()
                if au and au.Reset then
                    -- only soft-mute loops, don't reset creak state every frame
                    au.ProcessReel(0)
                    au.ProcessSpindle(0)
                end
            end

            local tipX, tipY, tipZ = WGLine.GetRodTip(rodObj, ped)
            if not tipX then
                tipX, tipY, tipZ = 0.0, 0.0, 0.0
            end

            -- Idle/aim bobber dangle (v4: float already hangs off the rod tip before casting)
            if (mode == 'idle' or mode == 'aim') and (tonumber(floatIndex) or 0) >= 1 then
                local hangX, hangY, hangZ = tipX, tipY, tipZ - 0.5
                if not floatPos then
                    floatPos = { hangX, hangY, hangZ }
                    WGFloat.Spawn(vector3(hangX, hangY, hangZ), floatIndex)
                end
                local dx = hangX - floatPos[1]
                local dy = hangY - floatPos[2]
                local dz = hangZ - floatPos[3]
                local len = math.sqrt(dx * dx + dy * dy + dz * dz)
                if len > 0.001 then
                    local ease = math.min(1.0, (dt * 1000.0) / 75.0)
                    floatPos[1] = floatPos[1] + dx * ease
                    floatPos[2] = floatPos[2] + dy * ease
                    floatPos[3] = floatPos[3] + dz * ease
                end
                local vx, vy, vz = floatPos[1] - tipX, floatPos[2] - tipY, floatPos[3] - tipZ
                local vlen = math.sqrt(vx * vx + vy * vy + vz * vz)
                local drawX, drawY, drawZ = floatPos[1], floatPos[2], floatPos[3]
                if vlen > 0.5 then
                    drawX = tipX + vx / vlen * 0.5
                    drawY = tipY + vy / vlen * 0.5
                    drawZ = tipZ + vz / vlen * 0.5
                end
                WGFloat.SetPos(drawX, drawY, drawZ)
                WGFloat.SetRot(180.0, 0.0, 0.0)
                WGLine.Draw(rodObj, ped, drawX, drawY, drawZ, lineColor, 0.0)
            elseif floatPos and mode ~= 'throw' and mode ~= 'waiting' and mode ~= 'catching' and mode ~= 'catched' then
                clearFloat()
            end

            -- Throw ballistic + in-water float update
            if floatPos and (mode == 'throw' or mode == 'waiting' or mode == 'catching' or mode == 'catched') then
                local x, y, z = floatPos[1], floatPos[2], floatPos[3]
                local ended = false

                if throwForce then
                    local a = phys.throwHorizAccel or -22.0
                    local s = math.max(0.0, throwForce[3] * dt + 0.5 * a * dt * dt)
                    throwForce[3] = math.max(0.0, throwForce[3] + a * dt)
                    x = x + throwForce[1] * s
                    y = y + throwForce[2] * s
                    local g = phys.throwGravity or -9.8
                    z = z + throwForce[4] * dt + 0.5 * g * dt * dt
                    throwForce[4] = throwForce[4] + g * dt
                    z = math.max(-2.0, z)
                    floatPos[1], floatPos[2], floatPos[3] = x, y, z
                end

                local deep, waterZ, depthVal = waterDepthAt(x, y, z)
                if depthVal then deepness = depthVal end
                if waterZ then
                    if z > waterZ then
                        -- still airborne
                    else
                        z = waterZ
                        floatPos[3] = z
                    end
                end

                if mode == 'throw' and throwForce then
                    local landed = throwForce[3] <= 0 and throwForce[4] <= 0 and waterZ and z <= (waterZ + 0.05)
                    if not landed and waterZ and z <= waterZ and throwForce[4] <= 0 then
                        landed = true
                    end
                    if landed then
                        throwForce = nil
                        floatPos[3] = waterZ or z
                        x, y, z = floatPos[1], floatPos[2], floatPos[3]
                        local dist = #(vector3(tipX, tipY, tipZ) - vector3(x, y, z))
                        lineLength = math.max(0.5, dist - 0.125)
                        if deep then
                            floatingValue = 1.0
                            enterWaiting()
                        else
                            QBCore.Functions.Notify('Itt nem elég mély a víz a horgászathoz.', 'error')
                            beginGetOut(false)
                            ended = true
                        end
                    else
                        local dist = #(vector3(tipX, tipY, tipZ) - vector3(x, y, z))
                        lineLength = math.max(0.125, dist - 0.125)
                    end
                end

                if not ended and floatPos and (mode == 'waiting' or mode == 'catching' or mode == 'catched' or mode == 'throw') then
                    -- float bob / underwater
                    local dipDepth = (phys.biteDipDepth or 2.15)
                    if mode == 'catched' then
                        lineUnderwater = math.min(1.0, lineUnderwater + 2.8 * dt)
                    elseif mode == 'catching' then
                        -- götgetés: erőteljesebb merülés a rántásokkal
                        local pulse = catchingForce and math.max(0.0, catchingForce[3] or 0.0) or 0.0
                        local targetDip = 0.45 + math.min(0.55, pulse * 0.12)
                        if lineUnderwater < targetDip then
                            lineUnderwater = math.min(targetDip, lineUnderwater + 6.0 * dt)
                        else
                            lineUnderwater = math.max(0.25, lineUnderwater - 1.5 * dt)
                        end
                    else
                        lineUnderwater = math.max(0.0, lineUnderwater - 2.0 * dt)
                    end
                    local drawZ = floatPos[3] - lineUnderwater * dipDepth
                    x, y, z = floatPos[1], floatPos[2], floatPos[3]

                    if mode == 'waiting' or mode == 'catching' or mode == 'catched' then
                        applyScrollImpulse()
                        decayLineVel(dt)

                        local floaterDistance = #(vector3(tipX, tipY, tipZ) - vector3(x, y, drawZ))
                        rawTension = (floaterDistance - lineLength) / (phys.tensionDiv or 1.5)
                        smoothTension(rawTension, dt)

                        local vx = tipX - x
                        local vy = tipY - y
                        local len2 = math.sqrt(vx * vx + vy * vy)
                        if len2 > 0.001 then
                            vx, vy = vx / len2, vy / len2
                            local a = math.abs(tension)
                            if a > 0.1 then
                                local t = tension - 0.1 * (tension / a)
                                local speed = 0.5
                                if tension > 0 then
                                    speed = 5 + (1 - (mode == 'catched' and (fishWeight or 0) / 60 or 0)) * 12
                                else
                                    t = math.min(-0.25, t)
                                end
                                t = t * speed
                                floatPos[1] = floatPos[1] + vx * t * dt
                                floatPos[2] = floatPos[2] + vy * t * dt
                                x, y = floatPos[1], floatPos[2]
                            end
                        end

                        if mode == 'catching' then
                            local fMin = phys.biteForceMin or 2.8
                            local fMax = phys.biteForceMax or 5.5
                            local fDecay = phys.biteForceDecay or 3.2
                            if not catchingForce then
                                local rad = math.random() * math.pi * 2
                                catchingForce = { math.cos(rad), math.sin(rad), fMin + math.random() * (fMax - fMin) }
                            end
                            catchingForce[3] = catchingForce[3] - fDecay * dt
                            if catchingForce[3] > 0 then
                                floatPos[1] = floatPos[1] + catchingForce[1] * catchingForce[3] * dt
                                floatPos[2] = floatPos[2] + catchingForce[2] * catchingForce[3] * dt
                            else
                                local rad = math.random() * math.pi * 2
                                catchingForce = { math.cos(rad), math.sin(rad), fMin + math.random() * (fMax - fMin) }
                            end
                            local sink = phys.biteFloatSink or 2.4
                            local floor = phys.biteFloatFloor or 0.05
                            floatingValue = math.max(floor, floatingValue - sink * dt)
                            if tension > (Config.HookTension or 0.25) then
                                TriggerServerEvent('wellgame_fishing:server:hook')
                                mode = 'catched'
                                setGotFishState('catched')
                                fishEnergy = 1.0
                                fishMinimumDistance = lineLength
                                fishPosition = { floatPos[1], floatPos[2] }
                                catchStartAt = now
                            end
                        end

                        if mode == 'catched' and floatPos then
                            if updateCatchedFishAI(dt, tipX, tipY, waterZ) or not floatPos then
                                ended = true
                            else
                                x, y = floatPos[1], floatPos[2]
                            end
                        end

                        if floatPos then
                            -- Auto-payout under load (keeps fight catchable; gear 1 loosest)
                            local payout = math.max(0.0, tension) * (phys.autoPayout or 5.5) / gearMul()
                            if spindleGear() <= 1 then
                                payout = payout * 1.5
                            end
                            local vel = lineVelocity + payout
                            if vel > 0 and lineLength >= 100 then vel = 0 end
                            lineLength = math.max(0.5, lineLength + vel * dt)
                            spindleRoll = spindleRoll - lineVelocity * dt * 0.35
                            local au = Audio()
                            if au then
                                -- v4: reel loop from total line vel (payout > 0); spindle from handle spin
                                au.ProcessReel(vel)
                                au.ProcessSpindle(math.abs(lineVelocity) * 5.0)
                                au.ProcessCreak(tension, dt)
                            end

                            local floater2D = #(vector2(tipX, tipY) - vector2(x, y))

                            -- Snap only from sustained real over-tension / hard distance — no LOS false snaps
                            local snapLim = (Config.SnapTension or 1.25)
                            if tension > snapLim then
                                snapOverTime = snapOverTime + dt
                            else
                                snapOverTime = math.max(0.0, snapOverTime - dt * 2.5)
                            end
                            local snapHold = (Config.Physics and Config.Physics.snapHoldSec) or 0.85
                            local shouldSnap = snapOverTime >= snapHold or floaterDistance > (Config.MaxLineDist or 105.0)

                            if shouldSnap then
                                doSnap(true, 'Elszakadt a damil!')
                                ended = true
                            elseif tension < (Config.TangleTension or -3.5) then
                                doSnap(false, 'Összecsomósodott a damilod!')
                                ended = true
                            elseif floater2D <= (Config.LandDistance2D or 1.0) and mode ~= 'throw' and mode ~= 'catching' then
                                if mode == 'catched' and fishKey then
                                    beginGetOut(true)
                                else
                                    beginGetOut(false)
                                end
                                ended = true
                            -- Shallow escape only if still far from shore (not mid-land)
                            elseif not deep and mode == 'catched' and floater2D > 3.0 then
                                if not (fishMinimumDistance and lineLength < fishMinimumDistance * 1.25) then
                                    QBCore.Functions.Notify('Elúszott a hal!', 'error')
                                    fishKey = nil
                                    beginGetOut(false)
                                    ended = true
                                end
                            end
                        end
                    end

                    -- draw only if float still exists (snap/getout törölheti)
                    if not ended and floatPos then
                        drawZ = floatPos[3] - lineUnderwater * (phys.biteDipDepth or 2.15)
                        WGFloat.SetPos(floatPos[1], floatPos[2], drawZ)
                        local deg = math.deg(math.atan2(tipY - floatPos[2], tipX - floatPos[1]))
                        WGFloat.SetRot(
                            180.0 * (1.0 - (floatingValue or 0)),
                            90.0 * math.abs(tension) * (tension < 0 and 0.15 or 1.0),
                            deg + (tension < 0 and 180.0 or 0.0)
                        )
                        WGLine.Draw(rodObj, ped, floatPos[1], floatPos[2], drawZ, lineColor, tension)
                    end
                end
            end

            hudTension = smoothToward(hudTension, math.max(0.0, tension), 8.0, dt)

            if rodObj and DoesEntityExist(rodObj) and not IsEntityAttachedToEntity(rodObj, ped) then
                bindRodToHand()
            end

            -- MP sync push
            if floatPos and (mode == 'throw' or mode == 'waiting' or mode == 'catching' or mode == 'catched') then
                TriggerEvent('wellgame_fishing:client:localSyncPush', {
                    mode = mode,
                    floatPos = { floatPos[1], floatPos[2], floatPos[3] },
                    lineLength = lineLength,
                    spindleGear = spindleGear(),
                    fish = mode == 'catched' and fishKey or nil,
                    throwForce = throwForce and true or false,
                    line = lineColor,
                })
            end

            updateHud()
            Wait(0)
        else
            lastPhysTick = 0
            gearUpHeld, gearDownHeld = false, false
            Wait(400)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    stopFishing()
end)

-- Export for sync / stand
exports('IsFishingActive', function() return active end)
exports('GetFishingMode', function() return mode end)
exports('GetRodObject', function() return rodObj end)

-- Élő kalibráló a bot-végpont eltolásához (Config.RodTipOffset), mivel ez a lokális
-- rod-modell-térben van megadva és csak élőben, a renderelést látva lehet pontosan eltalálni.
-- Használat: /fishtipcalib <x> <y> <z> — újra csatolja a jelzőt az új offszettel.
--           /fishtipshow — láthatóvá teszi a jelzőt (piros golflabda) kalibráláshoz.
local tipCalibVisible = false
RegisterCommand('fishtipcalib', function(_, args)
    local x = tonumber(args[1]) or Config.RodTipOffset.x
    local y = tonumber(args[2]) or Config.RodTipOffset.y
    local z = tonumber(args[3]) or Config.RodTipOffset.z
    Config.RodTipOffset = vector3(x, y, z)
    cachedTipOff = nil
    cachedTipModel = nil
    if rodObj and DoesEntityExist(rodObj) then
        WGLine.AttachTipMarker(rodObj)
        if tipCalibVisible and tipMarker then
            SetEntityVisible(tipMarker, true, false)
            SetEntityAlpha(tipMarker, 255, false)
        end
    end
    QBCore.Functions.Notify(('RodTipOffset = %.3f, %.3f, %.3f'):format(x, y, z), 'primary', 6000)
end, false)

RegisterCommand('fishtipshow', function()
    tipCalibVisible = not tipCalibVisible
    if tipMarker and DoesEntityExist(tipMarker) then
        SetEntityVisible(tipMarker, tipCalibVisible, false)
        SetEntityAlpha(tipMarker, tipCalibVisible and 255 or 0, false)
    end
    QBCore.Functions.Notify('Tip marker: ' .. (tipCalibVisible and 'látható' or 'rejtett'), 'primary')
end, false)
