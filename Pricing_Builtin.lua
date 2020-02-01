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

local AH_SHOWHIDE_EVENTS = {
    'AUCTION_HOUSE_SHOW',
    'AUCTION_HOUSE_CLOSED'
}

local AH_ITEM_EVENTS = {
    'AUCTION_HOUSE_BROWSE_RESULTS_ADDED',
    'AUCTION_HOUSE_BROWSE_RESULTS_UPDATED',
    'REPLICATE_ITEM_LIST_UPDATE'
}

-- local abortScan, lastGetAllTime = nil, 0

local AuctionHouseScanner = CreateFrame('Frame', 'TradeSkillPriceAHScanner')

local function CreateScanButton()
    if AuctionHouseFrame and not TradeSkillPriceAHScanButton then
        local b = CreateFrame('Button', 'TradeSkillPriceAHScanButton', AuctionHouseFrame.SearchBar, 'UIPanelButtonNoTooltipResizeToFitTemplate')
        b:SetPoint('RIGHT', AuctionHouseFrame.CategoriesList.ScrollFrame, 'RIGHT')
        b:SetPoint('CENTER', AuctionHouseFrame.SearchBar.FavoritesSearchButton, 'CENTER')
        b:SetText('TSP Scan')
        b:Show()
        b:SetScript('OnClick', function () C_AuctionHouse.ReplicateItems() end)
    end
end

--[[
local function CreateLockoutFrame()

    local f = CreateFrame('Frame', nil, AuctionHouseFrame)
    f:EnableMouse(true)
    f:SetFrameStrata('HIGH')
    f:SetAllPoints()

    f.texture = f:CreateTexture(nil, 'ARTWORK')
    f.texture:SetAllPoints()
    f.texture:SetColorTexture(0, 0.5, 0, 0.5)

    f.message = f:CreateFontString(nil, 'OVERLAY')
    f.message:SetPoint('CENTER', f, 'CENTER', 0, 48)
    f.message:SetFontObject(GameFontHighlightHuge)
    f.message:SetText('Auction House scan in progress, please wait.')

    f.progress = f:CreateFontString(nil, 'OVERLAY')
    f.progress:SetPoint('CENTER', f, 'CENTER', 0, 0)
    f.progress:SetFontObject(GameFontNormalHuge)

    f.cancel = CreateFrame('Button', nil, f, 'MagicButtonTemplate')
    f.cancel:SetPoint('CENTER', f, 'CENTER', 0, -48)
    f.cancel:SetText(CANCEL)
    f.cancel:SetScript('OnClick', function () abortScan = true end)

    return f
end
]]

local function UpdateItemPrice(itemID, price, count, when)
    local data = TradeSkillPrice.db.auctionData
    if not data[itemID] then
        data[itemID] = {
                price = price,
                count = count,
                when = when
            }
    elseif data[itemID].when < when or price < data[itemID].price then
        data[itemID].price = price
        data[itemID].count = count
        data[itemID].when = when
    end
end

--[[
local function StartScan(size)

    local now = time()

    local name, texture, count, quality, canUse, level, levelColHeader, minBid,
        minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner,
        ownerFullName, saleStatus, itemID, hasAllInfo

    local data = TradeSkillPrice.db.auctionData

    local nConsecutiveFailures = 0

    for i = 1, size do
        if abortScan then
            TradeSkillPrice:ChatMessage("Scan aborted")
            abortScan = nil
            return
        end

        name,           -- [1]
        texture,        -- [2]
        count,          -- [3]
        quality,        -- [4]
        canUse,         -- [5]
        level,          -- [6]
        levelColHeader, -- [7]
        minBid,         -- [8]
        minIncrement,   -- [9]
        buyoutPrice,    -- [10]
        bidAmount,      -- [11]
        highBidder,     -- [12]
        bidderFullName, -- [13]
        owner,          -- [14]
        ownerFullName,  -- [15]
        saleStatus,     -- [16]
        itemID,         -- [17]
        hasAllInfo      -- [18]
            = C_AuctionHouse.GetReplicateItemInfo(i-1)

        -- Saving the dumbest of dumb data, just the lowest price
        -- we've seen the most recently.

        if buyoutPrice and buyoutPrice > 0 then
            local costPer = buyoutPrice / count
            if not data[itemID]
               or data[itemID].when ~= now
               or costPer < data[itemID].price then
                data[itemID] = { price=costPer, when=now }
            else
                data[itemID].when = now
            end
            nConsecutiveFailures = 0
        else
            nConsecutiveFailures = nConsecutiveFailures + 1
            if nConsecutiveFailures > 100 then
                abortScan = true
            end
        end

        -- This modulus should be at least NUM_AUCTION_ITEMS_PER_PAGE (50)

        if i % 1000 == 0 then
            coroutine.yield()
        end
    end
    TradeSkillPrice:ChatMessage('Scan completed, %d items scanned.', size)
end
]]

