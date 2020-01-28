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

local modName, modTable = ...

TradeSkillPrice = CreateFrame("Frame", "TradeSkillPrice")
TradeSkillPrice.version = GetAddOnMetadata(modName, "Version")
TradeSkillPrice.costFunctions = {}
TradeSkillPrice.valueFunctions = {}

local defaultConfig = {
    vendorOverride = {},
    fixedPrice = {},
    knownReagents = {},
}

function TradeSkillPrice:ChatMessage(...)
    local msg = format(...)
    local f = SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
    f:AddMessage("|cff80d060TradeSkillPrice: "..msg.."|r")
end

function TradeSkillPrice:FormatMoneyForTooltip(money)
    local g = math.floor(money/10000)
    local s = math.fmod(math.floor(money/100),100)
    local c = math.fmod(money,100)

    local GSC_GOLD="ffd100"
    local GSC_SILVER="e6e6e6"
    local GSC_COPPER="c8602c"

    return string.format("|cff%s%d |cff%s%02d |cff%s%02d|r",
                         GSC_GOLD, g,
                         GSC_SILVER, s,
                         GSC_COPPER, c)

end

function TradeSkillPrice:FormatSource(source)
    return "|cffaaaaff" .. source .. "|r"
end

function TradeSkillPrice:FormatMoney(moneyString, highlight)
    if not moneyString then
        return nil, "?"
    end
    local neg

    local money = tonumber(moneyString)


    if money < 0 then
        neg = true
        money = -money
    end

    local GSC_GOLD = "ff807000"
    local GSC_SILVER = "ff808080"
    local GSC_COPPER = "ff643016"

    if highlight then
        GSC_GOLD="ffffd100"
        GSC_SILVER="ffe6e6e6"
        GSC_COPPER="ffc8602c"
    end

    local g, s, c
    local digits = 0

    g = math.floor(money/10000)
    s = math.fmod(math.floor(money/100),100)
    c = math.fmod(money,100)


    digits = math.floor(math.log10(money)+1)

    if neg then
        if digits < 3 then
            gsc = string.format("  |c%s%3d|r",  GSC_COPPER, -c)
        elseif digits < 4 then
            gsc = string.format("|c%s%2d |c%s%02d|r", GSC_SILVER, -s, GSC_COPPER, c)
        elseif digits < 6 then
            gsc = string.format("|c%s%2d |c%s%02d|r", GSC_GOLD, -g, GSC_SILVER, s)
        elseif digits < 8 then
            gsc = string.format("|c%s%5d|r", GSC_GOLD, -g)
        else
            gsc = string.format("|c%s%2.1fk|r", GSC_GOLD, -g/1000)
        end

        return gsc
    else
        if digits < 3 then
            gsc = string.format("   |c%s%2d|r",  GSC_COPPER, c)
        elseif digits < 5 then
            gsc = string.format("|c%s%2d|r |c%s%02d|r", GSC_SILVER, s, GSC_COPPER, c)
        elseif digits < 7 then
            gsc = string.format("|c%s%2d|r |c%s%02d|r", GSC_GOLD, g, GSC_SILVER, s)
        elseif digits < 9 then
            gsc = string.format("|c%s%5d|r", GSC_GOLD, g)
        else
            gsc = string.format("|c%s%2.1fk|r", GSC_GOLD, g/1000)
        end

        return gsc
    end
end

function TradeSkillPrice.ShowCostTooltip(button)
    if button.TooltipInfo then
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        for i, info in ipairs(button.TooltipInfo) do
            local name, count, cost = unpack(info)
            if name and count and i ~= 1 then
                name = format("%s x %d", name, count)
            end
            if cost then
                cost = TradeSkillPrice:FormatMoneyForTooltip(cost)
            end
            GameTooltip:AddDoubleLine(name, cost)
            if i == 1 then
                GameTooltip:AddLine(" ")
            end
        end
        GameTooltip:Show()
    end
end

function TradeSkillPrice.HideTooltip(button)
    if GameTooltip:GetOwner() == button then
        GameTooltip:Hide()
    end
end

function TradeSkillPrice.SetUpHeader(button, textWidth, tradeSkillInfo)
    button.lswCost:Hide()
    button.lswValue:Hide()
end

