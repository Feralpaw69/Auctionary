-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- Full scan: the lowest price of every item on the auction house
-- A 3.3.5 server offers two ways:
--   "getall"  everything with one request, once every 15 minutes
--   "pages"   50 auctions per request, always possible, slower
-- Messages on the event bus: FullScan.Events.ScanStart, ScanProgress(0..1),
-- ScanComplete(summary), ScanFailed.
--
-- Other parts can look at every single auction while a scan runs by setting
-- scanner.auctionCallback(info, itemLink, index) (the Sniping tab does).

local Info = Auctionary.Constants.AuctionItemInfo
local Events = Auctionary.FullScan.Events
local GETALL_COOLDOWN = 15 * 60
local GETALL_TIMEOUT = 60      -- seconds to wait for the answer to "getall"
local PER_STEP = 250           -- auctions read per step of a "getall" answer
local RETRIES = 4              -- rounds for auctions whose link came late

local scanner = CreateFrame("Frame")
scanner:Hide()
scanner.running = false
local bus = Auctionary.EventBus
bus:RegisterSource(scanner, "full scan")

local function Report(eventName, ...)
  bus:Fire(scanner, eventName, ...)
end

function scanner:IsInProgress()
  return self.running
end

function scanner:CanGetAll()
  return Auctionary.AH.CanQueryAll()
end

local function LastGetAll()
  return (Auctionary.SavedState and Auctionary.SavedState.LastGetAllAt) or 0
end

-- Seconds until "getall" is allowed again (0: now)
function scanner:GetCooldownRemaining()
  return math.max(0, GETALL_COOLDOWN - (time() - LastGetAll()))
end

function scanner:NextScanMessage()
  local left = self:GetCooldownRemaining()
  return AUCTIONARY2_L_SCAN_WAIT:format(math.floor(left / 60), left % 60)
end

---- Collecting

local function StartCollecting(self)
  self.prices = {}
  self.seen = 0
  self.skipped = 0
  self.ownCheck = Auctionary.AH.GetOwnAuctionChecker()
end

-- One auction; only buyout prices of other players count as market price
local function Collect(self, info, itemLink, index)
  local prices = self.prices
  Auctionary.CraftingInfo.NoteItemName(info[Info.Name], itemLink)
  if self.auctionCallback ~= nil then
    self.auctionCallback(info, itemLink, index)
  end
  self.seen = self.seen + 1

  local count, buyout = info[Info.Quantity] or 0, info[Info.Buyout] or 0
  if count <= 0 or buyout <= 0 or self.ownCheck(info, itemLink) then
    return
  end
  local unit = math.ceil(buyout / count)
  Auctionary.Utilities.DBKeyFromLink(itemLink, function(keys)
    if prices ~= self.prices then
      return -- belongs to an earlier scan
    end
    for _, key in ipairs(keys) do
      local best = prices[key]
      if best == nil then
        prices[key] = { { price = unit, available = count } }
      else
        best[1].available = best[1].available + count
        best[1].price = math.min(best[1].price, unit)
      end
    end
  end)
end

local function Stop(self)
  self.running = false
  self.pageScan = false
  self.waitingForAll = false
  self:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
  self:Hide()
end

local function Done(self)
  local prices, seen, skipped = self.prices, self.seen, self.skipped
  Stop(self)
  local items = Auctionary.Database:ProcessScan(prices)
  self.prices = {}
  Auctionary.Utilities.Message(AUCTIONARY2_L_SCAN_DONE:format(items))
  Auctionary.State.LastFullScanTime = GetTime()
  Report(Events.ScanProgress, 1)
  Report(Events.ScanComplete, {
    items = items, auctions = seen, skipped = skipped,
    seconds = GetTime() - self.startTime, mode = self.mode, automatic = self.automatic,
  })
end

local function Failed(self)
  if not self.running then
    return
  end
  Stop(self)
  self.prices = {}
  Auctionary.Utilities.Message(AUCTIONARY2_L_SCAN_FAILED)
  Report(Events.ScanFailed)
end

function scanner:Abort()
  if not self.running then
    return
  end
  if self.pageScan then
    self.pageScan = false
    Auctionary.AH.AbortQuery()
  end
  Failed(self)
end

---- Starting

