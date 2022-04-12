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

local function AuctionPrice(itemLink, count)
    local info = {}
    TUJMarketInfo(itemLink, info)
    if info['recent'] then
        return info['recent'] * count, "a"
    end
end

local function UpdateTime()
    return 0
end

if TUJMarketInfo then
    table.insert(TradeSkillPrice.priceModules,
        {
            ['name'] = 'TheUndermineJournal',
            ['GetBuyPrice'] = AuctionPrice,
            ['GetSellPrice'] = AuctionPrice,
            ['GetUpdateTime'] = UpdateTime,
        })
end
