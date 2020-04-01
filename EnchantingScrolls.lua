--[[----------------------------------------------------------------------------

    Copyright 2019-2020 Mike Battersby

    This file is part of TradeSkillPrice.

    TradeSkillPrice is free software; you can redistribute it or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation, version 2, 1991.

    TradeSkillPrice is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
    for more details.

    See the file LICENSE.txt for details.

----------------------------------------------------------------------------]]--

local recipeSpellsByID = {}
local scanFrame = CreateFrame('Frame')

local function Precache(min, max)
    -- This pulls the item into the client cache from the server so that
    -- GetItemSpell() returns the data. The cache isn't big enough to hold
    -- every item though which is why we do 1000 at a time.
    for itemID = min, max do
        GetItemInfo(itemID)
    end
end

local function ScanPartial(min, max)
    for itemID = min, max do
        local itemSpellName, itemSpellID = GetItemSpell(itemID)
        local itemName = GetItemInfo(itemID)
        -- if the item casts a spell and any recipe also casts that spell
        if itemSpellID and recipeSpellsByID[itemSpellID] then
            print(format('Found one %d = %s', itemID, itemName))
            -- associate the item with all recipes that cast the spell,
            -- matching them by name
            local allIDs = recipeSpellsByID[itemSpellID]
            for _,spellID in ipairs(allIDs) do
                TradeSkillPrice.db.scrollData = TradeSkillPrice.db.scrollData
                        .. "\n" ..
                        format("    [%06d] = %06d, -- %s", spellID, itemID, itemName)
            end
        end
    end
end

local function GetAllRanks(info)
    local recipes = { info.recipeID }

    while info.nextRecipeID do
        info = C_TradeSkillUI.GetRecipeInfo(info.nextRecipeID)
        table.insert(recipes, info.recipeID)
    end
    return recipes
end

local function Scan()
    print('You can close the tradeskill frame now.')
    for i = 0, 249 do
        print('Scan ' .. i*1000+1)
        Precache(i*1000+1, (i+1)*1000)
        coroutine.yield()
        ScanPartial(i*1000+1, (i+1)*1000)
        coroutine.yield()
    end
    print('Finished')
end

local function OnUpdate(self, elapsed)
    self.totalElapsed = (self.totalElapsed or 0) + elapsed

    -- This 0.5s is intended to be long enough that the GetItemInfo()
    -- data has time to come back from the server for 1000 items. There's
    -- no way to tell for sure if it's enough.

    if self.totalElapsed < 0.5 then
        return
    end

    self.totalElapsed = 0
    if not self.thread or coroutine.status(self.thread) == 'dead' then
        self:SetScript("OnUpdate", nil)
        self.thread = nil
        self.totalElapsed = nil
        TradeSkillPrice.db.scrollData = TradeSkillPrice.db.scrollData .. "\n}\n"
    else
        local t, e = coroutine.resume(self.thread)
        if t == false then
            print(e)
        end
    end
end

-- Strictly speaking this is not just scrolls, but anything where there's
-- an item that casts the same spell as the tradeskill does. By observation
-- the enchanting scrolls cast the rank 1 version of the spell, but there's
-- no reason to believe that will always be the case.

function TradeSkillPrice:ScanForScrolls()
    if not TradeSkillFrame or not TradeSkillFrame:IsVisible() then
        print('Open the enchanting tradeskill first.')
        return
    end

    print('Starting enchanting scroll scan.')

    for _,recipeSpellID in ipairs(C_TradeSkillUI.GetAllRecipeIDs()) do
        local info = C_TradeSkillUI.GetRecipeInfo(recipeSpellID)
        if not info.previousRecipeID then
            recipeSpellsByID[info.recipeID] = GetAllRanks(info)
        end
    end

    TradeSkillPrice.db.scrollData = "TradeSkillPrice.scrollData = {"
    scanFrame.thread = coroutine.create(Scan)
    scanFrame:SetScript("OnUpdate", OnUpdate)
end

-- spellid, itemid

