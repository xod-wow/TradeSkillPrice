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

local AHScanner = CreateFrame('Frame', 'TradeSkillPriceAHScanner')

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

local function GetKey(itemID, itemLevel)
    return string.format('%d:%d', itemID, itemLevel)
end

local function GetKeyFromBrowseResult(result)
    return GetKey(result.itemKey.itemID, result.itemKey.itemLevel)
end

local function GetKeyFromItemLink(itemLink)
    local itemID = GetItemInfoFromHyperlink(itemLink)
    local itemLevel = GetDetailedItemLevelInfo(itemLink)
    return GetKey(itemID, itemLevel)
end

local function UpdateItemPrice(key, price, count, when)
    local data = AHScanner.data
    if not data[key] then
        data[key] = {
                price = price,
                count = count,
                when = when
            }
    elseif data[key].when < when or price < data[key].price then
        data[key].price = price
        data[key].count = count
        data[key].when = when
    end
end

local function ProcessReplicateItemList(self)
    local now = time()
    local n = C_AuctionHouse.GetNumReplicateItems()

    local name, texture, count, qualityID, usable, level, levelType, minBid,
          minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName,
          owner, ownerFullName, saleStatus, itemID, hasAllInfo, link

    TradeSkillPrice:ChatMessage(format('Processing %d auction scan listings.', n))
    -- The indexes are c-style 0 to n-1
    for i = 0, n-1 do
        name, texture, count, qualityID, usable, level, levelType,
        minBid, minIncrement, buyoutPrice, bidAmount, highBidder,
        bidderFullName, owner, ownerFullName, saleStatus, itemID,
        hasAllInfo = C_AuctionHouse.GetReplicateItemInfo(i)
        local link = C_AuctionHouse.GetReplicateItemLink(i)

        if buyoutPrice > 0 then
            local key = GetKeyFromItemLink(itemLink)
            UpdateItemPrice(key, buyoutPrice/count, count, now)
        end
    end

    TradeSkillPrice:ChatMessage(format('Processed %d auction scan listings.', n))
end

local function ProcessBrowseResults(self, browseResults)
    TradeSkillPrice:ChatMessage(format('Processing %d auction browse results.', #browseResults))
    local now = time()
    for i, result in ipairs(browseResults) do
        local key = GetKeyFromBrowseResult(result)
        UpdateItemPrice(key, result.minPrice, result.totalQuantity, now)
    end
end

local function GetMinPrice(itemLink, count)
    local key = GetKeyFromItemLink(itemLink)
    if AHScanner.data and AHScanner.data[key] then
        return AHScanner.data[key].price * count, "a"
    end
end

local function TooltipAddPrice(ttFrame, link, count)
    if not link then return end
    count = count or 1
    local key = GetKeyFromItemLink(link)
    if key and AHScanner.data[key] then
        local copper = AHScanner.data[key].price
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

    -- This is not a good test. Assume if we only have vendor we shoud load
    if #TradeSkillPrice.valueFunctions > 1 then
        TradeSkillPrice.db.auctionData = nil
        return
    end

    local r = GetRealmName()
    TradeSkillPrice.db.auctionData = TradeSkillPrice.db.auctionData or {}
    TradeSkillPrice.db.auctionData[r] = TradeSkillPrice.db.auctionData[r] or {}

    self.data = TradeSkillPrice.db.auctionData[r]

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
            if not ttFrame:GetItem() then return end
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

AHScanner:RegisterEvent('ADDON_LOADED')
AHScanner:SetScript('OnEvent', OnEvent)
