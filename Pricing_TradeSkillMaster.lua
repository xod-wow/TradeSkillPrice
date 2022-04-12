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
    local itemString = TSM_API.ToItemString(itemLink)
    local a = TSM_API.GetCustomPriceValue('DBMarket', itemString) or 0
    local d = TSM_API.GetCustomPriceValue('Destroy', itemString) or 0
    local v = TSM_API.GetCustomPriceValue('VendorSell', itemString) or 0

    local p = math.max(a, d, v)

    if p == a then
        return a * count, "a"
    elseif p == d then
        return d * count, "d"
    elseif p == v then
        return v * count, "v"
    end
end

local function Cost(itemLink, count)
    local itemString = TSM_API.ToItemString(itemLink)
    local p = TSM_API.GetCustomPriceValue('DBMarket', itemString)
    if p then
        return p * count, "a"
    end
end

local function UpdateTime()
    -- this is super sketchy
    if TradeSkillMaster_AppHelperDB then
        return TradeSkillMaster_AppHelperDB.analytics.updateTime
    else
        return time()
    end
end

if TSM_API then
    table.insert(TradeSkillPrice.priceModules,
        {
            ['name'] = 'TSM_API',
            ['GetSellPrice'] =  Value,
            ['GetBuyPrice'] = Cost,
            ['GetUpdateTime'] = UpdateTime,
        })
end
