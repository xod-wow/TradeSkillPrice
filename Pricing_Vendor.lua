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