--[[
local function OnUpdate(self, elapsed)
    self.totalElapsed = (self.totalElapsed or 0) + elapsed
    if self.totalElapsed < 0.01 then
        return
    else
        self.totalElapsed = 0
    end

    if not self.thread or coroutine.status(self.thread) == 'dead' then
        self:SetScript('OnUpdate', nil)
        self.thread = nil
        self.totalElapsed = nil
        QueryAuctionItems('x_y_z_z_y')
        C_Timer.After(0.5, UnlockBlizzard)
    else
        local t, e = coroutine.resume(self.thread)
        if t == false then
            TradeSkillPrice:ChatMessage(e)
        end
    end
end
]]

local function ProcessReplicateItemList(self)
    local now = time()
    local n = C_AuctionHouse.GetNumReplicateItems()

    local name, texture, count, qualityID, usable, level, levelType, minBid,
          minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName,
          owner, ownerFullName, saleStatus, itemID, hasAllInfo

    TradeSkillPrice:ChatMessage(format('Processing %d auction scan listings.', n))
    -- The indexes are c-style 0 to n-1
    for i = 0, n-1 do
        name, texture, count, qualityID, usable, level, levelType,
        minBid, minIncrement, buyoutPrice, bidAmount, highBidder,
        bidderFullName, owner, ownerFullName, saleStatus, itemID,
        hasAllInfo = C_AuctionHouse.GetReplicateItemInfo(i)

        if buyoutPrice > 0 then
            UpdateItemPrice(itemID, buyoutPrice/count, count, now)
        end
    end

    TradeSkillPrice:ChatMessage(format('Processed %d auction scan listings.', n))
end

