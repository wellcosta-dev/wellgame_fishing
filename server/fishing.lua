local QBCore = exports['qb-core']:GetCoreObject()

-- Player.Functions.{GetItemBySlot,GetItemByName,AddItem,RemoveItem} don't exist on this
-- QBCore fork (inventory access is fully delegated to qb-inventory) — every call site below
-- used to silently error out mid-handler, which is why rods/bait/line/float never actually
-- got consumed or granted. Route everything through the real qb-inventory exports instead.
local function invGetBySlot(src, slot)
    return exports['qb-inventory']:GetItemBySlot(src, slot)
end

local function invGetByName(src, name)
    return exports['qb-inventory']:GetItemByName(src, name)
end

local function invAddItem(src, item, amount, info)
    return exports['qb-inventory']:AddItem(src, item, amount, false, info or {})
end

local function invRemoveItem(src, item, amount, slot)
    return exports['qb-inventory']:RemoveItem(src, item, amount, slot)
end

local fishing = {} -- [src] = session

local castRate = {} -- [src] = { times = {}, lastSell = 0 }

-- Tournament: cumulative weight over a scheduled day-based window (v4: characters.fishingWeight
-- + fishingEvent.json), with self-rank feedback and a win celebration when the event ends.
local tournament = {
    active = false,
    startDay = 0,
    endDay = 0,
    scores = {}, -- [citizenid] = { name, weight, fish, at } (cumulative weight)
}

local function currentDayIndex()
    return math.floor(os.time() / 86400)
end

local function saveTournamentState()
    SaveResourceFile(GetCurrentResourceName(), 'tournament_state.json', json.encode({
        active = tournament.active,
        startDay = tournament.startDay,
        endDay = tournament.endDay,
    }), -1)
end

local function loadTournamentState()
    local raw = LoadResourceFile(GetCurrentResourceName(), 'tournament_state.json')
    if not raw then return end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == 'table' then
        tournament.active = data.active == true
        tournament.startDay = tonumber(data.startDay) or 0
        tournament.endDay = tonumber(data.endDay) or 0
    end
end

local function tournamentTop()
    local list = {}
    for _, row in pairs(tournament.scores) do
        list[#list + 1] = row
    end
    table.sort(list, function(a, b) return (a.weight or 0) > (b.weight or 0) end)
    local n = (Config.Tournament and Config.Tournament.topN) or 10
    local out = {}
    for i = 1, math.min(n, #list) do out[i] = list[i] end
    return out
end

local function saveTournamentScore(cid, name, weight, fish)
    if not (Config.Tournament and Config.Tournament.useDatabase) then return end
    if not MySQL then return end
    pcall(function()
        MySQL.query.await([[
            INSERT INTO wellgame_fishing_tournament (citizenid, name, weight, fish, updated_at)
            VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              name = VALUES(name),
              fish = VALUES(fish),
              weight = weight + VALUES(weight),
              updated_at = VALUES(updated_at)
        ]], { cid, name, weight, fish, os.time() })
    end)
end

-- Self-migrating: creates the two tables the prize/pending-payout and catch-log features
-- need, so the resource works out of the box without requiring sql/tournament.sql to be run
-- by hand (that file is kept as a reference / for manual DBA review, not a hard requirement).
local function ensureFishingTables()
    if not MySQL then return end
    pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS wellgame_fishing_pending_prizes (
              citizenid VARCHAR(50) NOT NULL,
              cash INT NOT NULL DEFAULT 0,
              pp INT NOT NULL DEFAULT 0,
              reason VARCHAR(100) NOT NULL DEFAULT '',
              created_at INT NOT NULL DEFAULT 0,
              PRIMARY KEY (citizenid)
            )
        ]])
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS wellgame_fishing_log (
              citizenid VARCHAR(50) NOT NULL,
              fish_key VARCHAR(64) NOT NULL,
              count INT NOT NULL DEFAULT 0,
              best_weight FLOAT NOT NULL DEFAULT 0,
              best_length INT NOT NULL DEFAULT 0,
              first_caught_at INT NOT NULL DEFAULT 0,
              last_caught_at INT NOT NULL DEFAULT 0,
              PRIMARY KEY (citizenid, fish_key)
            )
        ]])
    end)
end

local function loadTournamentFromDb()
    if not (Config.Tournament and Config.Tournament.useDatabase) then return end
    if not MySQL then return end
    pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS wellgame_fishing_tournament (
              citizenid VARCHAR(50) NOT NULL,
              name VARCHAR(100) NOT NULL DEFAULT '',
              weight FLOAT NOT NULL DEFAULT 0,
              fish VARCHAR(64) NOT NULL DEFAULT '',
              updated_at INT NOT NULL DEFAULT 0,
              PRIMARY KEY (citizenid)
            )
        ]])
        local rows = MySQL.query.await('SELECT citizenid, name, weight, fish, updated_at FROM wellgame_fishing_tournament ORDER BY weight DESC LIMIT 50')
        if type(rows) == 'table' then
            for i = 1, #rows do
                local r = rows[i]
                tournament.scores[r.citizenid] = {
                    cid = r.citizenid,
                    name = r.name,
                    weight = tonumber(r.weight) or 0,
                    fish = r.fish,
                    at = tonumber(r.updated_at) or 0,
                }
            end
        end
    end)
