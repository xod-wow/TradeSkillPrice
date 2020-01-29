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
  alternateVerb       String  Alternate verb used for the recipe

  itemID              Number  ItemID of created item, or scroll for enchants
  itemLink            String  ItemLink of created item
  numCreated          Number
  hasCooldown         Boolean
  reagents            { itemID: count, ... }
}

]]

local function UpdateRecipeDetails(recipeID)
    local object = C_TradeSkillUI.GetRecipeInfo(recipeID)

    if object.type == 'header' or object.type == 'subheader' then
        return
    end

    -- Don't save recipes that we know a better rank of
    if object.nextRecipeID then
        local nr = C_TradeSkillUI.GetRecipeInfo(object.nextRecipeID)
        if nr and nr.learned then return end
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
            object.reagents[reagentItemID] = count
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
        if not recipeDetails[recipeID] then
            UpdateRecipeDetails(recipeID)
        end
    end
end

function TradeSkillPrice:ResetPricings()    
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

local function GetMinRecipeCost(object, seen)
    local cost = 0
    for itemID, count in pairs(object.reagents) do
        local c, s = GetMinItemBuyCost(itemID, count)
        cost = cost + (c or 0)
    end
    return cost
end

local function GetMinRecipeTooltip(object, seen)
    local tooltipLines = { }

    local cost = 0
    for itemID, count in pairs(object.reagents) do
        local c, s = GetMinItemBuyCost(itemID, count)
        local _, itemLink = GetItemInfo(itemID)
        table.insert(tooltipLines, { itemLink, count, c })
        cost = cost + (c or 0)
    end
    return tooltipLines
end

function TradeSkillPrice:GetRecipeCost(recipeID)
    local object = recipeDetails[recipeID]
    return GetMinRecipeCost(object, {})
end

function TradeSkillPrice:GetRecipeTooltip(recipeID)
    local object = recipeDetails[recipeID]
    return GetMinRecipeTooltip(object, {})
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
