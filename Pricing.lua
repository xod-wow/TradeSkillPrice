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

local recipeDetails = { }
local itemRecipesMap = { }
local recipeMinCostCache = { }

-- TradeSkillPrice._recipeDetails = recipeDetails
-- TradeSkillPrice._itemRecipesMap = itemRecipesMap

--[[
recipeDetails objects:

{
  categoryID          Number  ID of the category the recipe belongs to.
  craftable           Boolean Indicates if the recipe can be crafted.
  difficulty          String  "trivial", "easy", "optimal", or "medium"
  disabled            Boolean Indicates if the recipe is disabled.
  favorite            Boolean Indicates if the recipe is marked as a favorite.
  hiddenUnlessLearned Boolean Indicates if the recipe should be hidden if it has yet to be learned.
  icon                Number  ID of the recipe's icon.
  learned             Boolean Indicates if the character has learned the recipe.
  name                String  Name of the recipe.
  nextRecipeID        Number  ID of next recipe in the list.
  numAvailable        Number  The number that can be created with the available reagents.
  numIndents          Number  Number of indents when displaying under categories.
  numSkillUps         Number  The number of skillups from creating the recipe.
  previousRecipeID    Number  ID of the previous recipe in the list.
  recipeID            Number  ID of the recipe.
  sourceType          Number  Source of the recipe.
  type                String  Type of recipe
  alternateVerb       String  Alternate verb used for the recipe (such as enchants, or engineering tinkers)

  itemID              Number  ItemID of created item, or scroll for enchants
  itemLink            String  ItemLink of created item
  numCreated          Number
  hasCooldown         Boolean
  reagents            [ { itemID, count }, ... ]
}

]]

local function UpdateRecipeDetails(recipeID)
    local object = C_TradeSkillUI.GetRecipeInfo(recipeID)

    if object.type == 'header' or object.type == 'subheader' then
        return
    end

    if recipeDetails[recipeID] then
        recipeDetails[recipeID].craftable = object.craftable
        recipeDetails[recipeID].disabled = object.disabled
        recipeDetails[recipeID].learned = object.learned
        return
    end

    object.itemLink = C_TradeSkillUI.GetRecipeItemLink(recipeID)
    object.itemID = GetItemInfoFromHyperlink(object.itemLink)

    if object.itemID then
        local a, b = C_TradeSkillUI.GetRecipeNumItemsProduced(recipeID)
        object.numCreated = (a+b)/2
    elseif TradeSkillPrice.scrollData[recipeID] then
        object.itemID = TradeSkillPrice.scrollData[recipeID]
        object.numCreated = 1
    else
        -- It doesn't create anything, what now?
        object.numCreated = 1
    end

    local cooldown, isDayCooldown, charges, maxCharges = C_TradeSkillUI.GetRecipeCooldown(recipeID)
    if isDayCooldown or maxCharges > 0 then
        object.hasCooldown = true
    end

    object.reagents = object.reagents or { }

    for i=1, C_TradeSkillUI.GetRecipeNumReagents(recipeID) do
        local _, _, count = C_TradeSkillUI.GetRecipeReagentInfo(recipeID, i)
        local reagentItemLink = C_TradeSkillUI.GetRecipeReagentItemLink(recipeID, i)
        local reagentItemID = GetItemInfoFromHyperlink(reagentItemLink)

        if reagentItemID then
            table.insert(object.reagents, { reagentItemID, count })
            TradeSkillPrice.db.knownReagents[reagentItemID] = true
        end
    end

    if object.itemID then
        itemRecipesMap[object.itemID] = itemRecipesMap[object.itemID] or { }
        itemRecipesMap[object.itemID][recipeID] = true
    end

    recipeDetails[recipeID] = object
end

function TradeSkillPrice:ScanOpenTradeskill()
    if C_TradeSkillUI.IsTradeSkillLinked() then
        return
    end

    for i, recipeID in ipairs(C_TradeSkillUI.GetAllRecipeIDs()) do
        UpdateRecipeDetails(recipeID)
    end
end

function TradeSkillPrice:ResetPricings()    
    table.wipe(recipeMinCostCache)
end

local function GetMinItemBuyCost(itemID, count)
    local minCost, minCostSource

    for _,f in ipairs(TradeSkillPrice.costFunctions) do
        local c, s = f.func(itemID, count)
        if c and (minCost == nil or c < minCost) then
            minCost, minCostSource = c, s
        end
    end

    return minCost, minCostSource
end

local GetItemCostRecursive, GetRecipeCostRecursive

GetRecipeCostRecursive = function (object, seen)

    -- Can't depend on ourself, definitely not a winning strategy
    if seen[object.recipeID] ~= nil then
        return
    end

    -- Don't do non-optimal things when recursing
    if next(seen) then
        -- Abort if we don't know it or it has a cooldown
        if object.hasCooldown or not object.learned then
            return
        end

        -- Abort if we know a better rank
        if object.nextRecipeID and recipeDetails[object.nextRecipeID].learned then
            return
        end
    end

    if recipeMinCostCache[object.recipeID] then
        return unpack(recipeMinCostCache[object.recipeID])
    end

    seen[object.recipeID] = true

    local cost, source
    local ttInfo = { { object.name, object.numCreated } }

    for _, reagentInfo in pairs(object.reagents) do
        local itemID, numRequired = unpack(reagentInfo)
        local c, s, t = GetItemCostRecursive(itemID, numRequired, seen)
        if c ~= nil then
            cost = (cost or 0) + c
            for _,v in ipairs(t) do table.insert(ttInfo, v) end
        elseif select(14, GetItemInfo(itemID)) ~= 1 then
            -- We found an unbound object we don't have a price for
            -- What if GetItemInfo doesn't work yet?
            return
        end
    end
    if cost then
        recipeMinCostCache[object.recipeID] = { cost, "r", ttInfo }
        return cost, "r", ttInfo
    else
        recipeMinCostCache[object.recipeID] = { }
    end
end

GetItemCostRecursive = function (itemID, count, seen)
    local minCost, minCostSource = GetMinItemBuyCost(itemID, count)
    local ttInfo, object

    for recipeID in pairs(itemRecipesMap[itemID] or {}) do
        object = recipeDetails[recipeID]
        local c, s, t = GetRecipeCostRecursive(object, CopyTable(seen))
        if c then
            c = c * count / object.numCreated
            if minCost == nil or c < minCost then
                for _,v in ipairs(t) do
                    v[2] = v[2] * count / object.numCreated
                    if v[3] ~= nil then
                        v[3] = v[3] * count / object.numCreated
                    end
                end
                minCost, minCostSource, ttInfo = c, s, t
            end
        end
    end

    if minCost then
        if not ttInfo then
            local _, itemLink = GetItemInfo(itemID)
            ttInfo = { { itemLink, count, minCost } }
        end
        return minCost, minCostSource, ttInfo
    end
end

function TradeSkillPrice:GetRecipeCost(recipeID)
    local object = recipeDetails[recipeID]
    if object then
        return GetRecipeCostRecursive(object, {})
    end
end

function TradeSkillPrice:GetItemValue(itemID)
    local value, source

    for _,f in ipairs(TradeSkillPrice.valueFunctions) do
        local v, s = f.func(itemID, 1)
        if v and v > (value or 0) then
            value, source = v, s
        end
    end

    return value, source
end

function TradeSkillPrice:GetRecipeValue(recipeID)
    local object = recipeDetails[recipeID]
    if object and object.itemID then
        return self:GetItemValue(object.itemID)
    end
end
