local Auctionator = Auctionary

-- Small windows shared by the tabs: price history of an item, a text window
-- for importing/exporting shopping lists, and the default stack sizes.

local function CreateDialog(name, width, height, titleText)
  local dialog = CreateFrame("Frame", name, UIParent)
  dialog:SetWidth(width)
  dialog:SetHeight(height)
  dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  dialog:SetFrameStrata("DIALOG")
  dialog:SetToplevel(true)
  dialog:EnableMouse(true)
  dialog:SetMovable(true)
  dialog:RegisterForDrag("LeftButton")
  dialog:SetScript("OnDragStart", dialog.StartMoving)
  dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
  dialog:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
  })
  dialog:SetBackdropColor(0.05, 0.05, 0.05, 1)

  dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  dialog.title:SetPoint("TOP", dialog, "TOP", 0, -14)
  dialog.title:SetText(titleText or "")

  dialog.closeButton = CreateFrame("Button", name .. "Close", dialog, "UIPanelButtonTemplate")
  dialog.closeButton:SetWidth(90)
  dialog.closeButton:SetHeight(22)
  dialog.closeButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -14, 12)
  dialog.closeButton:SetText(CLOSE or "Close")
  dialog.closeButton:SetScript("OnClick", function()
    dialog:Hide()
  end)

  if UISpecialFrames ~= nil then
    table.insert(UISpecialFrames, name)
  end
  -- Same look as ElvUI's windows when its auction house skin is on
  dialog:SetScript("OnShow", function()
    if Auctionator.Tabs ~= nil and Auctionator.Tabs.SkinForElvUI ~= nil then
      pcall(Auctionator.Tabs.SkinForElvUI, dialog, true)
    end
    if Auctionator.Tabs ~= nil and Auctionator.Tabs.AddEscapeToBoxes ~= nil then
      pcall(Auctionator.Tabs.AddEscapeToBoxes, dialog)
    end
  end)
  dialog:Hide()
  return dialog
end

Auctionator.Components.CreateDialog = CreateDialog

local function HideWithAuctionHouse(dialog)
  local listener = {}
  function listener:ReceiveEvent()
    dialog:Hide()
  end
  Auctionator.EventBus:Register(listener, { Auctionator.AH.Events.Closed })
end

---- Price history / own posting history

local PRICE_LAYOUT = {
  { headerText = "Date", headerParameters = { "rawDay" }, cellParameters = { "date" }, width = 190 },
  { headerText = "Lowest", headerParameters = { "minSeen" }, cellParameters = { "minSeen" }, cellType = "price", width = 120 },
  { headerText = "Highest", headerParameters = { "maxSeen" }, cellParameters = { "maxSeen" }, cellType = "price", width = 120 },
  { headerText = "Available", headerParameters = { "available" }, cellParameters = { "available" } },
}
local POSTING_LAYOUT = {
  { headerText = "Date", headerParameters = { "rawDay" }, cellParameters = { "date" }, width = 190 },
  { headerText = "Unit Price", headerParameters = { "price" }, cellParameters = { "price" }, cellType = "price", width = 140 },
  { headerText = "Quantity", headerParameters = { "quantity" }, cellParameters = { "quantity" } },
}

local ALL_POSTINGS_LAYOUT = {
  { headerText = "Item", headerParameters = { "name" }, cellParameters = { "name" }, cellType = "item" },
  { headerText = "Date", headerParameters = { "rawDay" }, cellParameters = { "date" }, width = 170 },
  { headerText = "Unit Price", headerParameters = { "price" }, cellParameters = { "price" }, cellType = "price", width = 110 },
  { headerText = "Qty", headerParameters = { "quantity" }, cellParameters = { "quantity" }, width = 50 },
}

local historyDialog

local function CreateHistoryDialog()
  local dialog = CreateDialog("AuctionaryHistoryDialog", 560, 360, "")
  local number = Auctionator.Utilities.NumberComparator

  dialog.priceProvider = Auctionator.Components.CreateDataProvider({
    layout = PRICE_LAYOUT,
    comparators = { rawDay = number, minSeen = number, maxSeen = number, available = number },
  })
  dialog.postingProvider = Auctionator.Components.CreateDataProvider({
    layout = POSTING_LAYOUT,
    comparators = { rawDay = number, price = number, quantity = number },
  })
  dialog.priceListing = Auctionator.Components.CreateResultsListing(dialog, dialog.priceProvider, {
    emptyText = "No scan has seen this item yet.",
  })
  dialog.postingListing = Auctionator.Components.CreateResultsListing(dialog, dialog.postingProvider, {
    emptyText = "You have not posted this item with this addon yet.",
  })
  dialog.allProvider = Auctionator.Components.CreateDataProvider({
    layout = ALL_POSTINGS_LAYOUT,
    comparators = { rawDay = number, price = number, quantity = number },
  })
  dialog.allListing = Auctionator.Components.CreateResultsListing(dialog, dialog.allProvider, {
    emptyText = "You have not posted anything with this addon yet.",
    onRowClick = function(rowData)
      if rowData.itemLink ~= nil then
        Auctionator.Components.ShowHistory(rowData.itemLink, "posting")
      end
    end,
  })
  dialog.allListing:SetPoint("TOPLEFT", dialog, "TOPLEFT", 14, -36)
  dialog.allListing:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -14, 40)
  dialog.allListing:Hide()

  for _, listing in ipairs({ dialog.priceListing, dialog.postingListing }) do
    listing:SetPoint("TOPLEFT", dialog, "TOPLEFT", 14, -62)
    listing:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -14, 40)
  end

  local function ViewButton(text, x, view)
    local button = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    button:SetWidth(130)
    button:SetHeight(20)
    button:SetPoint("TOPLEFT", dialog, "TOPLEFT", x, -36)
    button:SetText(text)
    button:SetScript("OnClick", function()
      dialog:SetView(view)
    end)
    return button
  end
  dialog.priceButton = ViewButton("Price History", 14, "price")
  dialog.postingButton = ViewButton("Your History", 148, "posting")

  dialog.summary = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  dialog.summary:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 16, 18)
  dialog.summary:SetPoint("RIGHT", dialog.closeButton, "LEFT", -8, 0)
  dialog.summary:SetJustifyH("LEFT")

  function dialog:SetView(view)
    if view == "all" then
      self.priceListing:Hide()
      self.postingListing:Hide()
      self.priceButton:Hide()
      self.postingButton:Hide()
      self.allListing:Show()
      return
    end
    self.allListing:Hide()
    self.priceButton:Show()
    self.postingButton:Show()
    if view == "posting" then
      self.priceListing:Hide()
      self.postingListing:Show()
      self.postingButton:LockHighlight()
      self.priceButton:UnlockHighlight()
    else
      self.postingListing:Hide()
      self.priceListing:Show()
      self.priceButton:LockHighlight()
      self.postingButton:UnlockHighlight()
    end
  end

  HideWithAuctionHouse(dialog)
  return dialog
end

-- view: "price" (default) or "posting"
function Auctionator.Components.ShowHistory(itemLink, view)
  if itemLink == nil or Auctionator.Database == nil then
    return
  end
  if historyDialog == nil then
    historyDialog = CreateHistoryDialog()
  end
  local dialog = historyDialog

  Auctionator.Utilities.DBKeyFromLink(itemLink, function(dbKeys)
    local dbKey = dbKeys[1]
    if dbKey == nil then
      return
    end
    dialog.title:SetText(itemLink)

    local prices = Auctionator.Database:GetPriceHistory(dbKey)
    for _, entry in ipairs(prices) do
      entry.available = entry.available or ""
    end
    dialog.priceProvider:SetEntries(prices)

    local postings = {}
    if Auctionator.PostingHistory ~= nil and Auctionator.PostingHistory.GetPriceHistory ~= nil then
      local all = Auctionator.PostingHistory:GetPriceHistory(dbKey)
      -- newest first
      for index = #all, 1, -1 do
        table.insert(postings, all[index])
      end
    end
    dialog.postingProvider:SetEntries(postings)

    local average = Auctionator.Database:GetScanAverage(
      dbKey, Auctionator.Config.Get(Auctionator.Config.Options.AUCTION_MEAN_DAYS_LIMIT)
    )
    if average ~= nil then
      dialog.summary:SetText("Average: " .. Auctionator.Compat.GetMoneyString(average, true))
    else
      dialog.summary:SetText("")
    end

    dialog:SetView(view)
    dialog:Show()
  end)
