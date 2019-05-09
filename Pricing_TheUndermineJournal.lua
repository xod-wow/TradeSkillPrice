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

local function AuctionPrice(itemID)
    local info = {}
    TUJMarketInfo(itemID, info)
    return info['recent']
end

if TUJMarketInfo then
    table.insert(TSP.valueFunctions, AuctionPrice)
    table.insert(TSP.costFunctions, AuctionPrice)
end
