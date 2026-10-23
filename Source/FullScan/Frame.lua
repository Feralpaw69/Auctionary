local Auctionary = Auctionary

-- Reads the whole auction house and stores the lowest price of every item.
--
-- Two ways to do it on a 3.3.5 server:
--   "getall"  one request for everything, allowed once every 15 minutes
--             (some servers have it switched off)
--   "pages"   50 auctions at a time, always possible but slower
AuctionaryFullScanFrameMixin = {}

local AuctionItemInfo = Auctionary.Constants.AuctionItemInfo
local GETALL_COOLDOWN = 15 * 60
local GETALL_TIMEOUT = 60
local BATCH_SIZE = 250
local LINK_RETRIES = 4

function AuctionaryFullScanFrameMixin:OnLoad()
  Auctionary.Debug.Message("AuctionaryFullScanFrameMixin:OnLoad")
  Auctionary.EventBus:RegisterSource(self, "AuctionaryFullScanFrameMixin")
  Auctionary.EventBus:Register(self, {
    Auctionary.AH.Events.ScanResultsUpdate,
    Auctionary.AH.Events.ScanAborted,
    Auctionary.AH.Events.Closed,
  })
  self.state = Auctionary.SavedState
  self.inProgress = false
  self:SetScript("OnEvent", self.OnEvent)
end

function AuctionaryFullScanFrameMixin:ResetData()
  self.prices = {}
  self.isOwnAuction = nil
  self.auctionCount = 0
  self.skipped = 0
end

function AuctionaryFullScanFrameMixin:IsInProgress()
  return self.inProgress
end

function AuctionaryFullScanFrameMixin:CanGetAll()
  return Auctionary.AH.CanQueryAll()
end

-- mode: "getall", "pages" or nil to pick getall when the server allows it
-- automatic: started by the addon itself (on opening the auction house)
function AuctionaryFullScanFrameMixin:InitiateScan(mode, automatic)
  if self.inProgress then
    Auctionary.Utilities.Message(AUCTIONARY_L_FULL_SCAN_IN_PROGRESS)
    return
  end
  if not Auctionary.State.AHOpen then
    return
  end

  if mode == nil then
    mode = self:CanGetAll() and "getall" or "pages"
  elseif mode == "getall" and not self:CanGetAll() then
    Auctionary.Utilities.Message(self:NextScanMessage())
    return
  end

  self.mode = mode
  self.automatic = automatic and true or false
  self.inProgress = true
  self:ResetData()
  self.startTime = GetTime()

  Auctionary.EventBus:Fire(self, Auctionary.FullScan.Events.ScanStart)

  if mode == "getall" then
    Auctionary.Utilities.Message(AUCTIONARY_L_STARTING_FULL_SCAN_REPLICATE)
    self.state.TimeOfLastGetAllScan = time()
    Auctionary.AH.AbortQuery()
    self.waitingForGetAll = true
    self.getAllTime = GetTime()
    self:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
    self:SetScript("OnUpdate", self.OnUpdate)
    QueryAuctionItems("", "", "", nil, nil, nil, 0, nil, -1, true)
    Auctionary.EventBus:Fire(self, Auctionary.FullScan.Events.ScanProgress, 0.1)
  else
    Auctionary.Utilities.Message(AUCTIONARY_L_STARTING_FULL_SCAN_SUMMARY)
    self.pageScan = true
    Auctionary.AH.QueryAuctionItems({ searchString = "" })
    Auctionary.EventBus:Fire(self, Auctionary.FullScan.Events.ScanProgress, 0)
  end
end

-- Seconds until the next quick scan (0 when unknown or ready)
function AuctionaryFullScanFrameMixin:GetCooldownRemaining()
  local timeSinceLastScan = time() - (self.state.TimeOfLastGetAllScan or 0)
  return math.max(GETALL_COOLDOWN - timeSinceLastScan, 0)
end

function AuctionaryFullScanFrameMixin:NextScanMessage()
  local timeSinceLastScan = time() - (self.state.TimeOfLastGetAllScan or 0)
  local remaining = math.max(GETALL_COOLDOWN - timeSinceLastScan, 0)

  return AUCTIONARY_L_NEXT_SCAN_MESSAGE:format(math.floor(remaining / 60), remaining % 60)