TradeSkillPrice.scrollData = {
    [007418] = 038679, -- Enchant Bracer - Minor Health
    [007420] = 038766, -- Enchant Chest - Minor Health
    [007426] = 038767, -- Enchant Chest - Minor Absorption
    [007428] = 038768, -- Enchant Bracer - Minor Dodge
    [007443] = 038769, -- Enchant Chest - Minor Mana
    [007457] = 038771, -- Enchant Bracer - Minor Stamina
    [007745] = 038772, -- Enchant 2H Weapon - Minor Impact
    [007748] = 038773, -- Enchant Chest - Lesser Health
    [007766] = 038774, -- Enchant Bracer - Minor Versatility
    [007771] = 038775, -- Enchant Cloak - Minor Protection
    [007776] = 038776, -- Enchant Chest - Lesser Mana
    [007779] = 038777, -- Enchant Bracer - Minor Agility
    [007782] = 038778, -- Enchant Bracer - Minor Strength
    [007786] = 038779, -- Enchant Weapon - Minor Beastslayer
    [007788] = 038780, -- Enchant Weapon - Minor Striking
    [007793] = 038781, -- Enchant 2H Weapon - Lesser Intellect
    [007857] = 038782, -- Enchant Chest - Health
    [007859] = 038783, -- Enchant Bracer - Lesser Versatility
    [007863] = 038785, -- Enchant Boots - Minor Stamina
    [007867] = 038786, -- Enchant Boots - Minor Agility
    [013378] = 038787, -- Enchant Shield - Minor Stamina
    [013380] = 038788, -- Enchant 2H Weapon - Lesser Versatility
    [013419] = 038789, -- Enchant Cloak - Minor Agility
    [013421] = 038790, -- Enchant Cloak - Lesser Protection
    [013464] = 038791, -- Enchant Shield - Lesser Protection
    [013485] = 038792, -- Enchant Shield - Lesser Versatility
    [013501] = 038793, -- Enchant Bracer - Lesser Stamina
    [013503] = 038794, -- Enchant Weapon - Lesser Striking
    [013529] = 038796, -- Enchant 2H Weapon - Lesser Impact
    [013536] = 038797, -- Enchant Bracer - Lesser Strength
    [013538] = 038798, -- Enchant Chest - Lesser Absorption
    [013607] = 038799, -- Enchant Chest - Mana
    [013612] = 038800, -- Enchant Gloves - Mining
    [013617] = 038801, -- Enchant Gloves - Herbalism
    [013620] = 038802, -- Enchant Gloves - Fishing
    [013622] = 038803, -- Enchant Bracer - Lesser Intellect
    [013626] = 038804, -- Enchant Chest - Minor Stats
    [013631] = 038805, -- Enchant Shield - Lesser Stamina
    [013635] = 038806, -- Enchant Cloak - Defense
    [013637] = 038807, -- Enchant Boots - Lesser Agility
    [013640] = 038808, -- Enchant Chest - Greater Health
    [013642] = 038809, -- Enchant Bracer - Versatility
    [013644] = 038810, -- Enchant Boots - Lesser Stamina
    [013646] = 038811, -- Enchant Bracer - Lesser Dodge
    [013648] = 038812, -- Enchant Bracer - Stamina
    [013653] = 038813, -- Enchant Weapon - Lesser Beastslayer
    [013655] = 038814, -- Enchant Weapon - Lesser Elemental Slayer
    [013659] = 038816, -- Enchant Shield - Versatility
    [013661] = 038817, -- Enchant Bracer - Strength
    [013663] = 038818, -- Enchant Chest - Greater Mana
    [013687] = 038819, -- Enchant Boots - Lesser Versatility
    [013689] = 038820, -- Enchant Shield - Lesser Parry
    [013693] = 038821, -- Enchant Weapon - Striking
    [013695] = 038822, -- Enchant 2H Weapon - Impact
    [013698] = 038823, -- Enchant Gloves - Skinning
    [013700] = 038824, -- Enchant Chest - Lesser Stats
    [013746] = 038825, -- Enchant Cloak - Greater Defense
    [013815] = 038827, -- Enchant Gloves - Agility
    [013817] = 038828, -- Enchant Shield - Stamina
    [013822] = 038829, -- Enchant Bracer - Intellect
    [013836] = 038830, -- Enchant Boots - Stamina
    [013841] = 038831, -- Enchant Gloves - Advanced Mining
    [013846] = 038832, -- Enchant Bracer - Greater Versatility
    [013858] = 038833, -- Enchant Chest - Superior Health
    [013868] = 038834, -- Enchant Gloves - Advanced Herbalism
    [013882] = 038835, -- Enchant Cloak - Lesser Agility
    [013887] = 038836, -- Enchant Gloves - Strength
    [013890] = 038837, -- Enchant Boots - Minor Speed
    [013898] = 038838, -- Enchant Weapon - Fiery Weapon
    [013905] = 038839, -- Enchant Shield - Greater Versatility
    [013915] = 038840, -- Enchant Weapon - Demonslaying
    [013917] = 038841, -- Enchant Chest - Superior Mana
    [013931] = 038842, -- Enchant Bracer - Dodge
    [013935] = 038844, -- Enchant Boots - Agility
    [013937] = 038845, -- Enchant 2H Weapon - Greater Impact
    [013939] = 038846, -- Enchant Bracer - Greater Strength
    [013941] = 038847, -- Enchant Chest - Stats
    [013943] = 038848, -- Enchant Weapon - Greater Striking
    [013945] = 038849, -- Enchant Bracer - Greater Stamina
    [013947] = 038850, -- Enchant Gloves - Riding Skill
    [013948] = 038851, -- Enchant Gloves - Minor Haste
    [020008] = 038852, -- Enchant Bracer - Greater Intellect
    [020009] = 038853, -- Enchant Bracer - Superior Versatility
    [020010] = 038854, -- Enchant Bracer - Superior Strength
    [020011] = 038855, -- Enchant Bracer - Superior Stamina
    [020012] = 038856, -- Enchant Gloves - Greater Agility
    [020013] = 038857, -- Enchant Gloves - Greater Strength
    [020015] = 038859, -- Enchant Cloak - Superior Defense
    [020016] = 038860, -- Enchant Shield - Vitality
    [020017] = 038861, -- Enchant Shield - Greater Stamina
    [020020] = 038862, -- Enchant Boots - Greater Stamina
    [020023] = 038863, -- Enchant Boots - Greater Agility
    [020024] = 038864, -- Enchant Boots - Versatility
    [020025] = 038865, -- Enchant Chest - Greater Stats
    [020026] = 038866, -- Enchant Chest - Major Health
    [020028] = 038867, -- Enchant Chest - Major Mana
    [020029] = 038868, -- Enchant Weapon - Icy Chill
    [020030] = 038869, -- Enchant 2H Weapon - Superior Impact
    [020031] = 038870, -- Enchant Weapon - Superior Striking
    [020032] = 038871, -- Enchant Weapon - Lifestealing
    [020033] = 038872, -- Enchant Weapon - Unholy Weapon
    [020034] = 038873, -- Enchant Weapon - Crusader
    [020035] = 038874, -- Enchant 2H Weapon - Major Versatility
    [020036] = 038875, -- Enchant 2H Weapon - Major Intellect
    [021931] = 038876, -- Enchant Weapon - Winter's Might
    [022749] = 038877, -- Enchant Weapon - Spellpower
    [022750] = 038878, -- Enchant Weapon - Healing Power
    [023799] = 038879, -- Enchant Weapon - Strength
    [023800] = 038880, -- Enchant Weapon - Agility
    [023801] = 038881, -- Enchant Bracer - Argent Versatility
    [023802] = 038882, -- Enchant Bracer - Healing Power
    [023803] = 038883, -- Enchant Weapon - Mighty Versatility
    [023804] = 038884, -- Enchant Weapon - Mighty Intellect
    [025072] = 038885, -- Enchant Gloves - Threat
    [025073] = 038886, -- Enchant Gloves - Shadow Power
    [025074] = 038887, -- Enchant Gloves - Frost Power
    [025078] = 038888, -- Enchant Gloves - Fire Power
    [025079] = 038889, -- Enchant Gloves - Healing Power
    [025080] = 038890, -- Enchant Gloves - Superior Agility
    [025083] = 038893, -- Enchant Cloak - Stealth
    [025084] = 038894, -- Enchant Cloak - Subtlety
    [025086] = 038895, -- Enchant Cloak - Dodge
    [027837] = 038896, -- Enchant 2H Weapon - Agility
    [027899] = 038897, -- Enchant Bracer - Brawn
    [027905] = 035426, -- Enchant Bracer - Stats
    [027905] = 038898, -- Enchant Bracer - Stats
    [027906] = 035422, -- Enchant Bracer - Greater Dodge
    [027906] = 038899, -- Enchant Bracer - Greater Dodge
    [027911] = 035427, -- Enchant Bracer - Superior Healing
    [027911] = 038900, -- Enchant Bracer - Superior Healing
    [027913] = 035424, -- Enchant Bracer - Restore Mana Prime
    [027913] = 038901, -- Enchant Bracer - Versatility Prime
    [027914] = 035421, -- Enchant Bracer - Fortitude
    [027914] = 038902, -- Enchant Bracer - Fortitude
    [027917] = 035425, -- Enchant Bracer - Spellpower
    [027917] = 038903, -- Enchant Bracer - Spellpower
    [027944] = 038904, -- Enchant Shield - Lesser Dodge
    [027945] = 035448, -- Enchant Shield - Intellect
    [027945] = 038905, -- Enchant Shield - Intellect
    [027946] = 035451, -- Enchant Shield - Parry
    [027946] = 038906, -- Enchant Shield - Parry
    [027948] = 035419, -- Enchant Boots - Vitality
    [027948] = 038908, -- Enchant Boots - Vitality
    [027950] = 035417, -- Enchant Boots - Fortitude
    [027950] = 038909, -- Enchant Boots - Fortitude
    [027951] = 035400, -- Enchant Boots - Dexterity
    [027951] = 037603, -- Enchant Boots - Dexterity
    [027954] = 035418, -- Enchant Boots - Surefooted
    [027954] = 038910, -- Enchant Boots - Surefooted
    [027957] = 035428, -- Enchant Chest - Exceptional Health
    [027957] = 038911, -- Enchant Chest - Exceptional Health
    [027958] = 038912, -- Enchant Chest - Exceptional Mana
    [027960] = 035429, -- Enchant Chest - Exceptional Stats
    [027960] = 038913, -- Enchant Chest - Exceptional Stats
    [027961] = 035437, -- Enchant Cloak - Major Armor
    [027961] = 038914, -- Enchant Cloak - Major Armor
    [027967] = 035457, -- Enchant Weapon - Major Striking
    [027967] = 038917, -- Enchant Weapon - Major Striking
    [027968] = 035455, -- Enchant Weapon - Major Intellect
    [027968] = 038918, -- Enchant Weapon - Major Intellect
    [027971] = 035397, -- Enchant 2H Weapon - Savagery
    [027971] = 038919, -- Enchant 2H Weapon - Savagery
    [027972] = 035459, -- Enchant Weapon - Potency
    [027972] = 038920, -- Enchant Weapon - Potency
    [027975] = 035456, -- Enchant Weapon - Major Spellpower
    [027975] = 038921, -- Enchant Weapon - Major Spellpower
    [027977] = 035396, -- Enchant 2H Weapon - Major Agility
    [027977] = 038922, -- Enchant 2H Weapon - Major Agility
    [027981] = 035462, -- Enchant Weapon - Sunfire
    [027981] = 038923, -- Enchant Weapon - Sunfire
    [027982] = 035460, -- Enchant Weapon - Soulfrost
    [027982] = 038924, -- Enchant Weapon - Soulfrost
    [027984] = 035458, -- Enchant Weapon - Mongoose
    [027984] = 038925, -- Enchant Weapon - Mongoose
    [028003] = 035461, -- Enchant Weapon - Spellsurge
    [028003] = 038926, -- Enchant Weapon - Spellsurge
    [028004] = 035452, -- Enchant Weapon - Battlemaster
    [028004] = 038927, -- Enchant Weapon - Battlemaster
    [033990] = 035431, -- Enchant Chest - Major Spirit
    [033990] = 038928, -- Enchant Chest - Major Versatility
    [033991] = 038929, -- Enchant Chest - Versatility Prime
    [033992] = 035430, -- Enchant Chest - Major Resilience
    [033992] = 038930, -- Enchant Chest - Major Armor
    [033993] = 035439, -- Enchant Gloves - Blasting
    [033993] = 038931, -- Enchant Gloves - Blasting
    [033994] = 035443, -- Enchant Gloves - Spell Strike
    [033994] = 038932, -- Enchant Gloves - Precise Strikes
    [033995] = 035442, -- Enchant Gloves - Major Strength
    [033995] = 038933, -- Enchant Gloves - Major Strength
    [033996] = 035438, -- Enchant Gloves - Assault
    [033996] = 038934, -- Enchant Gloves - Assault
    [033997] = 035441, -- Enchant Gloves - Major Spellpower
    [033997] = 038935, -- Enchant Gloves - Major Spellpower
    [033999] = 035440, -- Enchant Gloves - Major Healing
    [033999] = 038936, -- Enchant Gloves - Major Healing
    [034001] = 035423, -- Enchant Bracer - Major Intellect
    [034001] = 038937, -- Enchant Bracer - Major Intellect
    [034002] = 038938, -- Enchant Bracer - Lesser Assault
    [034003] = 035436, -- Enchant Cloak - PvP Power
    [034003] = 038939, -- Enchant Cloak - Empowerment
    [034004] = 035432, -- Enchant Cloak - Greater Agility
    [034004] = 038940, -- Enchant Cloak - Greater Agility
    [034007] = 035399, -- Enchant Boots - Cat's Swiftness
    [034007] = 038943, -- Enchant Boots - Cat's Swiftness
    [034008] = 035398, -- Enchant Boots - Boar's Speed
    [034008] = 038944, -- Enchant Boots - Boar's Speed
    [034009] = 035449, -- Enchant Shield - Major Stamina
    [034009] = 038945, -- Enchant Shield - Major Stamina
    [034010] = 035454, -- Enchant Weapon - Major Healing
    [034010] = 038946, -- Enchant Weapon - Major Healing
    [042620] = 035453, -- Enchant Weapon - Greater Agility
    [042620] = 038947, -- Enchant Weapon - Greater Agility
    [042974] = 038948, -- Enchant Weapon - Executioner
    [044383] = 038949, -- Enchant Shield - Armor
    [044484] = 038951, -- Enchant Gloves - Haste
    [044488] = 038953, -- Enchant Gloves - Precision
    [044489] = 038954, -- Enchant Shield - Dodge
    [044492] = 038955, -- Enchant Chest - Mighty Health
    [044500] = 038959, -- Enchant Cloak - Superior Agility
    [044506] = 038960, -- Enchant Gloves - Gatherer
    [044508] = 038961, -- Enchant Boots - Greater Versatility
    [044509] = 038962, -- Enchant Chest - Greater Versatility
    [044510] = 038963, -- Enchant Weapon - Exceptional Versatility
    [044513] = 038964, -- Enchant Gloves - Greater Assault
    [044524] = 038965, -- Enchant Weapon - Icebreaker
    [044528] = 038966, -- Enchant Boots - Greater Fortitude
    [044529] = 038967, -- Enchant Gloves - Major Agility
    [044555] = 038968, -- Enchant Bracer - Exceptional Intellect
    [044575] = 044815, -- Enchant Bracer - Greater Assault
    [044576] = 038972, -- Enchant Weapon - Lifeward
    [044582] = 038973, -- Enchant Cloak - Minor Power
    [044584] = 038974, -- Enchant Boots - Greater Vitality
    [044588] = 038975, -- Enchant Chest - Exceptional Armor
    [044589] = 038976, -- Enchant Boots - Superior Agility
    [044591] = 038978, -- Enchant Cloak - Superior Dodge
    [044592] = 038979, -- Enchant Gloves - Exceptional Spellpower
    [044593] = 038980, -- Enchant Bracer - Major Versatility
    [044595] = 038981, -- Enchant 2H Weapon - Scourgebane
    [044598] = 038984, -- Enchant Bracer - Haste
    [044612] = 038985, -- Enchant Gloves - Greater Blasting
    [044616] = 038987, -- Enchant Bracer - Greater Stats
    [044621] = 038988, -- Enchant Weapon - Giant Slayer
    [044623] = 038989, -- Enchant Chest - Super Stats
    [044625] = 038990, -- Enchant Gloves - Armsman
    [044629] = 038991, -- Enchant Weapon - Exceptional Spellpower
    [044630] = 038992, -- Enchant 2H Weapon - Greater Savagery
    [044631] = 038993, -- Enchant Cloak - Shadow Armor
    [044633] = 038995, -- Enchant Weapon - Exceptional Agility
    [044635] = 038997, -- Enchant Bracer - Greater Spellpower
    [046578] = 038998, -- Enchant Weapon - Deathfrost
    [046594] = 038999, -- Enchant Chest - Dodge
    [047051] = 039000, -- Enchant Cloak - Greater Dodge
    [047672] = 039001, -- Enchant Cloak - Mighty Stamina
    [047766] = 039002, -- Enchant Chest - Greater Dodge
    [047898] = 039003, -- Enchant Cloak - Greater Speed
    [047899] = 039004, -- Enchant Cloak - Wisdom
    [047900] = 039005, -- Enchant Chest - Super Health
    [047901] = 039006, -- Enchant Boots - Tuskarr's Vitality
    [059619] = 044497, -- Enchant Weapon - Accuracy
    [059621] = 044493, -- Enchant Weapon - Berserking
    [059625] = 043987, -- Enchant Weapon - Black Magic
    [060606] = 044449, -- Enchant Boots - Assault
    [060609] = 044456, -- Enchant Cloak - Speed
    [060616] = 038971, -- Enchant Bracer - Assault
    [060621] = 044453, -- Enchant Weapon - Greater Potency
    [060623] = 038986, -- Enchant Boots - Icewalker
    [060653] = 044455, -- Shield Enchant - Greater Intellect
    [060663] = 044457, -- Enchant Cloak - Major Agility
    [060668] = 044458, -- Enchant Gloves - Crusher
    [060691] = 044463, -- Enchant 2H Weapon - Massacre
    [060692] = 044465, -- Enchant Chest - Powerful Stats
    [060707] = 044466, -- Enchant Weapon - Superior Potency
    [060714] = 044467, -- Enchant Weapon - Mighty Spellpower
    [060763] = 044469, -- Enchant Boots - Greater Assault
    [060767] = 044470, -- Enchant Bracer - Superior Spellpower
    [062256] = 044947, -- Enchant Bracer - Major Stamina
    [062257] = 044946, -- Enchant Weapon - Titanguard
    [062948] = 045056, -- Enchant Staff - Greater Spellpower
    [062959] = 045060, -- Enchant Staff - Spellpower
    [063746] = 045628, -- Enchant Boots - Lesser Accuracy
    [064441] = 046026, -- Enchant Weapon - Blade Ward
    [064579] = 046098, -- Enchant Weapon - Blood Draining
    [071692] = 050816, -- Enchant Gloves - Angler
    [074132] = 052687, -- Enchant Gloves - Mastery
    [074189] = 052743, -- Enchant Boots - Earthen Vitality
    [074191] = 052744, -- Enchant Chest - Mighty Stats
    [074192] = 052745, -- Enchant Cloak - Lesser Power
    [074193] = 052746, -- Enchant Bracer - Speed
    [074195] = 052747, -- Enchant Weapon - Mending
    [074197] = 052748, -- Enchant Weapon - Avalanche
    [074198] = 052749, -- Enchant Gloves - Haste
    [074199] = 052750, -- Enchant Boots - Haste
    [074200] = 052751, -- Enchant Chest - Stamina
    [074201] = 052752, -- Enchant Bracer - Critical Strike
    [074202] = 052753, -- Enchant Cloak - Intellect
    [074207] = 052754, -- Enchant Shield - Protection
    [074211] = 052755, -- Enchant Weapon - Elemental Slayer
    [074212] = 052756, -- Enchant Gloves - Exceptional Strength
    [074213] = 052757, -- Enchant Boots - Major Agility
    [074214] = 052758, -- Enchant Chest - Mighty Armor
    [074220] = 052759, -- Enchant Gloves - Greater Haste
    [074223] = 052760, -- Enchant Weapon - Hurricane
    [074225] = 052761, -- Enchant Weapon - Heartsong
    [074226] = 052762, -- Enchant Shield - Mastery
    [074229] = 052763, -- Enchant Bracer - Superior Dodge
    [074230] = 052764, -- Enchant Cloak - Critical Strike
    [074231] = 052765, -- Enchant Chest - Exceptional Versatility
    [074232] = 052766, -- Enchant Bracer - Precision
    [074234] = 052767, -- Enchant Cloak - Protection
    [074235] = 052768, -- Enchant Off-Hand - Superior Intellect
    [074236] = 052769, -- Enchant Boots - Precision
    [074237] = 052770, -- Enchant Bracer - Exceptional Versatility
    [074238] = 052771, -- Enchant Boots - Mastery
    [074239] = 052772, -- Enchant Bracer - Greater Haste
    [074240] = 052773, -- Enchant Cloak - Greater Intellect
    [074242] = 052774, -- Enchant Weapon - Power Torrent
    [074244] = 052775, -- Enchant Weapon - Windwalk
    [074246] = 052776, -- Enchant Weapon - Landslide
    [074247] = 052777, -- Enchant Cloak - Greater Critical Strike
    [074248] = 052778, -- Enchant Bracer - Greater Critical Strike
    [074250] = 052779, -- Enchant Chest - Peerless Stats
    [074251] = 052780, -- Enchant Chest - Greater Stamina
    [074252] = 052781, -- Enchant Boots - Assassin's Step
    [074253] = 052782, -- Enchant Boots - Lavawalker
    [074254] = 052783, -- Enchant Gloves - Mighty Strength
    [074255] = 052784, -- Enchant Gloves - Greater Mastery
    [074256] = 052785, -- Enchant Bracer - Greater Speed
    [095471] = 068134, -- Enchant 2H Weapon - Mighty Agility
    [096261] = 068785, -- Enchant Bracer - Major Strength
    [096262] = 068786, -- Enchant Bracer - Mighty Intellect
    [096264] = 068784, -- Enchant Bracer - Agility
    [104338] = 074700, -- Enchant Bracer - Mastery
    [104385] = 074701, -- Enchant Bracer - Major Dodge
    [104389] = 074703, -- Enchant Bracer - Super Intellect
    [104390] = 074704, -- Enchant Bracer - Exceptional Strength
    [104391] = 074705, -- Enchant Bracer - Greater Agility
    [104392] = 074706, -- Enchant Chest - Super Armor
    [104393] = 074707, -- Enchant Chest - Mighty Versatility
    [104395] = 074708, -- Enchant Chest - Glorious Stats
    [104397] = 074709, -- Enchant Chest - Superior Stamina
    [104398] = 074710, -- Enchant Cloak - Accuracy
    [104401] = 074711, -- Enchant Cloak - Greater Protection
    [104403] = 074712, -- Enchant Cloak - Superior Intellect
    [104404] = 074713, -- Enchant Cloak - Superior Critical Strike
    [104407] = 074715, -- Enchant Boots - Greater Haste
    [104408] = 074716, -- Enchant Boots - Greater Precision
    [104409] = 074717, -- Enchant Boots - Blurred Speed
    [104414] = 074718, -- Enchant Boots - Pandaren's Step
    [104416] = 074719, -- Enchant Gloves - Greater Haste
    [104417] = 074720, -- Enchant Gloves - Superior Haste
    [104419] = 074721, -- Enchant Gloves - Super Strength
    [104420] = 074722, -- Enchant Gloves - Superior Mastery
    [104425] = 074723, -- Enchant Weapon - Windsong
    [104427] = 074724, -- Enchant Weapon - Jade Spirit
    [104430] = 074725, -- Enchant Weapon - Elemental Force
    [104434] = 074726, -- Enchant Weapon - Dancing Steel
    [104440] = 074727, -- Enchant Weapon - Colossus
    [104442] = 074728, -- Enchant Weapon - River's Song
    [104445] = 074729, -- Enchant Off-Hand - Major Intellect
    [130758] = 089737, -- Enchant Shield - Greater Parry
    [158877] = 110631, -- Enchant Cloak - Breath of Critical Strike
    [158878] = 110632, -- Enchant Cloak - Breath of Haste
    [158879] = 110633, -- Enchant Cloak - Breath of Mastery
    [158881] = 110635, -- Enchant Cloak - Breath of Versatility
    [158884] = 110652, -- Enchant Cloak - Gift of Critical Strike
    [158885] = 110653, -- Enchant Cloak - Gift of Haste
    [158886] = 110654, -- Enchant Cloak - Gift of Mastery
    [158889] = 110656, -- Enchant Cloak - Gift of Versatility
    [158892] = 110624, -- Enchant Neck - Breath of Critical Strike
    [158893] = 110625, -- Enchant Neck - Breath of Haste
    [158894] = 110626, -- Enchant Neck - Breath of Mastery
    [158896] = 110628, -- Enchant Neck - Breath of Versatility
    [158899] = 110645, -- Enchant Neck - Gift of Critical Strike
    [158900] = 110646, -- Enchant Neck - Gift of Haste
    [158901] = 110647, -- Enchant Neck - Gift of Mastery
    [158903] = 110649, -- Enchant Neck - Gift of Versatility
    [158907] = 110617, -- Enchant Ring - Breath of Critical Strike
    [158908] = 110618, -- Enchant Ring - Breath of Haste
    [158909] = 110619, -- Enchant Ring - Breath of Mastery
    [158911] = 110621, -- Enchant Ring - Breath of Versatility
    [158914] = 110638, -- Enchant Ring - Gift of Critical Strike
    [158915] = 110639, -- Enchant Ring - Gift of Haste
    [158916] = 110640, -- Enchant Ring - Gift of Mastery
    [158918] = 110642, -- Enchant Ring - Gift of Versatility
    [159235] = 110682, -- Enchant Weapon - Mark of the Thunderlord
    [159236] = 112093, -- Enchant Weapon - Mark of the Shattered Hand
    [159671] = 112164, -- Enchant Weapon - Mark of Warsong
    [159672] = 112165, -- Enchant Weapon - Mark of the Frostwolf
    [159673] = 112115, -- Enchant Weapon - Mark of Shadowmoon
    [159674] = 112160, -- Enchant Weapon - Mark of Blackrock
    [173323] = 118015, -- Enchant Weapon - Mark of Bleeding Hollow
    [190866] = 128537, -- Enchant Ring - Word of Critical Strike
    [190867] = 128538, -- Enchant Ring - Word of Haste
    [190868] = 128539, -- Enchant Ring - Word of Mastery
    [190869] = 128540, -- Enchant Ring - Word of Versatility
    [190870] = 128541, -- Enchant Ring - Binding of Critical Strike
    [190871] = 128542, -- Enchant Ring - Binding of Haste
    [190872] = 128543, -- Enchant Ring - Binding of Mastery
    [190873] = 128544, -- Enchant Ring - Binding of Versatility
    [190874] = 128545, -- Enchant Cloak - Word of Strength
    [190875] = 128546, -- Enchant Cloak - Word of Agility
    [190876] = 128547, -- Enchant Cloak - Word of Intellect
    [190877] = 128548, -- Enchant Cloak - Binding of Strength
    [190878] = 128549, -- Enchant Cloak - Binding of Agility
    [190879] = 128550, -- Enchant Cloak - Binding of Intellect
    [190892] = 128551, -- Enchant Neck - Mark of the Claw
    [190893] = 128552, -- Enchant Neck - Mark of the Distant Army
    [190894] = 128553, -- Enchant Neck - Mark of the Hidden Satyr
    [190954] = 128554, -- Enchant Shoulder - Boon of the Scavenger
    [190988] = 128558, -- Enchant Gloves - Legion Herbalism
    [190989] = 128559, -- Enchant Gloves - Legion Mining
    [190990] = 128560, -- Enchant Gloves - Legion Skinning
    [190991] = 128561, -- Enchant Gloves - Legion Surveying
    [190992] = 128537, -- Enchant Ring - Word of Critical Strike
    [190993] = 128538, -- Enchant Ring - Word of Haste
    [190994] = 128539, -- Enchant Ring - Word of Mastery
    [190995] = 128540, -- Enchant Ring - Word of Versatility
    [190996] = 128541, -- Enchant Ring - Binding of Critical Strike
    [190997] = 128542, -- Enchant Ring - Binding of Haste
    [190998] = 128543, -- Enchant Ring - Binding of Mastery
    [190999] = 128544, -- Enchant Ring - Binding of Versatility
    [191000] = 128545, -- Enchant Cloak - Word of Strength
    [191001] = 128546, -- Enchant Cloak - Word of Agility
    [191002] = 128547, -- Enchant Cloak - Word of Intellect
    [191003] = 128548, -- Enchant Cloak - Binding of Strength
    [191004] = 128549, -- Enchant Cloak - Binding of Agility
    [191005] = 128550, -- Enchant Cloak - Binding of Intellect
    [191006] = 128551, -- Enchant Neck - Mark of the Claw
    [191007] = 128552, -- Enchant Neck - Mark of the Distant Army
    [191008] = 128553, -- Enchant Neck - Mark of the Hidden Satyr
    [191009] = 128537, -- Enchant Ring - Word of Critical Strike
    [191010] = 128538, -- Enchant Ring - Word of Haste
    [191011] = 128539, -- Enchant Ring - Word of Mastery
    [191012] = 128540, -- Enchant Ring - Word of Versatility
    [191013] = 128541, -- Enchant Ring - Binding of Critical Strike
    [191014] = 128542, -- Enchant Ring - Binding of Haste
    [191015] = 128543, -- Enchant Ring - Binding of Mastery
    [191016] = 128544, -- Enchant Ring - Binding of Versatility
    [191017] = 128545, -- Enchant Cloak - Word of Strength
    [191018] = 128546, -- Enchant Cloak - Word of Agility
    [191019] = 128547, -- Enchant Cloak - Word of Intellect
    [191020] = 128548, -- Enchant Cloak - Binding of Strength
    [191021] = 128549, -- Enchant Cloak - Binding of Agility
    [191022] = 128550, -- Enchant Cloak - Binding of Intellect
    [191023] = 128551, -- Enchant Neck - Mark of the Claw
    [191024] = 128552, -- Enchant Neck - Mark of the Distant Army
    [191025] = 128553, -- Enchant Neck - Mark of the Hidden Satyr
    [228402] = 141908, -- Enchant Neck - Mark of the Heavy Hide
    [228403] = 141908, -- Enchant Neck - Mark of the Heavy Hide
    [228404] = 141908, -- Enchant Neck - Mark of the Heavy Hide
    [228405] = 141909, -- Enchant Neck - Mark of the Trained Soldier
    [228406] = 141909, -- Enchant Neck - Mark of the Trained Soldier
    [228407] = 141909, -- Enchant Neck - Mark of the Trained Soldier
    [228408] = 141910, -- Enchant Neck - Mark of the Ancient Priestess
    [228409] = 141910, -- Enchant Neck - Mark of the Ancient Priestess
    [228410] = 141910, -- Enchant Neck - Mark of the Ancient Priestess
    [235695] = 144304, -- Enchant Neck - Mark of the Master
    [235696] = 144305, -- Enchant Neck - Mark of the Versatile
    [235697] = 144306, -- Enchant Neck - Mark of the Quick
    [235698] = 144307, -- Enchant Neck - Mark of the Deadly
    [235699] = 144304, -- Enchant Neck - Mark of the Master
    [235700] = 144305, -- Enchant Neck - Mark of the Versatile
    [235701] = 144306, -- Enchant Neck - Mark of the Quick
    [235702] = 144307, -- Enchant Neck - Mark of the Deadly
    [235703] = 144304, -- Enchant Neck - Mark of the Master
    [235704] = 144305, -- Enchant Neck - Mark of the Versatile
    [235705] = 144306, -- Enchant Neck - Mark of the Quick
    [235706] = 144307, -- Enchant Neck - Mark of the Deadly
    [255071] = 153438, -- Enchant Ring - Seal of Critical Strike
    [255072] = 153439, -- Enchant Ring - Seal of Haste
    [255073] = 153440, -- Enchant Ring - Seal of Mastery
    [255074] = 153441, -- Enchant Ring - Seal of Versatility
    [255075] = 153442, -- Enchant Ring - Pact of Critical Strike
    [255076] = 153443, -- Enchant Ring - Pact of Haste
    [255077] = 153444, -- Enchant Ring - Pact of Mastery
    [255078] = 153445, -- Enchant Ring - Pact of Versatility
    [255086] = 153438, -- Enchant Ring - Seal of Critical Strike
    [255087] = 153439, -- Enchant Ring - Seal of Haste
    [255088] = 153440, -- Enchant Ring - Seal of Mastery
    [255089] = 153441, -- Enchant Ring - Seal of Versatility
    [255090] = 153442, -- Enchant Ring - Pact of Critical Strike
    [255091] = 153443, -- Enchant Ring - Pact of Haste
    [255092] = 153444, -- Enchant Ring - Pact of Mastery
    [255093] = 153445, -- Enchant Ring - Pact of Versatility
    [255094] = 153438, -- Enchant Ring - Seal of Critical Strike
    [255095] = 153439, -- Enchant Ring - Seal of Haste
    [255096] = 153440, -- Enchant Ring - Seal of Mastery
    [255097] = 153441, -- Enchant Ring - Seal of Versatility
    [255098] = 153442, -- Enchant Ring - Pact of Critical Strike
    [255099] = 153443, -- Enchant Ring - Pact of Haste
    [255100] = 153444, -- Enchant Ring - Pact of Mastery
    [255101] = 153445, -- Enchant Ring - Pact of Versatility
    [255103] = 153476, -- Enchant Weapon - Coastal Surge
    [255104] = 153476, -- Enchant Weapon - Coastal Surge
    [255105] = 153476, -- Enchant Weapon - Coastal Surge
    [255110] = 153478, -- Enchant Weapon - Siphoning
    [255111] = 153478, -- Enchant Weapon - Siphoning
    [255112] = 153478, -- Enchant Weapon - Siphoning
    [255129] = 153479, -- Enchant Weapon - Torrent of Elements
    [255130] = 153479, -- Enchant Weapon - Torrent of Elements
    [255131] = 153479, -- Enchant Weapon - Torrent of Elements
    [255141] = 153480, -- Enchant Weapon - Gale-Force Striking
    [255142] = 153480, -- Enchant Weapon - Gale-Force Striking
    [255143] = 153480, -- Enchant Weapon - Gale-Force Striking
    [267458] = 159464, -- Enchant Gloves - Zandalari Herbalism
    [267482] = 159466, -- Enchant Gloves - Zandalari Mining
    [267486] = 159467, -- Enchant Gloves - Zandalari Skinning
    [267490] = 159468, -- Enchant Gloves - Zandalari Surveying
    [267495] = 159469, -- Enchant Bracers - Swift Hearthing
    [267498] = 159471, -- Enchant Gloves - Zandalari Crafting
    [268852] = 159788, -- Enchant Weapon - Versatile Navigation
    [268878] = 159788, -- Enchant Weapon - Versatile Navigation
    [268879] = 159788, -- Enchant Weapon - Versatile Navigation
    [268894] = 159786, -- Enchant Weapon - Quick Navigation
    [268895] = 159786, -- Enchant Weapon - Quick Navigation
    [268897] = 159786, -- Enchant Weapon - Quick Navigation
    [268901] = 159787, -- Enchant Weapon - Masterful Navigation
    [268902] = 159787, -- Enchant Weapon - Masterful Navigation
    [268903] = 159787, -- Enchant Weapon - Masterful Navigation
    [268907] = 159785, -- Enchant Weapon - Deadly Navigation
    [268908] = 159785, -- Enchant Weapon - Deadly Navigation
    [268909] = 159785, -- Enchant Weapon - Deadly Navigation
    [268913] = 159789, -- Enchant Weapon - Stalwart Navigation
    [268914] = 159789, -- Enchant Weapon - Stalwart Navigation
    [268915] = 159789, -- Enchant Weapon - Stalwart Navigation
    [271366] = 160328, -- Enchant Bracers - Safe Hearthing
    [271433] = 160330, -- Enchant Bracers - Cooled Hearthing
    [297989] = 168447, -- Enchant Ring - Accord of Haste
    [297991] = 168449, -- Enchant Ring - Accord of Versatility
    [297993] = 168449, -- Enchant Ring - Accord of Versatility
    [297994] = 168447, -- Enchant Ring - Accord of Haste
    [297995] = 168448, -- Enchant Ring - Accord of Mastery
    [297999] = 168449, -- Enchant Ring - Accord of Versatility
    [298001] = 168448, -- Enchant Ring - Accord of Mastery
    [298002] = 168448, -- Enchant Ring - Accord of Mastery
    [298009] = 168446, -- Enchant Ring - Accord of Critical Strike
    [298010] = 168446, -- Enchant Ring - Accord of Critical Strike
    [298011] = 168446, -- Enchant Ring - Accord of Critical Strike
    [298016] = 168447, -- Enchant Ring - Accord of Haste
    [298433] = 168593, -- Enchant Weapon - Machinist's Brilliance
    [298437] = 168592, -- Enchant Weapon - Oceanic Restoration
    [298438] = 168592, -- Enchant Weapon - Oceanic Restoration
    [298439] = 168596, -- Enchant Weapon - Force Multiplier
    [298440] = 168596, -- Enchant Weapon - Force Multiplier
    [298441] = 168598, -- Enchant Weapon - Naga Hide
    [298442] = 168598, -- Enchant Weapon - Naga Hide
    [298515] = 168592, -- Enchant Weapon - Oceanic Restoration
    [300769] = 168593, -- Enchant Weapon - Machinist's Brilliance
    [300770] = 168593, -- Enchant Weapon - Machinist's Brilliance
    [300788] = 168596, -- Enchant Weapon - Force Multiplier
    [300789] = 168598, -- Enchant Weapon - Naga Hide
}

