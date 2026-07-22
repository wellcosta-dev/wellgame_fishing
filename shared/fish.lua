FishTypes = {
    rise_fish_mackerel = {
        name = 'Makréla', nameEx = 'makrélát', sellableFish = true,
        length = 0.402829, weight = { 1, 5, 1, 1.3 }, item = 'fish_mackerel',
    },
    rise_fish_hardheadcatfish = {
        name = 'Keményfejű harcsa', nameEx = 'keményfejű harcsát', sellableFish = true,
        length = 0.579515, weight = { 1, 10, 0.8, 1.3 }, item = 'fish_catfish',
    },
    rise_fish_snapper = {
        name = 'Csattogóhal', nameEx = 'csattogóhalat', sellableFish = true,
        length = 0.589667, weight = { 2, 15, 0.8, 1.3 }, item = 'fish_snapper',
    },
    rise_fish_yellowtailsnapper = {
        name = 'Sárgafarkú csattogóhal', nameEx = 'sárgafarkú csattogóhalat', sellableFish = true,
        length = 0.640533, weight = { 2, 15, 0.8, 1.3 }, item = 'fish_yellowtail',
    },
    rise_fish_snapper_leg = {
        class = 'Legendary', name = 'Legendary Csattogóhal', nameEx = 'legendary csattogóhalat',
        sellableFish = true, length = 0.726116, weight = { 15, 20, 0.9, 1.2 }, item = 'fish_snapper_leg',
    },
    rise_fish_redsalmon = {
        name = 'Vörös lazac', nameEx = 'vörös lazacot', sellableFish = true,
        length = 0.690272, weight = { 5, 12, 0.8, 1.25 }, item = 'fish_redsalmon',
    },
    rise_fish_pinksalmon = {
        name = 'Rózsaszín lazac', nameEx = 'rózsaszín lazacot', sellableFish = true,
        length = 0.791416, weight = { 5, 12, 0.8, 1.25 }, item = 'fish_pinksalmon',
    },
    rise_fish_tunabluefin = {
        name = 'Kékúszójú tonhal', nameEx = 'kékúszójú tonhalat', sellableFish = true,
        length = 0.800695, weight = { 10, 50, 1.1, 1.7 }, item = 'fish_tunablue',
    },
    rise_fish_tunayellowfin = {
        name = 'Sárgaúszójú tonhal', nameEx = 'sárgaúszójú tonhalat', sellableFish = true,
        length = 0.800695, weight = { 10, 50, 1.1, 1.7 }, item = 'fish_tunayellow',
    },
    rise_fish_rooster = {
        name = 'Kakashal', nameEx = 'kakashalat', sellableFish = true,
        length = 1.00003, weight = { 10, 40, 0.8, 1.2 }, item = 'fish_rooster',
    },
    rise_fish_rooster_leg = {
        class = 'Legendary', name = 'Legendary Kakashal', nameEx = 'legendary kakashalat',
        sellableFish = true, length = 1.18155, weight = { 30, 40, 1, 1.2 }, item = 'fish_rooster_leg',
    },
    rise_fish_swordfish = {
        name = 'Kardhal', nameEx = 'kardhalat', sellableFish = true,
        length = 1.30176, weight = { 10, 45, 0.8, 1.1 }, item = 'fish_swordfish',
    },
    rise_fish_mahi = {
        name = 'Mahi-mahi', nameEx = 'mahi-mahit', sellableFish = true,
        length = 1.00431, weight = { 10, 30, 0.7, 1.1 }, item = 'fish_mahi',
    },
    rise_fish_mahi_leg = {
        class = 'Legendary', name = 'Legendary Mahi-mahi', nameEx = 'legendary mahi-mahit',
        sellableFish = true, length = 1.30112, weight = { 30, 40, 0.9, 1.1 }, item = 'fish_mahi_leg',
    },
    rise_fish_makoshark = {
        name = 'Makócápa', nameEx = 'makócápát', sellableFish = true,
        length = 1.61124, weight = { 10, 50, 0.5, 1 }, item = 'fish_mako',
    },
    rise_fish_tigershark = {
        name = 'Tigriscápa', nameEx = 'tigriscápát', sellableFish = true,
        length = 1.80773, weight = { 10, 50, 0.5, 1 }, item = 'fish_tiger',
    },
    rise_fish_greatwhite = {
        name = 'Fehér cápa', nameEx = 'fehér cápát', sellableFish = true,
        length = 2.2629, weight = { 20, 55, 0.5, 1 }, item = 'fish_greatwhite',
    },
    rise_fish_greatwhite_leg = {
        class = 'Legendary', name = 'Legendary Fehér cápa', nameEx = 'legendary fehér cápát',
        sellableFish = true, length = 2.8235, weight = { 50, 60, 0.8, 1 }, item = 'fish_greatwhite_leg',
    },
    oyster = {
        name = 'Kagyló', nameEx = 'kagylót', nonAlive = true, weight = 0.5, item = 'fishing_oyster',
    },
    oyster_empty = {
        name = 'Üres kagyló', nameEx = 'üres kagylót', nonAlive = true, weight = 0.5, item = 'fishing_oyster_empty',
    },
    chest = {
        class = 'Epic', name = 'Horgászláda', nameEx = 'horgászládát', nonAlive = true, weight = 2, item = 'fishing_chest',
    },
    rolex = {
        class = 'Rare', name = 'Arany óra', nameEx = 'arany órát', nonAlive = true, weight = 0.5, item = 'fishing_goldwatch',
    },
    chain = {
        class = 'Rare', name = 'Arany lánc', nameEx = 'arany láncot', nonAlive = true, weight = 0.5, item = 'fishing_goldchain',
    },
    trash_bag = {
        name = 'Szatyor', nameEx = 'szatyrot', nonAlive = true, weight = 0.1, item = 'fishing_trash',
    },
}

