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

local IDCache = { }

-- Auctionator's data is indexed only by name, and access using ids goes
-- through a GetItemInfo name lookup (which means that they're not available
-- at first request).
--
-- Auctionator keeps the itemIDs for the name in its history DB but it
-- never seems to use them, or make them available. Also some of them are
-- in gAtr_ScanDB for items that are manually scanned.
--
-- Honestly the more I look at it the worse it seems. I guess the auction
-- API added the itemID after they wrote the addon and they never rewrote
-- it to take advantage.

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

local function AuctionValue(itemID, count)
    if next(IDCache) == nil then
        RebuildIDCache()
    end

    -- Doing it this way has two advantages:
    --  1. It works before GetItemInfo returns id -> name data
    --  2. It picks up "<item> of the <suffix>" creations

    local price

    if IDCache[itemID] then
        -- This is picking the minimum price, because that's what
        -- Atr_GetAuctionPrice does. It could do the mean price.
        for itemName in pairs(IDCache[itemID]) do
            local p = Atr_GetAuctionPrice(itemName)
            if p and (price == nil or p < price) then
                price = p
            end
        end
    else
        price = Atr_GetAuctionPrice(itemID)
    end

    if price then
        return price * count, "a"
    end
end

local function Cost(itemID, count)
    local price
    if IDCache[itemID] then
        local itemName = next(IDCache[itemID])
        price = Atr_GetAuctionPrice(itemName)
    else
        price = Atr_GetAuctionPrice(itemID)
    end
    if price then
        return price * count, "a"
    end
end

if Atr_GetAuctionPrice then
    table.insert(TradeSkillPrice.valueFunctions,
                {
                    ['name'] = 'Auctionator',
                    ['func'] =  AuctionValue
                })
    table.insert(TradeSkillPrice.costFunctions,
                {
                    ['name'] = 'Auctionator',
                    ['func'] = Cost
                })

    Atr_RegisterFor_DBupdated(
        function ()
            RebuildIDCache()
            TradeSkillPrice:RecalculatePrices()
        end)
end
