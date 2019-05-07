local function Value(itemID)
    local price = AucAdvanced.API.GetMarketValue(itemID)
    if price then
        return price, "a"
    end
end

local function Cost(itemID)
    local cost = AucAdvanced.API.GetAlgorithmValue("Appraiser", itemID)
    if cost then
        return cost, "a"
    end
end

if AucAdvanced and AucAdvanced.API then
    table.insert(TSP.valueFunctions, Value)
    table.insert(TSP.costFunctions, Cost)

    local mod = AucAdvanced.NewModule("Util", "TradeSkillPrice")
    mod.Processors = {}
    mod.Processors.scanstats = function () TSP:RecalculatePrices() end
end