local rawChances = {
    rise_fish_mackerel = 15,
    rise_fish_hardheadcatfish = 10,
    rise_fish_snapper = 10,
    rise_fish_yellowtailsnapper = 10,
    rise_fish_redsalmon = 10,
    rise_fish_pinksalmon = 10,
    rise_fish_tunayellowfin = 8,
    rise_fish_tunabluefin = 8,
    rise_fish_mahi = 7,
    rise_fish_rooster = 5,
    rise_fish_swordfish = 5,
    rise_fish_tigershark = 3,
    rise_fish_makoshark = 3,
    rise_fish_greatwhite = 2,
    rise_fish_snapper_leg = 1.2,
    rise_fish_rooster_leg = 1.2,
    rise_fish_mahi_leg = 1.2,
    rise_fish_greatwhite_leg = 1.2,
    trash_bag = 3,
    oyster = 2,
    oyster_empty = 2,
    rolex = 0.35,
    chain = 0.3,
    chest = 0.2,
}

local multipler = 1.15
ChanceSum = 0
Chances = {}

for k, v in pairs(rawChances) do
    Chances[k] = v ^ multipler
end

for k, data in pairs(FishTypes) do
    data.catchChance = Chances[k] or 0
    ChanceSum = ChanceSum + data.catchChance
end

local basePrice = 84000 -- volt 420000 → halárak az ötödére
FishSellable = {}

for k, data in pairs(FishTypes) do
    if data.sellableFish then
        local w = data.weight
        local mid = (w[2] - w[1]) * 0.4 + w[1]
        data.price = (basePrice / (data.catchChance / ChanceSum * 100) / mid) * (Config and Config.EconomyScale or 0.001)
        FishSellable[data.item] = data
        FishSellable[k] = data
    end
end

-- legendaryMult (default 1.0): scales the catch-chance weight of every 'Legendary'-class
-- fish for this single roll — used to apply horgász-szint / hotspot / időjárás bónuszokat
-- without touching the base Chances table (which stays the shared, un-boosted baseline).
function ChooseRandomFish(legendaryMult)
    if ChanceSum <= 0 then return nil end
    legendaryMult = tonumber(legendaryMult) or 1.0

    if legendaryMult == 1.0 then
        local selected = math.random() * ChanceSum
        local iterated = 0
        for k, v in pairs(Chances) do
            iterated = iterated + v
            if selected <= iterated then return k end
        end
        return 'rise_fish_mackerel'
    end

    local sum = 0
    local weights = {}
    for k, v in pairs(Chances) do
        local w = v
        local ft = FishTypes[k]
        if ft and ft.class == 'Legendary' then
            w = w * legendaryMult
        end
        weights[k] = w
        sum = sum + w
    end

    local selected = math.random() * sum
    local iterated = 0
    for k, w in pairs(weights) do
        iterated = iterated + w
        if selected <= iterated then return k end
    end
    return 'rise_fish_mackerel'
end

function GetFishScale(fishType, weight)
    local scale = 1
    weight = tonumber(weight)
    if weight and fishType and type(fishType.weight) == 'table' then
        local minW, maxW = fishType.weight[1], fishType.weight[2]
        local minS, maxS = fishType.weight[3], fishType.weight[4]
        if maxW ~= minW then
            scale = (weight - minW) / (maxW - minW) * (maxS - minS) + minS
        end
    end
    return scale
end

function CalculateFishLength(fishKey, weight)
    local ft = FishTypes[fishKey]
    if not ft then return 0 end
    return math.floor((ft.length or 0) * GetFishScale(ft, weight) * 100)
end

function RandomFishWeight(fishKey)
    local ft = FishTypes[fishKey]
    if not ft then return 1.0 end
    if type(ft.weight) == 'table' then
        return math.random(ft.weight[1] * 10, ft.weight[2] * 10) / 10
    end
    return tonumber(ft.weight) or 1.0
end

function GetFishTypeByItem(itemName)
    for k, v in pairs(FishTypes) do
        if v.item == itemName then return k, v end
    end
    return nil, nil
end
