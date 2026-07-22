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
    tensionDiv = 1.5,
    tensionSmooth = 4.0,
    scrollImpulse = 0.38,
    gearStep = 0.35,
    autoPayout = 5.5,
    animProgressBase = 0.15,
    animProgressMul = 0.825,
    -- Kapás / götgetés (catching mode float jerks)
    biteForceMin = 2.8,
    biteForceMax = 5.5,
    biteForceDecay = 3.2,
    biteDipDepth = 2.15,      -- Z merülés szorzó (volt 1.25)
    biteFloatSink = 2.4,      -- úszó döntés merülési sebesség
    biteFloatFloor = 0.05,    -- min floatingValue kapáskor
    -- v4 fish AI (erősebb ellenállás + gyakoribb iránváltás + lassabb fáradás = nagyobb kihívás)
    fishSwimBase = 4.0,
    fishSwimWeightDiv = 10.0,
    fishResist = 0.85,
    fishEnergyDrain = 0.008,
    fishForceSwitchMin = 800,
    fishForceSwitchMax = 8000,
    snapHoldSec = 0.65,
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
    { coords = vector4(-1851.5, -1246.8, 8.6, 140.0), model = `prop_tool_bench02`, label = 'Horgász felszerelés' },
    { coords = vector4(131.5, 3371.5, 31.0, 200.0), model = `prop_tool_bench02`, label = 'Horgász felszerelés' },
    { coords = vector4(3809.5, 4479.5, 4.3, 200.0), model = `prop_tool_bench02`, label = 'Horgász felszerelés' },
}

Config.BaitshopItems = {
    { item = 'fishing_bait', price = 50, label = 'Csali (20 adag)' },
    { item = 'fishing_line_1', price = 120, label = 'Damil (bézs)' },
    { item = 'fishing_line_3', price = 180, label = 'Damil (fehér)' },
    { item = 'fishing_float_1', price = 80, label = 'Úszó' },
    { item = 'fishing_float_2', price = 120, label = 'Úszó Pro' },
    { item = 'fishing_rod_1', price = 500, label = 'Horgászbot' },
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
    pos = vector3(0.1, 0.05, 0.0),
    rot = vector3(80.0, 120.0, 160.0),
}

-- Calibrated tip for prop_fishing_rod_01 (entity-local). Use /fishtipcalib in-game to fine-tune live.
Config.RodTipOffset = vector3(0.0, 0.0, 2.51)

-- v4 guide points along rod (local Z of custom rod → remapped to tip fraction for GTA prop)
Config.LineGuides = { 0.16, 0.22, 0.41, 0.60, 0.79, 1.0 }

-- When YCD converted: change dict/clips here
Config.FishAnims = {
    dict = 'amb@world_human_stand_fishing@idle_a',
    idle = 'idle_c',
    cast = 'idle_a',
    getout = 'idle_b',
    -- Bedobás utáni fagyasztott póz (idle_c: nagyobb = előrébb, kisebb = hátrébb)
    waterPoseProgress = 1.0,
    -- future YCD: dict = 'fishing_bedobas', cast = 'bather', idle dict = 'fishing_stand', etc.
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

Config.Tournament = {
    enabled = true,
    ace = 'fishing.tournament',
    topN = 10,
    useDatabase = true,
    durationDays = 7,   -- /fishtournament start [days] default length (v4: fishingmaffia <days>)
    liveBoardN = 5,      -- rows shown on the in-world dropoff leaderboard
    liveBoardDistance = 15.0,
}