end

--- Rank of a citizenid across ALL saved scores (not just the cached top-50) — v4's self-rank query.
local function tournamentSelfRank(weight)
    if not (Config.Tournament and Config.Tournament.useDatabase) then return nil end
    if not MySQL then return nil end
    local ok, rows = pcall(function()
        return MySQL.query.await('SELECT COUNT(*) + 1 AS rnk FROM wellgame_fishing_tournament WHERE weight > ?', { weight })
    end)
    if ok and type(rows) == 'table' and rows[1] then
        return tonumber(rows[1].rnk)
    end
    return nil
end

local function broadcastTournamentBoard()
    TriggerClientEvent('wellgame_fishing:client:tournamentBoard', -1, { active = tournament.active, top = tournamentTop() })
end

local function formatMoney(n)
    n = math.floor(tonumber(n) or 0)
    local s = tostring(n)
    local out = s:reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^%s+', '')
    return out
end

-- Pays the tournament prize into a player's bank + premium points (metadata.premiumPoints,
-- same field wellgame_admin's economy tools use). If they're offline when the tournament
-- ends, the prize waits in wellgame_fishing_pending_prizes and is paid on their next login.
local function payTournamentPrize(cid, name)
    local prize = Config.Tournament and Config.Tournament.prize
    if not prize or (not prize.cash and not prize.pp) then return end
    local cash = math.floor(tonumber(prize.cash) or 0)
    local pp = math.floor(tonumber(prize.pp) or 0)
    if cash <= 0 and pp <= 0 then return end

    local Player = QBCore.Functions.GetPlayerByCitizenId(cid)
    if Player then
        local src = Player.PlayerData.source
        if cash > 0 then
            Player.Functions.AddMoney('bank', cash, 'wellgame-fishing-tournament-prize')
        end
        if pp > 0 then
            local oldPp = math.floor(tonumber((Player.PlayerData.metadata or {}).premiumPoints) or 0)
            local newPp = oldPp + pp
            Player.Functions.SetMetaData('premiumPoints', newPp)
            TriggerClientEvent('hud:client:OnPPChange', src, newPp, pp, false)
        end
        TriggerClientEvent('QBCore:Notify', src,
            ('Gratulálunk! Megnyerted a horgászversenyt: %s $ és %s PP a számládon.'):format(formatMoney(cash), formatMoney(pp)), 'success')
        return
    end

    if not MySQL then return end
    pcall(function()
        MySQL.query.await([[
            INSERT INTO wellgame_fishing_pending_prizes (citizenid, cash, pp, reason, created_at)
            VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE cash = cash + VALUES(cash), pp = pp + VALUES(pp), created_at = VALUES(created_at)
        ]], { cid, cash, pp, 'tournament', os.time() })
    end)
end

-- Catch-up: if the tournament ended while the winner was offline, pay them the moment they log in.
AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    if not MySQL or not Player then return end
    local cid = Player.PlayerData.citizenid
    CreateThread(function()
        local ok, row = pcall(function()
            return MySQL.single.await('SELECT * FROM wellgame_fishing_pending_prizes WHERE citizenid = ?', { cid })
        end)
        if not ok or not row then return end

        local src = Player.PlayerData.source
        local cash = math.floor(tonumber(row.cash) or 0)
        local pp = math.floor(tonumber(row.pp) or 0)
        if cash > 0 then
            Player.Functions.AddMoney('bank', cash, 'wellgame-fishing-tournament-prize')
        end
        if pp > 0 then
            local oldPp = math.floor(tonumber((Player.PlayerData.metadata or {}).premiumPoints) or 0)
            local newPp = oldPp + pp
            Player.Functions.SetMetaData('premiumPoints', newPp)
            TriggerClientEvent('hud:client:OnPPChange', src, newPp, pp, false)
        end
        MySQL.query('DELETE FROM wellgame_fishing_pending_prizes WHERE citizenid = ?', { cid })
        TriggerClientEvent('QBCore:Notify', src,
            ('A legutóbbi horgászverseny nyereményed megérkezett: %s $ és %s PP.'):format(formatMoney(cash), formatMoney(pp)), 'success')
    end)
end)

RegisterNetEvent('wellgame_fishing:server:requestTournamentState', function()
    local src = source
    TriggerClientEvent('wellgame_fishing:client:tournamentBoard', src, { active = tournament.active, top = tournamentTop() })
end)

