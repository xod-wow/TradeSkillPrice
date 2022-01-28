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

local function AuctionValue(itemID, count)
    local a = Auctionator.API.v1.GetAuctionPriceByItemID(addonName, itemID)
    local d = Auctionator.API.v1.GetDisenchantPriceByItemID(addonName, itemID)
    if a and a > (d or 0) then
        return a * count, "a"
    elseif d and d > (a or 0) then
        return d * count, "d"
    end
end

local function Cost(itemID, count)
    local price = Auctionator.API.v1.GetAuctionPriceByItemID(addonName, itemID)
    if price then
        return price * count, "a"
    end
end

if Auctionator and Auctionator.API and Auctionator.API.v1 then
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
end
