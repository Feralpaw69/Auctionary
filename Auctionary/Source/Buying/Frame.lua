-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

-- The list of single auctions of one item with a button to buy them, shown in
-- the Shopping tab after picking a search result. A 3.3.5 server only sells
-- whole auctions (stacks), so that is what gets bought.
local BuyFrame = {}

local AuctionItemInfo = Auctionary.Constants.AuctionItemInfo
local PAGE_SIZE = Auctionary.Constants.PageSize
local BUY_TIMEOUT = 6

local TIME_LEFT = {
  AUCTION_TIME_LEFT1 or "Short",
  AUCTION_TIME_LEFT2 or "Medium",
  AUCTION_TIME_LEFT3 or "Long",
  AUCTION_TIME_LEFT4 or "Very Long",
}

local UNKNOWN_SELLER_TEXT = "Cheapsell"

local BUY_TABLE_LAYOUT = {
  {
    title = AUCTIONARY2_L_COL_BUYOUT or "Buyout Price",
    sort = "stackPrice", field = "stackPrice",
    kind = "price", width = 130,
  },
  {
    title = AUCTIONARY2_L_COL_UNIT_PRICE or "Unit Price",
    sort = "unitPrice", field = "unitPrice",
    buyDot = true, kind = "price", width = 130,
  },
  {
    title = AUCTIONARY2_L_COL_AVAILABLE or "Available",
    sort = "stackSize", field = "availableText",
    width = 90,
  },
  {
    title = AUCTIONARY2_L_COL_SELLER or "Seller(s)",
    sort = "owner", field = "owner",
  },
  {
    title = AUCTIONARY2_L_COL_TIME_LEFT or "Time Left",
    sort = "timeLeft", field = "timeLeftText",
    width = 90,
  },
}

local BUY_EVENTS = {
  Auctionary.AH.Events.CurrentPage,
  Auctionary.AH.Events.ScanAborted,
}