local function endTournament(announce)
    tournament.active = false
    saveTournamentState()
    local top = tournamentTop()
    broadcastTournamentBoard()
    if announce and top[1] then
        local winner = top[1]
        TriggerClientEvent('QBCore:Notify', -1, 'Horgászverseny vége!', 'primary')
        TriggerClientEvent('wellgame_fishing:client:tournamentWin', -1, {
            name = winner.name,
            weight = winner.weight,
            fish = winner.fish,
        })

        local prize = Config.Tournament and Config.Tournament.prize
        if winner.cid then
            payTournamentPrize(winner.cid, winner.name)
        end
        if prize and (prize.cash or prize.pp) then
            TriggerClientEvent('chat:addMessage', -1, {
                template = '<div style="padding:2px 0;"><span style="color:#f5b942;">[Wellcosta - Horgászverseny]:</span> <span style="color:#ffffff;">Győztes: </span><span style="color:#3cb882;">{0}</span><span style="color:#ffffff;"> — {1} kg összsúllyal. Nyereménye: </span><span style="color:#3cb882;">{2} $</span><span style="color:#ffffff;"> és </span><span style="color:#3cb882;">{3} PP</span><span style="color:#ffffff;">!</span></div>',
                args = {
                    tostring(winner.name or '?'),
                    tostring(math.floor((winner.weight or 0) * 10) / 10),
                    formatMoney(prize.cash or 0),
                    formatMoney(prize.pp or 0),
                },
            })
        end
    end
end

CreateThread(function()
    Wait(2000)
    ensureFishingTables()
    loadTournamentState()
    loadTournamentFromDb()
end)

-- Napi ellenőrzés: automatikusan lezárja + kihirdeti a győztest, ha lejárt az esemény (v4: fishingEventEnd)
CreateThread(function()
    while true do
        Wait(60000)
        if tournament.active and tournament.endDay > 0 and currentDayIndex() >= tournament.endDay then
            endTournament(true)
        end
    end
end)

-- "Kedvcsináló" — amíg fut a verseny, rendszeres chat-hirdetés az aktuális állásról, hogy
-- azok is csatlakozzanak, akik lemaradtak az induló bejelentésről.
CreateThread(function()
    while true do
        Wait((Config.Tournament and Config.Tournament.hypeIntervalMs) or 600000)
        if tournament.active then
            local top = tournamentTop()
            local daysLeft = math.max(0, (tournament.endDay or 0) - currentDayIndex())
            local prize = Config.Tournament and Config.Tournament.prize

            local leaderText
            if top[1] then
                leaderText = ('Jelenlegi élen: <span style="color:#3cb882;">%s</span> (%s kg)'):format(
                    tostring(top[1].name or '?'), tostring(math.floor((top[1].weight or 0) * 10) / 10))
            else
                leaderText = 'Még senki nem fogott halat — legyél te az első!'
            end

            local prizeText = ''
            if prize and (prize.cash or prize.pp) then
                prizeText = (' Fődíj: <span style="color:#3cb882;">%s $</span> és <span style="color:#3cb882;">%s PP</span>.'):format(
                    formatMoney(prize.cash or 0), formatMoney(prize.pp or 0))
            end

            TriggerClientEvent('chat:addMessage', -1, {
                template = ('<div style="padding:2px 0;"><span style="color:#f5b942;">[Wellcosta - Horgászverseny]:</span> <span style="color:#ffffff;">Fut a verseny, még %d napig! %s%s</span></div>')
                    :format(daysLeft, leaderText, prizeText),
                args = {},
            })
        end
    end
end)

-- Personal catch log — one upsert per catch, feeds the /fishlog NUI collection screen.
local function recordCatchLog(cid, fishKey, weight, length)
    if not MySQL or not cid or not fishKey then return end
    weight = tonumber(weight) or 0
    length = tonumber(length) or 0
    local now = os.time()
    pcall(function()
        MySQL.query.await([[
            INSERT INTO wellgame_fishing_log (citizenid, fish_key, count, best_weight, best_length, first_caught_at, last_caught_at)
            VALUES (?, ?, 1, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              count = count + 1,
              best_weight = GREATEST(best_weight, VALUES(best_weight)),
              best_length = GREATEST(best_length, VALUES(best_length)),
              last_caught_at = VALUES(last_caught_at)
        ]], { cid, fishKey, weight, length, now, now })
    end)
end

-- ---------------------------------------------------------------------
-- Progression (horgász szint) + hotspot + napszak/időjárás bónusz
-- ---------------------------------------------------------------------

local playerCatchTotals = {} -- [src] = lifetime catches across all species (cached, not re-queried per cast)

local function loadCatchTotal(src, cid)
    if not MySQL then playerCatchTotals[src] = 0 return end
    local ok, row = pcall(function()
        return MySQL.single.await('SELECT SUM(count) AS total FROM wellgame_fishing_log WHERE citizenid = ?', { cid })
    end)
    playerCatchTotals[src] = (ok and row and tonumber(row.total)) or 0
end

local function ensureCatchTotal(src, cid)
    if playerCatchTotals[src] == nil then loadCatchTotal(src, cid) end
    return playerCatchTotals[src] or 0
end

function fisherLevel(totalCatches)
    local prog = Config.Progression
    if not prog or not prog.enabled then return 1 end
    local perLevel = prog.catchesPerLevel or 15
    return math.min(prog.maxLevel or 30, math.floor((totalCatches or 0) / perLevel) + 1)
end

-- Hotspot + napszak/időjárás bónusz a Legendary-osztályú halakra. Az időjárás-export
-- hívása pcall-ban van, mert qb-weathersync nélkül is futnia kell a resource-nak.
local function computeRareMultiplier(src, cid)
    local mult = 1.0

    if Config.Progression and Config.Progression.enabled then
        local level = fisherLevel(ensureCatchTotal(src, cid))
        mult = mult * (1.0 + (level - 1) * (Config.Progression.legendaryBonusPerLevel or 0))
    end

    local ped = GetPlayerPed(src)
    if ped ~= 0 then
        local coords = GetEntityCoords(ped)
        for _, hs in ipairs(Config.Hotspots or {}) do
            local dx, dy = coords.x - hs.coords.x, coords.y - hs.coords.y
            if math.sqrt(dx * dx + dy * dy) <= (hs.radius or 90.0) then
                mult = mult * (hs.rareBonus or 1.5)
                break
            end
        end
    end

    if GetResourceState('qb-weathersync') == 'started' then
        local okH, hour = pcall(function() return exports['qb-weathersync']:getTime() end)
        if okH and hour and (hour >= 21 or hour < 6) then
            mult = mult * (Config.NightRareBonus or 1.0)
        end
        local okW, weather = pcall(function() return exports['qb-weathersync']:getWeatherState() end)
        if okW and weather and Config.RareWeatherTypes and Config.RareWeatherTypes[weather] then
            mult = mult * (Config.RareWeatherBonus or 1.0)
        end
    end

    return mult
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    if not Player then return end
    loadCatchTotal(Player.PlayerData.source, Player.PlayerData.citizenid)
end)