end

function AuctionaryFullScanFrameMixin:Fail()
  if not self.inProgress then
    return
  end
  self.inProgress = false
  self.pageScan = false
  self.waitingForGetAll = false
  self:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
  self:SetScript("OnUpdate", nil)
  self:ResetData()

  Auctionary.Utilities.Message(AUCTIONARY_L_FULL_SCAN_FAILED)
  Auctionary.EventBus:Fire(self, Auctionary.FullScan.Events.ScanFailed)
end

function AuctionaryFullScanFrameMixin:Abort()
  if self.inProgress then
    if self.pageScan then
      self.pageScan = false
      Auctionary.AH.AbortQuery()
    end
    self:Fail()
  end
end

-- Adds one auction to the collected prices
-- index: position in the client's list (only for a "getall" scan)
function AuctionaryFullScanFrameMixin:AddAuction(info, itemLink, index)
  local count = info[AuctionItemInfo.Quantity] or 0
  local buyout = info[AuctionItemInfo.Buyout] or 0

  Auctionary.CraftingInfo.NoteItemName(info[AuctionItemInfo.Name], itemLink)

  -- Lets others look at every auction of the scan (Sniping tab)
  if self.auctionCallback ~= nil then
    self.auctionCallback(info, itemLink, index)
  end

  self.auctionCount = self.auctionCount + 1

  -- Auctions without a buyout price say nothing about the market price
  if count <= 0 or buyout <= 0 then
    return
  end
  -- The player's own auctions are not the market either
  if self.isOwnAuction == nil then
    self.isOwnAuction = Auctionary.AH.GetOwnAuctionChecker()
  end
  if self.isOwnAuction(info, itemLink) then
    return
  end

  local price = math.ceil(buyout / count)
  local prices = self.prices
  Auctionary.Utilities.DBKeyFromLink(itemLink, function(dbKeys)
    if prices ~= self.prices then
      return -- answer for an older scan
    end
    for _, dbKey in ipairs(dbKeys) do
      local entry = prices[dbKey]
      if entry == nil then
        prices[dbKey] = { { price = price, available = count } }
      else
        -- One entry per item is enough: lowest price and total quantity
        entry[1].available = entry[1].available + count
        if price < entry[1].price then
          entry[1].price = price
        end
      end
    end
  end)
end

function AuctionaryFullScanFrameMixin:Finish()
  self.inProgress = false
  self.pageScan = false
  self:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
  self:SetScript("OnUpdate", nil)

  local count = Auctionary.Database:ProcessScan(self.prices)
  Auctionary.Utilities.Message(AUCTIONARY_L_FINISHED_PROCESSING:format(count))

  local summary = {
    items = count,
    auctions = self.auctionCount,
    skipped = self.skipped,
    seconds = GetTime() - self.startTime,
    mode = self.mode,
    automatic = self.automatic,
  }
  self:ResetData()
  -- When the whole auction house was last read (for prices that count as fresh)
  Auctionary.State.LastFullScanTime = GetTime()

  Auctionary.EventBus:Fire(self, Auctionary.FullScan.Events.ScanProgress, 1)
  Auctionary.EventBus:Fire(self, Auctionary.FullScan.Events.ScanComplete, summary)
end

---- Page by page

function AuctionaryFullScanFrameMixin:ReceiveEvent(eventName, results, gotAllResults, progress)
  if eventName == Auctionary.AH.Events.ScanResultsUpdate then
    if not self.pageScan then
      return
    end
    for _, auction in ipairs(results) do
      self:AddAuction(auction.info, auction.itemLink)
    end
    Auctionary.EventBus:Fire(self, Auctionary.FullScan.Events.ScanProgress,
      progress.page / progress.totalPages, progress)
    if gotAllResults then
      self:Finish()
    end
  elseif eventName == Auctionary.AH.Events.ScanAborted then
    if self.pageScan then
      self.pageScan = false
      self:Fail()
    end
  elseif eventName == Auctionary.AH.Events.Closed then
    self:Abort()
  end