local function ProcessBrowseResults(self, browseResults)
    TradeSkillPrice:ChatMessage(format('Processing %d auction browse results.', #browseResults))
    local now = time()
    for i, result in ipairs(browseResults) do
        UpdateItemPrice(result.itemKey.itemID, result.minPrice, result.count, now)
    end
end

local function GetMinPrice(itemID, count)
    if TradeSkillPrice.db.auctionData and TradeSkillPrice.db.auctionData[itemID] then
        return TradeSkillPrice.db.auctionData[itemID].price * count, "a"
    end
end

local function TooltipAddPrice(ttFrame, link, count)
    if not link then return end
    count = count or 1
    local id = GetItemInfoFromHyperlink(link)
    if id and TradeSkillPrice.db.auctionData[id] then
        local copper = TradeSkillPrice.db.auctionData[id].price
        local price = GetMoneyString(copper, true)
        local text = format('|cff80d060Auction :|r |cffffffff%s', price)
        ttFrame:AddLine(text)
        if count > 1 then
            price = GetMoneyString(copper * count, true)
            if math.floor(count) == count then
                text = format('|cff80d060Auction x %d :|r |cffffffff%s|r', math.floor(count), price)
            else
                text = format('|cff80d060Auction x %0.1f :|r |cffffffff%s|r', count, price)
            end
            ttFrame:AddLine(text)
        end
        ttFrame:Show()
    end
end

local function Init(self)

    -- This is not a good test
    if #TradeSkillPrice.valueFunctions == 1 then
        TradeSkillPrice.db.auctionData = TradeSkillPrice.db.auctionData or {}

        FrameUtil.RegisterFrameForEvents(self, AH_SHOWHIDE_EVENTS)

        table.insert(TradeSkillPrice.valueFunctions,
                    {
                        ['name'] = 'TradeSkillPrice',
                        ['func'] =  GetMinPrice,
                    })
        table.insert(TradeSkillPrice.costFunctions,
                    {
                        ['name'] = 'TradeSkillPrice',
                        ['func'] =  GetMinPrice,
                    })

    hooksecurefunc(GameTooltip, 'SetBagItem',
        function (ttFrame, bag, slot)
            local link = GetContainerItemLink(bag, slot)
            local _, count = GetContainerItemInfo(bag, slot)
            TooltipAddPrice(ttFrame, link, count)
        end)
    hooksecurefunc(GameTooltip, 'SetLootItem',
        function (ttFrame, slot)
            local link, _, count = GetLootSlotLink(slot)
            TooltipAddPrice(ttFrame, link, count)
        end)
    hooksecurefunc(GameTooltip, 'SetInventoryItem',
        function (ttFrame, unit, slot)
            local link = GetInventoryItemLink(unit, slot)
            local count = GetInventoryItemCount(unit, slot)
            TooltipAddPrice(ttFrame, link, count)
        end)
    hooksecurefunc(GameTooltip, 'SetGuildBankItem',
        function (ttFrame, tab, slot)
            local link = GetGuildBankItemLink(tab, slot)
            local _, count = GetGuildBankItemInfo(tab, slot)
            TooltipAddPrice(ttFrame, link, count)
        end)
    hooksecurefunc(GameTooltip, 'SetRecipeResultItem',
        function (ttFrame, id)
            local link = C_TradeSkillUI.GetRecipeItemLink(id)
            local a, b = C_TradeSkillUI.GetRecipeNumItemsProduced(id)
            TooltipAddPrice(ttFrame, link, (a+b)/2)
        end)
    hooksecurefunc(GameTooltip, 'SetRecipeReagentItem',
        function (ttFrame, id, index)
            local link = C_TradeSkillUI.GetRecipeReagentItemLink(id, index)
            local _, _, count = C_TradeSkillUI.GetRecipeReagentInfo(id, index)
            TooltipAddPrice(ttFrame, link, count)
        end)
    else
        TradeSkillPrice.db.auctionData = nil
    end

end

local function OnEvent(self, event, arg1, ...)
    if event == 'AUCTION_HOUSE_SHOW' then
        FrameUtil.RegisterFrameForEvents(self, AH_ITEM_EVENTS)
        CreateScanButton()
    elseif event == 'AUCTION_HOUSE_CLOSED' then
        abortScan = true
        FrameUtil.UnregisterFrameForEvents(self, AH_ITEM_EVENTS)
    elseif event == 'AUCTION_HOUSE_BROWSE_RESULTS_ADDED' then
        ProcessBrowseResults(self, arg1)
    elseif event == 'AUCTION_HOUSE_BROWSE_RESULTS_UPDATED' then
        local browseResults = C_AuctionHouse.GetBrowseResults()
        ProcessBrowseResults(self, browseResults)
    elseif event == 'REPLICATE_ITEM_LIST_UPDATE' then
        if time() > (self.lastReplicate or 0) + 60 then
            ProcessReplicateItemList(self, browseResults)
            self.lastReplicate = time()
        end
    elseif event == 'ADDON_LOADED' then
        if arg1 == modName then
            Init(self)
            self:UnregisterEvent('ADDON_LOADED')
        end
    end
end

AuctionHouseScanner:RegisterEvent('ADDON_LOADED')
AuctionHouseScanner:SetScript('OnEvent', OnEvent)