AddEventHandler('playerDropped', function()
    playerCatchTotals[source] = nil
end)

QBCore.Functions.CreateCallback('wellgame_fishing:server:getLog', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not MySQL then cb({}, 1) return end
    local ok, rows = pcall(function()
        return MySQL.query.await(
            'SELECT fish_key, count, best_weight, best_length, first_caught_at, last_caught_at FROM wellgame_fishing_log WHERE citizenid = ?',
            { Player.PlayerData.citizenid }
        )
    end)
    cb(ok and type(rows) == 'table' and rows or {}, fisherLevel(ensureCatchTotal(source, Player.PlayerData.citizenid)))
end)

local function notify(src, typ, msg)
    TriggerClientEvent('QBCore:Notify', src, msg, typ or 'primary')
end

local function setItemInfo(src, slot, key, val)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    local item = Player.PlayerData.items[slot]
    if not item then return false end
    item.info = item.info or {}
    item.info[key] = val
    Player.PlayerData.items[slot] = item
    Player.Functions.SetPlayerData('items', Player.PlayerData.items)
    return true
end

local function getItemInfo(item, key, default)
    if not item or type(item.info) ~= 'table' then return default end
    local v = item.info[key]
    if v == nil then return default end
    return v
end

function GetFishing(src)
    return fishing[src]
end

function SetFishingMode(src, mode, syncAll)
    local data = fishing[src]
    if not data then return end
    data.mode = mode
    if syncAll then
        TriggerClientEvent('wellgame_fishing:client:sync', src, data)
    else
        TriggerClientEvent('wellgame_fishing:client:setMode', src, mode, data.fish, data.fishWeight)
    end
end

exports('GetFishing', GetFishing)

local function clearFishingTimers(src)
    local data = fishing[src]
    if not data then return end
    if data.waitTimer then
        ClearTimeout(data.waitTimer)
        data.waitTimer = nil
    end
    if data.awayTimer then
        ClearTimeout(data.awayTimer)
        data.awayTimer = nil
    end
    data.waitGen = (data.waitGen or 0) + 1
    data.awayGen = (data.awayGen or 0) + 1
end

function CancelFishing(src, reason)
    local data = fishing[src]
    if not data then return end
    clearFishingTimers(src)
    fishing[src] = nil
    TriggerClientEvent('wellgame_fishing:client:stop', src)
    TriggerEvent('wellgame_fishing:server:broadcastSync', src, nil)
    if reason then notify(src, 'error', reason) end
end

exports('CancelFishing', CancelFishing)

local function setWait(src, ms, fn)
    local data = fishing[src]
    if not data then return end
    if data.waitTimer then ClearTimeout(data.waitTimer) end
    data.waitGen = (data.waitGen or 0) + 1
    local gen = data.waitGen
    data.waitTimer = SetTimeout(ms, function()
        local d = fishing[src]
        if not d or d.waitGen ~= gen then return end
        d.waitTimer = nil
        fn()
    end)
end

local function setAway(src, ms, fn)
    local data = fishing[src]
    if not data then return end
    if data.awayTimer then ClearTimeout(data.awayTimer) end
    data.awayGen = (data.awayGen or 0) + 1
    local gen = data.awayGen
    data.awayTimer = SetTimeout(ms, function()
        local d = fishing[src]
        if not d or d.awayGen ~= gen then return end
        d.awayTimer = nil
        fn()
    end)
