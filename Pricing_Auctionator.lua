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

local function AuctionValue(itemID)
    local auctionPrice = Atr_GetAuctionPrice(itemID)
    if auctionPrice then
        return auctionPrice, "a"
    end
end

local function DisenchantValue(itemID)
    local dePrice = Atr_GetDisenchantValue(itemID)
    if dePrice then
        return dePrice, "d"
    end
end

local function Cost(itemID)
    return Atr_GetAuctionPrice(itemID), "a"
end

if Atr_GetAuctionPrice then
    table.insert(TSP.valueFunctions, AuctionValue)
    table.insert(TSP.valueFunctions, DisenchantValue)
    table.insert(TSP.costFunctions, Cost)

    Atr_RegisterFor_DBupdated(function () TSP:RecalculatePrices() end)
end
