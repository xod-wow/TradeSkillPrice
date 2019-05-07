local function AuctionValue(itemID)
    local auctionPrice = Atr_GetAuctionPrice(itemID)
    if auctionPrice then
        return auctionPrice, "a"
    end
end

local function DisenchantValue(itemID)
    local dePrice = Atr_GetDisenchantValue(itemID)
    if dePrice then
        return dePrice, "d"
    end
end

local function Cost(itemID)
    return Atr_GetAuctionPrice(itemID), "a"
end

if Atr_GetAuctionPrice then
    table.insert(TSP.valueFunctions, AuctionValue)
    table.insert(TSP.valueFunctions, DisenchantValue)
    table.insert(TSP.costFunctions, Cost)

    Atr_RegisterFor_DBupdated(function () TSP:RecalculatePrices() end)
end