-- mode: "getall", "pages" or nil (getall when allowed)
-- automatic: started by the addon on opening the auction house
function scanner:InitiateScan(mode, automatic)
  if self.running then
    Auctionary.Utilities.Message(AUCTIONARY2_L_SCAN_BUSY)
    return
  end
  if not Auctionary.State.AHOpen then
    return
  end
  mode = mode or (self:CanGetAll() and "getall" or "pages")
  if mode == "getall" and not self:CanGetAll() then
    Auctionary.Utilities.Message(self:NextScanMessage())
    return
  end

  self.mode, self.automatic = mode, automatic == true
  self.running = true
  self.startTime = GetTime()
  StartCollecting(self)
  Report(Events.ScanStart)

  if mode == "getall" then
    Auctionary.Utilities.Message(AUCTIONARY2_L_SCAN_START_ALL)
    Auctionary.SavedState.LastGetAllAt = time()
    Auctionary.AH.AbortQuery()
    self.waitingForAll = true
    self.askedAt = GetTime()
    self:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
    self:Show()
    QueryAuctionItems("", "", "", nil, nil, nil, 0, nil, -1, true)
    Report(Events.ScanProgress, 0.1)
  else
    Auctionary.Utilities.Message(AUCTIONARY2_L_SCAN_START_PAGES)
    self.pageScan = true
    Auctionary.AH.QueryAuctionItems({ searchString = "" })
    Report(Events.ScanProgress, 0)
  end
end

---- "pages": the search pages arrive over the event bus

function scanner:ReceiveEvent(eventName, results, gotAll, progress)
  if eventName == Auctionary.AH.Events.Closed then
    self:Abort()
  elseif not self.pageScan then
    return
  elseif eventName == Auctionary.AH.Events.ScanAborted then
    self.pageScan = false
    Failed(self)
  else
    for _, auction in ipairs(results) do
      Collect(self, auction.info, auction.itemLink)
    end
    Report(Events.ScanProgress, progress.page / progress.totalPages, progress)
    if gotAll then
      Done(self)
    end
  end
end
bus:Register(scanner, {
  Auctionary.AH.Events.ScanResultsUpdate,
  Auctionary.AH.Events.ScanAborted,
  Auctionary.AH.Events.Closed,
})

---- "getall": one big list, read a few hundred auctions per step

local function ReadList(self, positions, from, late, round)
  if not self.running then
    return
  end
  local to = math.min(from + PER_STEP - 1, #positions)
  for i = from, to do
    local index = positions[i]
    local info = { GetAuctionItemInfo("list", index) }
    local itemLink = GetAuctionItemLink("list", index)
    if info[Info.Name] ~= nil and itemLink ~= nil then
      Collect(self, info, itemLink, index)
    else
      late[#late + 1] = index
    end
  end
  if self.total > 0 then
    Report(Events.ScanProgress, 0.2 + 0.8 * math.min(self.seen / self.total, 1))
  end

  if to < #positions then
    Auctionary.Compat.After(0.01, function() ReadList(self, positions, to + 1, late, round) end)
  elseif #late > 0 and round < RETRIES then
    -- The client is still loading these items
    Auctionary.Compat.After(1, function() ReadList(self, late, 1, {}, round + 1) end)
  else
    self.skipped = #late
    -- Item data asked for while collecting may still be on its way
    Auctionary.Compat.After(0.5, function()
      if self.running then
        Done(self)
      end
    end)
  end
end

scanner:SetScript("OnEvent", function(self)
  if not self.waitingForAll then
    return
  end
  self.waitingForAll = false
  self:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
  self:Hide()
  Report(Events.ScanProgress, 0.2)
  local positions = {}
  for index = 1, (GetNumAuctionItems("list")) do
    positions[index] = index
  end
  self.total = #positions
  ReadList(self, positions, 1, {}, 0)
end)

-- Only shown while waiting for the "getall" answer
scanner:SetScript("OnUpdate", function(self)
  if self.waitingForAll and GetTime() - self.askedAt > GETALL_TIMEOUT then
    Failed(self)
  end
end)

---- Scan on opening the auction house (setting, off unless switched on)

local opener = {}
function opener:ReceiveEvent()
  if not Auctionary.Config.Get(Auctionary.Config.Options.AUTOSCAN) then
    return
  end
  Auctionary.Compat.After(1, function()
    if Auctionary.State.AHOpen and not scanner.running and not Auctionary.AH.IsQueryActive()
       and scanner:CanGetAll() then
      scanner:InitiateScan("getall", true)
    end
  end)
end
bus:Register(opener, { Auctionary.AH.Events.Opened })

function Auctionary.FullScan.Initialize()
  Auctionary.FullScan.Frame = scanner
end
