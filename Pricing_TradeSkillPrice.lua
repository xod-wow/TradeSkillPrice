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

local abortScan

local function StartScan(now, size)

    local name, texture, count, quality, canUse, level, levelColHeader, minBid,
        minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner,
        ownerFullName, saleStatus, itemID, hasAllInfo

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

        if buyoutPrice and buyoutPrice > 0 then
            TSP.auctionData[itemID] = TSP.auctionData[itemID] or  {}
            table.insert(TSP.auctionData[itemID], { buyoutPrice/count, now })
        end
        if i % 1000 == 0 then
            print(i)
        end
        if i % 25 == 0 then
            coroutine.yield()
        end
    end
end

local function OnUpdate(self, elapsed)
    self.totalElapsed = (self.totalElapsed or 0) + elapsed
    if self.totalElapsed < 0.1 then
        return
    else
        self.totalElapsed = 0
    end

    if not self.thread or coroutine.status(self.thread) == 'dead' then
        self:SetScript('OnUpdate', nil)
        self.thread = nil
        self.totalElapsed = nil
    else
        local t, e = coroutine.resume(self.thread)
        if t == false then
            print(e)
        end
    end
end

local function AuctionItemListUpdate(self)
    local batchSize, totalItems = GetNumAuctionItems('list')

    if batchSize ~= totalItems then
        -- we only support getall scans
        return
    end

    -- You can't get another set of getall data within 15 minutes so
    -- all the rest of the events are refinements of the getall
    if self.thread then
        return
    end

    TSP.auctionData = TSP.auctionData or {}

    local now = time()

    self.thread = coroutine.create(function () StartScan(now, batchSize) end)
    self:SetScript('OnUpdate', OnUpdate)
end

-- it doesn't really matter that much if this is a bit slow to query as long
-- as it's not too slow. Because the getall scan returns so much data we really
-- need to optimize for dealing with that.

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

function TSP:ScanAH()
    local canQuery, canQueryAll = CanSendAuctionQuery()
    if canQueryAll then
        QueryAuctionItems('', nil, nil, 0, nil, nil, true, false, nil)
    end
end

local scanner = CreateFrame('Frame')
scanner:RegisterEvent('AUCTION_HOUSE_SHOW')
scanner:RegisterEvent('AUCTION_HOUSE_CLOSED')
scanner:SetScript('OnEvent', OnEvent)
