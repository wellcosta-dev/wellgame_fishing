-- Fishing audio — looping reel/spindle (volume only, throttled NUI, no playbackRate)

local lastTension = 0.0
local lastCreak = 0
local lastReelVol = -1.0
local lastSpindleVol = -1.0
local VOL_EPS = 0.02

local function nuiSound(file, vol)
    SendNUIMessage({ action = 'playSound', file = file, volume = vol or 0.4 })
end

local function nuiLoop(id, file, volume)
    volume = math.max(0.0, math.min(1.0, tonumber(volume) or 0.0))
    local prev = id == 'reel' and lastReelVol or lastSpindleVol
    -- Skip tiny changes; always send mute↔unmute edges
    local edge = (volume <= 0.001) ~= (prev <= 0.001)
    if prev >= 0.0 and not edge and math.abs(volume - prev) < VOL_EPS then
        return
    end
    if id == 'reel' then
        lastReelVol = volume
    else
        lastSpindleVol = volume
    end
    SendNUIMessage({
        action = 'loopSound',
        id = id,
        file = file,
        volume = volume,
    })
end

local API = {}

function API.OneShot(file, vol)
    nuiSound(file, vol)
end

function API.Cast()
    nuiSound('woosh.mp3', 0.45)
end

function API.Splash()
    nuiSound('splash.mp3', 0.45)
end

function API.WaterOut()
    nuiSound('waterout.mp3', 0.4)
end

function API.Snap()
    nuiSound('snap.mp3', 0.5)
end

function API.Gear()
    nuiSound('gear.mp3', 0.3)
end

--- v4 processReelSound volume curve — quieter, rate fixed in NUI
function API.ProcessReel(spd)
    spd = tonumber(spd) or 0.0
    if spd <= 0.0 then
        nuiLoop('reel', 'reel.mp3', 0.0)
        return
    end
    local s = spd / 10.0
    local vol = math.min(0.38, math.min(1.0, s * 2.4) * 0.32)
    nuiLoop('reel', 'reel.mp3', vol)
end

--- v4 processSpindleSound — scroll/handle; keep softer to avoid mud with reel
function API.ProcessSpindle(spd)
    spd = tonumber(spd) or 0.0
    if spd <= 0.0 then
        nuiLoop('spindle', 'spindle.mp3', 0.0)
        return
    end
    local s = spd / 7.5
    local vol = math.min(0.32, math.min(1.0, s * 2.2) * 0.22)
    nuiLoop('spindle', 'spindle.mp3', vol)
end

function API.ProcessCreak(tension, dt)
    local creak = 0.0
    if dt and dt > 0 then
        creak = ((tension or 0) - lastTension) / dt * 25.0 * math.min(1.0, math.max(0.0, (tension or 0) / 0.5))
    end
    lastTension = tension or 0.0
    if creak > 0.28 then
        local now = GetGameTimer()
        if now - lastCreak >= 400 then
            lastCreak = now
            nuiSound('creak.mp3', math.min(0.18, creak / 0.2 * 0.12))
        end
    end
end

function API.Reset()
    lastTension = 0.0
    lastCreak = 0
    lastReelVol = -1.0
    lastSpindleVol = -1.0
    SendNUIMessage({ action = 'loopSound', id = 'reel', file = 'reel.mp3', volume = 0.0 })
    SendNUIMessage({ action = 'loopSound', id = 'spindle', file = 'spindle.mp3', volume = 0.0 })
    lastReelVol = 0.0
    lastSpindleVol = 0.0
end

exports('GetAudio', function()
    return API
end)
