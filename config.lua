Config = {}

Config.BaitDose = 20
Config.WaitMinMs = 10000
Config.WaitMaxMs = 37500
Config.GetAwayMs = 8000
Config.CastChargeMs = 2000
Config.MinCastTension = 0.25
Config.HookTension = 0.25
Config.SnapTension = 1.2
Config.TangleTension = -3.5
Config.MaxLineDist = 105.0
Config.MinWaterDepth = 2.5
Config.LandDistance2D = 1.0
Config.GetOutMs = 4000
Config.EconomyScale = 0.8

Config.Physics = {
    throwHorizMul = 60.0,
    throwVertMul = 15.0,
    throwHorizAccel = -22.0,
    throwGravity = -9.8,
    tensionDiv = 1.35,         -- kisebb = ugyanarra a húzásra nagyobb feszültség
    tensionSmooth = 7.0,       -- gyorsabb feszültség-válasz (érezhetőbb rántás)
    scrollImpulse = 0.38,
    scrollDirect = 0.55,
    scrollVelMul = 1.1,
    lineVelDecay = 1.4,
    gearStep = 0.35,
    autoPayout = 4.0,          -- kevesebb automatikus engedés → a hal jobban „fog”
    animProgressBase = 0.15,
    animProgressMul = 0.825,
    -- Kapás / götgetés
    biteForceMin = 3.8,
    biteForceMax = 7.2,
    biteForceDecay = 2.5,
    biteDipDepth = 2.15,
    biteFloatSink = 2.4,
    biteFloatFloor = 0.05,
    -- Hal AI: erősebb úszás + ellenállás, lassabb fáradás, gyakoribb iránváltás
    fishSwimBase = 5.5,
    fishSwimWeightDiv = 10.0,
    fishResist = 1.35,
    fishEnergyDrain = 0.0048,
    fishForceSwitchMin = 500,
    fishForceSwitchMax = 4200,
    snapHoldSec = 0.75,
}

Config.SyncIntervalMs = 250
Config.SyncRange = 80.0

Config.AntiCheat = {
    maxCastPerMin = 20,
    sellCooldownMs = 1500,
    landMaxDist = 12.0,
}

Config.Dropoffs = {
    { coords = vector4(-1850.2, -1248.5, 8.6, 140.0), label = 'Horgászbolt (Del Perro)', npcName = 'Halász János' },
    { coords = vector4(130.0, 3370.0, 31.0, 200.0), label = 'Horgászbolt (Alamo)', npcName = 'Halász János' },
    { coords = vector4(3805.7024, 4477.3027, 5.9927, 186.2961), label = 'Horgászbolt (Paleto Ocean)', npcName = 'Halász János' },
    { coords = vector4(714.4476, 4101.8506, 35.7852, 93.0325), label = 'Horgászbolt', npcName = 'Halász János' },
}

Config.DropoffRadius = 3.5

-- Felvásárló NPC névtábla (wellgame-nametag stílus)
Config.NpcTagDistance = 20.0
Config.NpcTagFadeStart = 0.6

-- Baitshop props at dropoffs (GTA fallback until des_baitshop stream)
Config.Baitshops = {
    { coords = vector4(-1851.5, -1246.8, 8.6, 140.0), model = `prop_tool_bench02`, label = 'Horgászbolt' },
    { coords = vector4(131.5, 3371.5, 31.0, 200.0), model = `prop_tool_bench02`, label = 'Horgászbolt' },
    { coords = vector4(3809.5, 4479.5, 4.3, 200.0), model = `prop_tool_bench02`, label = 'Horgászbolt' },
    { coords = vector4(715.9, 4103.3, 35.7852, 93.0), model = `prop_tool_bench02`, label = 'Horgászbolt' },
}

-- Horgászengedély: kötelező item a horgászbot használatához, a bolt(ok)ban vásárolható.
-- (A Config.BaitshopItems lentebb hivatkozik rá, ezért ennek előbb kell lefutnia.)
Config.License = {
    enabled = true,
    item = 'fishing_license',
    price = 1500,
}

-- Kezdőcsomag: egyben megvehető alapfelszerelés, a darabár-összegnél kicsit olcsóbban.
-- (Ugyanígy a Config.BaitshopItems előtt kell lennie.)
Config.StarterKit = {
    enabled = true,
    price = 3800, -- külön-külön: rod_1 3200 + line_1 550 + float_1 420 + bait 275 = 4445
    items = { 'fishing_rod_1', 'fishing_line_1', 'fishing_float_1', 'fishing_bait' },
}