function BuyFrame:OnLoad()
  Auctionary.EventBus:RegisterSource(self, "BuyFrame")

  self.rowSet = Auctionary.Components.CreateRowSet({
    columns = BUY_TABLE_LAYOUT,
    rowKey = function(entry) return entry.key end,
    sorters = {
      unitPrice = Auctionary.Utilities.NumberComparator,
      stackPrice = Auctionary.Utilities.NumberComparator,
      stackSize = Auctionary.Utilities.NumberComparator,
      timeLeft = Auctionary.Utilities.NumberComparator,
      owner = Auctionary.Utilities.StringComparator,
    },
  })

  self.Icon = self:CreateTexture(nil, "ARTWORK")
  self.Icon:SetWidth(28)
  self.Icon:SetHeight(28)
  self.Icon:SetPoint("TOPLEFT", self, "TOPLEFT", 4, -2)

  self.Name = self:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  self.Name:SetPoint("LEFT", self.Icon, "RIGHT", 8, 0)

  -- The item's tooltip when the mouse is over the icon or the name
  self.IconHover = CreateFrame("Button", nil, self)
  self.IconHover:SetPoint("TOPLEFT", self.Icon, "TOPLEFT", 0, 0)
  self.IconHover:SetPoint("BOTTOMLEFT", self.Icon, "BOTTOMLEFT", 0, 0)
  self.IconHover:SetPoint("RIGHT", self.Name, "RIGHT", 0, 0)
  self.IconHover:SetScript("OnEnter", function(hover)
    if self.result ~= nil and self.result.itemLink ~= nil then
      GameTooltip:SetOwner(hover, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink(self.result.itemLink)
      GameTooltip:Show()
    end
  end)
  self.IconHover:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  self.IconHover:SetScript("OnClick", function()
    if self.result ~= nil and self.result.itemLink ~= nil then
      if IsModifiedClick("CHATLINK") then
        ChatEdit_InsertLink(self.result.itemLink)
      elseif IsModifiedClick("DRESSUP") then
        DressUpItemLink(self.result.itemLink)
      end
    end
  end)

  self.BackButton = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
  self.BackButton:SetWidth(90)
  self.BackButton:SetHeight(22)
  self.BackButton:SetPoint("TOPRIGHT", self, "TOPRIGHT", -2, -4)
  self.BackButton:SetText(BACK or "Back")
  self.BackButton:SetScript("OnClick", function()
    self:Close()
  end)

  self.BuyButton = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
  self.BuyButton:SetWidth(120)
  self.BuyButton:SetHeight(22)
  self.BuyButton:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -2, 2)
  self.BuyButton:SetText(AUCTIONARY2_L_BUY_STACK or "Buy Stack")
  self.BuyButton:SetScript("OnClick", function()
    self:BuySelected()
  end)

  -- How many items are wanted in total; the cheapest stacks are then offered
  -- one after the other (every purchase still needs its own click)
  self.QuantityBox = CreateFrame("EditBox", "Auctionary2BuyQuantityBox", self, "InputBoxTemplate")
  self.QuantityBox:SetWidth(46)
  self.QuantityBox:SetHeight(20)
  self.QuantityBox:SetPoint("RIGHT", self.BuyButton, "LEFT", -8, 0)
  self.QuantityBox:SetAutoFocus(false)
  self.QuantityBox:SetNumeric(true)
  self.QuantityBox:SetMaxLetters(5)
  self.QuantityBox:SetScript("OnTextChanged", function(box, userInput)
    if userInput then
      self:SetWanted(tonumber(box:GetText()))
    end
  end)
  self.QuantityBox:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
  self.QuantityBox:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
  self.QuantityBox:SetScript("OnEnter", function(box)
    GameTooltip:SetOwner(box, "ANCHOR_TOP")
    GameTooltip:SetText("Quantity wanted")
    GameTooltip:AddLine("Enter how many you need. The cheapest stacks are picked for you one after the other; click Buy Stack for each of them.", 1, 1, 1, true)
    GameTooltip:AddLine("Stacks are sold whole, so you may end up with a few more.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  self.QuantityBox:SetScript("OnLeave", function() GameTooltip:Hide() end)
  self.quantityLabel = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  self.quantityLabel:SetPoint("RIGHT", self.QuantityBox, "LEFT", -8, 0)
  self.quantityLabel:SetText("Quantity")

  self.HistoryButton = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
  self.HistoryButton:SetWidth(110)
  self.HistoryButton:SetHeight(22)
  self.HistoryButton:SetPoint("RIGHT", self.BackButton, "LEFT", -4, 0)
  self.HistoryButton:SetText("Price History")
  self.HistoryButton:SetScript("OnClick", function()
    if self.result ~= nil then
      Auctionary.Components.ShowHistory(self.result.itemLink)
    end
  end)

  self.Status = self:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  self.Status:SetPoint("LEFT", self, "BOTTOMLEFT", 6, 13)
  self.Status:SetPoint("RIGHT", self.quantityLabel, "LEFT", -8, 0)
  self.Status:SetJustifyH("LEFT")

  self.rowTable = Auctionary.Components.CreateTable(self, self.rowSet, {
    onRowClick = function(rowData)
      if not self.bidding then
        self.selectedKey = rowData.key
        self:UpdateSelection()
      end
    end,
    isRowSelected = function(rowData)
      return rowData.key == self.selectedKey
    end,
  })
  self.rowTable:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -36)
  self.rowTable:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 30)

  self:SetScript("OnEvent", self.OnEvent)
  self:SetScript("OnUpdate", self.OnUpdate)

  -- Up/down: the previous/next auction; Enter: buy it (both switchable)
  local function Step(delta)
    if self.bidding then
      return
    end
    local entry = self.rowTable:Step(function(rowData)
      return rowData.key == self.selectedKey
    end, delta)
    if entry ~= nil and entry.key ~= self.selectedKey then
      self.selectedKey = entry.key
      self:UpdateSelection()
    end
  end
  local Options = Auctionary.Config.Options
  self.keys = Auctionary.Keys.Create({
    UP = function() Step(-1) end,
    DOWN = function() Step(1) end,
    ENTER = function()
      local enabled = self.BuyButton:IsEnabled()
      if enabled == 1 or enabled == true then
        self:BuySelected()
      end
    end,
  }, function(key)
    if not self:IsVisible() then
      return false
    end
    if key == "ENTER" then
      return Auctionary.Config.Get(Options.SHOPPING_BUY_ON_ENTER)
    end
    return Auctionary.Config.Get(Options.KEYS_SHOPPING)
  end)

  self:SetScript("OnHide", function()
    self:StopBuying()
  end)
