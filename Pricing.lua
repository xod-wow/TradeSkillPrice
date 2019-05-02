local recipeInfoCache = { }
local itemRecipesCache = { }
local itemCostCache =  { }

TSP._recipeInfoCache = recipeInfoCache
TSP._itemRecipesCache = itemRecipesCache
TSP._itemCostCache = itemCostCache

local function UpdateRecipeInfoCacheObject(object)
    if object.type == 'header' or object.type == 'subheader' then
        return
    end

    if recipeInfoCache[object.recipeID] then
        recipeInfoCache[object.recipeID].craftable = object.craftable
        recipeInfoCache[object.recipeID].disabled = object.disabled
        recipeInfoCache[object.recipeID].learned = object.learned
        return
    end

    local itemLink = C_TradeSkillUI.GetRecipeItemLink(object.recipeID)
    local itemID = GetItemInfoFromHyperlink(itemLink)

    object.itemLink = itemLink
    object.itemID = itemID

    local min, max
    if not itemID then
        itemID = TSP.scrollData[object.recipeID]
        object.numCreated = 1
    else
        local min, max = C_TradeSkillUI.GetRecipeNumItemsProduced(object.recipeID)
        object.numCreated = (min+max)/2
    end

    object.reagents = object.reagents or { }

    for i=1, C_TradeSkillUI.GetRecipeNumReagents(object.recipeID) do
        local _, _, count = C_TradeSkillUI.GetRecipeReagentInfo(object.recipeID, i)
        local reagentItemLink = C_TradeSkillUI.GetRecipeReagentItemLink(object.recipeID, i)
        local reagentItemID = GetItemInfoFromHyperlink(reagentItemLink)

        if reagentItemID then
            object.reagents[reagentItemID] = count
        end
    end

    recipeInfoCache[object.recipeID] = object

    if itemID then
        itemRecipesCache[itemID] = itemRecipesCache[itemID] or { }
        table.insert(itemRecipesCache[itemID], object.recipeID)
    end
end

function TSP:ClearItemCostCache()
    table.wipe(itemCostCache)
end

function TSP:UpdateRecipeInfoCache()
    if C_TradeSkillUI.IsTradeSkillLinked() then
        return
    end

    for i, recipeID in ipairs(C_TradeSkillUI.GetAllRecipeIDs()) do
        local object = C_TradeSkillUI.GetRecipeInfo(recipeID)
        UpdateRecipeInfoCacheObject(object)
    end
end

function TSP:GetItemValue(itemID)
    local sellPrice, _, _, bindType = select(11, GetItemInfo(itemID))

    if bindType == 1 then
        return sellPrice
    else
        local auctionPrice = Atr_GetAuctionBuyout(itemID)
        return max(auctionPrice or 0, sellPrice or 0)
    end
end

local GetItemCostRecursive, GetItemCostRecursive

GetRecipeCostRecursive = function (recipeID, seen)
    local object = recipeInfoCache[recipeID]

    if not object.learned then
        return nil
    end

    local cost
    for itemID, count in pairs(object.reagents) do
        local c = GetItemCostRecursive(itemID, seen)
        if c ~= nil then
            cost = (cost or 0) + c * count
        end
    end
    if cost ~= nil then
        return cost / object.numCreated
    else
        return nil
    end
end

GetItemCostRecursive = function (itemID, seen)
    if TSP.db.fixedPrice and TSP.db.fixedPrice[itemID] then
        return TSP.db.fixedPrice[itemID]
    end

    -- Unbound Tradeskill - Other items are assumed to be buyable
    local sellPrice, classID, subID, bindType = select(11, GetItemInfo(itemID))
    if bindType == 0 and classID == 7 and subID == 11 and sellPrice > 0 then
        return sellPrice * 4
    end

    -- BoP items are valueless
    if bindType == 1 then
        return nil
    end

    -- Can't depend on ourself, definitely not a winning strategy
    if seen[itemID] ~= nil then
        return nil
    end

    if itemCostCache[itemID] ~= nil then
        return itemCostCache[itemID]
    end

    local minCost = Atr_GetAuctionBuyout(itemID)

    seen[itemID] = true
    for _,recipeID in ipairs(itemRecipesCache[itemID] or {}) do
        local c = GetRecipeCostRecursive(recipeID, seen)
        if c ~= nil and (minCost == nil or c < minCost) then
            minCost = c
        end
    end

    itemCostCache[itemID] = minCost
    return minCost
end

function TSP:GetItemCost(itemID)
    return GetItemCostRecursive(itemID, {})
end

function TSP:GetRecipeCost(recipeID)
    return GetRecipeCostRecursive(recipeID, {})
end

function TSP:GetRecipeItem(recipeID)
    local itemLink = C_TradeSkillUI.GetRecipeItemLink(recipeID)
    local itemID = GetItemInfoFromHyperlink(itemLink)
                    or TSP.scrollData[recipeID]
    return itemID
end

function TSP:GetRecipeValue(recipeID)
    local item = self:GetRecipeItem(recipeID)
    if item then
        return self:GetItemValue(item)
    end
end