-- Boltárak: fix $-összeg (NEM EconomyScale). Emelt árak a régi qb-menu listához képest.
Config.BaitshopCategories = {
    { id = 'all', label = 'Összes' },
    { id = 'starter', label = 'Kezdőcsomag' },
    { id = 'license', label = 'Engedély' },
    { id = 'bait', label = 'Csali' },
    { id = 'line', label = 'Damil' },
    { id = 'float', label = 'Úszó' },
    { id = 'rod', label = 'Bot' },
    { id = 'elite', label = 'Elite' },
}

-- `starterkit` egy virtuális katalógustétel — a szerver (server/shop.lua) külön kezeli, és a
-- Config.StarterKit.items mindegyikéből egyet ad, nem egy valódi item.
Config.BaitshopItems = {
    { item = 'starterkit', price = Config.StarterKit.price, label = 'Kezdőcsomag', category = 'starter', image = 'fishing_rod_1.png', desc = 'Bot + damil + úszó + csali egyben, olcsóbban mintha külön vennéd' },
    { item = 'fishing_license', price = Config.License.price, label = 'Horgászengedély', category = 'license', desc = 'Enélkül nem vethetsz horgot' },
    { item = 'fishing_bait', price = 275, label = 'Csali doboz', category = 'bait', desc = '20 adag csali egy dobozban' },
    { item = 'fishing_line_1', price = 550, label = 'Damil — bézs', category = 'line', desc = 'Alap horgászdamil' },
    { item = 'fishing_line_2', price = 650, label = 'Damil — zöld', category = 'line', desc = 'Színezett damil' },
    { item = 'fishing_line_3', price = 750, label = 'Damil — fehér', category = 'line', desc = 'Erősebb fehér damil' },
    { item = 'fishing_line_4', price = 850, label = 'Damil — piros', category = 'line', desc = 'Látható piros damil' },
    { item = 'fishing_line_7', price = 950, label = 'Damil — kék', category = 'line', desc = 'Prémium kék damil' },
    { item = 'fishing_float_1', price = 420, label = 'Úszó', category = 'float', desc = 'Alap úszó' },
    { item = 'fishing_float_2', price = 680, label = 'Úszó Pro', category = 'float', desc = 'Stabilabb, jobb érzékelés' },
    { item = 'fishing_float_3', price = 980, label = 'Úszó Elite', category = 'float', desc = 'Versenyúszó' },
    { item = 'fishing_float_4', price = 1350, label = 'Úszó Master', category = 'float', desc = 'Csúcs úszó' },
    { item = 'fishing_rod_1', price = 3200, label = 'Horgászbot', category = 'rod', desc = 'Alap bot — damil + úszó kell' },
    { item = 'fishing_rod_2', price = 7800, label = 'Horgászbot Pro', category = 'rod', desc = 'Erősebb, tartósabb bot' },
    { item = 'fishing_rod_3', price = 14500, label = 'Horgászbot Elite', category = 'rod', desc = 'Csúcs felszerelés' },
    { item = 'fishing_seerod_5000', price = 45000, label = 'SeeRod 5000', category = 'elite', desc = 'Ritka csúcsbot — eddig csak horgászládából volt elérhető' },
    { item = 'fishing_seerod_6000', price = 78000, label = 'SeeRod 6000', category = 'elite', desc = 'A legjobb bot pénzért — még ritkább ládaverzió is létezik' },
}

-- Mirror Park lake — tilos horgászni (példa denied zóna)
Config.DeniedZones = {
    {
        vector2(1065.0, -685.0),
        vector2(1135.0, -685.0),
        vector2(1135.0, -630.0),
        vector2(1065.0, -630.0),
    },
}

-- Horgász szint: minden N fogás +1 szint, enyhe rare/legendary bónusz szorzóval fogásesélyre.
Config.Progression = {
    enabled = true,
    catchesPerLevel = 15,
    maxLevel = 30,
    legendaryBonusPerLevel = 0.03, -- +3% legendary/rare esély-súly szintenként
}

-- Horgászhelyek: a már bevált felvásárló-helyszínek (Del Perro / Alamo-tó / Paleto-öböl)
-- nyílt vízi meghosszabbításában — ezekről tudjuk, hogy víz felett vannak, nem kellett
-- vadonatúj, élőben nem tesztelt koordinátákat kitalálni hozzájuk.
Config.Hotspots = {
    { coords = vector3(-2230.0, -1320.0, 0.0), radius = 90.0, rareBonus = 1.6, label = 'Del Perro mélyvíz' },
    { coords = vector3(260.0, 3460.0, 0.0), radius = 90.0, rareBonus = 1.6, label = 'Alamo-tó közepe' },
    { coords = vector3(4120.0, 4620.0, 0.0), radius = 90.0, rareBonus = 1.6, label = 'Paleto-öböl mélyvíz' },
}

