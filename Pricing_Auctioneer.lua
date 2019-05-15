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

local function Value(itemID)
    local price = AucAdvanced.API.GetMarketValue(itemID)
    if price then
        return price, "a"
    end
end

local function Cost(itemID)
    local cost = AucAdvanced.API.GetAlgorithmValue("Appraiser", itemID)
    if cost then
        return cost, "a"
    end
end

if AucAdvanced and AucAdvanced.API then
    table.insert(TradeSkillPrice.valueFunctions,
                {
                    ['name'] = 'Auctioneer',
                    ['func'] =  Value
                })
    table.insert(TradeSkillPrice.costFunctions,
                {
                    ['name'] = 'Auctioneer',
                    ['func'] =  Cost
                })

    local mod = AucAdvanced.NewModule("Util", "TradeSkillPrice")
    mod.Processors = {}
    mod.Processors.scanstats = function () TradeSkillPrice:RecalculatePrices() end
end