end

-- Everything the player has posted with the addon, newest first. A click on
-- a row opens the history of that item.
function Auctionator.Components.ShowAllPostings()
  if historyDialog == nil then
    historyDialog = CreateHistoryDialog()
  end
  local dialog = historyDialog
  local entries = {}
  local db = Auctionator.PostingHistory and Auctionator.PostingHistory.db
  for dbKey, postings in pairs(db or {}) do
    local itemID = tostring(dbKey):match("^(%d+)")
    local name, itemLink, quality, iconTexture
    if itemID ~= nil then
      name, itemLink, quality = GetItemInfo(tonumber(itemID))
      iconTexture = select(10, GetItemInfo(tonumber(itemID)))
    end
    for _, posting in ipairs(type(postings) == "table" and postings or {}) do
      table.insert(entries, {
        name = name or ("Item " .. tostring(dbKey)),
        quality = quality,
        itemLink = itemLink,
        iconTexture = iconTexture,
        date = Auctionator.Utilities.PrettyDate(posting.time),
        rawDay = posting.time,
        price = posting.price,
        quantity = posting.quantity,
      })
    end
  end
  table.sort(entries, function(a, b)
    return (a.rawDay or 0) > (b.rawDay or 0)
  end)
  dialog.title:SetText("Your History - everything you posted")
  dialog.summary:SetText(#entries .. " entries. Click one for the history of that item.")
  dialog:SetView("all")
  dialog:Show()
  -- Filled after the list is visible: coin icons in text set on a hidden
  -- list do not get drawn by this client
  dialog.allProvider:SetEntries(entries)
  Auctionator.Compat.After(0.05, function()
    if dialog.allListing:IsVisible() then
      dialog.allListing:Refresh()
    end
  end)
end

---- Text window (import / export)

local textDialog

local function CreateTextDialog()
  local dialog = CreateDialog("AuctionaryTextDialog", 460, 300, "")

  dialog.hint = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  dialog.hint:SetPoint("TOPLEFT", dialog, "TOPLEFT", 16, -36)
  dialog.hint:SetPoint("RIGHT", dialog, "RIGHT", -16, 0)
  dialog.hint:SetJustifyH("LEFT")

  local area = CreateFrame("Frame", nil, dialog)
  area:SetPoint("TOPLEFT", dialog, "TOPLEFT", 14, -66)
  area:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -34, 42)
  area:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  area:SetBackdropColor(0, 0, 0, 1)

  local scroll = CreateFrame("ScrollFrame", "AuctionaryTextDialogScroll", area, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", area, "TOPLEFT", 6, -6)
  scroll:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -6, 6)

  local editBox = CreateFrame("EditBox", "AuctionaryTextDialogEditBox", scroll)
  editBox:SetMultiLine(true)
  editBox:SetAutoFocus(false)
  editBox:SetFontObject(ChatFontNormal)
  editBox:SetWidth(390)
  editBox:SetHeight(180)
  editBox:SetMaxLetters(0)
  editBox:SetScript("OnEscapePressed", function()
    dialog:Hide()
  end)
  scroll:SetScrollChild(editBox)
  area:EnableMouse(true)
  area:SetScript("OnMouseDown", function()
    editBox:SetFocus()
  end)
  dialog.editBox = editBox

  dialog.acceptButton = CreateFrame("Button", "AuctionaryTextDialogAccept", dialog, "UIPanelButtonTemplate")
  dialog.acceptButton:SetWidth(90)
  dialog.acceptButton:SetHeight(22)
  dialog.acceptButton:SetPoint("RIGHT", dialog.closeButton, "LEFT", -6, 0)
  dialog.acceptButton:SetScript("OnClick", function()
    local onAccept = dialog.onAccept
    dialog:Hide()
    if onAccept ~= nil then
      onAccept(editBox:GetText())
    end
  end)

  HideWithAuctionHouse(dialog)
  return dialog
end

-- details = { title, hint, text, acceptText, onAccept(text) }; without
-- onAccept the window only shows text to copy
function Auctionator.Components.ShowTextDialog(details, hint, text, acceptText, onAccept)
  if type(details) ~= "table" then
    details = { title = details, hint = hint, text = text, acceptText = acceptText, onAccept = onAccept }
  end
  if textDialog == nil then
    textDialog = CreateTextDialog()
  end
  local dialog = textDialog
  dialog.title:SetText(details.title or "")
  dialog.hint:SetText(details.hint or "")
  dialog.onAccept = details.onAccept
  dialog.editBox:SetText(details.text or "")
  if details.onAccept ~= nil then
    dialog.acceptButton:SetText(details.acceptText or ACCEPT or "Accept")
    dialog.acceptButton:Show()
  else
    dialog.acceptButton:Hide()
  end
  dialog:Show()
  dialog.editBox:SetFocus()
  if details.onAccept == nil then
    dialog.editBox:HighlightText()
  end
end

---- Default stack sizes

local quantitiesDialog

local function CreateQuantitiesDialog()
  local Options = Auctionator.Config.Options
  local classNames = { GetAuctionItemClasses() }
  local classIDs = {}
  for _, classID in pairs(Auctionator.Constants.ItemClass) do
    if Auctionator.Config.Defaults[Options.DEFAULT_QUANTITIES][classID] ~= nil then
      table.insert(classIDs, classID)
    end
  end
  table.sort(classIDs)

  local dialog = CreateDialog("AuctionaryQuantitiesDialog", 300, 96 + #classIDs * 22, "Default stack sizes")
  local hint = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -34)
  hint:SetText("Items per stack when you pick an item to sell.\n0 = a full stack.")
  hint:SetJustifyH("LEFT")

  dialog.boxes = {}
  for index, classID in ipairs(classIDs) do
    local y = -44 - index * 22
    local label = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, y)
    label:SetText(classNames[classID] or ("Class " .. classID))

    local box = CreateFrame("EditBox", "AuctionaryQuantitiesBox" .. classID, dialog, "InputBoxTemplate")
    box:SetWidth(40)
    box:SetHeight(18)
    box:SetPoint("TOPLEFT", dialog, "TOPLEFT", 200, y + 4)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(4)
    box:SetScript("OnTextChanged", function(_, userInput)
      if userInput then
        local quantities = Auctionator.Config.Get(Options.DEFAULT_QUANTITIES)
        quantities[classID] = tonumber(box:GetText()) or 0
        Auctionator.Config.Set(Options.DEFAULT_QUANTITIES, quantities)
      end
    end)
    box:SetScript("OnEnterPressed", function() box:ClearFocus() end)
    box:SetScript("OnEscapePressed", function() box:ClearFocus() end)
    dialog.boxes[classID] = box
  end

  dialog:HookScript("OnShow", function()
    local quantities = Auctionator.Config.Get(Options.DEFAULT_QUANTITIES)
    for classID, box in pairs(dialog.boxes) do
      box:SetText(tostring(quantities[classID] or 0))
    end
  end)
  HideWithAuctionHouse(dialog)
  return dialog
end