function TradeSkillPrice.SetUpRecipe(button, textWidth, tradeSkillInfo)

    local width = textWidth
                    - button.lswValue:GetWidth()
                    - button.lswCost:GetWidth()
                    - 4

    if button.SkillUps:IsShown() or button.LockedIcon:IsShown() then
        width = width - TRADE_SKILL_SKILLUP_TEXT_WIDTH
    end

    if button.Count:IsShown() then
        width = width - button.Count:GetWidth()
    end

    if button.StarsFrame:IsShown() then
        button.StarsFrame:ClearAllPoints()
        button.StarsFrame:SetPoint("RIGHT", -84, 0)
        width = width - button.StarsFrame:GetWidth()
    end

    button.SkillUps:ClearAllPoints()
    button.SkillUps:SetPoint("LEFT", 20, 0)

    if button.Text:GetWidth() > width then
        button.Text:SetWidth(width)
    end

    local recipeID = tradeSkillInfo.recipeID

    local costAmount, costSource, costTTInfo = TradeSkillPrice:GetRecipeCost(recipeID)
    local valueAmount, valueSource = TradeSkillPrice:GetRecipeValue(recipeID)
    local highlight = (costAmount or 0) < (valueAmount or 0)

    if valueAmount then
        local valueText = TradeSkillPrice:FormatMoney(valueAmount, highlight)
        local sourceText = TradeSkillPrice:FormatSource(valueSource)
        button.lswValue.Text:SetText(valueText .. sourceText)
    else
        button.lswValue.Text:SetText('--')
    end

    if costAmount then
        local costText = TradeSkillPrice:FormatMoney(costAmount)
        button.lswCost.Text:SetText(costText)
        button.lswCost.TooltipInfo = costTTInfo
    else
        button.lswCost.Text:SetText('--')
        button.lswValue.TooltipLines = nil
    end

    button.lswValue:Show()
    button.lswCost:Show()
end

function TradeSkillPrice:CreateDynamicButtons(button)
    local height = button:GetHeight()

    if not button.lswCost then
        button.lswCost = CreateFrame("Button", nil, button, "TradeSkillPriceButtonTemplate")
        button.lswCost:SetSize(40, height)
        button.lswCost:SetPoint("RIGHT", -4, 0)
        button.lswCost:SetScript("OnEnter", TradeSkillPrice.ShowCostTooltip)
        button.lswCost:SetScript("OnLeave", TradeSkillPrice.HideTooltip)

        button.lswValue = CreateFrame("Button", nil, button, "TradeSkillPriceButtonTemplate")
        button.lswValue:SetSize(40, height)
        button.lswValue:SetPoint("RIGHT", button.lswCost, "LEFT", 0, 0)

        hooksecurefunc(button, "SetUpHeader", TradeSkillPrice.SetUpHeader)
        hooksecurefunc(button, "SetUpRecipe", TradeSkillPrice.SetUpRecipe)
    end
end

function TradeSkillPrice:CreateAllDynamicButtons()
    for i, button in ipairs(TradeSkillFrame.RecipeList.buttons) do
        TradeSkillPrice:CreateDynamicButtons(button)
    end
end

function TradeSkillPrice:RefreshRecipeList()
    if TradeSkillFrame and TradeSkillFrame:IsShown() then
        TradeSkillFrame.RecipeList:Refresh()
    end
end

function TradeSkillPrice:RecalculatePrices()
    self:ResetPricings()
    self:RefreshRecipeList()
end

function TradeSkillPrice:Initialize()
    TradeSkillPriceDB = TradeSkillPriceDB or { }
    self.db = TradeSkillPriceDB
    for k,v in pairs(defaultConfig) do
        self.db[k] = self.db[k] or {}
    end
    self.initialized = true
end

TradeSkillPrice:RegisterEvent("ADDON_LOADED")
TradeSkillPrice:RegisterEvent("TRADE_SKILL_SHOW")
TradeSkillPrice:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
TradeSkillPrice:RegisterEvent("SKILL_LINES_CHANGED")

TradeSkillPrice:SetScript("OnEvent",
    function(self, event, arg1, arg2)
        if event == "TRADE_SKILL_SHOW" then
            self:CreateAllDynamicButtons()
        elseif event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
            self:ScanOpenTradeskill()
            self:RecalculatePrices()
            -- The first time we load the tradeskill the client doesn't have
            -- cached info so GetItemInfo() returns nil. Auctionator (at least)
            -- is keyed off name so it doesn't return sensible values at that
            -- point. This triggers a refresh to try to pick up the data.
            C_Timer.After(2, function () self:RecalculatePrices() end)
        elseif event == "SKILL_LINES_CHANGED" then
            self:ScanOpenTradeskill()
            self:RecalculatePrices()
        elseif event == "ADDON_LOADED" and arg1 == modName then
            self:Initialize()
        end
    end)
