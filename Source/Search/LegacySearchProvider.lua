local Auctionary = Auctionary

-- Runs the search terms of the Shopping tab against the 3.3.5 auction house.
-- Every term is searched over all its pages; the auctions found are then
-- grouped into one result per item:
-- {
--   itemLink, name, plainItemName, iconTexture, quality, itemLevel, itemID,
--   minPrice (lowest buyout for one unit, nil if nothing has a buyout),
--   totalQuantity, containsOwnerItem, purchaseQuantity,
--   auctions = { ... }  the auctions as reported by Auctionary.AH
-- }
AuctionaryLegacySearchProviderMixin = Auctionary.Compat.CreateFromMixins(
  AuctionaryMultiSearchMixin, AuctionarySearchProviderMixin
)

local AuctionItemInfo = Auctionary.Constants.AuctionItemInfo

local SEARCH_EVENTS = {
  Auctionary.AH.Events.ScanResultsUpdate,
  Auctionary.AH.Events.ScanAborted,
}

function AuctionaryLegacySearchProviderMixin:CreateSearchTerm(term)
  Auctionary.Debug.Message("AuctionaryLegacySearchProviderMixin:CreateSearchTerm()", term)

  local parsed = Auctionary.Search.SplitAdvancedSearch(term)
  local category = Auctionary.Search.GetLegacyCategory(parsed.categoryKey) or {}

  return {
    query = {
      searchString = parsed.searchString,
      minLevel = parsed.minLevel,
      maxLevel = parsed.maxLevel,
      qualityIndex = parsed.quality,
      classIndex = category.classIndex,
      subclassIndex = category.subclassIndex,
      invTypeIndex = category.invTypeIndex,
      isExact = parsed.isExact,
      -- Seller names arrive later than the auctions; waiting for them slows
      -- every page down, so only the names the client already has are shown
      needOwners = false,
    },
    extraFilters = {
      itemLevel = { min = parsed.minItemLevel, max = parsed.maxItemLevel },
      price = { min = parsed.minPrice, max = parsed.maxPrice },
    },
    resultMetadata = {
      quantity = parsed.quantity,
    },
  }
end

function AuctionaryLegacySearchProviderMixin:GetSearchProvider()
  return function(searchTerm)
    self.currentFilter = searchTerm.extraFilters
    self.resultMetadata = searchTerm.resultMetadata
    self.termAuctions = {}
    self.gotAllResults = false
    Auctionary.AH.QueryAuctionItems(searchTerm.query)
  end
end

function AuctionaryLegacySearchProviderMixin:HasCompleteTermResults()
  return self.gotAllResults
end

function AuctionaryLegacySearchProviderMixin:GetCurrentEmptyResult()
  local searchTerm = self:GetCurrentSearchParameter()
  return {
    key = "empty:" .. self:GetCurrentSearchIndex(),
    name = Auctionary.Search.PrettifySearchString(searchTerm),
    plainItemName = (searchTerm:gsub("\"", "")),
    totalQuantity = 0,
    available = "0",
    containsOwnerItem = false,
    auctions = {},
  }
end

function AuctionaryLegacySearchProviderMixin:RegisterProviderEvents()
  if not self.registeredForEvents then
    self.registeredForEvents = true
    Auctionary.EventBus:Register(self, SEARCH_EVENTS)
  end
end

function AuctionaryLegacySearchProviderMixin:UnregisterProviderEvents()
  if self.registeredForEvents then
    self.registeredForEvents = false
    Auctionary.EventBus:Unregister(self, SEARCH_EVENTS)
  end
end

function AuctionaryLegacySearchProviderMixin:AbortSearch()
  local wasRunning = not self.complete
  AuctionaryMultiSearchMixin.AbortSearch(self)
  if wasRunning then
    Auctionary.AH.AbortQuery()
  end
end

local function InRange(value, limits)
  return (limits.min == nil or limits.min <= value) and (limits.max == nil or limits.max >= value)
end

local function GroupKey(itemLink)
  -- Item, enchant, gems and random suffix; not the unique ID
  return itemLink:match("item:(%-?%d+:%-?%d*:%-?%d*:%-?%d*:%-?%d*:%-?%d*:%-?%d*)") or itemLink
