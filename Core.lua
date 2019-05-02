--[[----------------------------------------------------------------------------

TradeSkillPrice

----------------------------------------------------------------------------]]--

local modName, modTable = ...

TSP = CreateFrame("Frame", "TSP")
TSP.version = GetAddOnMetadata(modName, "Version")

local defaultConfig = {
    vendorOverride = {},
    fixedPrice = {},
}

function TSP:ChatMessage(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff80d060"..(msg or "nil"))
end

function TSP:ErrorMessage(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000"..(msg or "nil"))
end

function TSP:DebugMessage(flag, msg)
    if flag then
        DEFAULT_CHAT_FRAME:AddMessage("|cfff0f030"..(msg or "nil"))
    end
end

function TSP:FormatMoneyFixed(money)
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

function TSP:FormatMoney(moneyString, hilight)
    if not moneyString then
        return nil, "?"
    end
    local neg

    local money = tonumber(moneyString)


    if (money < 0) then
        neg = true
        money = -money
    end

    local GSC_GOLD = "ff807000"
    local GSC_SILVER = "ff808080"
    local GSC_COPPER = "ff643016"

    if (hilight) then
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

function TSP.ShowCostTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:Show()
end

function TSP.HideTooltip(button)
    if GameTooltip:GetOwner() == button then
        GameTooltip:Hide()
    end
end

function TSP.SetUpHeader(button, textWidth, tradeSkillInfo)
    button.lswCost:Hide()
    button.lswValue:Hide()
end

function TSP.SetUpRecipe(button, textWidth, tradeSkillInfo)

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

    if button.Text:GetWidth() > width then
        button.Text:SetWidth(width)
    end

    local recipeID = tradeSkillInfo.recipeID

    local costAmount = TSP:GetRecipeCost(recipeID)
    local valueAmount = TSP:GetRecipeValue(recipeID) or 0
    local hilight = (costAmount or 0) < (valueAmount or 0)

    local valueText = TSP:FormatMoney(valueAmount, hilight) or "--"
    button.lswValue.Text:SetText(valueText)
    button.lswValue:Show()

    local costText = TSP:FormatMoney(costAmount, false) or "--"
    button.lswCost.Text:SetText(costText)
    button.lswCost:Show()
end

function TSP:CreateDynamicButtons(button)
    local height = button:GetHeight()

    if not button.lswCost then
        button.lswCost = CreateFrame("Button", nil, button, "TSPButtonTemplate")
        button.lswCost:SetSize(40, height)
        button.lswCost:SetPoint("RIGHT", -4, 0)
        -- button.lswCost:SetScript("OnEnter", TSP.ShowCostTooltip)
        -- button.lswCost:SetScript("OnLeave", TSP.HideTooltip)

        button.lswValue = CreateFrame("Button", nil, button, "TSPButtonTemplate")
        button.lswValue:SetSize(40, height)
        button.lswValue:SetPoint("RIGHT", button.lswCost, "LEFT", 0, 0)

        hooksecurefunc(button, "SetUpHeader", TSP.SetUpHeader)
        hooksecurefunc(button, "SetUpRecipe", TSP.SetUpRecipe)
    end
end

function TSP:CreateAllDynamicButtons()
    for i, button in ipairs(TradeSkillFrame.RecipeList.buttons) do
        TSP:CreateDynamicButtons(button)
    end
end

function TSP.RefreshRecipeList()
    if TradeSkillFrame:IsShown() then
        TradeSkillFrame.RecipeList:Refresh()
    end
end

function TSP:Initialize()
    if not self.initialized then
        self:ChatMessage(modName .. " " ..self.version)
        self:CreateAllDynamicButtons()
        TradeSkillPriceDB = TradeSkillPriceDB or { }
        self.db = TradeSkillPriceDB

        Atr_RegisterFor_DBupdated(function ()
                self:ClearItemCostCache()
                self:RefreshRecipeList()
            end)
        self.initialized = true
    end
end

TSP:RegisterEvent("TRADE_SKILL_SHOW")
TSP:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")

TSP:SetScript("OnEvent",
    function(self, event, arg1, arg2)
        if event == "TRADE_SKILL_SHOW" then
            self:Initialize()
            self:ClearItemCostCache()
        elseif event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
            self:ClearItemCostCache()
            self:UpdateRecipeInfoCache()
        end
    end)
