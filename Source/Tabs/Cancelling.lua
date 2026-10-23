local Auctionator = Auctionary

-- The Cancelling tab: the player's own auctions, a scan that finds the ones
-- somebody else is selling cheaper, and buttons to cancel them.
AuctionaryCancellingTabFrameMixin = {}

local AuctionItemInfo = Auctionator.Constants.AuctionItemInfo
local EARLY_STOP_UNDERCUTS = 5  -- this many cheaper auctions (or as many as own ones are up): undercut for sure

local TIME_LEFT = {
  AUCTION_TIME_LEFT1 or "Short",
  AUCTION_TIME_LEFT2 or "Medium",
  AUCTION_TIME_LEFT3 or "Long",
  AUCTION_TIME_LEFT4 or "Very Long",
}

local STATUS_UNDERCUT = "Undercut"
local STATUS_LOWEST = "Lowest"
local STATUS_TIED = "Tied"
local STATUS_ONLY = "Only one"
local STATUS_SOLD = "Sold"

local ICON_READY = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14|t"
local ICON_NOT_READY = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14:14|t"
local ICON_WAITING = "|TInterface\\RaidFrame\\ReadyCheck-Waiting:14:14|t"

local CANCELLING_TABLE_LAYOUT = {
  {
    headerText = AUCTIONARY_L_RESULTS_NAME_COLUMN or "Name",
    headerParameters = { "name" }, cellParameters = { "name" },
    cellType = "item",
  },
  {
    headerText = STATUS or "Status",
    headerParameters = { "status" }, cellParameters = { "statusText" },
    width = 150,
  },
  {
    headerText = "Stack",
    headerParameters = { "stackSize" }, cellParameters = { "stackSize" },
    width = 50,
  },
  {
    headerText = AUCTIONARY_L_BUYOUT_PRICE or "Buyout Price",
    headerParameters = { "stackPrice" }, cellParameters = { "stackPrice" },
    cellType = "price", width = 110,
  },
  {
    headerText = AUCTIONARY_L_UNIT_PRICE or "Unit Price",
    headerParameters = { "unitPrice" }, cellParameters = { "unitPrice" },
    cellType = "price", width = 110,
  },
  {
    headerText = "Lowest Other",
    headerParameters = { "lowestOther" }, cellParameters = { "lowestOther" },
    cellType = "price", width = 110,
  },
  {
    headerText = AUCTIONARY_L_TIME_LEFT or "Time Left",
    headerParameters = { "timeLeft" }, cellParameters = { "timeLeftText" },
    width = 80,
  },
}

local function GroupKey(itemLink)
  return itemLink:match("item:(%-?%d+:%-?%d*:%-?%d*:%-?%d*:%-?%d*:%-?%d*:%-?%d*)") or itemLink
end

