--[[----------------------------------------------------------------------------

    Copyright 2019 Mike Battersby

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

local IDCache = { }

-- Auctionator's data is indexed only by name, and access using ids goes
-- through a GetItemInfo name lookup
--
-- Auctionator keeps the itemIDs for the name in its history DB but it
-- never seems to use them, or make them available. Also some of them are
-- in gAtr_ScanDB, but not many.
--
-- Honestly the more I look at it the worse it seems.

local function RebuildIDCache()
    wipe(IDCache)
    for k,v in pairs(AUCTIONATOR_PRICING_HISTORY) do
        if v.is then
            local id = string.split(':', v.is)
            id = tonumber(id)
            IDCache[id] = IDCache[id] or {}
            IDCache[id][k] = true
        end
    end
    for k,v in pairs(gAtr_ScanDB) do
        if v.id then
            local id = string.split(':', v.id)
            id = tonumber(id)
            IDCache[id] = IDCache[id] or {}
            IDCache[id][k] = true
        end
    end
end

local function AuctionValue(itemID)
    if next(IDCache) == nil then
        RebuildIDCache()
    end

    -- Doing it this way has two advantages:
    --  1. It works before GetItemInfo returns id -> name data
    --  2. It picks up "<item> of the <suffix>" creations

    if IDCache[itemID] then
        local price, count
        for itemName in pairs(IDCache[itemID]) do
            local p = Atr_GetAuctionPrice(itemName)
            if p then
                price = (price or 0) + p
                count = (count or 0) + 1
            end
        end
        if price then
            return price/count, "a"
        end
    else
        local price = Atr_GetAuctionPrice(itemID)
        if price then
            return price, "a"
        end
    end
end

local function DisenchantValue(itemID)
    local price

    -- Assumption is that if an item has multiple variants that they
    -- all DE the same.

    if IDCache[itemID] then
        local itemName = next(IDCache[itemID])
        price = Atr_GetDisenchantValue(itemName)
    else
        price = Atr_GetDisenchantValue(itemID)
    end

    return price, "d"
end

local function Cost(itemID)
    local price
    if IDCache[itemID] then
        local itemName = next(IDCache[itemID])
        price = Atr_GetAuctionPrice(itemName)
    else
        price = Atr_GetAuctionPrice(itemID)
    end
    if price then
        return price, "a"
    end
end

if Atr_GetAuctionPrice then
    table.insert(TSP.valueFunctions,
                {
                    ['name'] = 'Auctionator',
                    ['func'] =  AuctionValue
                })
    table.insert(TSP.valueFunctions,
                {
                    ['name'] = 'Auctionator Disenchant',
                    ['func'] = DisenchantValue
                })
    table.insert(TSP.costFunctions,
                {
                    ['name'] = 'Auctionator',
                    ['func'] = Cost
                })

    Atr_RegisterFor_DBupdated(
        function ()
            RebuildIDCache()
            TSP:RecalculatePrices()
        end)
end
