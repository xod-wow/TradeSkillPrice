--[[----------------------------------------------------------------------------

    Copyright 2019 Mike Battersby

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

local abortScan

local AuctionHouseScanner = CreateFrame('Frame')
local lockoutFrame, needReregister

local function CreateLockoutFrame()

    local f = CreateFrame('Frame', nil, AuctionFrame)
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

function LockoutBlizzard()
    if not AuctionFrame then return end

    lockoutFrame = lockoutFrame or CreateLockoutFrame()
    lockoutFrame:Show()

    AuctionFrameBrowse:UnregisterEvent('AUCTION_ITEM_LIST_UPDATE')
    needReregister = true
end

function UnlockBlizzard()
    if not AuctionFrameBrowse then return end

    QueryAuctionItems('xyzzy', nil, nil, 0, nil, nil, false, false, nil)
    if lockoutFrame then
        lockoutFrame:Hide()
    end
    if needReregister then
        AuctionFrameBrowse:RegisterEvent('AUCTION_ITEM_LIST_UPDATE')
        needReregister = nil
    end
end

local function StartScan(now, size)

    local name, texture, count, quality, canUse, level, levelColHeader, minBid,
        minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner,
        ownerFullName, saleStatus, itemID, hasAllInfo

    local data = TSP.db.auctionData

    lockoutFrame.progress:SetText(format('0/%d', size))

    for i = 1, size do
        if abortScan then
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
            = GetAuctionItemInfo('list', i)

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
        end

        if i % 1000 == 0 then
            lockoutFrame.progress:SetText(format('%d/%d', i, size))
            coroutine.yield()
        end
    end
end

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
        UnlockBlizzard()
    else
        TSP:ChatMessage('Scheduling thread')
        local t, e = coroutine.resume(self.thread)
        if t == false then
            TSP:ChatMessage(e)
        end
    end
end

local function AuctionItemListUpdate(self)
    local batchSize, totalItems = GetNumAuctionItems('list')

    if batchSize == 0 or batchSize ~= totalItems then
        TSP:ChatMessage('Empty or non-getall scan found, ignoring')
        -- we only support getall scans
        return
    end

    -- You can't get another set of getall data within 15 minutes so all the
    -- rest of the events are refinements of the getall. Or, something did
    -- another search, in which case we're boned.

    if self.thread then
        return
    end

    TSP.db.auctionData = TSP.db.auctionData or {}

    local now = time()

    TSP:ChatMessage('Creating thread')
    self.thread = coroutine.create(function () StartScan(now, batchSize) end)
    self:SetScript('OnUpdate', OnUpdate)
end

local function OnEvent(self, event, ...)
    if event == 'AUCTION_HOUSE_SHOW' then
        self:RegisterEvent('AUCTION_ITEM_LIST_UPDATE')
    elseif event == 'AUCTION_HOUSE_CLOSED' then
        abortScan = true
        self:UnregisterEvent('AUCTION_ITEM_LIST_UPDATE')
    elseif event == 'AUCTION_ITEM_LIST_UPDATE' then
        AuctionItemListUpdate(self)
    end
end

local function GetMinPrice(itemID)
    if TSP.db.auctionData and TSP.db.auctionData[itemID] then
        return TSP.db.auctionData[itemID].price, "a"
    end
end

function TSP:ScanAH()
    local canQuery, canQueryAll = CanSendAuctionQuery()
    if canQueryAll then
        LockoutBlizzard()
        lockoutFrame.progress:SetText("Waiting for data")
        QueryAuctionItems('', nil, nil, 0, nil, nil, true, false, nil)
    end
end


-- This is not a good test

if #TSP.valueFunctions == 1 then
    AuctionHouseScanner:RegisterEvent('AUCTION_HOUSE_SHOW')
    AuctionHouseScanner:RegisterEvent('AUCTION_HOUSE_CLOSED')
    AuctionHouseScanner:SetScript('OnEvent', OnEvent)

    table.insert(TSP.valueFunctions,
                {
                    ['name'] = 'TradeSkillPrice',
                    ['func'] =  GetMinPrice,
                })
    table.insert(TSP.costFunctions,
                {
                    ['name'] = 'TradeSkillPrice',
                    ['func'] =  GetMinPrice,
                })
else
    -- Don't keep our old possibly stale data around
    AuctionHouseScanner:RegisterEvent('ADDON_LOADED')
    AuctionHouseScanner:SetScript('OnEvent', function (self, event, arg1)
            if arg1 == modName then TSP.db.auctionData = nil end
            self:UnregisterEvent('ADDON_LOADED')
        end)
end