function AuctionaryCancellingTabFrameMixin:OnLoad()
  Auctionator.EventBus:RegisterSource(self, "AuctionaryCancellingTabFrameMixin")

  self.rows = {}
  -- [item key] = { lowestOther = unit price or false if nobody else sells it }
  self.market = {}

  self.ScanButton = CreateFrame("Button", "AuctionaryCancellingScanButton", self, "UIPanelButtonTemplate")
  self.ScanButton:SetWidth(150)
  self.ScanButton:SetHeight(22)
  self.ScanButton:SetPoint("TOPLEFT", self, "TOPLEFT", 88, -44)
  self.ScanButton:SetText("Scan for Undercuts")
  self.ScanButton:SetScript("OnClick", function()
    if self.scanning then
      self:StopScan()
    else
      self:StartScan()
    end
  end)

  -- Items hidden with a shift-click stay hidden until this button is used
  -- or the interface is loaded again
  self.hiddenItems = {}
  self.ShowHiddenButton = CreateFrame("Button", "AuctionaryCancellingShowHiddenButton", self, "UIPanelButtonTemplate")
  self.ShowHiddenButton:SetWidth(140)
  self.ShowHiddenButton:SetHeight(22)
  -- Total buyout of everything you have up, at the right end of the top bar
  self.TotalText = self:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  self.TotalText:SetPoint("RIGHT", self, "TOPRIGHT", -36, -55)
  self.TotalText:SetJustifyH("RIGHT")
  self.ShowHiddenButton:SetPoint("RIGHT", self.TotalText, "LEFT", -12, 0)
  self.ShowHiddenButton:SetScript("OnClick", function()
    self.hiddenItems = {}
    self:ApplyMarket()
  end)
  self.ShowHiddenButton:Hide()

  self.Status = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  self.Status:SetPoint("LEFT", self.ScanButton, "RIGHT", 12, 0)
  self.Status:SetPoint("RIGHT", self.ShowHiddenButton, "LEFT", -8, 0)
  self.Status:SetJustifyH("LEFT")

  self.DataProvider = Auctionator.Components.CreateDataProvider({
    layout = CANCELLING_TABLE_LAYOUT,
    uniqueKey = function(entry) return entry.key end,
    comparators = {
      name = Auctionator.Utilities.StringComparator,
      status = Auctionator.Utilities.NumberComparator,
      stackSize = Auctionator.Utilities.NumberComparator,
      unitPrice = Auctionator.Utilities.NumberComparator,
      stackPrice = Auctionator.Utilities.NumberComparator,
      lowestOther = Auctionator.Utilities.NumberComparator,
      timeLeft = Auctionator.Utilities.NumberComparator,
    },
  })
  self.ResultsListing = Auctionator.Components.CreateResultsListing(self, self.DataProvider, {
    onRowClick = function(rowData)
      -- Shift-click hides the item, a double click cancels the auction
      if IsShiftKeyDown() then
        self:HideItem(rowData)
        return
      end
      local now = GetTime()
      local isDouble = Auctionator.Config.Get(Auctionator.Config.Options.DOUBLE_CLICK_ACTIONS)
        and self.lastClickKey == rowData.key and now - (self.lastClickTime or 0) < 0.4
      self.lastClickKey, self.lastClickTime = rowData.key, now
      if isDouble then
        self.lastClickKey = nil
        if not self:CancelRow(rowData) then
          self.BottomStatus:SetText(rowData.name .. " was already sold, cancelled or expired - removed from the list.")
        end
        return
      end
      self.selectedKey = rowData.key
      self:UpdateButtons()
      self.ResultsListing:Refresh()
    end,
    isRowSelected = function(rowData)
      return rowData.key == self.selectedKey
    end,
    emptyText = "You have no auctions.",
  })
  self.ResultsListing:SetPoint("TOPLEFT", self, "TOPLEFT", 26, -82)
  self.ResultsListing:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -14, 72)

  self.CancelButton = CreateFrame("Button", "AuctionaryCancellingCancelButton", self, "UIPanelButtonTemplate")
  self.CancelButton:SetWidth(140)
  self.CancelButton:SetHeight(22)
  self.CancelButton:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -16, 46)
  self.CancelButton:SetText("Cancel Selected")
  self.CancelButton:SetScript("OnClick", function()
    local row = self:GetSelectedRow()
    if row ~= nil and not self:CancelRow(row) then
      self.BottomStatus:SetText(row.name .. " was already sold, cancelled or expired - removed from the list.")
    end
  end)

  self.CancelNextButton = CreateFrame("Button", "AuctionaryCancellingCancelNextButton", self, "UIPanelButtonTemplate")
  self.CancelNextButton:SetWidth(170)
  self.CancelNextButton:SetHeight(22)
  self.CancelNextButton:SetPoint("RIGHT", self.CancelButton, "LEFT", -6, 0)
  self.CancelNextButton:SetText("Cancel Next Undercut")
  self.CancelNextButton:SetScript("OnClick", function()
    -- Rows whose auction is gone already (sold, expired) are skipped
    local row = self:GetNextUndercut()
    while row ~= nil and not self:CancelRow(row) do
      row = self:GetNextUndercut()
    end
    if row == nil then
      self.BottomStatus:SetText("No undercut auction left.")
    end
  end)

  -- Cancels every auction marked as undercut. The first click only asks, the second
  -- one (within five seconds) does it.
  self.CancelAllButton = CreateFrame("Button", "AuctionaryCancellingCancelAllButton", self, "UIPanelButtonTemplate")
  self.CancelAllButton:SetWidth(150)
  self.CancelAllButton:SetHeight(22)
  self.CancelAllButton:SetPoint("RIGHT", self.CancelNextButton, "LEFT", -6, 0)
  self.CancelAllButton:SetText("Cancel All Undercut")
  self.CancelAllButton:SetScript("OnClick", function()
    local count = self:CountCancellable()
    if count == 0 then
      self.BottomStatus:SetText("No undercut auction to cancel.")
      return
    end
    if self.cancelAllArmed ~= nil and GetTime() - self.cancelAllArmed <= 5 then
      self.cancelAllArmed = nil
      self:CancelAll()
    else
      self.cancelAllArmed = GetTime()
      self.BottomStatus:SetText("|cffff2020Click again to cancel " .. count .. " undercut auctions.|r")
    end
  end)

  self.BottomStatus = self:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  self.BottomStatus:SetPoint("LEFT", self, "BOTTOMLEFT", 30, 57)
  self.BottomStatus:SetPoint("RIGHT", self.CancelAllButton, "LEFT", -8, 0)
  self.BottomStatus:SetJustifyH("LEFT")

  Auctionator.EventBus:Register(self, {
    Auctionator.AH.Events.OwnedAuctionsUpdate,
    Auctionator.AH.Events.ScanResultsUpdate,
    Auctionator.AH.Events.ScanAborted,
  })

  self:SetScript("OnShow", function()
    -- Every time the tab is opened the auctions are checked for undercuts,
    -- as soon as the list of own auctions is there
    self.autoScanPending = true
    Auctionator.AH.QueryOwnedAuctions()
  end)
  self:SetScript("OnHide", function()
    self.autoScanPending = false
    self:StopScan()
  end)
