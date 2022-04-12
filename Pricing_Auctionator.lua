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

local addonName, addonTable = ...

local function Value(itemLink, count)
    local a = Auctionator.API.v1.GetAuctionPriceByItemLink(addonName, itemLink)
    local d = Auctionator.API.v1.GetDisenchantPriceByItemLink(addonName, itemLink)
    if a and a > (d or 0) then
        return a * count, "a"
    elseif d and d > (a or 0) then
        return d * count, "d"
    end
end

local function Cost(itemLink, count)
    local price = Auctionator.API.v1.GetAuctionPriceByItemLink(addonName, itemLink)
    if price then
        return price * count, "a"
    end
end

local function UpdateTime()
    return Auctionator.SavedState.TimeOfLastReplicateScan or 0
end

if Auctionator and Auctionator.API and Auctionator.API.v1 then
    table.insert(TradeSkillPrice.priceModules,
        {
            ['name'] = 'Auctionator',
            ['GetSellPrice'] =  Value,
            ['GetBuyPrice'] = Cost,
            ['GetUpdateTime'] = UpdateTime,
        })

    Auctionator.EventBus:Register(
        {
            ReceiveEvent =
                function ()
                    TradeSkillPrice:RecalculatePrices()
                end
        },
        {
            Auctionator.FullScan.Events.ScanComplete,
            Auctionator.IncrementalScan.Events.ScanComplete,
        }
    )
end