end

local function trackCast(src)
    local ac = Config.AntiCheat or {}
    local maxC = ac.maxCastPerMin or 20
    castRate[src] = castRate[src] or { times = {}, lastSell = 0 }
    local now = os.time()
    local times = castRate[src].times
    local filtered = {}
    for i = 1, #times do
        if now - times[i] < 60 then filtered[#filtered + 1] = times[i] end
    end
    filtered[#filtered + 1] = now
    castRate[src].times = filtered
    return #filtered <= maxC
end

function StartBiteWait(src)
    local data = fishing[src]
    if not data or not data.hasBait then return end
    if data.mode ~= 'waiting' then return end
    local ms = math.random(Config.WaitMinMs or 10000, Config.WaitMaxMs or 37500)
    setWait(src, ms, function()
        local d = fishing[src]
        -- Strict: only bite while still waiting with bait in the water
        if not d or d.mode ~= 'waiting' or not d.hasBait then return end
        local biteMult = 1.0
        local biteCid = (QBCore.Functions.GetPlayer(src) or {}).PlayerData
        biteCid = biteCid and biteCid.citizenid or nil
        if biteCid then biteMult = computeRareMultiplier(src, biteCid) end

        local fish = ChooseRandomFish(biteMult)
        if not fish or not FishTypes[fish] then
            StartBiteWait(src)
            return
        end
        d.fish = fish
        d.fishWeight = RandomFishWeight(fish)
        d.hasBait = false
        d.mode = 'catching'
        d.biteAt = os.time()
        TriggerClientEvent('wellgame_fishing:client:bite', src, fish, d.fishWeight, FishTypes[fish])
        TriggerEvent('wellgame_fishing:server:broadcastSync', src, d)
        setAway(src, Config.GetAwayMs or 8000, function()
            local dd = fishing[src]
            if not dd or dd.mode ~= 'catching' then return end
            notify(src, 'error', 'Elúszott a hal, és elvitte a csalit!')
            dd.fish = nil
            dd.fishWeight = nil
            dd.mode = 'waiting'
            -- no bait left — must cast again to consume bait; stay waiting without restart bite
            TriggerClientEvent('wellgame_fishing:client:setMode', src, 'waiting')
            TriggerClientEvent('wellgame_fishing:client:fishGotAway', src)
            TriggerEvent('wellgame_fishing:server:broadcastSync', src, dd)
        end)
    end)
end

RegisterNetEvent('wellgame_fishing:server:start', function(slot)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if Config.License and Config.License.enabled and not Player.Functions.HasItem(Config.License.item, 1) then
        notify(src, 'error', 'Horgászengedély nélkül nem vethetsz horgot — vedd meg a boltban.')
        return
    end

    if fishing[src] then CancelFishing(src) end

    local item = invGetBySlot(src, slot)
    if not item or not Config.Rods[item.name] then
        notify(src, 'error', 'Érvénytelen horgászbot.')
        return
    end

    local info = item.info or {}
    local line = tonumber(info.line) or 0
    local wear = tonumber(info.wear) or 0
    local float = tonumber(info.float) or 0

    if not Config.LineColors[line] then
        notify(src, 'error', 'Nincs damil a horgászbotodon! (Használd a damil itemet a botra.)')
        return
    end
    if wear >= 100 then
        notify(src, 'error', 'Elhasználódott a damil!')
        return
    end
    if float < 1 or float > 4 then
        notify(src, 'error', 'Nincs úszó a horgászbotodon!')
        return
    end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    if GetVehiclePedIsIn(ped, false) ~= 0 then
        notify(src, 'error', 'Járműben nem horgászhatsz!')
        return
    end

    fishing[src] = {
        mode = 'idle',
        rodSlot = slot,
        rodName = item.name,
        line = line,
        wear = wear,
        float = float,
        hasBait = false,
        fish = nil,
        fishWeight = nil,
        spindleGear = 0,
        startedAt = os.time(),
    }

    TriggerClientEvent('wellgame_fishing:client:start', src, {
        rod = item.name,
        line = line,
        wear = wear,
        float = float,
        slot = slot,
    })
end)

RegisterNetEvent('wellgame_fishing:server:stop', function()
    CancelFishing(source)
end)

RegisterNetEvent('wellgame_fishing:server:throwStart', function()
    local src = source
    local data = fishing[src]
    if not data then return end
    if data.mode ~= 'idle' and data.mode ~= 'aim' and data.mode ~= 'throw' then return end
    if not trackCast(src) then
        notify(src, 'error', 'Túl gyors dobások — várj egy kicsit.')
        return
    end
    data.mode = 'throw'
    TriggerEvent('wellgame_fishing:server:broadcastSync', src, data)
end)

RegisterNetEvent('wellgame_fishing:server:cast', function()
    local src = source
    local data = fishing[src]
    if not data then return end
    if data.mode ~= 'throw' and data.mode ~= 'waiting' and data.mode ~= 'idle' then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if not data.hasBait then
        local bait = invGetByName(src, Config.BaitItem)
        if not bait then
            notify(src, 'error', 'Nincs nálad csali!')
            TriggerClientEvent('wellgame_fishing:client:setMode', src, 'idle')
            data.mode = 'idle'
            return
        end
        local uses = tonumber(getItemInfo(bait, 'uses', 0)) or 0
        uses = uses + 1
        if uses >= (Config.BaitDose or 20) then
            invRemoveItem(src, Config.BaitItem, 1, bait.slot)
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.BaitItem], 'remove')
        else
            setItemInfo(src, bait.slot, 'uses', uses)
        end
        data.hasBait = true
    end

    data.mode = 'waiting'
    data.fish = nil
    data.fishWeight = nil
    TriggerClientEvent('wellgame_fishing:client:setMode', src, 'waiting')
    TriggerEvent('wellgame_fishing:server:broadcastSync', src, data)
    StartBiteWait(src)
end)