end

function AuctionaryCancellingTabFrameMixin:SetStatus(text)
  self.Status:SetText(text or "")
end

---- Own auctions

local function StatusFor(row, market)
  if row.isSold then
    return STATUS_SOLD, 5
  end
  if market == nil or row.stackPrice == 0 then
    return "", 4
  end
  if market.lowestOther == false then
    return STATUS_ONLY, 3
  elseif row.unitPrice > market.lowestOther then
    return STATUS_UNDERCUT, 1
  elseif row.unitPrice == market.lowestOther then
    return STATUS_TIED, 2
  else
    return STATUS_LOWEST, 3
  end
end

function AuctionaryCancellingTabFrameMixin:BuildRows(auctions)
  local rows = {}
  local seen = {}
  for _, auction in ipairs(auctions) do
    local info = auction.info
    local count = info[AuctionItemInfo.Quantity] or 1
    local buyout = info[AuctionItemInfo.Buyout] or 0
    local itemKey = GroupKey(auction.itemLink)
    -- Identical auctions get a running number so each keeps its own row
    local base = auction.itemLink .. ":" .. count .. ":" .. buyout .. ":" .. (info[AuctionItemInfo.MinBid] or 0)
    seen[base] = (seen[base] or 0) + 1

    local row = {
      key = base .. "#" .. seen[base],
      itemKey = itemKey,
      itemLink = auction.itemLink,
      name = info[AuctionItemInfo.Name],
      quality = info[AuctionItemInfo.Quality],
      iconTexture = info[AuctionItemInfo.Texture],
      stackSize = count,
      stackPrice = buyout,
      unitPrice = buyout > 0 and math.ceil(buyout / math.max(count, 1)) or 0,
      timeLeft = auction.timeLeft or 0,
      timeLeftText = TIME_LEFT[auction.timeLeft] or "",
      isSold = info[AuctionItemInfo.SaleStatus] == 1,
      hasBid = (info[AuctionItemInfo.BidAmount] or 0) > 0,
      auction = auction,
    }
    table.insert(rows, row)
  end
  return rows
