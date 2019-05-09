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

local function GetVendorCost(itemID)
    -- Unbound Tradeskill - Other items are assumed to be buyable
    local sellPrice, classID, subID, bindType = select(11, GetItemInfo(itemID))
    if bindType == 0 and classID == 7 and subID == 11 and sellPrice > 0 then
        return sellPrice * 4, "v"
    end
end

local function GetVendorValue(itemID)
    local sellPrice = select(11, GetItemInfo(itemID))
    return sellPrice, "v"
end

table.insert(TSP.costFunctions, GetVendorCost)
table.insert(TSP.valueFunctions, GetVendorValue)
