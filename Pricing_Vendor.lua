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


local function GetVendorCost(itemLink, count)
    local itemID = GetItemInfoFromHyperlink(itemLink)
    TradeSkillPrice.db.merchantItems = TradeSkillPrice.db.merchantItems or {}
    if TradeSkillPrice.db.merchantItems[itemID] then
        return TradeSkillPrice.db.merchantItems[itemID] * count, "v"
    end
end

local function GetVendorValue(itemLink, count)
    local itemID = GetItemInfoFromHyperlink(itemLink)
    local sellPrice = select(11, GetItemInfo(itemID))
    if sellPrice then
        return sellPrice * count, "v"
    end
end

local function ScanMerchantForReagents()
    TradeSkillPrice.db.merchantItems = TradeSkillPrice.db.merchantItems or {}

    local _, price, numAvailable, isPurchasable, currencyID

    for i = 1, GetMerchantNumItems() do
        local id = GetMerchantItemID(i)
        _, _, price, _, numAvailable, isPurchasable, _, _, currencyID = GetMerchantItemInfo(i)

        if price > 0 and numAvailable < 0 and isPurchasable and not currencyID then
            local classID = select(12, GetItemInfo(id))
            if classID == 7 or TradeSkillPrice.db.knownReagents[id] then
                TradeSkillPrice.db.merchantItems[id] = price
            end
        end
    end
end

table.insert(TradeSkillPrice.priceModules,
    {
        ['name'] = TRANSMOG_SOURCE_3,
        ['GetBuyPrice'] = GetVendorPrice,
        ['GetsellPrice'] = GetVendorValue,
        ['GetUpdateTime'] = function () return 1 end,
    }
 )

local scanner = CreateFrame('frame')
scanner:RegisterEvent('MERCHANT_SHOW')
scanner:SetScript('OnEvent', ScanMerchantForReagents)