end

function AuctionaryCancellingTabFrameMixin:UpdateTotal()
  local total, count = 0, 0
  for _, row in ipairs(self.rows or {}) do
    if not row.isSold and (row.stackPrice or 0) > 0 then
      total = total + row.stackPrice
      count = count + 1
    end
  end
  self.TotalText:SetText("|cffffd100Posted:|r " .. Auctionator.Compat.GetMoneyString(total, true)
    .. "  |cff909090(" .. count .. ")|r")
end

function AuctionaryCancellingTabFrameMixin:ApplyMarket()
  pcall(self.UpdateTotal, self)
  local undercut = 0
  for _, row in ipairs(self.rows) do
    local market = self.market[row.itemKey]
    row.statusText, row.status = StatusFor(row, market)
    row.lowestOther = market and market.lowestOther or nil
    if row.hasBid and not row.isSold then
      row.statusText = row.statusText .. (row.statusText ~= "" and ", " or "") .. "has bid"
    end
    row.hidden = self.hiddenItems[row.itemKey] == true
    if row.status == 1 and not row.hidden then
      undercut = undercut + 1
    end
    -- Mark in front of the text: green tick, red cross or a question mark
    local bid = (row.hasBid and not row.isSold) and ", has bid" or ""
    if row.isSold then
      row.statusText = ICON_READY .. " |cff20ff20Sold|r"
    elseif row.status == 1 then
      row.statusText = ICON_NOT_READY .. " |cffff2020You got undercut|r" .. bid
    elseif row.status == 2 then
      row.statusText = ICON_WAITING .. " |cffffd100Tied for cheapest|r" .. bid
    elseif row.status == 3 then
      row.statusText = ICON_READY .. " |cff20ff20Still cheapest|r" .. bid
    elseif row.hasBid then
      row.statusText = "has bid"
    end
  end
  self.undercutCount = undercut
  local visible, hiddenCount = {}, 0
  for _, row in ipairs(self.rows) do
    if row.hidden then
      hiddenCount = hiddenCount + 1
    else
      table.insert(visible, row)
    end
  end
  self.DataProvider:SetEntries(visible)
  if hiddenCount > 0 then
    self.ShowHiddenButton:SetText("Show Hidden (" .. hiddenCount .. ")")
    self.ShowHiddenButton:Show()
  else
    self.ShowHiddenButton:Hide()
  end
  local selected = self:GetSelectedRow()
  if selected ~= nil and selected.hidden then
    self.selectedKey = nil
  end
  self:UpdateButtons()
end

function AuctionaryCancellingTabFrameMixin:HideItem(row)
  self.hiddenItems[row.itemKey] = true
  self.BottomStatus:SetText(row.name .. " is hidden. \"Show Hidden\" at the top right brings it back.")
  self:ApplyMarket()
end

function AuctionaryCancellingTabFrameMixin:GetSelectedRow()
  for _, row in ipairs(self.rows) do
    if row.key == self.selectedKey then
      return row
    end
  end
end

function AuctionaryCancellingTabFrameMixin:GetNextUndercut()
  for _, row in ipairs(self.rows) do
    if row.status == 1 and not row.isSold and not row.hidden then
      return row
    end
  end
end

function AuctionaryCancellingTabFrameMixin:UpdateButtons()
  local selected = self:GetSelectedRow()
  if selected ~= nil and not selected.isSold then
    self.CancelButton:Enable()
  else
    self.CancelButton:Disable()
  end
  if self:CountCancellable() > 0 then
    self.CancelAllButton:Enable()
  else
    self.CancelAllButton:Disable()
  end
  if self:GetNextUndercut() ~= nil then
    self.CancelNextButton:Enable()
  else
    self.CancelNextButton:Disable()
  end