end

function AuctionaryLegacySearchProviderMixin:GroupAuctions(auctions)
  local playerName = UnitName("player")
  local isOwnAuction = Auctionary.AH.GetOwnAuctionChecker()
  local groups, order = {}, {}

  for _, auction in ipairs(auctions) do
    local info = auction.info
    local key = GroupKey(auction.itemLink)
    local group = groups[key]
    if group == nil then
      local _, _, _, itemLevel = GetItemInfo(auction.itemLink)
      group = {
        key = key,
        itemLink = auction.itemLink,
        itemID = tonumber(Auctionary.Utilities.BasicDBKeyFromLink(auction.itemLink)),
        name = info[AuctionItemInfo.Name],
        plainItemName = info[AuctionItemInfo.Name],
        iconTexture = info[AuctionItemInfo.Texture],
        quality = info[AuctionItemInfo.Quality],
        itemLevel = itemLevel or 0,
        totalQuantity = 0,
        containsOwnerItem = false,
        auctions = {},
      }
      groups[key] = group
      table.insert(order, group)
      Auctionary.CraftingInfo.NoteItemName(group.name, auction.itemLink)
    end

    local count = info[AuctionItemInfo.Quantity] or 0
    local buyout = info[AuctionItemInfo.Buyout] or 0
    group.totalQuantity = group.totalQuantity + count
    local isOwn = isOwnAuction(info, auction.itemLink)
    if buyout > 0 and count > 0 then
      local unitPrice = math.ceil(buyout / count)
      if group.minPrice == nil or unitPrice < group.minPrice then
        group.minPrice = unitPrice
      end
      -- What gets saved as the market price leaves the own auctions out
      if not isOwn and (group.marketPrice == nil or unitPrice < group.marketPrice) then
        group.marketPrice = unitPrice
      end
    end
    if isOwn then
      group.containsOwnerItem = true
    end
    table.insert(group.auctions, auction)
  end

  return order
end

function AuctionaryLegacySearchProviderMixin:FinishTerm()
  local results = {}
  for _, group in ipairs(self:GroupAuctions(self.termAuctions)) do
    -- All auctions of an item were seen, so its lowest price is known
    if group.marketPrice ~= nil then
      local minPrice, totalQuantity = group.marketPrice, group.totalQuantity
      Auctionary.Utilities.DBKeyFromLink(group.itemLink, function(dbKeys)
        -- The plain item ID of gear with a random suffix would only get the
        -- price of this one suffix
        if dbKeys[1] ~= nil then
          Auctionary.Database:SetPrice(dbKeys[1], minPrice, totalQuantity)
        end
      end)
    end

    if InRange(group.minPrice or 0, self.currentFilter.price) and
       (group.itemLevel == 0 or InRange(group.itemLevel, self.currentFilter.itemLevel)) then
      group.purchaseQuantity = self.resultMetadata.quantity
      group.available = Auctionary.Compat.FormatLargeNumber(group.totalQuantity)
      group.isOwned = group.containsOwnerItem and (AUCTIONARY_L_UNDERCUT_YES or YES) or ""
      table.insert(results, group)
    end
  end
  self.termAuctions = {}
  self.gotAllResults = true
  self:AddResults(results)
end

function AuctionaryLegacySearchProviderMixin:ReceiveEvent(eventName, results, gotAllResults, progress)
  if self.complete then
    return
  end

  if eventName == Auctionary.AH.Events.ScanResultsUpdate then
    for _, auction in ipairs(results) do
      table.insert(self.termAuctions, auction)
    end
    if self.onPageProgress then
      self.onPageProgress(progress)
    end
    if gotAllResults then
      self:FinishTerm()
    end
  elseif eventName == Auctionary.AH.Events.ScanAborted then
    -- Closed auction house or a search by something else
    AuctionaryMultiSearchMixin.AbortSearch(self)
  end
end

function Auctionary.Search.CreateLegacySearchProvider()
  local provider = Auctionary.Compat.CreateFromMixins(AuctionaryLegacySearchProviderMixin)
  provider.complete = true
  return provider
end