-- Napszak/időjárás hatás — a qb-weathersync exportjaiból olvasva (ha fut a resource, egyébként
-- kihagyva). Az itt szereplő 3 időjárás-string a qb-weathersync saját config.lua-jában is szerepel.
Config.NightRareBonus = 1.25 -- 21:00–06:00 (játékbeli idő) között
Config.RareWeatherBonus = 1.3
Config.RareWeatherTypes = { RAIN = true, THUNDER = true, FOGGY = true }

-- Stream-ready model names (joaat). Replace when YDR is in stream/
Config.RodProp = `prop_fishing_rod_01`
Config.RodPropsByIndex = {
    [0] = `prop_fishing_rod_01`,
    [1] = `prop_fishing_rod_01`,
    [2] = `prop_fishing_rod_01`,
    [3] = `prop_fishing_rod_01`,
    [4] = `prop_fishing_rod_01`,
}

Config.BobberProp = `prop_golf_ball`
Config.BobberPropsByFloat = {
    [1] = `prop_golf_ball`,
    [2] = `prop_golf_ball`,
    [3] = `prop_golf_ball`,
    [4] = `prop_golf_ball`,
}

Config.FishPreviewProp = `prop_cs_steak`

Config.RodAttach = {
    bone = 18905,
    -- Enyhén balra a középről (70/95/188 → balabb)
    pos = vector3(0.08, 0.03, 0.0),
    rot = vector3(72.0, 108.0, 175.0),
    -- Bedobás töltés: bot hátradöntése (kiegészíti a felsőtest-dőlést)
    castLeanRot = vector3(-28.0, 0.0, 0.0),
}

-- Calibrated tip for prop_fishing_rod_01 (entity-local). Use /fishtipcalib in-game to fine-tune live.
Config.RodTipOffset = vector3(0.0, 0.0, 2.51)

-- v4 guide points along rod (local Z of custom rod → remapped to tip fraction for GTA prop)
Config.LineGuides = { 0.16, 0.22, 0.41, 0.60, 0.79, 1.0 }

-- When YCD converted: change dict/clips here
-- True waist lean needs custom fishing_bedobas YCD (v4 IFP is SA-format — not usable on GTA V).
-- Until then: upper-body-only idle_c scrub (legs stay planted) + rod tilt. NO SetEntityRotation on ped.
Config.FishAnims = {
    dict = 'amb@world_human_stand_fishing@idle_a',
    idle = 'idle_c',
    cast = 'idle_a', -- NEM használjuk — tekerő clip
    getout = 'idle_b',
    waterPoseProgress = 0.99,
    -- Szűk sáv: 0.99 → 0.86 = törzs/derék, nem végigtekeri az orsót
    castLeanBackProgress = 0.86,
    castLeanRecoverMs = 750,
}

Config.Controls = {
    aim = 25,
    cast = 24,
    gearUp = 21,
    gearDown = 36,
}

Config.LineColors = {
    [1] = { 173, 176, 151, 'bézs' },
    [2] = { 163, 244, 171, 'zöld' },
    [3] = { 210, 210, 255, 'fehér' },
    [4] = { 255, 140, 140, 'piros' },
    [5] = { 222, 222, 110, 'sárga' },
    [6] = { 255, 150, 255, 'pink' },
    [7] = { 100, 200, 255, 'kék' },
}

Config.Rods = {
    fishing_rod_1 = { index = 0, label = 'Horgászbot' },
    fishing_rod_2 = { index = 1, label = 'Horgászbot Pro' },
    fishing_rod_3 = { index = 2, label = 'Horgászbot Elite' },
    fishing_seerod_5000 = { index = 3, label = 'SeeRod 5000' },
    fishing_seerod_6000 = { index = 4, label = 'SeeRod 6000' },
}

Config.Lines = {
    fishing_line_1 = 1,
    fishing_line_2 = 2,
    fishing_line_3 = 3,
    fishing_line_4 = 4,
    fishing_line_5 = 5,
    fishing_line_6 = 6,
    fishing_line_7 = 7,
}

Config.Floats = {
    fishing_float_1 = 1,
    fishing_float_2 = 2,
    fishing_float_3 = 3,
    fishing_float_4 = 4,
}

Config.BaitItem = 'fishing_bait'
Config.ChestItem = 'fishing_chest'

Config.ChestRewards = {
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

Config.Tournament = {
    enabled = true,
    ace = 'fishing.tournament',
    topN = 10,
    useDatabase = true,
    durationDays = 7,   -- /fishtournament start [days] default length (v4: fishingmaffia <days>)
    liveBoardN = 5,      -- rows shown on the in-world dropoff leaderboard
    liveBoardDistance = 15.0,
    prize = { cash = 1000000, pp = 100000 }, -- paid to the #1 player when the tournament ends
    hypeIntervalMs = 10 * 60000, -- chat teaser interval while a tournament is active
}