end

---- Undercut scan: one exact search per different item

function AuctionaryCancellingTabFrameMixin:StartScan()
  local queue, queued = {}, {}
  for _, row in ipairs(self.rows) do
    if not row.isSold and row.stackPrice > 0 and not queued[row.name] then
      queued[row.name] = true
      table.insert(queue, row.name)
    end
  end
  if #queue == 0 then
    self:SetStatus("Nothing to check.")
    return
  end

  self.scanning = true
  self.scanQueue = queue
  self.scanPosition = 0
  self.market = {}
  self.playerName = UnitName("player")
  self.ownAuctionKeys = {}
  -- Per item: how many own auctions are up and the cheapest of them. Once
  -- enough cheaper auctions of others are found, the rest of the pages is
  -- not needed any more.
  self.ownByName = {}
  for _, row in ipairs(self.rows) do
    self.ownAuctionKeys[row.itemLink .. ":" .. row.stackSize .. ":" .. row.stackPrice] = true
    if not row.isSold and row.stackPrice > 0 then
      local own = self.ownByName[row.name] or { count = 0 }
      own.count = own.count + 1
      if own.lowest == nil or row.unitPrice < own.lowest then
        own.lowest = row.unitPrice
      end
      self.ownByName[row.name] = own
    end
  end
  self.ScanButton:SetText(AUCTIONARY_L_CANCEL or CANCEL)
  self:NextItem()
end