function Auctionator.Components.ShowQuantitiesDialog()
  if quantitiesDialog == nil then
    quantitiesDialog = CreateQuantitiesDialog()
  end
  quantitiesDialog:Show()
end

Auctionator.Components.ShowDefaultQuantities = Auctionator.Components.ShowQuantitiesDialog


---- Sales: what sold and what expired, read from the auction house mail

local SALES_KEEP_DAYS = 400
local MAIL_DAYS = 30

-- "Auction successful: %s" -> pattern that captures the item name
local function SubjectPattern(format)
  if type(format) ~= "string" then
    return nil
  end
  local pattern = format:gsub("%%s", "\001")
  pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")
  pattern = pattern:gsub("\001", "(.+)")
  return "^" .. pattern .. "$"
end
local SOLD_PATTERN = SubjectPattern(AUCTION_SOLD_MAIL_SUBJECT)
local EXPIRED_PATTERN = SubjectPattern(AUCTION_EXPIRED_MAIL_SUBJECT)

local function SalesList()
  if Auctionator.SavedState == nil then
    return nil
  end
  Auctionator.SavedState.Sales = Auctionator.SavedState.Sales or {}
  return Auctionator.SavedState.Sales
end

-- Mails carry no id, so a mail counts as already recorded when a record of
-- the same kind, item, amount and (roughly) time exists
local function ScanInbox()
  local sales = SalesList()
  if sales == nil or GetInboxNumItems == nil then
    return
  end
  local now = time()
  local realm, character = GetRealmName(), UnitName("player")
  local used = {}
  for index = 1, (GetInboxNumItems() or 0) do
    local _, _, _, subject, money, _, daysLeft = GetInboxHeaderInfo(index)
    if type(subject) == "string" and daysLeft ~= nil then
      local kind, name
      local sold = SOLD_PATTERN and subject:match(SOLD_PATTERN)
      local expired = EXPIRED_PATTERN and subject:match(EXPIRED_PATTERN)
      if sold then
        kind, name = "s", sold
      elseif expired then
        kind, name = "e", expired
      end
      if kind ~= nil then
        local gold, buyer, quantity = 0, nil, nil
        if kind == "s" then
          gold = money or 0
          local invoiceType, itemName, playerName, bid, _, deposit, consignment = GetInboxInvoiceInfo(index)
          if invoiceType == "seller" then
            buyer = playerName
            name = itemName or name
            -- Stays the same after the gold was taken out of the mail
            gold = (bid or 0) + (deposit or 0) - (consignment or 0)
          end
        else
          local _, _, count = GetInboxItem(index, 1)
          quantity = count
        end
        if kind == "e" or gold > 0 then
          local when = math.floor(now - (MAIL_DAYS - daysLeft) * 86400)
          local found
          for position, record in ipairs(sales) do
            if not used[position] and record.k == kind and record.n == name and record.c == character
               and record.r == realm and (record.g or 0) == gold and math.abs(record.t - when) < 1800 then
              found = position
              break
            end
          end
          if found == nil then
            table.insert(sales, { t = when, k = kind, n = name, g = gold, b = buyer, q = quantity, r = realm, c = character })
            found = #sales
          end
          used[found] = true
        end
      end
    end
  end
  for position = #sales, 1, -1 do
    if now - (sales[position].t or 0) > SALES_KEEP_DAYS * 86400 then
      table.remove(sales, position)
    end
  end
end

local mailFrame = CreateFrame("Frame")
mailFrame:RegisterEvent("MAIL_INBOX_UPDATE")
mailFrame:SetScript("OnEvent", function()
  pcall(ScanInbox)
end)

local SALES_LAYOUT = {
  { headerText = "Item", headerParameters = { "name" }, cellParameters = { "name" }, cellType = "item" },
  { headerText = "Result", headerParameters = { "result" }, cellParameters = { "resultText" }, width = 70 },
  { headerText = "Gold", headerParameters = { "gold" }, cellParameters = { "goldText" }, width = 110 },
  { headerText = "Buyer", headerParameters = { "buyer" }, cellParameters = { "buyer" }, width = 100 },
  { headerText = "Character", headerParameters = { "character" }, cellParameters = { "character" }, width = 90 },
  { headerText = "Date", headerParameters = { "rawTime" }, cellParameters = { "date" }, width = 110 },
}
local salesDialog

function Auctionator.Components.ShowSales()
  if salesDialog == nil then
    local number = Auctionator.Utilities.NumberComparator
    local text = Auctionator.Utilities.StringComparator
    salesDialog = CreateDialog("AuctionarySalesDialog", 700, 440, "Sales Summary")
    salesDialog.provider = Auctionator.Components.CreateDataProvider({
      layout = SALES_LAYOUT,
      comparators = { name = text, result = text, gold = number, buyer = text, character = text, rawTime = number },
    })
    salesDialog.listing = Auctionator.Components.CreateResultsListing(salesDialog, salesDialog.provider, {
      emptyText = "Nothing recorded yet. Open your mailbox: auction house mail is counted from then on.",
    })
    salesDialog.listing:SetPoint("TOPLEFT", salesDialog, "TOPLEFT", 14, -96)
    salesDialog.listing:SetPoint("BOTTOMRIGHT", salesDialog, "BOTTOMRIGHT", -14, 40)
    salesDialog.totals = salesDialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    salesDialog.totals:SetPoint("TOPLEFT", salesDialog, "TOPLEFT", 18, -38)
    salesDialog.totals:SetPoint("RIGHT", salesDialog, "RIGHT", -18, 0)
    salesDialog.totals:SetJustifyH("LEFT")
    salesDialog.summary = salesDialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    salesDialog.summary:SetPoint("BOTTOMLEFT", salesDialog, "BOTTOMLEFT", 16, 18)
    salesDialog.summary:SetPoint("RIGHT", salesDialog.closeButton, "LEFT", -8, 0)
    salesDialog.summary:SetJustifyH("LEFT")
  end
  local dialog = salesDialog
  local now, realm = time(), GetRealmName()
  local periods = {
    { label = "Last 24 hours", seconds = 86400 },
    { label = "Last 7 days", seconds = 7 * 86400 },
    { label = "Last 30 days", seconds = 30 * 86400 },
  }
  for _, period in ipairs(periods) do
    period.sold, period.gold, period.expired = 0, 0, 0
  end
  local entries = {}
  for _, record in ipairs(SalesList() or {}) do
    if record.r == realm then
      for _, period in ipairs(periods) do
        if now - record.t <= period.seconds then
          if record.k == "s" then
            period.sold = period.sold + 1
            period.gold = period.gold + (record.g or 0)
          else
            period.expired = period.expired + 1
          end
        end
      end
      local _, itemLink, quality, _, _, _, _, _, _, iconTexture = GetItemInfo(record.n or "")
      table.insert(entries, {
        name = (record.n or "?") .. ((record.q or 1) > 1 and (" x" .. record.q) or ""),
        itemLink = itemLink,
        quality = quality,
        iconTexture = iconTexture,
        result = record.k,
        resultText = record.k == "s" and "|cff20ff20Sold|r" or "|cffff6060Expired|r",
        gold = record.g or 0,
        goldText = record.k == "s" and Auctionator.Compat.GetMoneyString(record.g or 0, true) or "",
        buyer = record.b or "",
        character = record.c or "",
        rawTime = record.t,
        date = date("%b %d, %H:%M", record.t),
      })
    end
  end
  table.sort(entries, function(a, b)
    return a.rawTime > b.rawTime
  end)
  local lines = {}
  for _, period in ipairs(periods) do
    table.insert(lines, ("|cffffd100%s:|r  %d sold for %s,  %d expired"):format(
      period.label, period.sold, Auctionator.Compat.GetMoneyString(period.gold, true), period.expired))
  end
  dialog.totals:SetText(table.concat(lines, "\n"))
  dialog.summary:SetText("Gold is what arrived by mail (after the fee). Only mail seen in an open mailbox is counted.")
  dialog:Show()
  dialog.provider:SetEntries(entries)
  Auctionator.Compat.After(0.05, function()
    if dialog.listing:IsVisible() then
      dialog.listing:Refresh()
    end
  end)
