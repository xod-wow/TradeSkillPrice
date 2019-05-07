local function AuctionPrice(itemID)
    local info = {}
    TUJMarketInfo(itemID, info)
    return info['recent']
end

if TUJMarketInfo then
    table.insert(TSP.valueFunctions, AuctionPrice)
    table.insert(TSP.costFunctions, AuctionPrice)
end