RegisterNetEvent('wellgame_fishing:server:hook', function()
    local src = source
    local data = fishing[src]
    if not data or data.mode ~= 'catching' then return end
    clearFishingTimers(src)
    data.mode = 'catched'
    TriggerClientEvent('wellgame_fishing:client:setMode', src, 'catched', data.fish, data.fishWeight)
    TriggerEvent('wellgame_fishing:server:broadcastSync', src, data)
end)

RegisterNetEvent('wellgame_fishing:server:getoutIdle', function()
    local src = source
    local data = fishing[src]
    if not data then return end
    clearFishingTimers(src)
    data.fish = nil
    data.fishWeight = nil
    data.hasBait = false
    data.mode = 'getout'
    data.getoutGen = (data.getoutGen or 0) + 1
    local gen = data.getoutGen
    SetTimeout(Config.GetOutMs or 4000, function()
        local d = fishing[src]
        if not d or d.getoutGen ~= gen then return end
        d.mode = 'idle'
        TriggerClientEvent('wellgame_fishing:client:setMode', src, 'idle')
        TriggerEvent('wellgame_fishing:server:broadcastSync', src, d)
    end)
end)

RegisterNetEvent('wellgame_fishing:server:land', function()
    local src = source
    local data = fishing[src]
    if not data then return end
    -- Accept catching with a fish as late hook (avoids race: land packet before hook)
    if data.mode == 'catching' and data.fish then
        clearFishingTimers(src)
        data.mode = 'catched'
    end
    if data.mode ~= 'catched' and data.mode ~= 'getout' then return end
    if not data.fish then return end
    clearFishingTimers(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local coords = GetEntityCoords(ped)
    if coords.z < -50.0 then return end
    local maxD = (Config.AntiCheat and Config.AntiCheat.landMaxDist) or 12.0
    if data.floatPos then
        local fx = data.floatPos[1] or data.floatPos.x
        local fy = data.floatPos[2] or data.floatPos.y
        local fz = data.floatPos[3] or data.floatPos.z or coords.z
        if fx and fy then
            local dist = #(coords - vector3(fx + 0.0, fy + 0.0, fz + 0.0))
            if dist > maxD then return end
        end
    end

    local fishKey = data.fish
    local weight = data.fishWeight
    local ft = fishKey and FishTypes[fishKey]
    if not ft or not ft.item then
        data.mode = 'idle'
        TriggerClientEvent('wellgame_fishing:client:setMode', src, 'idle')
        return
    end

    local fightMs = data.biteAt and ((os.time() - data.biteAt) * 1000) or 0
    local info = { weight = weight, fish = fishKey }
    if invAddItem(src, ft.item, 1, info) then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[ft.item], 'add')
        local len = CalculateFishLength(fishKey, weight)
        recordCatchLog(Player.PlayerData.citizenid, fishKey, weight, len)
        playerCatchTotals[src] = (playerCatchTotals[src] or 0) + 1
        notify(src, 'success', ('Kifogtál egy %s!'):format(ft.nameEx))
        notify(src, 'primary', ('Súly: %s kg, hossz: %s cm'):format(weight, len))

        local rodLabel = (Config.Rods[data.rodName] and Config.Rods[data.rodName].label) or data.rodName or 'Horgászbot'
        TriggerClientEvent('wellgame_fishing:client:catchWin', src, {
            key = fishKey,
            name = ft.name,
            class = ft.class or 'Common',
            weight = weight,
            length = len,
            timeMs = fightMs,
            rod = rodLabel,
        })

        if tournament.active and weight then
            local cid = Player.PlayerData.citizenid
            local name = Player.PlayerData.charinfo and (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname) or GetPlayerName(src)
            local prev = tournament.scores[cid]
            local newWeight = (prev and prev.weight or 0) + weight
            tournament.scores[cid] = { cid = cid, name = name, weight = newWeight, fish = ft.name, at = os.time() }
            saveTournamentScore(cid, name, weight, ft.name)
            broadcastTournamentBoard()

            local top = tournamentTop()
            local inTop = false
            for i = 1, #top do
                if top[i] == tournament.scores[cid] then inTop = true break end
            end
            if not inTop then
                local rank = tournamentSelfRank(newWeight)
                if rank then
                    TriggerClientEvent('wellgame_fishing:client:tournamentSelfRank', src, { rank = rank, weight = newWeight })
                end
            end
        end
    else
        notify(src, 'error', 'Nincs hely az inventoryban!')
    end

    data.fish = nil
    data.fishWeight = nil
    data.hasBait = false
    data.mode = 'getout'
    data.getoutGen = (data.getoutGen or 0) + 1
    local gen = data.getoutGen
    TriggerEvent('wellgame_fishing:server:broadcastSync', src, data)
    SetTimeout(Config.GetOutMs or 4000, function()
        local d = fishing[src]
        if not d or d.getoutGen ~= gen then return end
        d.mode = 'idle'
        TriggerClientEvent('wellgame_fishing:client:setMode', src, 'idle')
        TriggerEvent('wellgame_fishing:server:broadcastSync', src, d)
    end)
end)

