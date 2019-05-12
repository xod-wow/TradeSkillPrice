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
    TSP.db.merchantItems = TSP.db.merchantItems or {}
    if TSP.db.merchantItems[itemID] then
        return TSP.db.merchantItems[itemID], "v"
    end
end

local function GetVendorValue(itemID)
    local sellPrice = select(11, GetItemInfo(itemID))
    return sellPrice, "v"
end

local function ScanMerchantForReagents()
    TSP.db.merchantItems = TSP.db.merchantItems or {}

    local _, price, numAvailable, isPurchasable, currencyID

    for i = 1, GetMerchantNumItems() do
        local id = GetMerchantItemID(i)
        _, _, price, _, numAvailable, isPurchasable, _, _, currencyID = GetMerchantItemInfo(i)

        if price > 0 and numAvailable < 0 and isPurchasable and not currencyID then
            if select(12, GetItemInfo(id)) == 7 then
                TSP.db.merchantItems[id] = price
            end
        end
    end
end

table.insert(TSP.costFunctions,
            {
                ['name'] = TRANSMOG_SOURCE_3,
                ['func'] = GetVendorCost
            })
table.insert(TSP.valueFunctions, { 
                ['name'] = TRANSMOG_SOURCE_3,
                ['func'] = GetVendorValue
            })

local scanner = CreateFrame('frame')
scanner:RegisterEvent('MERCHANT_SHOW')
scanner:SetScript('OnEvent', ScanMerchantForReagents)
