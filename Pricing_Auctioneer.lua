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

local function Value(itemLink, count)
    local price = AucAdvanced.API.GetMarketValue(itemLink)
    if price then
        return price * count, "a"
    end
end

local function Cost(itemLink, count)
    local cost = AucAdvanced.API.GetAlgorithmValue("Appraiser", itemLink)
    if cost then
        return cost * count, "a"
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