end

---- Gold Tracker: what was earned (sales), spent (purchases) and paid as
-- deposits, as a list and as a chart over a chosen period

Auctionator.GoldLog = {}
local GOLD_LOG_DAYS = 400

local function GoldLogList()
  if Auctionator.SavedState == nil then
    return nil
  end
  Auctionator.SavedState.GoldLog = Auctionator.SavedState.GoldLog or {}
  return Auctionator.SavedState.GoldLog
end

-- kind: "b" bought, "d" deposit; gold in copper (what left your bags)
function Auctionator.GoldLog.Add(kind, name, itemLink, quantity, gold, source, extra)
  local log = GoldLogList()
  if log == nil or (gold or 0) <= 0 then
    return
  end
  local Options = Auctionator.Config.Options
  if not Auctionator.Config.Get(Options.GOLD_TRACKER_RECORD)
     or (kind == "v" and not Auctionator.Config.Get(Options.GOLD_TRACKER_VENDOR)) then
    return
  end
  if name == nil and itemLink ~= nil then
    name = GetItemInfo(itemLink)
  end
  table.insert(log, {
    t = time(), k = kind, n = name or "?", q = quantity, g = math.floor(gold),
    s = source, r = GetRealmName(), c = UnitName("player"),
    m = extra and extra.m, p = extra and extra.p and math.floor(extra.p), v = extra and extra.v,
  })
  local now = time()
  while #log > 0 and now - (log[1].t or 0) > GOLD_LOG_DAYS * 86400 do
    table.remove(log, 1)
  end
end

local goldModel
local goldDialog

-- Deletes everything the Gold Tracker recorded (sales, purchases, deposits,
-- vendor sales, gold history) and starts again from the gold this
-- character has right now. Other characters start when they log in.
function Auctionator.GoldLog.Reset()
  local state = Auctionator.SavedState
  if state == nil then
    return
  end
  state.GoldLog = {}
  state.Sales = {}
  state.Money = {}
  state.MoneyHistory = {}
  local realm, character = GetRealmName(), UnitName("player")
  if realm ~= nil and character ~= nil then
    state.Money[realm] = { [character] = GetMoney() }
    state.MoneyHistory[realm] = { [character] = { { time(), GetMoney() } } }
  end
  goldModel = nil
  if goldDialog ~= nil and goldDialog:IsShown() then
    Auctionator.Components.ShowGoldTracker()
  end
end