end

---- Everything with one request

function AuctionaryFullScanFrameMixin:OnEvent(eventName)
  if eventName == "AUCTION_ITEM_LIST_UPDATE" and self.waitingForGetAll then
    self.waitingForGetAll = false
    self:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
    self:SetScript("OnUpdate", nil)

    Auctionary.EventBus:Fire(self, Auctionary.FullScan.Events.ScanProgress, 0.2)

    local pending = {}
    for index = 1, (GetNumAuctionItems("list")) do
      pending[index] = index
    end
    self.getAllTotal = #pending
    self:ProcessBatch(pending, 1, {}, 0)
  end
end

function AuctionaryFullScanFrameMixin:OnUpdate()
  if self.waitingForGetAll and GetTime() - self.getAllTime > GETALL_TIMEOUT then
    Auctionary.Debug.Message("full scan: no answer to the getAll request")
    self:Fail()
  end
end

-- pending: positions in the client's list still to read
-- missing: positions whose item link was not available yet
function AuctionaryFullScanFrameMixin:ProcessBatch(pending, start, missing, attempt)
  if not self.inProgress then
    return
  end

  local last = math.min(start + BATCH_SIZE - 1, #pending)
  for i = start, last do
    local index = pending[i]
    local info = { GetAuctionItemInfo("list", index) }
    local itemLink = GetAuctionItemLink("list", index)
    if info[AuctionItemInfo.Name] ~= nil and itemLink ~= nil then
      self:AddAuction(info, itemLink, index)
    else
      table.insert(missing, index)
    end
  end

  if self.getAllTotal > 0 then
    Auctionary.EventBus:Fire(self, Auctionary.FullScan.Events.ScanProgress,
      0.2 + 0.8 * math.min(self.auctionCount / self.getAllTotal, 1))
  end

  if last < #pending then
    Auctionary.Compat.After(0.01, function()
      self:ProcessBatch(pending, last + 1, missing, attempt)
    end)
  elseif #missing > 0 and attempt < LINK_RETRIES then
    -- The client is still loading some items, look at those again shortly
    Auctionary.Compat.After(1, function()
      self:ProcessBatch(missing, 1, {}, attempt + 1)
    end)
  else
    self.skipped = #missing
    -- Item data requested by DBKeyFromLink may still be arriving
    Auctionary.Compat.After(0.5, function()
      if self.inProgress then
        self:Finish()
      end
    end)
  end
end

-- Scans as soon as the auction house is opened, if the server allows a scan
-- of everything right now (Auctionary.Config.Options.AUTOSCAN)
local autoScanListener = {}
function autoScanListener:ReceiveEvent()
  if Auctionary.SavedState ~= nil and not Auctionary.SavedState.AutoscanDefaultApplied then
    -- Switched on once; /aury config autoscan_2 switches it off again
    Auctionary.SavedState.AutoscanDefaultApplied = true
    Auctionary.Config.Set(Auctionary.Config.Options.AUTOSCAN, true)
  end
  if not Auctionary.Config.Get(Auctionary.Config.Options.AUTOSCAN) then
    return
  end
  -- A moment later, so the window is up and other addons are done opening
  Auctionary.Compat.After(1, function()
    local frame = Auctionary.FullScan.Frame
    if frame ~= nil and Auctionary.State.AHOpen and not frame:IsInProgress() and
       not Auctionary.AH.IsQueryActive() and frame:CanGetAll() then
      frame:InitiateScan("getall", true)
    end
  end)
end
Auctionary.EventBus:Register(autoScanListener, { Auctionary.AH.Events.Opened })

function Auctionary.FullScan.Initialize()
  if Auctionary.FullScan.Frame ~= nil then
    return
  end
  local frame = CreateFrame("Frame", "AuctionaryFullScanFrame", UIParent)
  Auctionary.Compat.Mixin(frame, AuctionaryFullScanFrameMixin)
  frame:OnLoad()
  Auctionary.FullScan.Frame = frame
end
