local Auctionator = Auctionary

-- Runs name/category searches against the 3.3.5 auction house, one page of 50
-- auctions at a time.
--
-- query = {
--   searchString, minLevel, maxLevel, invTypeIndex, classIndex, subclassIndex,
--   isUsable, qualityIndex (minimum quality, nil for all),
--   needOwners (wait for the seller names, slower),
--   isExact (only keep auctions whose name equals searchString)
-- }
--
-- Every auction is reported as
-- {
--   info      = { GetAuctionItemInfo("list", index) },  see Constants.AuctionItemInfo
--   itemLink  = GetAuctionItemLink("list", index),
--   timeLeft  = GetAuctionItemTimeLeft("list", index),   see Constants.TimeLeftBand
--   index, page, query
-- }
AuctionaryAHScanFrameMixin = {}

local PAGE_SIZE = Auctionator.Constants.PageSize
-- Seconds to wait for seller names/item links that the server sends late
local DETAILS_WAIT = 0.2
-- Seconds without any answer before a page is requested again
-- Seconds an answer that looks like the previous page is not trusted
local STALE_WAIT = 1
local ANSWER_TIMEOUT = 12
local MAX_RETRIES = 3

function AuctionaryAHScanFrameMixin:OnLoad()
  self.active = false
  self:SetScript("OnEvent", self.OnEvent)
  self:RegisterEvent("AUCTION_HOUSE_CLOSED")
  Auctionator.EventBus:RegisterSource(self, "AuctionaryAHScanFrameMixin")

  -- Another addon (or the Browse tab) searching while a scan runs replaces
  -- the results the scan is waiting for, so the scan has to stop.
  hooksecurefunc("QueryAuctionItems", function()
    if self.active and not self.sendingOwnQuery then
      Auctionator.Debug.Message("scan: foreign query, aborting")
      self:Abort()
    end
  end)
end

function AuctionaryAHScanFrameMixin:Start(query, page, singlePage)
  self:Abort()

  self.query = query
  self.page = page or 0
  self.singlePage = singlePage and true or false
  self.active = true
  self.retries = 0
  self.lastFingerprint = nil
  -- Where the time goes, in seconds: waiting until the server allows the next
  -- request, waiting for its answer, waiting for seller names/item links
  self.stats = { throttle = 0, answer = 0, details = 0, pages = 0 }

  self:SendPage()
end

function AuctionaryAHScanFrameMixin:IsActive()
  return self.active
end

function AuctionaryAHScanFrameMixin:Stop()
  if self.sendFunc ~= nil then
    Auctionator.AH.Queue:Remove(self.sendFunc)
    self.sendFunc = nil
  end
  self.active = false
  self.awaiting = false
  self:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
  self:SetScript("OnUpdate", nil)
end

function AuctionaryAHScanFrameMixin:Abort()
  if self.active then
    self:Stop()
    Auctionator.EventBus:Fire(self, Auctionator.AH.Events.ScanAborted)
  end
end

function AuctionaryAHScanFrameMixin:SendPage()
  local query = self.query
  local page = self.page

  self.awaiting = false
  local enqueueTime = GetTime()
  self.sendFunc = function()
    self.sendFunc = nil
    self.stats.throttle = self.stats.throttle + (GetTime() - enqueueTime)
    self.awaiting = true
    self.gotAnswer = false
    self.sentTime = GetTime()
    self:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
    self:SetScript("OnUpdate", self.OnUpdate)

    self.sendingOwnQuery = true
    QueryAuctionItems(
      query.searchString or "",
      query.minLevel or "",
      query.maxLevel or "",
      query.invTypeIndex,
      query.classIndex,
      query.subclassIndex,
      page,
      query.isUsable and 1 or nil,
      query.qualityIndex or -1
    )
    self.sendingOwnQuery = false
  end
  Auctionator.AH.Queue:Enqueue(self.sendFunc)
end

