local Auctionary = Auctionary

local AuctionItemInfo = Auctionary.Constants.AuctionItemInfo

-- Searches every page for the query. Results arrive page by page with the
-- event Auctionary.AH.Events.ScanResultsUpdate. See Source/AH/Scan.lua for
-- the format of query and results.
function Auctionary.AH.QueryAuctionItems(query)
  Auctionary.AH.Internals.scan:Start(query, 0, false)
end

-- Loads one page (first page is 0) and leaves it as the client's current
-- "list" so its auctions can be bought. Answer: Auctionary.AH.Events.CurrentPage
function Auctionary.AH.QueryAndFocusPage(query, page)
  Auctionary.AH.Internals.scan:Start(query, page, true)
end

function Auctionary.AH.AbortQuery()
  Auctionary.AH.Internals.scan:Abort()
end

function Auctionary.AH.IsQueryActive()
  return Auctionary.AH.Internals.scan:IsActive()
end

-- Reads the client's current "list", "owner" or "bidder" auctions
function Auctionary.AH.DumpAuctions(view)
  local auctions = {}
  for index = 1, (GetNumAuctionItems(view)) do
    local info = { GetAuctionItemInfo(view, index) }
    local itemLink = GetAuctionItemLink(view, index)
    if info[AuctionItemInfo.Name] ~= nil and itemLink ~= nil then
      table.insert(auctions, {
        info = info,
        itemLink = itemLink,
        timeLeft = GetAuctionItemTimeLeft(view, index),
        index = index,
      })
    end
  end
  return auctions
end

-- Returns a function(info, itemLink) that says whether an auction is one of
-- the player's own. The seller's name decides; while the client has not got
-- the name yet, being identical to one of the own auctions does.
function Auctionary.AH.GetOwnAuctionChecker()
  local playerName = UnitName("player")
  local own = {}
  for index = 1, (GetNumAuctionItems("owner")) do
    local link = GetAuctionItemLink("owner", index)
    local info = { GetAuctionItemInfo("owner", index) }
    if link ~= nil then
      own[link .. ":" .. (info[AuctionItemInfo.Quantity] or 0) .. ":" .. (info[AuctionItemInfo.Buyout] or 0)] = true
    end
  end
  return function(info, itemLink)
    local owner = info[AuctionItemInfo.Owner]
    if owner ~= nil then
      return owner == playerName
    end
    return own[(itemLink or "") .. ":" .. (info[AuctionItemInfo.Quantity] or 0) .. ":" .. (info[AuctionItemInfo.Buyout] or 0)] == true
  end
end

-- Answer: Auctionary.AH.Events.OwnedAuctionsUpdate
function Auctionary.AH.QueryOwnedAuctions()
  Auctionary.AH.Internals.owned:Query()
end

local function IsSameAuction(a, b)
  if a.itemLink ~= b.itemLink then
    return false
  end
  for _, key in ipairs({ "Quantity", "MinBid", "Buyout", "BidAmount" }) do
    if a.info[AuctionItemInfo[key]] ~= b.info[AuctionItemInfo[key]] then
      return false
    end
  end
  return true
end

-- The client only knows auctions by their position in the current list, and
-- the list changes whenever something is bought, sold or cancelled. Finds the
-- position of the given auction (as reported by a scan) in the current view.
function Auctionary.AH.FindAuctionIndex(view, auction)
  local ownerIndex = AuctionItemInfo.Owner
  local numItems = GetNumAuctionItems(view)

  local function Matches(index)
    -- The link is compared first: it is the cheapest way to rule a row out,
    -- which matters for the list of a full scan with tens of thousands of rows
    if GetAuctionItemLink(view, index) ~= auction.itemLink then
      return false
    end
    local other = { info = { GetAuctionItemInfo(view, index) }, itemLink = auction.itemLink }
    return IsSameAuction(auction, other), other.info[ownerIndex] == auction.info[ownerIndex]
  end

  -- Usually still where the scan saw it
  if auction.index ~= nil and auction.index <= numItems and Matches(auction.index) then
    return auction.index
  end

  local fallback = nil
  for index = 1, numItems do
    local same, sameOwner = Matches(index)
    if same then
      if sameOwner then
        return index
      end
      fallback = fallback or index
    end
  end
  return fallback
end

-- Buys or bids on an auction from the current page (see QueryAndFocusPage).
-- Returns true when the request was sent.
function Auctionary.AH.PlaceAuctionBid(auction, amount)
  local index = Auctionary.AH.FindAuctionIndex("list", auction)
  if index == nil then
    return false
  end
  PlaceAuctionBid("list", index, amount)
  return true
end

function Auctionary.AH.IsAuctionOwned(auction)
  return auction.info[AuctionItemInfo.Owner] == (UnitName("player"))
end

-- Cancels one of the player's own auctions (as reported by
-- OwnedAuctionsUpdate). Returns true when the request was sent.
function Auctionary.AH.CancelAuction(auction)
  local index = Auctionary.AH.FindAuctionIndex("owner", auction)
  if index == nil then
    return false
  end
  CancelAuction(index)
  return true
end

-- The item has to be in the auction sell slot already
-- (ClickAuctionSellItemButton). duration is in hours (12, 24 or 48), the
-- prices are for one stack.
function Auctionary.AH.PostAuction(startingBid, buyoutPrice, duration, stackSize, numStacks)
  StartAuction(
    startingBid,
    buyoutPrice,
    Auctionary.Constants.DurationToRunTime[duration],
    stackSize,
    numStacks
  )
end

-- Event ThrottleUpdate will fire whenever the state changes
function Auctionary.AH.IsNotThrottled()
  return Auctionary.AH.Internals ~= nil and Auctionary.AH.Internals.throttling:IsReady()
end

-- Whether the server currently allows downloading the whole auction house
-- with one request (at most once every 15 minutes)
function Auctionary.AH.CanQueryAll()
  local _, canQueryAll = CanSendAuctionQuery("list")
  return canQueryAll and true or false
end

function Auctionary.AH.GetAuctionItemSubClasses(classID)
  return { GetAuctionItemSubClasses(classID) }
end