RegisterNetEvent('wellgame_fishing:server:snap', function(tear)
    local src = source
    local data = fishing[src]
    if not data then return end
    clearFishingTimers(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local item = invGetBySlot(src, data.rodSlot)
    if item and item.name == data.rodName then
        -- v4-feel (játékos elvárás): damil megmarad wear-rel; a hal elviszi az úszót
        local wear = (tonumber(getItemInfo(item, 'wear', 0)) or 0) + math.random(15, 35)
        local lostLine = false
        if wear >= 100 then
            setItemInfo(src, data.rodSlot, 'line', 0)
            setItemInfo(src, data.rodSlot, 'wear', 0)
            data.line = 0
            data.wear = 0
            lostLine = true
            notify(src, 'error', tear and 'Elszakadt a damil!' or 'Elszakadt a damil (túl kopott)!')
        else
            setItemInfo(src, data.rodSlot, 'wear', wear)
            data.wear = wear
            if tear then
                notify(src, 'error', ('Elszakadt a damil — állapot: %d%%'):format(math.max(0, 100 - wear)))
            else
                notify(src, 'error', ('Összecsomósodott a damil — állapot: %d%%'):format(math.max(0, 100 - wear)))
            end
        end

        -- úszó mindig elvész snap/tangle esetén (a hal elviszi / elszakad)
        local hadFloat = (tonumber(getItemInfo(item, 'float', 0)) or 0) > 0
        if hadFloat then
            setItemInfo(src, data.rodSlot, 'float', 0)
            data.float = 0
            notify(src, 'primary', 'A hal elvitte az úszót.')
        end

        -- refresh client rod meta so next cast checks float/line
        TriggerClientEvent('wellgame_fishing:client:rodMeta', src, {
            line = tonumber(getItemInfo(invGetBySlot(src, data.rodSlot), 'line', 0)) or 0,
            wear = tonumber(getItemInfo(invGetBySlot(src, data.rodSlot), 'wear', 0)) or 0,
            float = 0,
            lostLine = lostLine,
        })
    end

    data.fish = nil
    data.fishWeight = nil
    data.hasBait = false
    data.mode = 'idle'
    data.floatPos = nil
    TriggerClientEvent('wellgame_fishing:client:setMode', src, 'idle')
    TriggerClientEvent('wellgame_fishing:client:playSound', src, 'snap.mp3')
    TriggerEvent('wellgame_fishing:server:broadcastSync', src, nil)
end)

RegisterNetEvent('wellgame_fishing:server:syncState', function(payload)
    local src = source
    local data = fishing[src]
    if not data or type(payload) ~= 'table' then return end
    if payload.spindleGear ~= nil then
        data.spindleGear = math.max(0, math.min(4, tonumber(payload.spindleGear) or 0))
    end
    if payload.mode and type(payload.mode) == 'string' then
        -- client-authoritative water modes only for sync visuals
        local allowed = {
            throw = true, waiting = true, catching = true, catched = true, getout = true, idle = true, aim = true,
        }
        if allowed[payload.mode] then data.mode = payload.mode end
    end
    if payload.floatPos then data.floatPos = payload.floatPos end
    if payload.lineLength then data.lineLength = tonumber(payload.lineLength) end
    if payload.line and type(payload.line) == 'table' then data.lineColor = payload.line end
    if payload.fish ~= nil then data.syncFish = payload.fish end
    TriggerEvent('wellgame_fishing:server:broadcastSync', src, data)
end)

RegisterNetEvent('wellgame_fishing:server:attachLine', function(lineSlot, rodSlot)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local lineItem = invGetBySlot(src, lineSlot)
    local rodItem = invGetBySlot(src, rodSlot)
    if not lineItem or not rodItem then return end
    local lineId = Config.Lines[lineItem.name]
    if not lineId or not Config.Rods[rodItem.name] then return end
    setItemInfo(src, rodSlot, 'line', lineId)
    setItemInfo(src, rodSlot, 'wear', 0)
    invRemoveItem(src, lineItem.name, 1, lineSlot)
    notify(src, 'success', ('Felszereltél egy %s damilt.'):format(Config.LineColors[lineId][4]))
    if fishing[src] then
        fishing[src].line = lineId
        fishing[src].wear = 0
    end
    TriggerClientEvent('wellgame_fishing:client:rodMeta', src, {
        line = lineId,
        wear = 0,
        float = fishing[src] and fishing[src].float or (tonumber(getItemInfo(rodItem, 'float', 0)) or 0),
    })
end)

RegisterNetEvent('wellgame_fishing:server:attachFloat', function(floatSlot, rodSlot)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local floatItem = invGetBySlot(src, floatSlot)
    local rodItem = invGetBySlot(src, rodSlot)
    if not floatItem or not rodItem then return end
    local floatId = Config.Floats[floatItem.name]
    if not floatId or not Config.Rods[rodItem.name] then return end
    setItemInfo(src, rodSlot, 'float', floatId)
    invRemoveItem(src, floatItem.name, 1, floatSlot)
    notify(src, 'success', 'Felszereltél egy úszót.')
    if fishing[src] then
        fishing[src].float = floatId
    end
    TriggerClientEvent('wellgame_fishing:client:rodMeta', src, {
        line = fishing[src] and fishing[src].line or (tonumber(getItemInfo(rodItem, 'line', 0)) or 0),
        wear = fishing[src] and fishing[src].wear or (tonumber(getItemInfo(rodItem, 'wear', 0)) or 0),
        float = floatId,
    })
end)

-- Sell cooldown helper for sell.lua
function FishingSellCooldownOk(src)
    castRate[src] = castRate[src] or { times = {}, lastSell = 0 }
    local ms = (GetGameTimer and GetGameTimer()) or (os.time() * 1000)
    local cd = (Config.AntiCheat and Config.AntiCheat.sellCooldownMs) or 1500
    if ms - (castRate[src].lastSell or 0) < cd then return false end
    castRate[src].lastSell = ms
    return true
end
exports('FishingSellCooldownOk', FishingSellCooldownOk)

RegisterCommand('fishtournament', function(src, args)
    if src > 0 then
        local ace = (Config.Tournament and Config.Tournament.ace) or 'fishing.tournament'
        if not IsPlayerAceAllowed(src, ace) and not QBCore.Functions.HasPermission(src, 'admin') then
            notify(src, 'error', 'Nincs jogod.')
            return
        end
    end
    local sub = (args[1] or ''):lower()
    if sub == 'start' then
        local days = tonumber(args[2]) or (Config.Tournament and Config.Tournament.durationDays) or 7
        tournament.active = true
        tournament.scores = {}
        tournament.startDay = currentDayIndex()
        tournament.endDay = tournament.startDay + days
        saveTournamentState()
        if MySQL and Config.Tournament and Config.Tournament.useDatabase then
            pcall(function() MySQL.query.await('TRUNCATE TABLE wellgame_fishing_tournament') end)
        end
        TriggerClientEvent('QBCore:Notify', -1, ('Horgászverseny elindult! (%d nap)'):format(days), 'success')
        broadcastTournamentBoard()
    elseif sub == 'stop' then
        endTournament(true)
    elseif sub == 'board' or sub == 'top' then
        TriggerClientEvent('wellgame_fishing:client:tournamentBoardShow', src > 0 and src or -1, { active = tournament.active, top = tournamentTop() })
    else
        if src > 0 then
            notify(src, 'primary', 'Használat: /fishtournament start [nap]|stop|board')
        end
    end
end, false)

AddEventHandler('playerDropped', function()
    local src = source
    CancelFishing(src)
    castRate[src] = nil
end)

CreateThread(function()
    for rodName in pairs(Config.Rods) do
        QBCore.Functions.CreateUseableItem(rodName, function(source, item)
            TriggerClientEvent('wellgame_fishing:client:useRod', source, item.slot)
        end)
    end
    for lineName in pairs(Config.Lines) do
        QBCore.Functions.CreateUseableItem(lineName, function(source, item)
            TriggerClientEvent('wellgame_fishing:client:useLine', source, item.slot, item.name)
        end)
    end
    for floatName in pairs(Config.Floats) do
        QBCore.Functions.CreateUseableItem(floatName, function(source, item)
            TriggerClientEvent('wellgame_fishing:client:useFloat', source, item.slot, item.name)
        end)
    end
    QBCore.Functions.CreateUseableItem(Config.ChestItem, function(source, item)
        TriggerClientEvent('wellgame_fishing:client:openChest', source, item.slot)
    end)
    for itemName, data in pairs(FishSellable) do
        if type(itemName) == 'string' and data.sellableFish and data.item == itemName then
            QBCore.Functions.CreateUseableItem(itemName, function(source, item)
                TriggerClientEvent('wellgame_fishing:client:trySell', source, item.slot, item.name)
            end)
        end
    end
end)