end

-- result: one entry of the Shopping search results
function BuyFrame:Open(result)
  self.result = result
  self.Icon:SetTexture(result.iconTexture)
  local _, _, _, hex = GetItemQualityColor(result.quality or 1)
  if hex ~= nil and string.sub(hex, 1, 2) ~= "|c" then
    hex = "|c" .. hex
  end
  self.Name:SetText((hex or "") .. result.name .. "|r")

  self.wanted = nil
  self.confirmed = nil
  self.QuantityBox:SetText("")
  self.average = nil
  if result.itemLink ~= nil and Auctionary.Database ~= nil then
    Auctionary.Utilities.DBKeyFromLink(result.itemLink, function(dbKeys)
      if dbKeys[1] ~= nil then
        self.average = Auctionary.Database:GetScanAverage(
          dbKeys[1], Auctionary.Config.Get(Auctionary.Config.Options.AUCTION_MEAN_DAYS_LIMIT)
        )
      end
    end)
  end

  self.rows = self:BuildRows(result.auctions)
  self.selectedKey = self.rows[1] and self.rows[1].key
  self.rowSet:Replace(self.rows)
  self:SetStatus("")
  self:Show()
  self:UpdateSelection()
end

function BuyFrame:Close()
  self:StopBuying()
  self:Hide()
  if self.onClose then
    self.onClose()
  end
end

-- Identical stacks of one seller become one row
function BuyFrame:BuildRows(auctions)
  local playerName = UnitName("player")
  local isOwnAuction = Auctionary.AH.GetOwnAuctionChecker()
  local byKey, rows = {}, {}

  for _, auction in ipairs(auctions) do
    local info = auction.info
    local count = info[AuctionItemInfo.Quantity] or 0
    local buyout = info[AuctionItemInfo.Buyout] or 0
    if buyout > 0 and count > 0 then
      local owner = info[AuctionItemInfo.Owner]
      if owner == nil and isOwnAuction(info, auction.itemLink) then
        owner = playerName
      end
      owner = owner or UNKNOWN_SELLER_TEXT
      local key = buyout .. ":" .. count .. ":" .. owner
      local row = byKey[key]
      if row == nil then
        row = {
          key = key,
          unitPrice = math.ceil(buyout / count),
          stackPrice = buyout,
          stackSize = count,
          owner = owner,
          isOwned = owner == playerName,
          timeLeft = auction.timeLeft or 0,
          timeLeftText = TIME_LEFT[auction.timeLeft] or "",
          itemLink = auction.itemLink,
          auctions = {},
        }
        byKey[key] = row
        table.insert(rows, row)
      end
      table.insert(row.auctions, auction)
    end
  end

  for _, row in ipairs(rows) do
    row.availableText = #row.auctions .. " x " .. row.stackSize
  end
  table.sort(rows, function(a, b)
    if a.unitPrice ~= b.unitPrice then
      return a.unitPrice < b.unitPrice
    end
    return a.stackSize < b.stackSize
  end)
  return rows
end

-- The cheapest row (per item) that is not the player's own
function BuyFrame:GetCheapestRow()
  local best
  for _, row in ipairs(self.rows or {}) do
    if not row.isOwned and #row.auctions > 0 and (best == nil or row.unitPrice < best.unitPrice) then
      best = row
    end
  end
  return best
end

