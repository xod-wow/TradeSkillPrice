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

local function Cost(itemLink, count)
    local itemID = GetItemInfoFromHyperlink(itemLink)
    if TradeSkillPrice.db.fixedPrice and TradeSkillPrice.db.fixedPrice[itemID] then
        return TradeSkillPrice.db.fixedPrice[itemID] * count, "f"
    end
end

local function UpdateTime()
    return 1
end

table.insert(TradeSkillPrice.priceModules,
    {
        ['name'] = 'Fixed',
        ['GetBuyPrice'] = Cost,
        ['GetUpdateTime'] = UpdateTime,
    })
