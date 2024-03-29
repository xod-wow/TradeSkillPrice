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

TradeSkillPrice._recipeDetails = recipeDetails
TradeSkillPrice._itemRecipesMap = itemRecipesMap

--[[
recipeDetails objects:

{
  categoryID          Number  ID of the category the recipe belongs to.
  craftable           Boolean
  difficulty          String  "trivial", "easy", "optimal", or "medium"
  disabled            Boolean
  favorite            Boolean
  hiddenUnlessLearned Boolean
  icon                Number  ID of the recipe's icon.
  learned             Boolean
  name                String
  nextRecipeID        Number  ID of next recipe in the list.
  numAvailable        Number
  numIndents          Number  Number of indents when displaying.
  numSkillUps         Number
  previousRecipeID    Number  ID of the previous recipe in the list.
  recipeID            Number  ID of the recipe.
  sourceType          Number  Source of the recipe.
  type                String  Type of recipe
  alternateVerb       String  Alternate verb used for the recipe

  itemID              Number  ItemID of created item, or scroll for enchants
  itemLink            String  ItemLink of created item
  numCreated          Number
  hasCooldown         Boolean
  reagents            { { itemLink, count }, ... }
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

    if not object.itemLink then
        return
    end

    object.itemID = GetItemInfoFromHyperlink(object.itemLink)

    if TradeSkillPrice.scrollData[recipeID] then
        object.itemLink = TradeSkillPrice.scrollData[recipeID]
        -- Bail out if the init hasn't turned it into a link yet
        if type(object.itemLink) ~= 'string' then
            return
        end
        object.itemID = GetItemInfoFromHyperlink(object.itemLink)
        object.numCreated = 1
    elseif object.itemLink then
        local a, b = C_TradeSkillUI.GetRecipeNumItemsProduced(recipeID)
        object.numCreated = (a+b)/2
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

        -- First time around the returned itemLink doesn't have the name in it!
        local reagentItemID = GetItemInfoFromHyperlink(reagentItemLink)
        local item = Item:CreateFromItemID(reagentItemID)
        if not item:IsItemEmpty() then
            item:ContinueOnItemLoad(
                function ()
                    object.reagents[i] = { item:GetItemLink(), count }
                    TradeSkillPrice.db.knownReagents[reagentItemID] = true
                end
            )
        end
    end

    if object.itemLink then
        itemRecipesMap[object.itemLink] = itemRecipesMap[object.itemLink] or { }
        itemRecipesMap[object.itemLink][recipeID] = true
    end

    recipeDetails[recipeID] = object
end

function TradeSkillPrice:ScanOpenTradeskill()
--  if C_TradeSkillUI.IsTradeSkillLinked() then
--      return
--  end

    for i, recipeID in ipairs(C_TradeSkillUI.GetAllRecipeIDs()) do
        if not recipeDetails[recipeID] then
            UpdateRecipeDetails(recipeID)
        end
    end
end

function TradeSkillPrice:ResetPricings()    
end

local pricerTable = {}

function TradeSkillPrice:GetPricers(funcName)
    table.wipe(pricerTable)
    local mostRecent = -1

    for _,m in ipairs(self.priceModules) do
        if m[funcName] then
            local updateTime = m:GetUpdateTime()
            if updateTime == 1 then
                table.insert(pricerTable, m)
            elseif updateTime > mostRecent then
                table.insert(pricerTable, m)
                mostRecent = updateTime
            end
        end
    end
    return pricerTable
end

local function GetMinItemBuyCost(itemLink, count)
    local minCost, minCostSource

    for _,m in ipairs(TradeSkillPrice:GetPricers('GetBuyPrice')) do
        local c, s = m.GetBuyPrice(itemLink, count)
        if c and (minCost == nil or c < minCost) then
            minCost, minCostSource = c, s
        end
    end

    return minCost, minCostSource
end

local function GetMinRecipeCost(object, seen)
    local cost = 0
    for _, info in ipairs(object.reagents) do
        local itemLink, count = unpack(info)
        local c, s = GetMinItemBuyCost(itemLink, count)
        cost = cost + (c or 0)
    end
    return cost
end

local function GetMinRecipeTooltip(object, seen)
    local tooltipLines = { }

    local cost = 0
    for _, info in ipairs(object.reagents) do
        local itemLink, count = unpack(info)
        local c, s = GetMinItemBuyCost(itemLink, count)
        table.insert(tooltipLines, { itemLink, count, c })
        cost = cost + (c or 0)
    end
    return tooltipLines
end

function TradeSkillPrice:GetRecipeCost(recipeID)
    local object = recipeDetails[recipeID]
    if object then
        return GetMinRecipeCost(object, {})
    end
end

function TradeSkillPrice:GetRecipeTooltip(recipeID)
    local object = recipeDetails[recipeID]
    if object then
        return GetMinRecipeTooltip(object, {})
    end
end

function TradeSkillPrice:GetItemValue(itemLink)
    local value, source

    local itemID = GetItemInfoFromHyperlink(itemLink)
    local cData = TradeSkillPrice.alchemyContainerData[itemID]
    if cData then
        for _, info in ipairs(cData) do
            local v, s = self:GetItemValue(info[3])
            if not source then
                source = s
            elseif source ~= s then
                source = m
            end
            value = (value or 0) + v * info[2]
        end
    else
        for _,m in ipairs(TradeSkillPrice:GetPricers('GetSellPrice')) do
            local v, s = m.GetSellPrice(itemLink, 1)
            if v and v > (value or 0) then
                value, source = v, s
            end
        end
    end

    return value, source
end

function TradeSkillPrice:GetRecipeValue(recipeID)
    local object = recipeDetails[recipeID]
    if object and object.itemID then
        local cost, source = self:GetItemValue(object.itemLink)
        if cost then
            return cost * object.numCreated, source
        end
    end
end