-- quantity: how many items are wanted in total (nil or 0 switches it off)
function BuyFrame:SetWanted(quantity)
  if quantity == nil or quantity <= 0 then
    self.wanted = nil
    return
  end
  self.wanted = { left = quantity, bought = 0, spent = 0 }
  if not self.bidding then
    local row = self:GetCheapestRow()
    if row ~= nil then
      self.selectedKey = row.key
      self:UpdateSelection()
    end
  end
end

function BuyFrame:GetSelectedRow()
  for _, row in ipairs(self.rows or {}) do
    if row.key == self.selectedKey then
      return row
    end
  end
end

function BuyFrame:SetStatus(text)
  self.Status:SetText(text or "")
end

function BuyFrame:UpdateSelection()
  self:SetStatus("")
  self:Prepare()
  self.rowTable:Refresh()
end

---- Buying one auction
-- The client can only buy from the page it currently shows, and only as the
-- direct result of a mouse click. So the page with the wanted auction is
-- loaded first ("locating"); once it is there the Buy button gets enabled and
-- the click itself places the bid. Auctions move between pages when others
-- are bought, so the other pages are looked through as well.

local NO_ANSWER_TEXT = "No answer from the auction house."
local GONE_TEXT = "This auction no longer exists."

function BuyFrame:CancelLocating()
  local locating = self.locating
  if locating ~= nil then
    self.locating = nil
    if locating.registered then
      Auctionary.EventBus:Unregister(self, BUY_EVENTS)
    end
    Auctionary.AH.AbortQuery()
  end
end

