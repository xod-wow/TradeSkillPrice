local function Cost(itemID)
    if TSP.db.fixedPrice and TSP.db.fixedPrice[itemID] then
        return TSP.db.fixedPrice[itemID], "f"
    end
end

table.insert(TSP.costFunctions, Cost)
