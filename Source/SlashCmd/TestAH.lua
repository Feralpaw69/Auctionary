local Auctionator = Auctionary

-- /aury test ah | search <name> | scan [pages|getall] | stop | owned | price <item link>
-- Chat-only checks of the auction house layer, used until the tabs exist.
local AuctionItemInfo = Auctionator.Constants.AuctionItemInfo

local function Say(text)
  Auctionator.Utilities.Message(text)
end

local function Money(amount)
  return Auctionator.Compat.GetMoneyString(math.floor(amount + 0.5), true)
end

local TIME_LEFT = { "< 30 min", "30 min - 2 h", "2 - 12 h", "12 - 48 h" }

local listener = { search = nil, lastProgress = 0 }

function listener:ReceiveEvent(eventName, ...)
  if eventName == Auctionator.AH.Events.ScanResultsUpdate then
    local results, gotAllResults, progress = ...
    local search = self.search
    if search == nil then
      return
    end
    for _, auction in ipairs(results) do
      table.insert(search.results, auction)
    end
    Say("Search: page " .. progress.page .. " of " .. progress.totalPages
      .. " (" .. progress.total .. " auctions on the server)")
    if gotAllResults then
      self.search = nil
      self:ReportSearch(search)
      local stats = progress.stats
      Say(("Time per page: %.2f s waiting for the server to allow the request, %.2f s for its answer, %.2f s for seller names (%d pages)."):format(
        stats.throttle / stats.pages, stats.answer / stats.pages, stats.details / stats.pages, stats.pages
      ))
    end

  elseif eventName == Auctionator.AH.Events.ScanAborted then
    if self.search ~= nil then
      self.search = nil
      Say("Search aborted (auction house closed, another search started or no answer).")
    end

  elseif eventName == Auctionator.AH.Events.OwnedAuctionsUpdate then
    if not self.waitingForOwned then
      return
    end
    self.waitingForOwned = false
    local auctions = ...
    Say("Own auctions: " .. #auctions)
    for i = 1, math.min(#auctions, 8) do
      local info = auctions[i].info
      Say("  " .. auctions[i].itemLink .. " x" .. info[AuctionItemInfo.Quantity]
        .. "  buyout " .. Money(info[AuctionItemInfo.Buyout])
        .. "  " .. (TIME_LEFT[auctions[i].timeLeft] or "?")
        .. (info[AuctionItemInfo.SaleStatus] == 1 and "  (sold)" or ""))
    end

  elseif eventName == Auctionator.FullScan.Events.ScanStart then
    self.lastProgress = 0

  elseif eventName == Auctionator.FullScan.Events.ScanProgress then
    local fraction, progress = ...
    if fraction - self.lastProgress >= 0.1 and fraction < 1 then
      self.lastProgress = fraction
      Say("Scan: " .. math.floor(fraction * 100) .. " %"
        .. (progress and (" (page " .. progress.page .. " of " .. progress.totalPages .. ")") or ""))
    end

  elseif eventName == Auctionator.FullScan.Events.ScanComplete then
    local summary = ...
    Say(("Scan finished (%s): %d auctions read, %d different items with a price, %d skipped, %.0f seconds. The database now has %d entries."):format(
      summary.mode == "getall" and "all at once" or "page by page",
      summary.auctions, summary.items, summary.skipped, summary.seconds,
      Auctionator.Database:GetItemCount()
    ))

  elseif eventName == Auctionator.FullScan.Events.ScanFailed then
    Say("Scan not completed.")
  end
end

function listener:ReportSearch(search)
  local results = search.results
  local withBuyout = {}
  local units = 0
  for _, auction in ipairs(results) do
    local count = auction.info[AuctionItemInfo.Quantity]
    units = units + count
    if auction.info[AuctionItemInfo.Buyout] > 0 and count > 0 then
      auction.unitPrice = auction.info[AuctionItemInfo.Buyout] / count
      table.insert(withBuyout, auction)
    end
  end
  table.sort(withBuyout, function(a, b)
    return a.unitPrice < b.unitPrice
  end)

  Say(("Search finished: %d auctions, %d items, %d with a buyout, %.1f seconds."):format(
    #results, units, #withBuyout, GetTime() - search.startTime
  ))
  for i = 1, math.min(#withBuyout, 5) do
    local auction = withBuyout[i]
    Say("  " .. i .. ". " .. auction.itemLink .. " x" .. auction.info[AuctionItemInfo.Quantity]
      .. "  " .. Money(auction.unitPrice) .. " each"
      .. "  by " .. tostring(auction.info[AuctionItemInfo.Owner] or "?")
      .. "  " .. (TIME_LEFT[auction.timeLeft] or "?")
      .. "  (page " .. (auction.page + 1) .. ", position " .. auction.index .. ")")
  end
end

local registered = false
local function Prepare()
  if not Auctionator.State.AHOpen then
    Say("Please open the auction house first.")
    return false
  end
  if not registered then
    registered = true
    Auctionator.EventBus:Register(listener, {
      Auctionator.AH.Events.ScanResultsUpdate,
      Auctionator.AH.Events.ScanAborted,
      Auctionator.AH.Events.OwnedAuctionsUpdate,
      Auctionator.FullScan.Events.ScanStart,
      Auctionator.FullScan.Events.ScanProgress,
      Auctionator.FullScan.Events.ScanComplete,
      Auctionator.FullScan.Events.ScanFailed,
    })
  end
  return true
end

local function Status()
  local canQuery, canQueryAll = CanSendAuctionQuery("list")
  Say("Auction house open: " .. tostring(Auctionator.State.AHOpen == true)
    .. "; can query: " .. tostring(canQuery and true or false)
    .. "; can scan everything at once: " .. tostring(canQueryAll and true or false))
  if Auctionator.State.AHOpen then
    local numBatch, total = GetNumAuctionItems("list")
    Say("Current list: " .. tostring(numBatch) .. " shown, " .. tostring(total) .. " in total"
      .. "; search running: " .. tostring(Auctionator.AH.IsQueryActive())
      .. "; scan running: " .. tostring(Auctionator.FullScan.Frame:IsInProgress()))
  end
  Say("Price database: " .. Auctionator.Database:GetItemCount() .. " entries")
end

local function Search(text)
  if not Prepare() then
    return
  end
  if text == "" then
    Say("Example: /aury test search Saronite Bar   (in quotes = exactly this name only)")
    return
  end
  if Auctionator.FullScan.Frame:IsInProgress() then
    Say("A scan is running. Stop it with /aury test stop")
    return
  end

  local exact = text:match('^"(.*)"$')
  -- An item link is searched by its name
  local linkName = text:match("|h%[(.-)%]|h")
  local searchString = exact or linkName or text

  listener.search = { results = {}, startTime = GetTime() }
  Say("Searching for \"" .. searchString .. "\"" .. ((exact or linkName) and " (exact)" or "") .. " ...")
  Auctionator.AH.QueryAuctionItems({
    searchString = searchString,
    isExact = (exact or linkName) and true or false,
    needOwners = true,
  })
end

local function Scan(mode)
  if not Prepare() then
    return
  end
  if mode ~= "" and mode ~= "pages" and mode ~= "getall" then
    Say("Possible: /aury test scan, /aury test scan pages, /aury test scan getall")
    return
  end
  listener.search = nil
  Auctionator.FullScan.Frame:InitiateScan(mode ~= "" and mode or nil)
end

local function Stop()
  if not Prepare() then
    return
  end
  Auctionator.FullScan.Frame:Abort()
  Auctionator.AH.AbortQuery()
  Say("Stopped.")
end

local function Owned()
  if not Prepare() then
    return
  end
  listener.waitingForOwned = true
  Auctionator.AH.QueryOwnedAuctions()
end

local function Price(text)
  local itemLink = text:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)")
  if itemLink == nil then
    Say("Example: type /aury test price and shift-click an item.")
    return
  end
  Auctionator.Utilities.DBKeyFromLink(itemLink, function(dbKeys)
    local found = false
    for _, dbKey in ipairs(dbKeys) do
      local price = Auctionator.Database:GetPrice(dbKey)
      if price ~= nil then
        found = true
        local history = Auctionator.Database:GetPriceHistory(dbKey)
        Say(itemLink .. " [" .. dbKey .. "]: " .. Money(price)
          .. ", last seen " .. tostring(Auctionator.Database:GetPriceAge(dbKey)) .. " days ago"
          .. ", " .. #history .. " days of history"
          .. (history[1] and history[1].available and (", last " .. history[1].available .. " available") or ""))
      end
    end
    if not found then
      Say(itemLink .. " [" .. table.concat(dbKeys, ", ") .. "]: no price stored.")
    end
  end)
end

local COMMANDS = {
  ah = Status,
  search = Search,
  scan = Scan,
  stop = Stop,
  owned = Owned,
  price = Price,
}

-- input is everything after "/aury ". Returns true when it was one of the
-- auction house test commands.
function Auctionator.SlashCmd.TestAH(input)
  local sub, rest = input:match("^%s*%S+%s+(%a+)%s*(.-)%s*$")
  local handler = sub and COMMANDS[string.lower(sub)]
  if handler == nil then
    return false
  end
  handler(rest or "")
  return true
end