-- Gets the cheapest auction of the selected row onto the current page
function BuyFrame:Prepare()
  self:CancelLocating()
  self.ready = nil
  self.BuyButton:Disable()

  local row = self:GetSelectedRow()
  if row == nil or #row.auctions == 0 or self.bidding then
    return
  end
  if row.isOwned then
    self:SetStatus(AUCTIONARY2_L_COL_OWN or "Owned?")
    return
  end
  if GetMoney() < row.stackPrice then
    self:SetStatus(ERR_NOT_ENOUGH_MONEY or "Not enough money")
    return
  end

  local auction = row.auctions[#row.auctions]

  -- Still on the page the client shows?
  if Auctionary.AH.FindAuctionIndex("list", auction) ~= nil and not Auctionary.AH.IsQueryActive() then
    self:SetReady(row, auction)
    return
  end

  self:SetStatus((SEARCHING or "Searching") .. " ...")
  self.locating = {
    row = row,
    auction = auction,
    query = {
      searchString = auction.info[AuctionItemInfo.Name],
      isExact = true,
    },
    pagesToTry = { auction.page },
    tried = {},
    nextSequentialPage = 0,
  }
  self:TryNextPage()
  if self.locating ~= nil then
    Auctionary.EventBus:Register(self, BUY_EVENTS)
    self.locating.registered = true
  end
end

function BuyFrame:TryNextPage()
  local locating = self.locating
  local page = table.remove(locating.pagesToTry, 1)
  while page ~= nil and locating.tried[page] do
    page = table.remove(locating.pagesToTry, 1)
  end
  if page == nil then
    self:CancelLocating()
    self:RemoveAuction(locating.row, locating.auction)
    self:SetStatus(Auctionary.Compat.Colors.RED_FONT_COLOR:WrapTextInColorCode(GONE_TEXT))
    return
  end
  locating.tried[page] = true
  Auctionary.AH.QueryAndFocusPage(locating.query, page)
end

-- What the wanted quantity costs when the cheapest stacks are bought one
-- after the other (whole stacks, so it can be a little more than wanted).
-- Returns the cost and how many items that covers.
function BuyFrame:EstimateWantedCost(quantity)
  local rows = {}
  for _, row in ipairs(self.rows or {}) do
    if not row.isOwned and #row.auctions > 0 then
      table.insert(rows, row)
    end
  end
  table.sort(rows, function(a, b)
    if a.unitPrice ~= b.unitPrice then
      return a.unitPrice < b.unitPrice
    end
    return a.stackSize < b.stackSize
  end)
  local cost, covered = 0, 0
  for _, row in ipairs(rows) do
    for _ = 1, #row.auctions do
      if covered >= quantity then
        return cost, covered
      end
      cost = cost + row.stackPrice
      covered = covered + row.stackSize
    end
  end
  return cost, covered
end

function BuyFrame:SetReady(row, auction)
  self.ready = { row = row, auction = auction }
  self.BuyButton:Enable()
  local text = row.stackSize .. " x " .. self.result.name .. ": "
    .. Auctionary.Compat.GetMoneyString(row.stackPrice, true)
  if self.wanted ~= nil then
    text = text .. "   (" .. self.wanted.left .. " more wanted"
    local cost, covered = self:EstimateWantedCost(self.wanted.left)
    if cost > 0 then
      text = text .. ", together " .. Auctionary.Compat.GetMoneyString(cost, true)
      if covered < self.wanted.left then
        text = text .. " for the " .. covered .. " available"
      end
    end
    text = text .. ")"
  end
  self:SetStatus(text)
end

function BuyFrame:ReceiveEvent(eventName, results, total)
  local locating = self.locating
  if locating == nil then
    return
  end

  if eventName == Auctionary.AH.Events.CurrentPage then
    if Auctionary.AH.FindAuctionIndex("list", locating.auction) ~= nil then
      self.locating = nil
      Auctionary.EventBus:Unregister(self, BUY_EVENTS)
      self:SetReady(locating.row, locating.auction)
    else
      -- Not on this page (any more): look through the other pages
      local lastPage = math.max(math.ceil((total or 0) / PAGE_SIZE) - 1, 0)
      while locating.nextSequentialPage <= lastPage do
        table.insert(locating.pagesToTry, locating.nextSequentialPage)
        locating.nextSequentialPage = locating.nextSequentialPage + 1
      end
      self:TryNextPage()
    end
  elseif eventName == Auctionary.AH.Events.ScanAborted then
    -- Auction house closed or another search took over
    self.locating = nil
    Auctionary.EventBus:Unregister(self, BUY_EVENTS)
    self:SetStatus("")
  end
end

-- Runs inside the click on the Buy button
function BuyFrame:BuySelected()
  local ready = self.ready
  if ready == nil or self.bidding then
    return
  end
  local auction = ready.auction
  local buyout = auction.info[AuctionItemInfo.Buyout]

  if GetMoney() < buyout then
    self:Prepare()
    return
  end

  -- The page may have changed since it was loaded
  local index = Auctionary.AH.FindAuctionIndex("list", auction)
  if index == nil then
    self:Prepare()
    return
  end

  -- Far above the usual price: ask for a second click
  if Auctionary.Config.Get(Auctionary.Config.Options.SHOPPING_CONFIRM_HIGH_PRICE)
     and self.average ~= nil and self.average > 0
     and ready.row.unitPrice > self.average * 1.5 and self.confirmed ~= auction then
    self.confirmed = auction
    self:SetStatus(Auctionary.Compat.Colors.RED_FONT_COLOR:WrapTextInColorCode(
      ("%d%% of the average price (%s). Click again to buy anyway."):format(
        math.floor(ready.row.unitPrice / self.average * 100),
        Auctionary.Compat.GetMoneyString(self.average, true)
      )
    ))
    return
  end

  self.ready = nil
  self.bidding = {
    row = ready.row,
    auction = auction,
    moneyBefore = GetMoney(),
    bidTime = GetTime(),
  }
  self.BuyButton:Disable()
  self:SetStatus((AUCTIONARY2_L_BUYING or "Buying") .. " ...")
  self:RegisterEvent("PLAYER_MONEY")
  self:RegisterEvent("UI_ERROR_MESSAGE")

  PlaceAuctionBid("list", index, buyout)
end

function BuyFrame:OnEvent(eventName, message)
  local bidding = self.bidding
  if bidding == nil then
    return
  end
  if eventName == "PLAYER_MONEY" then
    if GetMoney() < bidding.moneyBefore then
      self:FinishBidding(true)
    end
  elseif eventName == "UI_ERROR_MESSAGE" then
    self:FinishBidding(false, message)
  end
end

function BuyFrame:OnUpdate()
  local bidding = self.bidding
  if bidding ~= nil and GetTime() - bidding.bidTime > BUY_TIMEOUT then
    self:FinishBidding(false, NO_ANSWER_TEXT)
  end
end

function BuyFrame:StopBuying()
  self:CancelLocating()
  self.ready = nil
  if self.bidding ~= nil then
    self.bidding = nil
    self:UnregisterEvent("PLAYER_MONEY")
    self:UnregisterEvent("UI_ERROR_MESSAGE")
  end
end

function BuyFrame:RemoveAuction(row, auction)
  for index, other in ipairs(row.auctions) do
    if other == auction then
      table.remove(row.auctions, index)
      break
    end
  end
  for index, other in ipairs(self.result.auctions) do
    if other == auction then
      table.remove(self.result.auctions, index)
      break
    end
  end

  if #row.auctions == 0 then
    for index, other in ipairs(self.rows) do
      if other == row then
        table.remove(self.rows, index)
        break
      end
    end
    if self.selectedKey == row.key then
      self.selectedKey = self.rows[1] and self.rows[1].key
    end
  else
    row.availableText = #row.auctions .. " x " .. row.stackSize
  end
  self.rowSet:Replace(self.rows)
end

function BuyFrame:FinishBidding(success, message)
  local bidding = self.bidding
  if bidding == nil then
    return
  end
  self.bidding = nil
  self:UnregisterEvent("PLAYER_MONEY")
  self:UnregisterEvent("UI_ERROR_MESSAGE")

  local row = bidding.row
  if success then
    if Auctionary.GoldLog ~= nil then
      Auctionary.GoldLog.Add("b", self.result and self.result.name, row.itemLink, row.stackSize, row.stackPrice, "Shopping")
    end
    self:RemoveAuction(row, bidding.auction)
    Auctionary.Utilities.Message((AUCTIONARY2_L_BUYING_FOR or "Buying %s for %s"):format(
      row.stackSize .. " x " .. self.result.name,
      Auctionary.Compat.GetMoneyString(row.stackPrice, true)
    ))
    local wanted = self.wanted
    if wanted ~= nil then
      wanted.left = wanted.left - row.stackSize
      wanted.bought = wanted.bought + row.stackSize
      wanted.spent = wanted.spent + row.stackPrice
      if wanted.left <= 0 then
        self.wanted = nil
        self.QuantityBox:SetText("")
        Auctionary.Utilities.Message(("Bought %d x %s for %s in total."):format(
          wanted.bought, self.result.name, Auctionary.Compat.GetMoneyString(wanted.spent, true)
        ))
      else
        self.QuantityBox:SetText(tostring(wanted.left))
        local cheapest = self:GetCheapestRow()
        if cheapest ~= nil then
          self.selectedKey = cheapest.key
        else
          self.wanted = nil
          Auctionary.Utilities.Message(("No more auctions. Bought %d x %s for %s."):format(
            wanted.bought, self.result.name, Auctionary.Compat.GetMoneyString(wanted.spent, true)
          ))
        end
      end
    end
    -- Get the next one ready
    self:UpdateSelection()
  else
    self.rowTable:Refresh()
    self:SetStatus(Auctionary.Compat.Colors.RED_FONT_COLOR:WrapTextInColorCode(message or ""))
    -- The list has to be loaded again before another try; picking a row does that
  end
end

function Auctionary.Buying.CreateFrame(parent)
  local frame = CreateFrame("Frame", "Auctionary2BuyFrame", parent)
  Auctionary.Compat.Mixin(frame, BuyFrame)
  frame:Hide()
  frame:OnLoad()
  return frame
end

-- Auctions grouped into rows of the same stack size and price (the Selling
-- tab shows the competition with these)
function Auctionary.Buying.GroupAuctions(auctions)
  return BuyFrame.BuildRows(nil, auctions)
end