function AuctionaryAHScanFrameMixin:OnEvent(eventName)
  if eventName == "AUCTION_ITEM_LIST_UPDATE" then
    if self.awaiting then
      if not self.gotAnswer then
        self.gotAnswer = true
        self.answerTime = GetTime()
        self.stats.answer = self.stats.answer + (self.answerTime - self.sentTime)
      end
      if self:HasAllDetails() then
        self:ProcessPage()
      end
    end
  elseif eventName == "AUCTION_HOUSE_CLOSED" then
    self:Abort()
  end
end

function AuctionaryAHScanFrameMixin:OnUpdate()
  if not self.awaiting then
    return
  end

  if self.gotAnswer then
    if self:HasAllDetails() or GetTime() - self.answerTime > DETAILS_WAIT then
      self:ProcessPage()
    end
  elseif GetTime() - self.sentTime > ANSWER_TIMEOUT then
    self.retries = self.retries + 1
    if self.retries > MAX_RETRIES then
      Auctionator.Debug.Message("scan: no answer, giving up")
      self:Abort()
    else
      Auctionator.Debug.Message("scan: no answer, asking again", self.page)
      self:SendPage()
    end
  end
end

-- Text that is the same only for the same page of auctions
local function GetFingerprint()
  local parts = {}
  for index = 1, (GetNumAuctionItems("list")) do
    local name, _, count, _, _, _, minBid, _, buyoutPrice, bidAmount = GetAuctionItemInfo("list", index)
    parts[index] = tostring(name) .. tostring(count) .. ":" .. tostring(minBid) .. ":"
      .. tostring(buyoutPrice) .. ":" .. tostring(bidAmount)
  end
  return table.concat(parts, "|")
end

function AuctionaryAHScanFrameMixin:HasAllDetails()
  local ownerIndex = Auctionator.Constants.AuctionItemInfo.Owner
  local needOwners = self.query.needOwners
  local numBatch = GetNumAuctionItems("list")

  -- Seller names of the previous page can arrive after the next page was
  -- requested. That looks like an answer but still shows the previous page.
  if numBatch > 0 and self.lastFingerprint ~= nil and
     GetTime() - self.answerTime < STALE_WAIT and
     GetFingerprint() == self.lastFingerprint then
    return false
  end

  for index = 1, numBatch do
    if GetAuctionItemLink("list", index) == nil or
       (needOwners and select(ownerIndex, GetAuctionItemInfo("list", index)) == nil) then
      return false
    end
  end
  return true
end

function AuctionaryAHScanFrameMixin:ProcessPage()
  self.awaiting = false
  self:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
  self:SetScript("OnUpdate", nil)

  self.stats.details = self.stats.details + (GetTime() - self.answerTime)
  self.stats.pages = self.stats.pages + 1

  local query = self.query
  local page = self.page
  local numBatch, total = GetNumAuctionItems("list")
  local nameIndex = Auctionator.Constants.AuctionItemInfo.Name
  local exactName = query.isExact and query.searchString and string.lower(query.searchString)

  self.lastFingerprint = GetFingerprint()

  local results = {}
  for index = 1, numBatch do
    local info = { GetAuctionItemInfo("list", index) }
    local itemLink = GetAuctionItemLink("list", index)
    local name = info[nameIndex]

    if name ~= nil and itemLink ~= nil and
       (not exactName or string.lower(name) == exactName) then
      table.insert(results, {
        info = info,
        itemLink = itemLink,
        timeLeft = GetAuctionItemTimeLeft("list", index),
        index = index,
        page = page,
        query = query,
      })
    end
  end

  if self.singlePage then
    self:Stop()
    Auctionator.EventBus:Fire(self, Auctionator.AH.Events.CurrentPage, results, total)
    return
  end

  local totalPages = math.ceil(total / PAGE_SIZE)
  local gotAllResults = numBatch < PAGE_SIZE or (page + 1) >= totalPages
  local progress = { page = page + 1, totalPages = math.max(totalPages, 1), total = total, stats = self.stats }

  if gotAllResults then
    self:Stop()
  else
    self.page = page + 1
    self.retries = 0
    self:SendPage()
  end

  Auctionator.EventBus:Fire(self, Auctionator.AH.Events.ScanResultsUpdate, results, gotAllResults, progress)
end
