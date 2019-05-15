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

local abortScan, lastGetAllTime = nil, 0

local AuctionHouseScanner = CreateFrame('Frame')
local lockoutFrame, needReregister

local function CreateScanButton(parent)
    if not TSPAHScanButton then
        local b = CreateFrame('Button', 'TSPAHScanButton', parent, 'UIPanelButtonTemplate')
        b:SetSize(80, 22)
        b:SetPoint('RIGHT', BrowseSearchButton, 'LEFT', -5, 0)
        b:SetText('Full Scan')
        b:Show()
        -- b:SetScript('OnClick', function () TSP:ScanAH() end)
    end
end

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

local function LockoutBlizzard()
    if not AuctionFrame then return end

    lockoutFrame = lockoutFrame or CreateLockoutFrame()
    lockoutFrame.progress:SetText("Waiting for data from server")
    lockoutFrame:Show()

    AuctionFrameBrowse:UnregisterEvent('AUCTION_ITEM_LIST_UPDATE')
    needReregister = true
end

local function UnlockBlizzard()
    if not AuctionFrameBrowse then return end

    if lockoutFrame then
        lockoutFrame:Hide()
    end
    if needReregister then
        AuctionFrameBrowse:RegisterEvent('AUCTION_ITEM_LIST_UPDATE')
        needReregister = nil
    end
end

local function StartScan(size)

    local now = time()

    local name, texture, count, quality, canUse, level, levelColHeader, minBid,
        minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner,
        ownerFullName, saleStatus, itemID, hasAllInfo

    local data = TSP.db.auctionData

    if lockoutFrame and lockoutFrame:IsShown() then
        lockoutFrame.progress:SetText(format("0/%d", size))
    end

    local nConsecutiveFailures = 0

    for i = 1, size do
        if abortScan then
            TSP:ChatMessage("Scan aborted")
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
            nConsecutiveFailures = 0
        else
            nConsecutiveFailures = nConsecutiveFailures + 1
            if nConsecutiveFailures > 100 then
                abortScan = true
            end
        end

        -- This modulus should be at least NUM_AUCTION_ITEMS_PER_PAGE (50)

        if i % 1000 == 0 then
            if lockoutFrame and lockoutFrame:IsShown() then
                lockoutFrame.progress:SetText(format("%d/%d", i, size))
            end
            coroutine.yield()
        end
    end
    TSP:ChatMessage('Scan completed, %d items scanned.', size)
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
        QueryAuctionItems('x_y_z_z_y')
        C_Timer.After(0.5, UnlockBlizzard)
    else
        local t, e = coroutine.resume(self.thread)
        if t == false then
            TSP:ChatMessage(e)
        end
    end
end

local function AuctionItemListUpdate(self)
    local batchSize, totalItems = GetNumAuctionItems('list')

    -- A dummy 0 result search is used to trigger the end of the scan
    -- and re-enabling the Blizzard frame. A getall scan means we should
    -- throw away all the other data

    if batchSize ~= totalItems then
        TSP:ChatMessage('Non-getall scan found')
        UnlockBlizzard()
        -- return
    elseif time() < lastGetAllTime + 890 then
        -- the getall seems to trigger returning the data twice, so we
        -- guard against seeing it again too soon, as it can only happen
        -- every 900 seconds.
        TSP:ChatMessage('Duplicate? %d %d', batchSize, totalItems)
        return
    else
        lastGetAllTime = time()
        table.wipe(TSP.db.auctionData)
    end

    if batchSize == 0 then
        return
    end

    -- AUCTION_ITEM_LIST_UPDATE triggers on practically everything, and
    -- multiple times. We can't do anything more useful so we just ignore
    -- extra results while we're in the middle of doing something.

    if self.thread then
        return
    end

    TSP:ChatMessage('Starting auction house data scan of %d auctions', batchSize)
    self.thread = coroutine.create(function () StartScan(batchSize) end)
    self:SetScript('OnUpdate', OnUpdate)
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
        QueryAuctionItems('', nil, nil, 0, nil, nil, true, false, nil)
    end
end

local function Init()

    -- This is not a good test
    if #TSP.valueFunctions == 1 then
        TSP.db.auctionData = TSP.db.auctionData or {}

        AuctionHouseScanner:RegisterEvent('AUCTION_HOUSE_SHOW')
        AuctionHouseScanner:RegisterEvent('AUCTION_HOUSE_CLOSED')

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
        TSP.db.auctionData = nil
    end
end

local function OnEvent(self, event, arg1)
    if event == 'AUCTION_HOUSE_SHOW' then
        self:RegisterEvent('AUCTION_ITEM_LIST_UPDATE')
    elseif event == 'AUCTION_HOUSE_CLOSED' then
        abortScan = true
        self:UnregisterEvent('AUCTION_ITEM_LIST_UPDATE')
    elseif event == 'AUCTION_ITEM_LIST_UPDATE' then
        AuctionItemListUpdate(self)
    elseif event == 'ADDON_LOADED' then
        if arg1 == modName then
            Init()
        elseif arg1 == 'Blizzard_AuctionUI' then
            CreateScanButton()
        end
    end
end

AuctionHouseScanner:RegisterEvent('ADDON_LOADED')
AuctionHouseScanner:SetScript('OnEvent', OnEvent)
