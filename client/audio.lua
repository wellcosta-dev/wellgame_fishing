-- Fishing audio API (exported — lua54 safe across files)
-- Rate-limited one-shots via NUI sound pool (avoids overlapping crackle)

local lastReel, lastSpindle, lastCreak = 0, 0, 0
local lastTension = 0.0

local function nuiSound(file, vol)
    SendNUIMessage({ action = 'playSound', file = file, volume = vol or 0.4 })
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

function API.ProcessReel(spd)
    local now = GetGameTimer()
    if not spd or spd <= 0.12 then return end
    local vol = math.min(0.28, (spd / 8.0) * 0.22)
    -- Long interval — one overlapping Audio() stack was the crackle source
    local interval = math.max(220, math.floor(380 / math.max(0.35, spd / 4.0)))
    if now - lastReel >= interval then
        lastReel = now
        nuiSound('reel.mp3', vol)
    end
end

function API.ProcessSpindle(spd)
    local now = GetGameTimer()
    if not spd or spd <= 0.12 then return end
    local vol = math.min(0.3, (spd / 8.0) * 0.25)
    if now - lastSpindle >= 280 then
        lastSpindle = now
        nuiSound('spindle.mp3', vol)
    end
end

function API.ProcessCreak(tension, dt)
    local creak = 0.0
    if dt and dt > 0 then
        creak = ((tension or 0) - lastTension) / dt * 25.0 * math.min(1.0, math.max(0.0, (tension or 0) / 0.5))
    end
    lastTension = tension or 0.0
    -- Higher threshold + slower fire = less recsegés
    if creak > 0.22 then
        local now = GetGameTimer()
        if now - lastCreak >= 350 then
            lastCreak = now
            nuiSound('creak.mp3', math.min(0.35, creak / 0.2 * 0.22))
        end
    end
end

function API.Reset()
    lastTension = 0.0
    lastReel, lastSpindle, lastCreak = 0, 0, 0
end

exports('GetAudio', function()
    return API
end)