function AuctionaryCancellingTabFrameMixin:NextItem()
  self.scanPosition = self.scanPosition + 1
  local name = self.scanQueue[self.scanPosition]
  if name == nil then
    self:FinishScan(true)
    return
  end
  self.scanAuctions = {}
  self.scanName = name
  self:SetStatus("Checking " .. self.scanPosition .. " of " .. #self.scanQueue .. ": " .. name)
  Auctionator.AH.QueryAuctionItems({ searchString = name, isExact = true })
end

function AuctionaryCancellingTabFrameMixin:StopScan()
  if self.scanning then
    self.scanning = false
    Auctionator.AH.AbortQuery()
    self:FinishScan(false)
  end
end

function AuctionaryCancellingTabFrameMixin:FinishScan(completed)
  self.scanning = false
  self.ScanButton:SetText("Scan for Undercuts")
  self:ApplyMarket()
  if completed then
    self:SetStatus(self.undercutCount .. " of your auctions are undercut.")
  else
    self:SetStatus("Scan stopped. " .. self.undercutCount .. " undercut so far.")
  end
end

-- Enough cheaper auctions of others seen already? (5, or fewer when fewer
-- own auctions of the item are up)
function AuctionaryCancellingTabFrameMixin:EnoughUndercuts()
  local own = self.ownByName and self.ownByName[self.scanName]
  if own == nil or own.lowest == nil then
    return false
  end
  local needed = math.min(EARLY_STOP_UNDERCUTS, own.count)
  local found = 0
  for _, auction in ipairs(self.scanAuctions) do
    local info = auction.info
    local count = info[AuctionItemInfo.Quantity] or 0
    local buyout = info[AuctionItemInfo.Buyout] or 0
    if count > 0 and buyout > 0 and info[AuctionItemInfo.Owner] ~= self.playerName
       and not self.ownAuctionKeys[auction.itemLink .. ":" .. count .. ":" .. buyout]
       and math.ceil(buyout / count) < own.lowest then
      found = found + 1
      if found >= needed then
        return true
      end
    end
  end
  return false
end

-- Lowest price per item among the auctions that are not the player's
-- (partial: not all pages were read, so nothing goes into the price database)
function AuctionaryCancellingTabFrameMixin:RecordMarket(auctions, partial)
  local lowestAny, totals = {}, {}
  for _, auction in ipairs(auctions) do
    local info = auction.info
    local count = info[AuctionItemInfo.Quantity] or 0
    local buyout = info[AuctionItemInfo.Buyout] or 0
    if count > 0 and buyout > 0 then
      local itemKey = GroupKey(auction.itemLink)
      local unitPrice = math.ceil(buyout / count)
      local market = self.market[itemKey]
      if market == nil then
        market = { lowestOther = false }
        self.market[itemKey] = market
      end
      -- Own auctions are told apart by the seller name and, in case the
      -- client has not got the name yet, by being identical to an own auction
      local isOwn = info[AuctionItemInfo.Owner] == self.playerName
        or self.ownAuctionKeys[auction.itemLink .. ":" .. count .. ":" .. buyout]
      if not isOwn then
        if market.lowestOther == false or unitPrice < market.lowestOther then
          market.lowestOther = unitPrice
        end
      end

      if not isOwn and (lowestAny[itemKey] == nil or unitPrice < lowestAny[itemKey].price) then
        lowestAny[itemKey] = { price = unitPrice, itemLink = auction.itemLink }
      end
      totals[itemKey] = (totals[itemKey] or 0) + count
    end
  end

  -- All auctions of these items were seen: remember their lowest price
  if partial then
    return
  end
  for itemKey, lowest in pairs(lowestAny) do
    Auctionator.Utilities.DBKeyFromLink(lowest.itemLink, function(dbKeys)
      if dbKeys[1] ~= nil then
        Auctionator.Database:SetPrice(dbKeys[1], lowest.price, totals[itemKey])
      end
    end)
  end
end

function AuctionaryCancellingTabFrameMixin:ReceiveEvent(eventName, results, gotAllResults)
  if eventName == Auctionator.AH.Events.OwnedAuctionsUpdate then
    if self:IsVisible() then
      self.rows = self:BuildRows(results)
      if self:GetSelectedRow() == nil then
        self.selectedKey = nil
      end
      self:ApplyMarket()
      if not self.scanning and self.cancelMessage == nil then
        self:SetStatus(#self.rows .. " auctions. Shift-click hides an item."
          .. (Auctionator.Config.Get(Auctionator.Config.Options.DOUBLE_CLICK_ACTIONS) and " Double-click cancels one." or ""))
      end
      self.cancelMessage = nil

      if self.autoScanPending and #self.rows > 0 and not self.scanning then
        local fullScan = Auctionator.FullScan.Frame
        local busy = Auctionator.AH.IsQueryActive() or (fullScan ~= nil and fullScan:IsInProgress())
        if busy then
          self:SetStatus("Another scan is running. Press \"Scan for Undercuts\" when it is done.")
        else
          self:StartScan()
        end
        self.autoScanPending = false
      end
    end

  elseif eventName == Auctionator.AH.Events.ScanResultsUpdate then
    if self.scanning then
      for _, auction in ipairs(results) do
        table.insert(self.scanAuctions, auction)
      end
      if gotAllResults then
        self:RecordMarket(self.scanAuctions)
        self:ApplyMarket()
        self:NextItem()
      elseif self:EnoughUndercuts() then
        -- Undercut for sure: stop reading this item's pages, on to the next
        self:RecordMarket(self.scanAuctions, true)
        self:ApplyMarket()
        self.ignoreAbort = true
        Auctionator.AH.AbortQuery()
        self.ignoreAbort = false
        self:NextItem()
      end
    end

  elseif eventName == Auctionator.AH.Events.ScanAborted then
    if self.scanning and not self.ignoreAbort then
      self.scanning = false
      self:FinishScan(false)
    end
  end
end

---- Cancelling (runs inside the click on a button)

-- Position of the row's auction in the client's list of own auctions. The
-- exact match is tried first; bids change an auction's details, so after
-- that the same item, stack size and buyout is enough.
local function FindOwnIndex(row)
  local index = Auctionator.AH.FindAuctionIndex("owner", row.auction)
  if index ~= nil then
    return index
  end
  for other = 1, (GetNumAuctionItems("owner")) do
    if GetAuctionItemLink("owner", other) == row.itemLink then
      local info = { GetAuctionItemInfo("owner", other) }
      if info[AuctionItemInfo.Quantity] == row.stackSize
         and (info[AuctionItemInfo.Buyout] or 0) == row.stackPrice
         and info[AuctionItemInfo.SaleStatus] ~= 1 then
        return other
      end
    end
  end
end

function AuctionaryCancellingTabFrameMixin:RemoveRow(row)
  for index, other in ipairs(self.rows) do
    if other == row then
      table.remove(self.rows, index)
      break
    end
  end
  if self.selectedKey == row.key then
    self.selectedKey = nil
  end
end

-- Returns true when the cancel request was sent
function AuctionaryCancellingTabFrameMixin:CancelRow(row)
  if row.isSold then
    return false
  end
  local index = FindOwnIndex(row)
  -- Either way the row is done with: cancelled now, or already gone
  self:RemoveRow(row)
  if index ~= nil then
    CancelAuction(index)
    self.cancelMessage = true
    self.BottomStatus:SetText("Cancelled " .. row.stackSize .. " x " .. row.name
      .. (row.hasBid and "  (it had a bid: the auction house keeps a fee)" or ""))
  end
  self:ApplyMarket()
  -- The server sends the new list; ask again in case it does not
  Auctionator.Compat.After(1.5, function()
    if self:IsVisible() then
      Auctionator.AH.QueryOwnedAuctions()
    end
  end)
  return index ~= nil
end

local function IsUndercutRow(row)
  return row.status == 1 and not row.isSold and not row.hidden
end

function AuctionaryCancellingTabFrameMixin:CountCancellable()
  local count = 0
  for _, row in ipairs(self.rows or {}) do
    if IsUndercutRow(row) then
      count = count + 1
    end
  end
  return count
end

-- Cancels every auction marked as undercut. Runs inside one click. The
-- client's list only changes once the server answers, so the positions stay
-- valid; going from the end is the safe order.
function AuctionaryCancellingTabFrameMixin:CancelAll()
  -- How many auctions of each kind (item, stack size, buyout) are wanted
  local wanted = {}
  for index = #self.rows, 1, -1 do
    local row = self.rows[index]
    if IsUndercutRow(row) then
      local token = row.itemLink .. "|" .. row.stackSize .. "|" .. row.stackPrice
      wanted[token] = (wanted[token] or 0) + 1
      table.remove(self.rows, index)
    end
  end
  local cancelled = 0
  for index = (GetNumAuctionItems("owner")), 1, -1 do
    local link = GetAuctionItemLink("owner", index)
    local info = { GetAuctionItemInfo("owner", index) }
    if link ~= nil and info[AuctionItemInfo.SaleStatus] ~= 1 then
      local token = link .. "|" .. (info[AuctionItemInfo.Quantity] or 0) .. "|" .. (info[AuctionItemInfo.Buyout] or 0)
      if (wanted[token] or 0) > 0 then
        wanted[token] = wanted[token] - 1
        CancelAuction(index)
        cancelled = cancelled + 1
      end
    end
  end
  self.selectedKey = nil
  self.cancelMessage = true
  self.BottomStatus:SetText("Cancelled " .. cancelled .. " undercut auctions.")
  self:ApplyMarket()
  Auctionator.Compat.After(1.5, function()
    if self:IsVisible() then
      Auctionator.AH.QueryOwnedAuctions()
    end
  end)
end

Auctionator.Tabs.RegisterContent("Cancelling", function(panel)
  local frame = CreateFrame("Frame", "AuctionaryCancellingTabFrame", panel)
  frame:SetAllPoints(panel)
  Auctionator.Compat.Mixin(frame, AuctionaryCancellingTabFrameMixin)
  frame:OnLoad()
  panel.Content = frame
end)
