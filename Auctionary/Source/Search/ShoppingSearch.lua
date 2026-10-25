-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- Shopping search
-- Searches a list of terms one after the other, each over all its pages,
-- and turns the auctions of a term into one result per item:
--   key, itemLink, itemID, name, plainItemName, iconTexture, quality,
--   itemLevel, minPrice (cheapest buyout per unit, own auctions included),
--   totalQuantity, available (text), containsOwnerItem, isOwned (text),
--   purchaseQuantity, auctions (as delivered by Auctionary.AH)
--
--   local search = Auctionary.Search.CreateShoppingSearch({
--     onTerm = function(number, count, resultsOfTheLastTerm) end,
--     onPage = function(progress) end,      -- progress.page / .totalPages
--     onDone = function(allResults, stopped) end,
--   })
--   search:Start({ "Frostweave Cloth", "\"Eternal Life\"" })
--   search:Stop()

local Info = Auctionary.Constants.AuctionItemInfo
local AHEvents = Auctionary.AH.Events
local LISTENED = { AHEvents.ScanResultsUpdate, AHEvents.ScanAborted }

local Search = {}
local SearchMeta = { __index = Search }

local function Nothing() end

function Auctionary.Search.CreateShoppingSearch(callbacks)
  callbacks = callbacks or {}
  return setmetatable({
    onTerm = callbacks.onTerm or Nothing,
    onPage = callbacks.onPage or Nothing,
    onDone = callbacks.onDone or Nothing,
    running = false,
    listening = false,
  }, SearchMeta)
end

function Search:IsRunning()
  return self.running
end

-- Number of the term being searched and how many there are
function Search:GetPosition()
  return self.position or 0, #(self.terms or {})
end

local function Listen(self, on)
  if on ~= self.listening then
    self.listening = on
    if on then
      Auctionary.EventBus:Register(self, LISTENED)
    else
      Auctionary.EventBus:Unregister(self, LISTENED)
    end
  end
end

local function End(self, stopped)
  if not self.running then
    return
  end
  self.running = false
  Listen(self, false)
  local results = self.results
  self.results, self.pageAuctions = {}, {}
  self.onDone(results, stopped == true)
end

-- What the auction house is asked, and what is checked afterwards
local function Request(term)
  local parts = Auctionary.Search.SplitAdvancedSearch(term)
  local category = Auctionary.Search.GetLegacyCategory(parts.categoryKey) or {}
  return {
    query = {
      searchString = parts.searchString,
      isExact = parts.isExact,
      minLevel = parts.minLevel, maxLevel = parts.maxLevel,
      qualityIndex = parts.quality,
      classIndex = category.classIndex,
      subclassIndex = category.subclassIndex,
      invTypeIndex = category.invTypeIndex,
      -- Waiting for seller names would slow every page down
      needOwners = false,
    },
    itemLevel = { parts.minItemLevel, parts.maxItemLevel },
    price = { parts.minPrice, parts.maxPrice },
    quantity = parts.quantity,
  }
end

-- For /aury test and the self checks
Auctionary.Search.ShoppingRequest = Request

local function SearchNext(self)
  self.position = self.position + 1
  local term = self.terms[self.position]
  if term == nil then
    End(self)
    return
  end
  self.onTerm(self.position, #self.terms, self.lastTermResults)
  self.lastTermResults = {}
  self.request = Request(term)
  self.pageAuctions = {}
  Auctionary.AH.QueryAuctionItems(self.request.query)
end

function Search:Start(terms)
  self:Stop()
  self.terms = terms or {}
  self.position = 0
  self.results, self.lastTermResults = {}, {}
  self.running = true
  Listen(self, true)
  SearchNext(self)
end

function Search:Stop()
  if self.running then
    Auctionary.AH.AbortQuery()
    End(self, true)
  end
end

---- Turning auctions into results

local function Within(value, limits)
  local low, high = limits[1], limits[2]
  return (low == nil or value >= low) and (high == nil or value <= high)
end

-- Same item with the same enchant, gems and suffix; the unique ID differs
-- between two otherwise equal auctions
local function SameItemKey(itemLink)
  return itemLink:match("item:([%-%d]+:[%-%d]*:[%-%d]*:[%-%d]*:[%-%d]*:[%-%d]*:[%-%d]*)") or itemLink
end

local function NewResult(key, auction)
  local info = auction.info
  local name = info[Info.Name]
  Auctionary.CraftingInfo.NoteItemName(name, auction.itemLink)
  return {
    key = key,
    itemLink = auction.itemLink,
    itemID = tonumber(Auctionary.Utilities.BasicDBKeyFromLink(auction.itemLink)),
    name = name,
    plainItemName = name,
    iconTexture = info[Info.Texture],
    quality = info[Info.Quality],
    itemLevel = select(4, GetItemInfo(auction.itemLink)) or 0,
    totalQuantity = 0,
    containsOwnerItem = false,
    auctions = {},
  }
end

local function ByItem(auctions)
  local isOwn = Auctionary.AH.GetOwnAuctionChecker()
  local byKey, list = {}, {}
  for _, auction in ipairs(auctions) do
    local key = SameItemKey(auction.itemLink)
    local result = byKey[key]
    if result == nil then
      result = NewResult(key, auction)
      byKey[key] = result
      list[#list + 1] = result
    end
    local count = auction.info[Info.Quantity] or 0
    local buyout = auction.info[Info.Buyout] or 0
    local own = isOwn(auction.info, auction.itemLink)
    result.totalQuantity = result.totalQuantity + count
    result.containsOwnerItem = result.containsOwnerItem or own
    if count > 0 and buyout > 0 then
      local unit = math.ceil(buyout / count)
      result.minPrice = math.min(result.minPrice or unit, unit)
      -- The price that is remembered leaves the own auctions out
      if not own then
        result.marketPrice = math.min(result.marketPrice or unit, unit)
      end
    end
    result.auctions[#result.auctions + 1] = auction
  end
  return list
end

-- Every auction of the item was seen, so the cheapest one is the market price
local function Remember(result)
  local price, count = result.marketPrice, result.totalQuantity
  if price == nil then
    return
  end
  Auctionary.Utilities.DBKeyFromLink(result.itemLink, function(keys)
    -- Only the most exact key: the plain ID of gear with a random suffix
    -- would get the price of this one suffix
    if keys[1] ~= nil then
      Auctionary.Database:SetPrice(keys[1], price, count)
    end
  end)
end

local function TermDone(self)
  local request = self.request
  local yes = AUCTIONARY2_L_YES or YES
  for _, result in ipairs(ByItem(self.pageAuctions)) do
    Remember(result)
    local levelOk = result.itemLevel == 0 or Within(result.itemLevel, request.itemLevel)
    if levelOk and Within(result.minPrice or 0, request.price) then
      result.purchaseQuantity = request.quantity
      result.available = Auctionary.Compat.FormatLargeNumber(result.totalQuantity)
      result.isOwned = result.containsOwnerItem and yes or ""
      self.results[#self.results + 1] = result
      self.lastTermResults[#self.lastTermResults + 1] = result
    end
  end
  self.pageAuctions = {}
  SearchNext(self)
end

function Search:ReceiveEvent(eventName, auctions, complete, progress)
  if not self.running then
    return
  end
  if eventName == AHEvents.ScanAborted then
    -- The auction house closed, or something else started a search
    End(self, true)
    return
  end
  local collected = self.pageAuctions
  for _, auction in ipairs(auctions) do
    collected[#collected + 1] = auction
  end
  self.onPage(progress)
  if complete then
    TermDone(self)
  end
end