-- Gold of every character on this realm, and how it changed over time
-- (one point per 10 minutes), for the gold at the start of a period
local MONEY_POINT_SECONDS = 600
-- This client reports 0 gold for a moment after logging in, so the gold is
-- taken a few seconds later, then on every change and once a minute.
local moneyFrame = CreateFrame("Frame")
local function RecordMoney()
  local state = Auctionator.SavedState
  local realm, character = GetRealmName(), UnitName("player")
  if state == nil or realm == nil or character == nil then
    return
  end
  if not Auctionator.Config.Get(Auctionator.Config.Options.GOLD_TRACKER_RECORD) then
    return
  end
  -- Records of 0 gold from the version that read it too early
  if not state.MoneyZeroFixed then
    state.MoneyZeroFixed = true
    for _, characters in pairs(state.MoneyHistory or {}) do
      for _, history in pairs(characters) do
        for index = #history, 1, -1 do
          if history[index][2] == 0 then
            table.remove(history, index)
          end
        end
      end
    end
    for _, characters in pairs(state.Money or {}) do
      for name, amount in pairs(characters) do
        if amount == 0 then
          characters[name] = nil
        end
      end
    end
  end
  local money, now = GetMoney(), time()
  state.Money = state.Money or {}
  state.Money[realm] = state.Money[realm] or {}
  state.Money[realm][character] = money
  state.MoneyHistory = state.MoneyHistory or {}
  state.MoneyHistory[realm] = state.MoneyHistory[realm] or {}
  local history = state.MoneyHistory[realm][character] or {}
  state.MoneyHistory[realm][character] = history
  local last = history[#history]
  if last ~= nil and now - last[1] < MONEY_POINT_SECONDS then
    last[2] = money
  else
    table.insert(history, { now, money })
  end
  while #history > 2 and now - history[1][1] > GOLD_LOG_DAYS * 86400 do
    table.remove(history, 1)
  end
end

local sinceLogin, sinceRecord, ready = 0, 0, false
moneyFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
moneyFrame:RegisterEvent("PLAYER_MONEY")
moneyFrame:SetScript("OnEvent", function(_, eventName)
  if eventName == "PLAYER_ENTERING_WORLD" then
    sinceLogin, ready = 0, false
  elseif ready then
    pcall(RecordMoney)
  end
end)
moneyFrame:SetScript("OnUpdate", function(_, elapsed)
  sinceLogin = sinceLogin + (elapsed or 0)
  sinceRecord = sinceRecord + (elapsed or 0)
  if not ready then
    -- Real gold arrived, or (for a character with no gold) enough time passed
    if (sinceLogin > 3 and GetMoney() > 0) or sinceLogin > 20 then
      ready, sinceRecord = true, 0
      pcall(RecordMoney)
    end
  elseif sinceRecord >= 60 then
    sinceRecord = 0
    pcall(RecordMoney)
  end
end)

-- Gold of all characters at a moment; exact is false when a character's
-- records only start later
-- Character shown in the Gold Tracker (nil: all characters of the account)
local trackedCharacter
-- Gold of a character at any moment. Between two snapshots (taken while
-- playing) the auction house and vendor records of the character fill the
-- gaps, so the line also moves for times before the first snapshot.

local function BuildGoldModel()
  local state = Auctionator.SavedState
  local realm = GetRealmName()
  local model = {}
  local function Character(name)
    if model[name] == nil then
      model[name] = { points = {}, moves = {} }
    end
    return model[name]
  end
  for name, history in pairs(state and state.MoneyHistory and state.MoneyHistory[realm] or {}) do
    for _, point in ipairs(history) do
      table.insert(Character(name).points, { t = point[1], v = point[2] })
    end
  end
  local function AddMoves(list)
    for _, record in ipairs(list or {}) do
      if record.r == realm and record.c ~= nil and (record.g or 0) > 0 then
        local sign = (record.k == "s" or record.k == "v") and 1 or ((record.k == "b" or record.k == "d") and -1 or 0)
        if sign ~= 0 then
          table.insert(Character(record.c).moves, { t = record.t, g = sign * record.g })
        end
      end
    end
  end
  AddMoves(state and state.Sales)
  AddMoves(state and state.GoldLog)
  local player = UnitName("player")
  for name, data in pairs(model) do
    if name == player then
      table.insert(data.points, { t = time(), v = GetMoney() })
    end
    table.sort(data.points, function(a, b) return a.t < b.t end)
    table.sort(data.moves, function(a, b) return a.t < b.t end)
    -- Running total of the moves for quick sums
    local sum = 0
    for _, move in ipairs(data.moves) do
      sum = sum + move.g
      move.sum = sum
    end
  end
  return model
end

-- Sum of the moves up to and including moment
local function MovesUntil(moves, moment)
  local low, high, found = 1, #moves, 0
  while low <= high do
    local middle = math.floor((low + high) / 2)
    if moves[middle].t <= moment then
      found = moves[middle].sum
      low = middle + 1
    else
      high = middle - 1
    end
  end
  return found
end

local function CharacterGoldAt(data, moment)
  local points = data.points
  if #points == 0 then
    return nil, false
  end
  local before, after
  for _, point in ipairs(points) do
    if point.t <= moment then
      before = point
    else
      after = point
      break
    end
  end
  if before ~= nil then
    -- Last snapshot, plus what happened at the auction house since
    return before.v + MovesUntil(data.moves, moment) - MovesUntil(data.moves, before.t), true
  end
  -- Before the first snapshot: go back from it through the records
  return after.v - (MovesUntil(data.moves, after.t) - MovesUntil(data.moves, moment)), false
end

local function GoldAt(moment)
  goldModel = goldModel or BuildGoldModel()
  local total, exact, any = 0, true, false
  for name, data in pairs(goldModel) do
    if trackedCharacter == nil or name == trackedCharacter then
      local value, known = CharacterGoldAt(data, moment)
      if value ~= nil then
        total = total + math.max(value, 0)
        any = true
        exact = exact and known
      end
    end
  end
  return any and total or nil, exact
end

-- Items sold to a vendor (selling from the bags while a merchant is open)
if hooksecurefunc ~= nil then
  hooksecurefunc("UseContainerItem", function(bag, slot)
    if MerchantFrame == nil or not MerchantFrame:IsShown() then
      return
    end
    local ok = pcall(function()
      local link = GetContainerItemLink(bag, slot)
      local _, count, locked = GetContainerItemInfo(bag, slot)
      if link == nil then
        return
      end
      local name, _, _, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(link)
      if (vendorPrice or 0) > 0 then
        Auctionator.GoldLog.Add("v", name, link, count or 1, vendorPrice * (count or 1), "Vendor")
      end
    end)
  end)
end

local GOLD_LAYOUT = {
  { headerText = "Item", headerParameters = { "name" }, cellParameters = { "name" }, cellType = "item" },
  { headerText = "Type", headerParameters = { "kind" }, cellParameters = { "kindText" }, width = 70 },
  { headerText = "Qty", headerParameters = { "quantity" }, cellParameters = { "quantity" }, width = 45 },
  { headerText = "Gold", headerParameters = { "gold" }, cellParameters = { "goldText" }, width = 120 },
  { headerText = "Where", headerParameters = { "source" }, cellParameters = { "source" }, width = 70 },
  { headerText = "Character", headerParameters = { "character" }, cellParameters = { "character" }, width = 90 },
  { headerText = "Date", headerParameters = { "rawTime" }, cellParameters = { "date" }, width = 105 },
}
local KIND_TEXT = {
  s = "|cff20ff20Sold|r", b = "|cffff6060Bought|r", d = "|cffffa040Deposit|r", e = "|cff909090Expired|r",
  v = "|cffffff60Vendor|r",
}
local INCOME = { s = true, v = true }
local CHART_WIDTH, CHART_HEIGHT = 640, 130

local function Money(amount)
  return Auctionator.Compat.GetMoneyString(math.floor(amount), true)
end
local function Signed(amount)
  if amount < 0 then
    return "|cffff6060-" .. Money(-amount) .. "|r"
  end
  return "|cff20ff20" .. Money(amount) .. "|r"
end

local function Midnight(moment)
  local parts = date("*t", moment)
  parts.hour, parts.min, parts.sec = 0, 0, 0
  return time(parts)
end

-- Periods of the drop-down menu: from, to, number of bars, label
local function MakeRange(kind, value)
  local now = time()
  local today = Midnight(now)
  if kind == "today" then
    return { from = today, to = today + 86400, bars = 12, label = "Today" }
  elseif kind == "yesterday" then
    return { from = today - 86400, to = today, bars = 12, label = "Yesterday" }
  elseif kind == "24h" then
    return { from = now - 86400, to = now, bars = 12, label = "Last 24 hours" }
  elseif kind == "7d" then
    return { from = today - 6 * 86400, to = today + 86400, bars = 7, label = "Last 7 days" }
  elseif kind == "30d" then
    return { from = today - 29 * 86400, to = today + 86400, bars = 30, label = "Last 30 days" }
  elseif kind == "day" then
    return { from = value, to = value + 86400, bars = 12, label = date("%a %d %b", value) }
  elseif kind == "month" then
    -- value: any moment in the month
    local parts = date("*t", value)
    local first = time({ year = parts.year, month = parts.month, day = 1, hour = 0 })
    local nextFirst = time({ year = parts.year + (parts.month == 12 and 1 or 0), month = parts.month % 12 + 1, day = 1, hour = 0 })
    local days = math.floor((nextFirst - first) / 86400 + 0.5)
    return { from = first, to = nextFirst, bars = days, label = date("%B %Y", first) }
  elseif kind == "all" then
    -- From the first record on (at least the last 7 days)
    local first = today - 6 * 86400
    local state = Auctionator.SavedState
    for _, list in ipairs({ state and state.Sales or {}, state and state.GoldLog or {} }) do
      for _, record in ipairs(list) do
        if record.t ~= nil and record.t < first then
          first = record.t
        end
      end
    end
    first = Midnight(first)
    local days = math.ceil((today + 86400 - first) / 86400)
    return { from = first, to = first + days * 86400, bars = math.min(days, 30), label = "All time" }
  end
end

local function BarLabel(range, slotStart, slotSeconds)
  if slotSeconds >= 86400 then
    return range.bars > 10 and date("%d.", slotStart) or date("%a %d.", slotStart)
  end
  return date("%H:%M", slotStart)
end

-- Sniping results over all records: what was bought, what came back from
-- the vendor and from the auction house (matched by item name, oldest
-- purchase first; the auction house mail does not say how many were sold,
-- so a sale counts as one purchase)
local function SnipingSummary(realm)
  local events = {}
  for _, record in ipairs(GoldLogList() or {}) do
    if record.r == realm and ((record.k == "b" and record.s == "Sniping") or record.k == "v") then
      table.insert(events, record)
    end
  end
  for _, record in ipairs((Auctionator.SavedState and Auctionator.SavedState.Sales) or {}) do
    if record.r == realm and record.k == "s" then
      table.insert(events, record)
    end
  end
  table.sort(events, function(a, b)
    if a.t ~= b.t then
      return a.t < b.t
    end
    return (a.k == "b" and 0 or 1) < (b.k == "b" and 0 or 1)
  end)
  local result = {
    bought = 0, cost = 0, expected = 0,
    vendorCost = 0, vendorIncome = 0, auctionCost = 0, auctionIncome = 0, heldCost = 0,
  }
  local stock = {}
  for _, record in ipairs(events) do
    local name = record.n or "?"
    if record.k == "b" then
      result.bought = result.bought + 1
      result.cost = result.cost + (record.g or 0)
      result.expected = result.expected + (record.p or 0)
      stock[name] = stock[name] or {}
      table.insert(stock[name], { left = record.q or 1, unit = (record.g or 0) / math.max(record.q or 1, 1) })
    elseif record.k == "v" then
      local lots, sold = stock[name], record.q or 1
      local covered = 0
      while lots ~= nil and #lots > 0 and covered < sold do
        local lot = lots[1]
        local take = math.min(lot.left, sold - covered)
        result.vendorCost = result.vendorCost + take * lot.unit
        lot.left = lot.left - take
        covered = covered + take
        if lot.left <= 0 then
          table.remove(lots, 1)
        end
      end
      if covered > 0 then
        result.vendorIncome = result.vendorIncome + (record.g or 0) * covered / sold
      end
    elseif record.k == "s" then
      local lots = stock[name]
      if lots ~= nil and #lots > 0 then
        local lot = table.remove(lots, 1)
        result.auctionCost = result.auctionCost + lot.left * lot.unit
        result.auctionIncome = result.auctionIncome + (record.g or 0)
      end
    end
  end
  for _, lots in pairs(stock) do
    for _, lot in ipairs(lots) do
      result.heldCost = result.heldCost + lot.left * lot.unit
    end
  end
  return result
end

local function CreateGoldDialog()
  local dialog = CreateDialog("AuctionaryGoldDialog", 760, 590, "Gold Tracker")
  local number = Auctionator.Utilities.NumberComparator
  local text = Auctionator.Utilities.StringComparator
  dialog.range = MakeRange("7d")
  dialog.history = {}

  -- Period drop-down
  dialog.periodButton = CreateFrame("Button", "AuctionaryGoldPeriodButton", dialog, "UIPanelButtonTemplate")
  dialog.periodButton:SetWidth(190)
  dialog.periodButton:SetHeight(22)
  dialog.periodButton:SetPoint("TOPLEFT", dialog, "TOPLEFT", 16, -32)
  dialog.periodMenu = CreateFrame("Frame", "AuctionaryGoldPeriodMenu", UIParent, "UIDropDownMenuTemplate")
  UIDropDownMenu_Initialize(dialog.periodMenu, function(_, level)
    local function Add(text, kind, value)
      local info = UIDropDownMenu_CreateInfo()
      info.text = text
      info.notCheckable = true
      info.func = function()
        dialog.history = {}
        dialog.range = MakeRange(kind, value)
        Auctionator.Components.ShowGoldTracker()
      end
      UIDropDownMenu_AddButton(info, level)
    end
    if level == 2 then
      -- The last twelve months
      local parts = date("*t")
      for back = 0, 11 do
        local month = parts.month - back
        local year = parts.year
        while month < 1 do
          month = month + 12
          year = year - 1
        end
        local moment = time({ year = year, month = month, day = 15, hour = 12 })
        Add(date("%B %Y", moment), "month", moment)
      end
      return
    end
    Add("Last 24 hours", "24h")
    Add("Last 7 days", "7d")
    Add("Last 30 days", "30d")
    local months = UIDropDownMenu_CreateInfo()
    months.text = "Past months"
    months.hasArrow = true
    months.notCheckable = true
    months.value = "months"
    UIDropDownMenu_AddButton(months)
    Add("All time", "all")
    local title = UIDropDownMenu_CreateInfo()
    title.text = "Single day"
    title.isTitle = true
    title.notCheckable = true
    UIDropDownMenu_AddButton(title)
    Add("Today", "today")
    Add("Yesterday", "yesterday")
    local today = Midnight(time())
    for back = 2, 13 do
      local day = today - back * 86400
      Add(date("%a %d %b", day), "day", day)
    end
  end, "MENU")
  dialog.periodButton:SetScript("OnClick", function(button)
    ToggleDropDownMenu(1, nil, dialog.periodMenu, button, 0, 0)
  end)

  dialog.backButton = CreateFrame("Button", "AuctionaryGoldBackButton", dialog, "UIPanelButtonTemplate")
  dialog.backButton:SetWidth(70)
  dialog.backButton:SetHeight(22)
  dialog.backButton:SetPoint("LEFT", dialog.periodButton, "RIGHT", 6, 0)
  dialog.backButton:SetText("< Back")

  -- Whose gold: all characters or one of them
  dialog.characterButton = CreateFrame("Button", "AuctionaryGoldCharacterButton", dialog, "UIPanelButtonTemplate")
  dialog.characterButton:SetWidth(210)
  dialog.characterButton:SetHeight(22)
  dialog.characterButton:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -16, -32)
  dialog.characterMenu = CreateFrame("Frame", "AuctionaryGoldCharacterMenu", UIParent, "UIDropDownMenuTemplate")
  UIDropDownMenu_Initialize(dialog.characterMenu, function()
    local function Add(text, character)
      local info = UIDropDownMenu_CreateInfo()
      info.text = text
      info.notCheckable = true
      info.func = function()
        trackedCharacter = character
        Auctionator.Components.ShowGoldTracker()
      end
      UIDropDownMenu_AddButton(info)
    end
    Add("All characters", nil)
    local names, seen = {}, {}
    local state = Auctionator.SavedState
    local realm = GetRealmName()
    for _, source in ipairs({ state and state.Money and state.Money[realm] or {}, state and state.MoneyHistory and state.MoneyHistory[realm] or {} }) do
      for name in pairs(source) do
        if not seen[name] then
          seen[name] = true
          table.insert(names, name)
        end
      end
    end
    table.sort(names)
    for _, name in ipairs(names) do
      Add(name, name)
    end
  end, "MENU")
  dialog.characterButton:SetScript("OnClick", function(button)
    ToggleDropDownMenu(1, nil, dialog.characterMenu, button, 0, 0)
  end)
  dialog.backButton:SetScript("OnClick", function()
    local previous = table.remove(dialog.history)
    if previous ~= nil then
      dialog.range = previous
      Auctionator.Components.ShowGoldTracker()
    end
  end)

  dialog.totals = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  dialog.totals:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -62)
  dialog.totals:SetPoint("RIGHT", dialog, "RIGHT", -18, 0)
  dialog.totals:SetJustifyH("LEFT")
  dialog.totals:SetSpacing(2)

  -- Chart: earned grows up from the middle line (green), spent down (red)
  local chart = CreateFrame("Frame", nil, dialog)
  chart:SetWidth(CHART_WIDTH)
  chart:SetHeight(CHART_HEIGHT)
  chart:SetPoint("TOPLEFT", dialog, "TOPLEFT", 92, -150)
  chart.background = chart:CreateTexture(nil, "BACKGROUND")
  chart.background:SetAllPoints(chart)
  chart.background:SetTexture(1, 1, 1, 0.04)
  chart.middle = chart:CreateTexture(nil, "BORDER")
  chart.middle:SetTexture(1, 1, 1, 0.35)
  chart.middle:SetHeight(1)
  chart.middle:SetPoint("LEFT", chart, "LEFT", 0, 0)
  chart.middle:SetPoint("RIGHT", chart, "RIGHT", 0, 0)
  chart.slots = {}
  chart.dots = {}
  -- Gold scale of the line on the left side
  chart.axis = {}
  chart.grid = {}
  for index = 1, 5 do
    local label = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetJustifyH("RIGHT")
    label:SetTextColor(1, 0.82, 0)
    chart.axis[index] = label
    local line = chart:CreateTexture(nil, "BORDER")
    line:SetTexture(1, 0.82, 0, 0.12)
    line:SetHeight(1)
    chart.grid[index] = line
  end
  chart.line = CreateFrame("Frame", nil, chart)
  chart.line:SetAllPoints(chart)
  chart.line:SetFrameLevel((chart:GetFrameLevel() or 0) + 5)
  dialog.chart = chart

  dialog.chartScale = dialog:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  dialog.chartScale:SetPoint("BOTTOMLEFT", chart, "TOPLEFT", 0, 2)

  dialog.provider = Auctionator.Components.CreateDataProvider({
    layout = GOLD_LAYOUT,
    comparators = { name = text, kind = text, quantity = number, gold = number, source = text, character = text, rawTime = number },
  })
  dialog.listing = Auctionator.Components.CreateResultsListing(dialog, dialog.provider, {
    emptyText = "Nothing recorded in this period.",
  })
  dialog.listing:SetPoint("TOPLEFT", dialog, "TOPLEFT", 14, -300)
  dialog.listing:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -14, 40)

  dialog.summary = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  dialog.summary:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 16, 18)
  dialog.summary:SetPoint("RIGHT", dialog.closeButton, "LEFT", -8, 0)
  dialog.summary:SetJustifyH("LEFT")
  dialog.summary:SetText("Click a bar to look at that day or hours. Sales come from the auction house mail; purchases, deposits and vendor sales are recorded as they happen.")
  return dialog
end

local function GetSlot(chart, index)
  local slot = chart.slots[index]
  if slot ~= nil then
    return slot
  end
  slot = CreateFrame("Button", nil, chart)
  slot.today = slot:CreateTexture(nil, "BACKGROUND")
  slot.today:SetAllPoints(slot)
  slot.today:SetTexture(1, 0.82, 0, 0.12)
  slot.up = slot:CreateTexture(nil, "ARTWORK")
  slot.up:SetTexture(0.15, 0.85, 0.2, 0.85)
  slot.down = slot:CreateTexture(nil, "ARTWORK")
  slot.down:SetTexture(0.9, 0.2, 0.2, 0.85)
  slot:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
  slot.label = slot:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  slot.label:SetPoint("TOP", slot, "BOTTOM", 0, -2)
  slot:SetScript("OnEnter", function()
    GameTooltip:SetOwner(slot, "ANCHOR_RIGHT")
    GameTooltip:SetText(slot.title or "")
    GameTooltip:AddDoubleLine("Earned", Money(slot.earned or 0), 1, 1, 1, 0.2, 1, 0.2)
    GameTooltip:AddDoubleLine("Spent", Money(slot.spent or 0), 1, 1, 1, 1, 0.3, 0.3)
    GameTooltip:AddDoubleLine("Net", Signed((slot.earned or 0) - (slot.spent or 0)), 1, 1, 1)
    GameTooltip:AddLine("Click: look at this part only", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
  slot:SetScript("OnClick", function()
    if goldDialog == nil or slot.from == nil then
      return
    end
    table.insert(goldDialog.history, goldDialog.range)
    local span = slot.to - slot.from
    local days = math.floor(span / 86400 + 0.5)
    if days >= 2 then
      goldDialog.range = {
        from = slot.from, to = slot.to, bars = math.min(days, 30),
        label = date("%d %b", slot.from) .. " - " .. date("%d %b", slot.to - 1),
      }
    else
      goldDialog.range = {
        from = slot.from, to = slot.to,
        bars = span >= 86400 and 12 or 8,
        label = span >= 86400 and date("%a %d %b", slot.from)
          or (date("%a %d %b, %H:%M", slot.from) .. " - " .. date("%H:%M", slot.to)),
      }
    end
    Auctionator.Components.ShowGoldTracker()
  end)
  chart.slots[index] = slot
  return slot
end

local function Thousands(number)
  local text = tostring(number)
  while true do
    local changed
    text, changed = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    if changed == 0 then
      return text
    end
  end
end

-- Value for the scale, as exact as the span of the scale needs it
local function ScaleText(copper, span)
  copper = math.floor(copper + 0.5)
  local gold = math.floor(copper / 10000)
  if span >= 30 * 10000 then
    return Thousands(math.floor(copper / 10000 + 0.5)) .. "g"
  elseif span >= 30 * 100 then
    return Thousands(gold) .. "g " .. math.floor(copper % 10000 / 100) .. "s"
  end
  return Thousands(gold) .. "g " .. math.floor(copper % 10000 / 100) .. "s " .. (copper % 100) .. "c"
end

-- Round step size for the scale (1, 2, 5, 10, 20, 50 ... copper)
local function NiceStep(span)
  local step = 1
  while true do
    for _, factor in ipairs({ 1, 2, 5 }) do
      if step * factor * 4 >= span then
        return step * factor
      end
    end
    step = step * 10
  end
end

-- The gold over the period as a line going up and down, drawn from small
-- dots (this client cannot draw slanted lines)
local function DrawGoldLine(chart, from, to, bars, now)
  for _, dot in ipairs(chart.dots) do
    dot:Hide()
  end
  goldModel = BuildGoldModel()
  local span = to - from
  local last = math.min(to, now)
  -- Points: the bar borders and every moment the gold changed
  local moments, seen = {}, {}
  local function AddMoment(moment)
    if moment >= from and moment <= last and not seen[moment] then
      seen[moment] = true
      table.insert(moments, moment)
    end
  end
  for index = 0, bars do
    AddMoment(math.min(from + index * span / bars, last))
  end
  for name, data in pairs(goldModel) do
    if trackedCharacter == nil or name == trackedCharacter then
      for _, move in ipairs(data.moves) do
        AddMoment(move.t)
      end
      for _, point in ipairs(data.points) do
        AddMoment(point.t)
      end
    end
  end
  table.sort(moments)
  local points = {}
  for _, moment in ipairs(moments) do
    local value = GoldAt(moment)
    if value ~= nil then
      table.insert(points, { x = (moment - from) / span * CHART_WIDTH, value = value })
    end
  end
  if #points < 2 then
    for index, label in ipairs(chart.axis) do
      label:SetText("")
      chart.grid[index]:Hide()
    end
    return
  end

  -- Scale fitted to the lowest and highest value, in round steps
  local low, high = points[1].value, points[1].value
  for _, point in ipairs(points) do
    low, high = math.min(low, point.value), math.max(high, point.value)
  end
  local step = NiceStep(math.max(high - low, 100))
  local bottom = math.floor(low / step) * step
  local top = bottom + 4 * step
  while top < high do
    step = NiceStep(step * 4 + 1)
    bottom = math.floor(low / step) * step
    top = bottom + 4 * step
  end
  for index = 1, 5 do
    local value = bottom + (index - 1) * step
    local y = 4 + (value - bottom) / (top - bottom) * (CHART_HEIGHT - 8)
    chart.axis[index]:ClearAllPoints()
    chart.axis[index]:SetPoint("RIGHT", chart, "BOTTOMLEFT", -6, y)
    chart.axis[index]:SetText(ScaleText(value, top - bottom))
    chart.grid[index]:ClearAllPoints()
    chart.grid[index]:SetPoint("LEFT", chart, "BOTTOMLEFT", 0, y)
    chart.grid[index]:SetPoint("RIGHT", chart, "BOTTOMRIGHT", 0, y)
    chart.grid[index]:Show()
  end
  local function Y(value)
    return 4 + (value - bottom) / (top - bottom) * (CHART_HEIGHT - 8)
  end

  local used = 0
  local function Dot(x, y, size)
    used = used + 1
    local dot = chart.dots[used]
    if dot == nil then
      dot = chart.line:CreateTexture(nil, "OVERLAY")
      dot:SetTexture(1, 0.82, 0, 1)
      chart.dots[used] = dot
    end
    dot:SetWidth(size)
    dot:SetHeight(size)
    dot:ClearAllPoints()
    dot:SetPoint("CENTER", chart, "BOTTOMLEFT", x, y)
    dot:Show()
  end
  for index = 1, #points - 1 do
    local x1, y1 = points[index].x, Y(points[index].value)
    local x2, y2 = points[index + 1].x, Y(points[index + 1].value)
    local steps = math.max(math.ceil(math.max(math.abs(x2 - x1), math.abs(y2 - y1)) / 1.5), 1)
    for part = 0, steps do
      Dot(x1 + (x2 - x1) * part / steps, y1 + (y2 - y1) * part / steps, 3)
      if used > 4000 then
        return
      end
    end
  end
  Dot(points[1].x, Y(points[1].value), 7)
  Dot(points[#points].x, Y(points[#points].value), 7)
end

function Auctionator.Components.ShowGoldTracker()
  if goldDialog == nil then
    goldDialog = CreateGoldDialog()
  end
  local dialog = goldDialog
  local range = dialog.range
  local now, realm = time(), GetRealmName()
  local from, to = range.from, range.to
  local slotSeconds = (to - from) / range.bars
  local earnedPer, spentPer = {}, {}
  for index = 1, range.bars do
    earnedPer[index], spentPer[index] = 0, 0
  end
  local sales, vendor, bought, deposits, sold, expired = 0, 0, 0, 0, 0, 0
  local entries = {}

  local function Use(record)
    if record.r ~= realm or record.t < from or record.t >= to then
      return
    end
    if trackedCharacter ~= nil and record.c ~= trackedCharacter then
      return
    end
    local index = math.max(1, math.min(range.bars, math.floor((record.t - from) / slotSeconds) + 1))
    local gold = record.g or 0
    if record.k == "s" then
      sales, sold = sales + gold, sold + 1
    elseif record.k == "v" then
      vendor = vendor + gold
    elseif record.k == "b" then
      bought = bought + gold
    elseif record.k == "d" then
      deposits = deposits + gold
    elseif record.k == "e" then
      expired = expired + 1
    end
    if INCOME[record.k] then
      earnedPer[index] = earnedPer[index] + gold
    elseif record.k ~= "e" then
      spentPer[index] = spentPer[index] + gold
    end
    local _, itemLink, quality, _, _, _, _, _, _, iconTexture = GetItemInfo(record.n or "")
    table.insert(entries, {
      name = record.n or "?", itemLink = itemLink, quality = quality, iconTexture = iconTexture,
      kind = record.k, kindText = KIND_TEXT[record.k] or record.k,
      quantity = record.q or "",
      gold = INCOME[record.k] and gold or -gold,
      goldText = record.k == "e" and "" or ((INCOME[record.k] and "|cff20ff20+|r " or "|cffff6060-|r ") .. Money(gold)),
      source = record.s or (record.k == "s" and "Mail" or ""),
      character = record.c or "",
      rawTime = record.t,
      date = date("%b %d, %H:%M", record.t),
    })
  end
  for _, record in ipairs((Auctionator.SavedState and Auctionator.SavedState.Sales) or {}) do
    Use(record)
  end
  for _, record in ipairs(GoldLogList() or {}) do
    Use(record)
  end

  -- Totals
  local spent = bought + deposits
  local auctionNet = sales - spent
  goldModel = BuildGoldModel()
  local startGold, startExact = GoldAt(from)
  local endGold = GoldAt(math.min(to, now))
  local lines = {}
  table.insert(lines, ("|cffffd100Start gold:|r %s%s     |cffffd100Spent:|r %s  (bought %s, deposits %s)"):format(
    startGold and Money(startGold) or "not recorded yet", (startGold and not startExact) and " *" or "",
    Money(spent), Money(bought), Money(deposits)))
  table.insert(lines, ("|cffffd100Got back:|r %s  (%d sold)     |cffffd100Vendor sales:|r %s     |cffffd100Auction house result:|r %s"):format(
    Money(sales), sold, Money(vendor), Signed(auctionNet)))
  if startGold and endGold then
    local change = endGold - startGold
    table.insert(lines, ("|cffffd100End gold:|r %s     |cffffd100Change:|r %s     |cffffd100Other (quests, loot, repairs...):|r %s%s"):format(
      Money(endGold), Signed(change), Signed(change - auctionNet - vendor),
      expired > 0 and ("     |cff909090" .. expired .. " expired|r") or ""))
  else
    table.insert(lines, ("|cffffd100Gold now:|r %s%s"):format(Money(endGold or GetMoney()),
      expired > 0 and ("     |cff909090" .. expired .. " expired|r") or ""))
  end
  -- Sniping (only where the tab exists), over everything recorded
  if AuctionarySnipingTabFrameMixin ~= nil and Auctionator.Config.Get(Auctionator.Config.Options.GOLD_TRACKER_SNIPING) then
    local ok, snipe = pcall(SnipingSummary, realm)
    if ok and snipe.bought > 0 then
      local vendorMade = snipe.vendorIncome - snipe.vendorCost
      local auctionMade = snipe.auctionIncome * Auctionator.Constants.AfterAHCut - snipe.auctionCost
      table.insert(lines, ("|cffffd100Sniping (all recorded):|r %d bought for %s     |cffffd100Vendored:|r %s     |cffffd100Resold:|r %s     |cffffd100Total:|r %s     |cff909090still held: %s|r"):format(
        snipe.bought, Money(snipe.cost), Signed(vendorMade), Signed(auctionMade), Signed(vendorMade + auctionMade), Money(snipe.heldCost)))
    end
  end
  dialog.totals:SetText(table.concat(lines, "\n"))
  dialog.characterButton:SetText("Gold of: " .. (trackedCharacter or "All characters")
    .. "  |TInterface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up:18:18:0:-2:32:32:6:26:6:26|t")
  dialog.periodButton:SetText("Period: " .. range.label .. "  |TInterface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up:18:18:0:-2:32:32:6:26:6:26|t")
  if #dialog.history > 0 then dialog.backButton:Show() else dialog.backButton:Hide() end

  -- Chart
  local chart = dialog.chart
  local largest = 1
  for index = 1, range.bars do
    largest = math.max(largest, earnedPer[index], spentPer[index])
  end
  local half = CHART_HEIGHT / 2 - 2
  local slotWidth = CHART_WIDTH / range.bars
  local labelEvery = range.bars > 12 and 3 or 1
  for _, slot in ipairs(chart.slots) do
    slot:Hide()
  end
  local today = Midnight(now)
  for index = 1, range.bars do
    local slot = GetSlot(chart, index)
    local slotStart = from + (index - 1) * slotSeconds
    slot.from, slot.to = slotStart, slotStart + slotSeconds
    slot:ClearAllPoints()
    slot:SetPoint("TOPLEFT", chart, "TOPLEFT", (index - 1) * slotWidth, 0)
    slot:SetWidth(slotWidth)
    slot:SetHeight(CHART_HEIGHT)
    local barWidth = math.max(slotWidth - 4, 2)
    slot.up:ClearAllPoints()
    slot.up:SetPoint("BOTTOM", slot, "CENTER", 0, 0)
    slot.up:SetWidth(barWidth)
    slot.up:SetHeight(math.max(half * earnedPer[index] / largest, 0.01))
    slot.down:ClearAllPoints()
    slot.down:SetPoint("TOP", slot, "CENTER", 0, 0)
    slot.down:SetWidth(barWidth)
    slot.down:SetHeight(math.max(half * spentPer[index] / largest, 0.01))
    slot.earned, slot.spent = earnedPer[index], spentPer[index]
    slot.title = (slotSeconds >= 2 * 86400 - 1 and (date("%d %b", slotStart) .. " - " .. date("%d %b", slotStart + slotSeconds - 1)))
      or slotSeconds >= 86400 and date("%A %d %b", slotStart)
      or (date("%b %d, %H:%M", slotStart) .. " - " .. date("%H:%M", slotStart + slotSeconds))
    -- Today (or the part that is going on now) stands out
    local current = now >= slotStart and now < slotStart + slotSeconds
    if current then
      slot.today:Show()
      slot.label:SetText("|cffffd100" .. ((slotSeconds >= 86400 and slotSeconds < 2 * 86400) and "Today" or "Now") .. "|r")
    else
      slot.today:Hide()
      slot.label:SetText((index - 1) % labelEvery == 0 and BarLabel(range, slotStart, slotSeconds) or "")
    end
    slot:Show()
  end
  pcall(DrawGoldLine, chart, from, to, range.bars, now)
  dialog.chartScale:SetText("Highest bar: " .. Money(largest) .. "   (green: sold incl. vendor, red: bought and deposits, |cffffd100gold line: gold on your characters|r)"
    .. ((startGold and not startExact) and "   * gold before the first record of a character is not known" or ""))

  table.sort(entries, function(a, b) return a.rawTime > b.rawTime end)
  dialog:Show()
  dialog.provider:SetEntries(entries)
  Auctionator.Compat.After(0.05, function()
    if dialog.listing:IsVisible() then
      dialog.listing:Refresh()
    end
  end)
end
