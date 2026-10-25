-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

-- The Selling tab: the sellable items of the bags on the left; on the right
-- the chosen item with stack size, number of stacks, price and duration, and
-- below that the auctions of the same item that are up right now.
local SellingTab = {}

local AuctionItemInfo = Auctionary.Constants.AuctionItemInfo
local Options = Auctionary.Config.Options

local BAG_COLUMNS = 5
local BAG_BUTTON_SIZE = 37
local BAG_SPACING = 3
local BAG_ROW_HEIGHT = BAG_BUTTON_SIZE + BAG_SPACING
local POST_TIMEOUT = 10
local GOOD_TO_SELL_FACTOR = 1.10
local BAD_TO_SELL_FACTOR = 0.90
local FRESH_SCAN_SECONDS = 30
local QUICK_SEARCH_LIMIT = 3
local DURATIONS = { 12, 24, 48 }

local UNSELLABLE_TEXTS = {}
for _, globalName in ipairs({
  "ITEM_SOULBOUND", "ITEM_BIND_QUEST", "ITEM_CONJURED", "ITEM_ACCOUNTBOUND", "ITEM_BIND_TO_ACCOUNT",
}) do
  if _G[globalName] ~= nil then
    table.insert(UNSELLABLE_TEXTS, _G[globalName])
  end
end

local PRICES_TABLE_LAYOUT = {
  {
    title = AUCTIONARY2_L_COL_BUYOUT or "Buyout Price",
    sort = "stackPrice", field = "stackPrice",
    kind = "price", width = 130,
  },
  {
    title = AUCTIONARY2_L_COL_UNIT_PRICE or "Unit Price",
    sort = "unitPrice", field = "unitPrice",
    kind = "price", width = 130,
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
    title = AUCTIONARY2_L_COL_OWN or "Owned?",
    sort = "ownedText", field = "ownedText",
    width = 70,
  },
}

local function Money(amount)
  return Auctionary.Compat.GetMoneyString(amount, true)
end

function SellingTab:OnLoad()
  Auctionary.EventBus:RegisterSource(self, "SellingTab")

  self.bagItems = {}
  self.bagButtons = {}

  self:CreateBagView()
  self:CreateSaleControls()
  self:CreatePrices()

  Auctionary.EventBus:Register(self, {
    Auctionary.AH.Events.ScanResultsUpdate,
    Auctionary.AH.Events.ScanAborted,
    Auctionary.AH.Events.CurrentPage,
  })

  -- Catches an item that is dragged from the bags into the window. It is
  -- only there while the cursor holds an item, so it never blocks clicks.
  self.DropCatcher = CreateFrame("Button", "Auctionary2SellingDropCatcher", self)
  self.DropCatcher:SetAllPoints(self)
  self.DropCatcher:SetFrameLevel((self:GetFrameLevel() or 0) + 30)
  self.DropCatcher:RegisterForClicks("LeftButtonUp")
  self.DropCatcher:SetScript("OnReceiveDrag", function() self:OnItemDropped() end)
  self.DropCatcher:SetScript("OnClick", function() self:OnItemDropped() end)
  self.DropCatcher:Hide()

  self:SetScript("OnEvent", self.OnEvent)
  self:SetScript("OnUpdate", self.OnUpdate)

  -- Tab / Shift-Tab walk through stack size, stacks and the price boxes
  local priceName = self.UnitPrice:GetName()
  local fields = { self.StackSize, self.NumStacks, _G[priceName .. "Gold"], _G[priceName .. "Silver"], _G[priceName .. "Copper"] }
  local function FocusField(index)
    local field = fields[((index - 1) % #fields) + 1]
    if field ~= nil then
      field:SetFocus()
      if field.HighlightText ~= nil then
        field:HighlightText()
      end
    end
  end
  self.StackSize:SetScript("OnTabPressed", function()
    FocusField(IsShiftKeyDown() and 5 or 2)
  end)
  self.NumStacks:SetScript("OnTabPressed", function()
    FocusField(IsShiftKeyDown() and 1 or 3)
  end)
  self.UnitPrice.previousFocus = self.NumStacks
  self.UnitPrice.nextFocus = self.StackSize

  self.keys = Auctionary.Keys.Create({
    TAB = function() FocusField(1) end,
    ["SHIFT-TAB"] = function() FocusField(5) end,
    LEFT = function() self:StepItem(-1) end,
    RIGHT = function() self:StepItem(1) end,
    UP = function() self:StepItem(-BAG_COLUMNS) end,
    DOWN = function() self:StepItem(BAG_COLUMNS) end,
  }, function(key)
    if key == "TAB" or key == "SHIFT-TAB" then
      return self:IsVisible() and self.selected ~= nil and not self.posting
    end
    return self:IsVisible() and not self.posting and Auctionary.Config.Get(Options.KEYS_SELLING)
  end)
  self:SetScript("OnShow", function()
    self:RegisterEvent("BAG_UPDATE")
    self:RegisterEvent("NEW_AUCTION_UPDATE")
    self:RefreshBags()
    self:UpdateControls()
  end)
  self:SetScript("OnHide", function()
    if self.enterBound and not (InCombatLockdown ~= nil and InCombatLockdown()) then
      ClearOverrideBindings(self)
      self.enterBound = false
    end
    self.repostActive = false
    self.repostDone = {}
    self:UnregisterEvent("BAG_UPDATE")
    self:UnregisterEvent("NEW_AUCTION_UPDATE")
    self:StopSearch()
    if not self.posting then
      self:ClearSelection()
    end
  end)
end

---- Bag view

function SellingTab:CreateBagView()
  self.BagFrame = CreateFrame("Frame", nil, self)
  self.BagFrame:SetPoint("TOPLEFT", self, "TOPLEFT", 26, -82)
  self.BagFrame:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 26, 44)
  self.BagFrame:SetWidth(BAG_COLUMNS * BAG_ROW_HEIGHT + 22)

  self.BagScroll = CreateFrame("ScrollFrame", "Auctionary2SellingBagScroll", self.BagFrame, "FauxScrollFrameTemplate")
  self.BagScroll:SetPoint("TOPLEFT", self.BagFrame, "TOPLEFT", 0, 0)
  self.BagScroll:SetPoint("BOTTOMRIGHT", self.BagFrame, "BOTTOMRIGHT", -22, 0)
  self.BagScroll:SetScript("OnVerticalScroll", function(scrollFrame, offset)
    FauxScrollFrame_OnVerticalScroll(scrollFrame, offset, BAG_ROW_HEIGHT, function()
      self:UpdateBagButtons()
    end)
  end)
  self.BagFrame:EnableMouseWheel(true)
  self.BagFrame:SetScript("OnMouseWheel", function(_, delta)
    local scrollBar = _G["Auctionary2SellingBagScrollScrollBar"]
    scrollBar:SetValue(scrollBar:GetValue() - delta * BAG_ROW_HEIGHT)
  end)

  self.BagEmptyText = self.BagFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  self.BagEmptyText:SetPoint("TOP", self.BagFrame, "TOP", -10, -40)
  self.BagEmptyText:SetWidth(180)
  self.BagEmptyText:SetText("Nothing in your bags can be auctioned.")
  self.BagEmptyText:Hide()
end

function SellingTab:GetBagRows()
  local height = self.BagFrame:GetHeight()
  if height == nil or height <= 0 then
    return 7
  end
  return math.max(math.floor(height / BAG_ROW_HEIGHT), 1)
end

function SellingTab:GetBagButton(index)
  local button = self.bagButtons[index]
  if button ~= nil then
    return button
  end

  local name = "Auctionary2SellingBagItem" .. index
  button = CreateFrame("Button", name, self.BagFrame, "ItemButtonTemplate")
  local row = math.floor((index - 1) / BAG_COLUMNS)
  local column = (index - 1) % BAG_COLUMNS
  button:SetPoint("TOPLEFT", self.BagFrame, "TOPLEFT", column * BAG_ROW_HEIGHT, -row * BAG_ROW_HEIGHT)
  button.iconTexture = _G[name .. "IconTexture"]
  button.countText = _G[name .. "Count"]

  button.selectedTexture = button:CreateTexture(nil, "OVERLAY")
  button.selectedTexture:SetTexture("Interface\\Buttons\\CheckButtonHilight")
  button.selectedTexture:SetBlendMode("ADD")
  button.selectedTexture:SetAllPoints(button)
  button.selectedTexture:Hide()

  -- Border in the item's quality colour (green and better)
  button.qualityBorder = button:CreateTexture(nil, "ARTWORK")
  button.qualityBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  button.qualityBorder:SetBlendMode("ADD")
  button.qualityBorder:SetWidth(68)
  button.qualityBorder:SetHeight(68)
  button.qualityBorder:SetPoint("CENTER", button, "CENTER", 0, 1)
  button.qualityBorder:Hide()

  button.favouriteTexture = button:CreateTexture(nil, "OVERLAY")
  button.favouriteTexture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
  button.favouriteTexture:SetWidth(14)
  button.favouriteTexture:SetHeight(14)
  button.favouriteTexture:SetPoint("TOPRIGHT", button, "TOPRIGHT", 2, 2)
  button.favouriteTexture:Hide()

  -- Green dot: the price is well above the item's average right now
  button.goodTexture = button:CreateTexture(nil, "OVERLAY")
  button.goodTexture:SetTexture("Interface\\FriendsFrame\\StatusIcon-Online")
  button.goodTexture:SetWidth(14)
  button.goodTexture:SetHeight(14)
  button.goodTexture:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
  button.goodTexture:Hide()

  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:SetScript("OnClick", function(_, mouseButton)
    if button.item ~= nil and mouseButton == "RightButton" then
      self:ToggleFavourite(button.item)
      return
    end
    if button.item ~= nil then
      if IsModifiedClick("CHATLINK") and ChatEdit_InsertLink(button.item.itemLink) then
        return
      end
      if button.item.missing then
        self:SetStatus(button.item.name .. " is a favourite, but you have none in your bags.")
        return
      end
      self.repostActive = false
      self:SelectItem(button.item)
    end
  end)
  button:SetScript("OnEnter", function()
    if button.item ~= nil then
      local location = button.item.locations[1]
      GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
      if location ~= nil then
        GameTooltip:SetBagItem(location.bag, location.slot)
      else
        GameTooltip:SetHyperlink(button.item.itemLink)
        GameTooltip:AddLine("Favourite - none in your bags", 1, 0.3, 0.3)
      end
      if button.item.badPercent ~= nil then
        GameTooltip:AddLine("Cheap right now: " .. button.item.badPercent .. "% below its average", 1, 0.55, 0.1)
      end
      if button.item.goodPercent ~= nil then
        GameTooltip:AddLine("Good to sell: " .. button.item.goodPercent .. "% above its average", 0.2, 1, 0.2)
      end
      GameTooltip:AddLine(self:IsFavourite(button.item) and "Right-click: remove from favourites"
        or "Right-click: add to favourites (listed first)", 0.5, 0.5, 0.5)
      GameTooltip:Show()
    end
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  self.bagButtons[index] = button
  return button
end

local function GroupKey(itemLink)
  return itemLink:match("item:(%-?%d+:%-?%d*:%-?%d*:%-?%d*:%-?%d*:%-?%d*:%-?%d*)") or itemLink
end

-- Favourites are remembered by item ID and suffix
local function FavouriteKey(item)
  return item.itemLink:match("item:(%-?%d+)") .. ":" .. (item.itemLink:match("item:%-?%d+:%-?%d*:%-?%d*:%-?%d*:%-?%d*:%-?%d*:(%-?%d*)") or "")
end

function SellingTab:IsFavourite(item)
  local favourites = Auctionary.Config.Get(Options.SELLING_FAVOURITE_KEYS) or {}
  return favourites[FavouriteKey(item)] ~= nil
end

function SellingTab:ToggleFavourite(item)
  local favourites = Auctionary.Config.Get(Options.SELLING_FAVOURITE_KEYS) or {}
  local key = FavouriteKey(item)
  if favourites[key] ~= nil then
    favourites[key] = nil
  else
    -- The link is kept so the item can be shown while it is not in the bags
    favourites[key] = item.itemLink
  end
  Auctionary.Config.Set(Options.SELLING_FAVOURITE_KEYS, favourites)
  GameTooltip:Hide()
  self:RefreshBags()
end

-- One entry per kind of item that can be auctioned
function SellingTab:ScanBags()
  local items, byKey = {}, {}
  local tooltip

  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) do
      local itemLink = GetContainerItemLink(bag, slot)
      if itemLink ~= nil then
        local texture, count = GetContainerItemInfo(bag, slot)
        local key = GroupKey(itemLink)
        local item = byKey[key]
        if item == nil then
          tooltip = Auctionary.Compat.GetScanTooltip()
          tooltip:SetBagItem(bag, slot)
          if not Auctionary.Compat.ScanTooltipHasLine(tooltip, UNSELLABLE_TEXTS) then
            local name, _, quality, _, _, _, _, maxStack = GetItemInfo(itemLink)
            if name ~= nil then
              item = {
                key = key,
                itemLink = itemLink,
                name = name,
                quality = quality,
                iconTexture = texture,
                maxStack = maxStack or 1,
                classID = Auctionary.Compat.GetItemClassID(itemLink) or 99,
                total = 0,
                locations = {},
              }
              table.insert(items, item)
            end
          end
          -- false: looked at, not sellable
          byKey[key] = item or false
        end
        if item then
          item.total = item.total + (count or 1)
          table.insert(item.locations, { bag = bag, slot = slot, count = count or 1 })
        end
      end
    end
  end

  -- Good to sell: the latest scan (today or yesterday) saw the item at least
  -- 10% above its average
  if Auctionary.Database ~= nil then
    local days = Auctionary.Config.Get(Options.AUCTION_MEAN_DAYS_LIMIT)
    for _, item in ipairs(items) do
      item.goodPercent = nil
      item.badPercent = nil
      Auctionary.Utilities.DBKeyFromLink(item.itemLink, function(dbKeys)
        local dbKey = dbKeys[1]
        if dbKey == nil then
          return
        end
        local price = Auctionary.Database:GetPrice(dbKey)
        local average = Auctionary.Database:GetScanAverage(dbKey, days)
        local age = Auctionary.Database:GetPriceAge(dbKey)
        if price ~= nil and average ~= nil and average > 0 and age ~= nil and age <= 1 then
          if price >= average * GOOD_TO_SELL_FACTOR then
            item.goodPercent = math.floor(price / average * 100 - 100 + 0.5)
          elseif price <= average * BAD_TO_SELL_FACTOR then
            item.badPercent = math.floor(100 - price / average * 100 + 0.5)
          end
        end
      end)
    end
  end

  local favourites = Auctionary.Config.Get(Options.SELLING_FAVOURITE_KEYS) or {}
  local present = {}
  for _, item in ipairs(items) do
    local favouriteKey = FavouriteKey(item)
    item.isFavourite = favourites[favouriteKey] ~= nil
    item.missing = false
    present[favouriteKey] = true
    if favourites[favouriteKey] == true then
      favourites[favouriteKey] = item.itemLink -- saved by an older version
    end
  end
  -- Favourites that are not in the bags right now stay visible, greyed out
  for favouriteKey, itemLink in pairs(favourites) do
    if not present[favouriteKey] and type(itemLink) == "string" then
      local name, _, quality, _, _, _, _, maxStack, _, texture = GetItemInfo(itemLink)
      if name ~= nil then
        table.insert(items, {
          key = "missing:" .. favouriteKey,
          itemLink = itemLink,
          name = name,
          quality = quality,
          iconTexture = texture,
          maxStack = maxStack or 1,
          classID = Auctionary.Compat.GetItemClassID(itemLink) or 99,
          total = 0,
          locations = {},
          isFavourite = true,
          missing = true,
        })
      end
    end
  end
  table.sort(items, function(a, b)
    if a.isFavourite ~= b.isFavourite then
      return a.isFavourite
    end
    if a.missing ~= b.missing then
      return b.missing
    end
    if a.classID ~= b.classID then
      return a.classID < b.classID
    end
    return a.name < b.name
  end)
  return items
end

function SellingTab:RefreshBags()
  self.bagsDirty = false
  self.bagItems = self:ScanBags()

  -- Keep the selection on the same kind of item
  if self.selected ~= nil then
    local stillThere = nil
    for _, item in ipairs(self.bagItems) do
      if item.key == self.selected.key then
        stillThere = item
        break
      end
    end
    if stillThere ~= nil then
      self.selected = stillThere
    elseif not self.posting then
      self:ClearSelection()
    end
  end

  if #self.bagItems == 0 then
    self.BagEmptyText:Show()
  else
    self.BagEmptyText:Hide()
  end
  self:UpdateBagButtons()
end

function SellingTab:UpdateBagButtons()
  local rows = self:GetBagRows()
  local totalRows = math.ceil(#self.bagItems / BAG_COLUMNS)
  FauxScrollFrame_Update(self.BagScroll, totalRows, rows, BAG_ROW_HEIGHT)
  local offset = FauxScrollFrame_GetOffset(self.BagScroll)

  for index = 1, rows * BAG_COLUMNS do
    local button = self:GetBagButton(index)
    local item = self.bagItems[index + offset * BAG_COLUMNS]
    button.item = item
    if item == nil then
      button:Hide()
    else
      button.iconTexture:SetTexture(item.iconTexture)
      if item.total > 1 then
        button.countText:SetText(item.total)
        button.countText:Show()
      else
        button.countText:Hide()
      end
      if button.iconTexture.SetDesaturated ~= nil then
        button.iconTexture:SetDesaturated(item.missing and true or false)
      end
      button.iconTexture:SetVertexColor(item.missing and 0.5 or 1, item.missing and 0.5 or 1, item.missing and 0.5 or 1)
      if (item.quality or 0) >= 2 then
        local r, g, b = GetItemQualityColor(item.quality)
        button.qualityBorder:SetVertexColor(r, g, b, item.missing and 0.4 or 0.9)
        button.qualityBorder:Show()
      else
        button.qualityBorder:Hide()
      end
      if item.goodPercent ~= nil and not item.missing then
        button.goodTexture:SetTexture("Interface\\FriendsFrame\\StatusIcon-Online")
        button.goodTexture:SetVertexColor(1, 1, 1)
        button.goodTexture:Show()
      elseif item.badPercent ~= nil and not item.missing then
        -- Orange dot: cheaper than usual right now, better wait
        -- The yellow "away" dot, tinted towards orange
        button.goodTexture:SetTexture("Interface\\FriendsFrame\\StatusIcon-Away")
        button.goodTexture:SetVertexColor(1, 0.6, 0.25)
        button.goodTexture:Show()
      else
        button.goodTexture:Hide()
      end
      if item.isFavourite then
        button.favouriteTexture:Show()
      else
        button.favouriteTexture:Hide()
      end
      if self.selected ~= nil and self.selected.key == item.key then
        button.selectedTexture:Show()
      else
        button.selectedTexture:Hide()
      end
      button:Show()
    end
  end
  for index = rows * BAG_COLUMNS + 1, #self.bagButtons do
    self.bagButtons[index]:Hide()
  end
end

---- Sale controls

local function Label(parent, text, x, y)
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  label:SetText(text)
  return label
end

function SellingTab:CreateSaleControls()
  local onChanged = function()
    self:UpdateControls()
  end

  self.ItemIcon = self:CreateTexture(nil, "ARTWORK")
  self.ItemIcon:SetWidth(30)
  self.ItemIcon:SetHeight(30)
  self.ItemIcon:SetPoint("TOPLEFT", self, "TOPLEFT", 88, -40)
  self.ItemIcon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")

  self.ItemName = self:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  self.ItemName:SetPoint("LEFT", self.ItemIcon, "RIGHT", 8, 0)
  self.ItemName:SetText("Choose or drag an item")

  -- The item's tooltip when the mouse is over the icon or the name
  self.IconHover = CreateFrame("Button", nil, self)
  self.IconHover:SetPoint("TOPLEFT", self.ItemIcon, "TOPLEFT", 0, 0)
  self.IconHover:SetPoint("BOTTOMLEFT", self.ItemIcon, "BOTTOMLEFT", 0, 0)
  self.IconHover:SetPoint("RIGHT", self.ItemName, "RIGHT", 0, 0)
  self.IconHover:SetScript("OnEnter", function(hover)
    if self.selected ~= nil then
      GameTooltip:SetOwner(hover, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink(self.selected.itemLink)
      GameTooltip:Show()
    end
  end)
  self.IconHover:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  self.Status = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  self.Status:SetPoint("LEFT", self.ItemName, "RIGHT", 14, 0)
  self.Status:SetPoint("RIGHT", self, "RIGHT", -150, 0)
  self.Status:SetJustifyH("LEFT")

  self.PostButton = CreateFrame("Button", "Auctionary2SellingPostButton", self, "UIPanelButtonTemplate")
  self.PostButton:SetWidth(110)
  self.PostButton:SetHeight(22)
  self.PostButton:SetPoint("TOPRIGHT", self, "TOPRIGHT", -36, -44)
  self.PostButton:SetText((AUCTIONARY2_L_POST or "Post") .. " (Enter)")
  self.PostButton:SetScript("OnClick", function()
    self:Post()
  end)

  self.HistoryButton = CreateFrame("Button", "Auctionary2SellingHistoryButton", self, "UIPanelButtonTemplate")
  self.HistoryButton:SetWidth(90)
  self.HistoryButton:SetHeight(22)
  self.HistoryButton:SetPoint("RIGHT", self.PostButton, "LEFT", -4, 0)
  self.HistoryButton:SetText("History")
  self.HistoryButton:SetScript("OnClick", function()
    if self.selected ~= nil then
      Auctionary.Components.ShowHistory(self.selected.itemLink, IsShiftKeyDown() and "posting" or "price")
    else
      -- Nothing chosen: everything that was posted
      Auctionary.Components.ShowAllPostings()
    end
  end)
  self.HistoryButton:SetScript("OnEnter", function(button)
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText("Price history of the chosen item (Shift-click: what you posted it for). Without an item: everything you posted.", 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  self.HistoryButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

  self.SalesButton = CreateFrame("Button", "Auctionary2SellingSalesButton", self, "UIPanelButtonTemplate")
  self.SalesButton:SetWidth(60)
  self.SalesButton:SetHeight(22)
  self.SalesButton:SetPoint("RIGHT", self.HistoryButton, "LEFT", -4, 0)
  self.SalesButton:SetText("Sales")
  self.SalesButton:SetScript("OnClick", function()
    Auctionary.Components.ShowSales()
  end)
  self.SalesButton:SetScript("OnEnter", function(button)
    GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
    GameTooltip:SetText("What sold and what expired, read from your auction house mail.\nOpen the mailbox so new mail gets counted.", 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  self.SalesButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Walks through the items worth posting again, one after the other
  self.PostNextButton = CreateFrame("Button", "Auctionary2SellingPostNextButton", self, "UIPanelButtonTemplate")
  self.PostNextButton:SetWidth(90)
  self.PostNextButton:SetHeight(22)
  self.PostNextButton:SetPoint("RIGHT", self.SalesButton, "LEFT", -4, 0)
  self.PostNextButton:SetText("Post Next")
  self.PostNextButton:SetScript("OnClick", function()
    self:PostNext(true)
  end)
  self.PostNextButton:SetScript("OnEnter", function(button)
    GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Repost round: selects the next item you posted before or marked as a favourite.\nPost it (Enter) and the next one follows by itself. Click again to skip an item.", 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  self.PostNextButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

  self:CreateBuyCheapButton()

  -- The status text ends where the buttons begin (two lines if needed)
  self.Status:ClearAllPoints()
  self.Status:SetPoint("LEFT", self.ItemName, "RIGHT", 14, 0)
  self.Status:SetPoint("RIGHT", self.BuyCheapButton, "LEFT", -8, 0)
  self.Status:SetHeight(24)

  -- Row 1: stack size, number of stacks, unit price
  local row1 = -90
  Label(self, "Stack Size", 256, row1)
  self.StackSize = CreateFrame("EditBox", "Auctionary2SellingStackSize", self, "InputBoxTemplate")
  self.StackSize:SetWidth(40)
  self.StackSize:SetHeight(20)
  self.StackSize:SetPoint("TOPLEFT", self, "TOPLEFT", 322, row1 + 5)
  self.StackSize:SetAutoFocus(false)
  self.StackSize:SetNumeric(true)
  self.StackSize:SetMaxLetters(4)

  Label(self, "Stacks", 376, row1)
  self.NumStacks = CreateFrame("EditBox", "Auctionary2SellingNumStacks", self, "InputBoxTemplate")
  self.NumStacks:SetWidth(40)
  self.NumStacks:SetHeight(20)
  self.NumStacks:SetPoint("TOPLEFT", self, "TOPLEFT", 422, row1 + 5)
  self.NumStacks:SetAutoFocus(false)
  self.NumStacks:SetNumeric(true)
  self.NumStacks:SetMaxLetters(4)

  for _, box in ipairs({ self.StackSize, self.NumStacks }) do
    box:SetScript("OnTextChanged", onChanged)
    box:SetScript("OnEscapePressed", function(editBox) editBox:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(editBox)
      editBox:ClearFocus()
      if Auctionary.Config.Get(Options.SELLING_POST_ON_ENTER) then
        self:Post()
      end
    end)
  end

  self.MaxButton = CreateFrame("Button", "Auctionary2SellingMaxButton", self, "UIPanelButtonTemplate")
  self.MaxButton:SetWidth(44)
  self.MaxButton:SetHeight(20)
  self.MaxButton:SetPoint("LEFT", self.NumStacks, "RIGHT", 6, 0)
  self.MaxButton:SetText(AUCTIONARY2_L_MAX or "Max")
  self.MaxButton:SetScript("OnClick", function()
    local stackSize = self.StackSize:GetNumber()
    if self.selected ~= nil and stackSize > 0 then
      self.NumStacks:SetText(math.max(math.floor(self.selected.total / stackSize), 1))
    end
  end)

  Label(self, AUCTIONARY2_L_COL_UNIT_PRICE or "Unit Price", 532, row1)
  self.UnitPrice = CreateFrame("Frame", "Auctionary2SellingUnitPrice", self, "MoneyInputFrameTemplate")
  self.UnitPrice:SetPoint("TOPLEFT", self, "TOPLEFT", 600, row1 + 5)
  MoneyInputFrame_SetOnValueChangedFunc(self.UnitPrice, onChanged)
  -- Enter in one of the price boxes posts as well
  for _, suffix in ipairs({ "Gold", "Silver", "Copper" }) do
    local box = _G["Auctionary2SellingUnitPrice" .. suffix]
    if box ~= nil and box.SetScript ~= nil then
      box:SetScript("OnEnterPressed", function(editBox)
        editBox:ClearFocus()
        if Auctionary.Config.Get(Options.SELLING_POST_ON_ENTER) then
          self:Post()
        end
      end)
    end
  end

  -- Row 2: duration, deposit, total
  local row2 = -118
  Label(self, AUCTIONARY2_L_DURATION or "Duration", 256, row2)
  self.DurationButtons = {}
  for index, hours in ipairs(DURATIONS) do
    local name = "Auctionary2SellingDuration" .. hours
    local radio = CreateFrame("CheckButton", name, self, "UIRadioButtonTemplate")
    radio:SetPoint("TOPLEFT", self, "TOPLEFT", 322 + (index - 1) * 50, row2 + 2)
    local hoursLabel = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hoursLabel:SetPoint("LEFT", radio, "RIGHT", 3, 0)
    hoursLabel:SetText(tostring(hours))
    radio:SetScript("OnClick", function()
      self:SetDuration(hours)
      Auctionary.Config.Set(Options.AUCTION_DURATION, hours)
    end)
    self.DurationButtons[hours] = radio
  end

  Label(self, AUCTIONARY2_L_DEPOSIT or "Deposit:", 486, row2)
  self.DepositText = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  self.DepositText:SetPoint("TOPLEFT", self, "TOPLEFT", 536, row2)

  Label(self, AUCTIONARY2_L_TOTAL or "Total Price:", 636, row2)
  self.TotalText = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  self.TotalText:SetPoint("TOPLEFT", self, "TOPLEFT", 706, row2)

  local duration = Auctionary.Config.Get(Options.AUCTION_DURATION)
  if Auctionary.Constants.DurationToRunTime[duration] == nil then
    duration = 24
  end
  self:SetDuration(duration)
end

function SellingTab:SetDuration(hours)
  self.duration = hours
  for buttonHours, radio in pairs(self.DurationButtons) do
    radio:SetChecked(buttonHours == hours)
  end
  self:UpdateControls()
end

function SellingTab:SetStatus(text)
  self.Status:SetText(text or "")
end

---- Current prices

function SellingTab:CreatePrices()
  self.priceSet = Auctionary.Components.CreateRowSet({
    columns = PRICES_TABLE_LAYOUT,
    rowKey = function(entry) return entry.key end,
    sorters = {
      unitPrice = Auctionary.Utilities.NumberComparator,
      stackPrice = Auctionary.Utilities.NumberComparator,
      stackSize = Auctionary.Utilities.NumberComparator,
      owner = Auctionary.Utilities.StringComparator,
      ownedText = Auctionary.Utilities.StringComparator,
    },
  })
  self.priceTable = Auctionary.Components.CreateTable(self, self.priceSet, {
    onRowClick = function(rowData)
      -- Price yourself against this auction
      if rowData.isOwned then
        self:SetUnitPrice(rowData.unitPrice)
      else
        self:SetUnitPrice(self:Undercut(rowData.unitPrice))
      end
    end,
    emptyText = "",
  })
  self.priceTable:SetPoint("TOPLEFT", self, "TOPLEFT", 254, -142)
  self.priceTable:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -14, 44)
end

-- The price to post at to be cheaper than the given one
function SellingTab:Undercut(price)
  local result
  if Auctionary.Config.Get(Options.AUCTION_SALES_PREFERENCE) == Auctionary.Config.SalesTypes.STATIC then
    result = price - Auctionary.Config.Get(Options.UNDERCUT_STATIC_VALUE)
  else
    result = math.floor(price * (100 - Auctionary.Config.Get(Options.UNDERCUT_PERCENTAGE)) / 100)
  end
  -- Nothing configured: one copper less, the usual way to be first in the list
  if result >= price then
    result = price - 1
  end
  return math.max(result, 1)
end

function SellingTab:SetUnitPrice(price)
  MoneyInputFrame_SetCopper(self.UnitPrice, math.max(math.floor(price or 0), 0))
  self:UpdateControls()
end

function SellingTab:StopSearch()
  if self.searching then
    self.searching = false
    Auctionary.AH.AbortQuery()
  end
end

function SellingTab:SearchPrices()
  local item = self.selected
  if item == nil then
    return
  end
  self:StopSearch()
  self.searchAuctions = {}
  self.searching = true
  self.searchKey = item.key
  self.priceSet:Replace({})
  self.priceRows = nil
  self.buyLocating = nil
  self:UpdateBuyCheapButton()
  self:SetStatus((SEARCHING or "Searching") .. " ...")
  Auctionary.AH.QueryAuctionItems({ searchString = item.name, isExact = true })
end

function SellingTab:ReceiveEvent(eventName, results, gotAllResults)
  if eventName == Auctionary.AH.Events.CurrentPage then
    self:BuyCheapPageLoaded()
    return
  end
  if not self.searching then
    return
  end

  if eventName == Auctionary.AH.Events.ScanResultsUpdate then
    for _, auction in ipairs(results) do
      -- Same name, but only the same item (and suffix) is a competitor
      if GroupKey(auction.itemLink) == self.searchKey then
        table.insert(self.searchAuctions, auction)
      end
    end
    if gotAllResults then
      self.searching = false
      self:ShowPrices()
    end
  elseif eventName == Auctionary.AH.Events.ScanAborted then
    self.searching = false
    self:SetStatus("")
  end
end

function SellingTab:ShowPrices()
  local item = self.selected
  if item == nil or item.key ~= self.searchKey then
    return
  end
  self.quickDeadline = nil
  -- Taken before this search's lowest price goes into the database
  local usual = self:UsualPrice(item)
  self.baitLimit = nil

  local rows = Auctionary.Buying.GroupAuctions(self.searchAuctions)
  local total = 0
  for _, row in ipairs(rows) do
    row.ownedText = row.isOwned and (AUCTIONARY2_L_YES or YES) or ""
    total = total + #row.auctions * row.stackSize
  end
  self.priceSet:Replace(rows)
  self.priceRows = rows
  Auctionary.Compat.After(0, function() self:UpdateBuyCheapButton() end)

  local lowest = rows[1]
  if lowest ~= nil then
    local bait = self:FindBait(rows, usual)
    self.baitLimit = bait and bait.limit or nil
    -- All auctions of the item were seen: remember the lowest price that is
    -- not one of the player's own (and not bait)
    local market
    for _, row in ipairs(rows) do
      if not row.isOwned and (market == nil or row.unitPrice < market) then
        market = row.unitPrice
      end
    end
    if bait ~= nil and bait.normal ~= nil then
      market = bait.normal.unitPrice
    end
    if market ~= nil then
      Auctionary.Utilities.DBKeyFromLink(item.itemLink, function(dbKeys)
        if dbKeys[1] ~= nil then
          Auctionary.Database:SetPrice(dbKeys[1], market, total)
        end
      end)
    end

    for _, row in ipairs(rows) do
      if not row.isOwned then
        self.lowestOther = row.unitPrice
        break
      end
    end
    if bait ~= nil then
      self:PriceAroundBait(bait, rows)
    elseif lowest.isOwned then
      self:SetUnitPrice(lowest.unitPrice)
      self:SetStatus("You already have the lowest price.")
    else
      self:SetUnitPrice(self:Undercut(lowest.unitPrice))
      self:SetStatus("Lowest: " .. Money(lowest.unitPrice))
    end
  else
    -- No competition: 10% above the average price, else the last price seen
    local known, average
    Auctionary.Utilities.DBKeyFromLink(item.itemLink, function(dbKeys)
      known = Auctionary.Database:GetFirstPrice(dbKeys)
      if dbKeys[1] ~= nil then
        average = Auctionary.Database:GetScanAverage(
          dbKeys[1], Auctionary.Config.Get(Options.AUCTION_MEAN_DAYS_LIMIT)
        )
      end
    end)
    if average ~= nil and average > 0 then
      self:SetUnitPrice(math.floor(average * 1.1))
      self:SetStatus("None on the auction house. Price is the average (" .. Money(average) .. ") plus 10%.")
    else
      self:SetUnitPrice(known or 0)
      self:SetStatus(known and "None on the auction house. Price is the last one seen."
        or "None on the auction house and no known price. Enter a price.")
    end
  end
end

---- Scam sell protection
-- An auction far below the usual price is often bait: the seller hopes
-- others follow it down (and buys their cheap auctions), or it is a typo
-- that is gone a minute later. Such auctions are not undercut; the price
-- follows the first normal auction instead, with a warning.

-- Usual unit price: median of the daily prices of the last days (a few
-- odd days hardly move it), else their average
function SellingTab:UsualPrice(item)
  local usual
  Auctionary.Utilities.DBKeyFromLink(item.itemLink, function(dbKeys)
    if dbKeys[1] ~= nil then
      local days = Auctionary.Config.Get(Options.AUCTION_MEAN_DAYS_LIMIT)
      usual = Auctionary.Database:GetScanMedian(dbKeys[1], days)
        or Auctionary.Database:GetScanAverage(dbKeys[1], days)
    end
  end)
  return usual
end

-- Auctions of others below the protection limit (rows: cheapest first).
-- The reference is the median of the other sellers' prices when at least
-- three are listed (the market right now), else the price history.
function SellingTab:FindBait(rows, usual)
  if not Auctionary.Config.Get(Options.SELLING_SCAM_PROTECTION) then
    return nil
  end
  local others = {}
  for _, row in ipairs(rows) do
    if not row.isOwned then
      others[#others + 1] = row.unitPrice
    end
  end
  if #others >= 3 then
    usual = others[math.floor(#others / 2) + 1]
  end
  if usual == nil or usual <= 0 then
    return nil
  end
  local limit = math.floor(usual * Auctionary.Config.Get(Options.SELLING_SCAM_PERCENT) / 100)
  local bait = { count = 0, limit = limit, usual = usual }
  for _, row in ipairs(rows) do
    if not row.isOwned then
      if row.unitPrice >= limit then
        bait.normal = row
        break
      end
      bait.count = bait.count + #row.auctions
      bait.lowest = bait.lowest or row.unitPrice
    end
  end
  return bait.count > 0 and bait or nil
end

function SellingTab:PriceAroundBait(bait, rows)
  local percent = math.floor(bait.lowest / bait.usual * 100 + 0.5)
  local warning = "|cffff8000Scam sell protection:|r " .. bait.count .. (bait.count == 1 and " auction" or " auctions")
    .. " from " .. Money(bait.lowest) .. " (" .. percent .. "% of the usual " .. Money(bait.usual) .. ") not undercut. "
  -- Own auction cheaper than the first normal one: keep that price
  local ownBest
  for _, row in ipairs(rows) do
    if row.isOwned and row.unitPrice >= bait.limit then
      ownBest = row
      break
    end
  end
  if bait.normal ~= nil and not (ownBest ~= nil and ownBest.unitPrice <= bait.normal.unitPrice) then
    self.lowestOther = bait.normal.unitPrice
    self:SetUnitPrice(self:Undercut(bait.normal.unitPrice))
    self:SetStatus(warning .. "Price follows the next one (" .. Money(bait.normal.unitPrice) .. ").")
  elseif ownBest ~= nil then
    self:SetUnitPrice(ownBest.unitPrice)
    self:SetStatus(warning .. "You have the lowest normal price.")
  else
    self.lowestOther = bait.usual
    self:SetUnitPrice(bait.usual)
    self:SetStatus(warning .. "Price is the usual one.")
  end
end

---- Choosing an item

-- Takes whatever is in the auction house's sell slot back out
local function EmptySellSlot()
  if GetAuctionSellItemInfo() ~= nil then
    ClearCursor()
    ClickAuctionSellItemButton()
    ClearCursor()
  end
end

function SellingTab:ClearSelection()
  self.selected = nil
  self.sellInfo = nil
  EmptySellSlot()
  self.ItemIcon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
  self.ItemName:SetText("Choose or drag an item")
  self.StackSize:SetText("")
  self.NumStacks:SetText("")
  MoneyInputFrame_SetCopper(self.UnitPrice, 0)
  self.priceSet:Replace({})
  self.priceRows = nil
  self.buyLocating = nil
  if self.UpdateBuyCheapButton ~= nil then
    self:UpdateBuyCheapButton()
  end
  self:SetStatus("")
  self:UpdateBagButtons()
  self:UpdateControls()
end

-- Puts the item into the auction house's sell slot. Returns true on success.
function SellingTab:PlaceInSellSlot(item)
  EmptySellSlot()
  local location = item.locations[1]
  if location == nil then
    return false
  end
  ClearCursor()
  PickupContainerItem(location.bag, location.slot)
  ClickAuctionSellItemButton()
  ClearCursor()

  local name, _, _, _, _, _, _, stackCount, totalCount = GetAuctionSellItemInfo()
  if name == nil then
    return false
  end
  self.sellInfo = { maxStack = stackCount, total = totalCount }
  return true
end

function SellingTab:SelectItem(item)
  if self.posting then
    return
  end
  self:StopSearch()
  self.selected = item
  self.sellInfo = nil

  if not self:PlaceInSellSlot(item) then
    self.selected = nil
    self:SetStatus(Auctionary.Compat.Colors.RED_FONT_COLOR:WrapTextInColorCode(
      (ERR_AUCTION_BOUND_ITEM or "This item cannot be auctioned.")
    ))
    self:UpdateBagButtons()
    self:UpdateControls()
    return
  end

  -- The client knows these best
  if self.sellInfo.maxStack and self.sellInfo.maxStack > 0 then
    item.maxStack = self.sellInfo.maxStack
  end
  if self.sellInfo.total and self.sellInfo.total > 0 then
    item.total = self.sellInfo.total
  end

  self.ItemIcon:SetTexture(item.iconTexture)
  local _, _, _, hex = GetItemQualityColor(item.quality or 1)
  if hex ~= nil and string.sub(hex, 1, 2) ~= "|c" then
    hex = "|c" .. hex
  end
  self.ItemName:SetText((hex or "") .. item.name .. "|r  x" .. item.total)

  local stackSize = math.min(item.maxStack, item.total)
  -- Configured default for this kind of item (0 = a full stack)
  local defaults = Auctionary.Config.Get(Options.DEFAULT_QUANTITIES) or {}
  local default = tonumber(defaults[item.classID]) or 0
  if default > 0 then
    stackSize = math.min(default, stackSize)
  end
  local numStacks = math.max(math.floor(item.total / stackSize), 1)
  -- What was posted last time for this item wins over the defaults, as far
  -- as the bags allow it
  local state = Auctionary.SavedState
  local last = state ~= nil and state.LastQuantities ~= nil and state.LastQuantities[item.key]
  if type(last) == "table" and (tonumber(last[1]) or 0) > 0 then
    stackSize = math.max(math.min(last[1], item.maxStack, item.total), 1)
    numStacks = math.max(math.min(tonumber(last[2]) or 1, math.floor(item.total / stackSize)), 1)
  end
  self.lowPriceConfirmed = nil
  self.lowestOther = nil
  self.baitLimit = nil
  self.StackSize:SetText(stackSize)
  self.NumStacks:SetText(numStacks)
  MoneyInputFrame_SetCopper(self.UnitPrice, 0)

  self:UpdateBagButtons()
  self:UpdateControls()
  self:SearchPrices()
  self:UseFreshScanPrice(item)
end

-- Right after a full scan the saved price is as good as a new search: it is
-- filled in at once. The search still runs and replaces it when it is done
-- in time; after QUICK_SEARCH_LIMIT seconds it is stopped and the saved
-- price stays.
function SellingTab:UseFreshScanPrice(item)
  self.quickDeadline = nil
  local lastScan = Auctionary.State.LastFullScanTime
  if lastScan == nil or GetTime() - lastScan > FRESH_SCAN_SECONDS or Auctionary.Database == nil then
    return
  end
  local price
  Auctionary.Utilities.DBKeyFromLink(item.itemLink, function(dbKeys)
    if dbKeys[1] ~= nil and Auctionary.Database:GetPriceAge(dbKeys[1]) == 0 then
      price = Auctionary.Database:GetPrice(dbKeys[1])
    end
  end)
  if price == nil or price <= 0 then
    return
  end
  -- The scan's lowest may be bait; then the search decides
  if Auctionary.Config.Get(Options.SELLING_SCAM_PROTECTION) then
    local usual = self:UsualPrice(item)
    if usual ~= nil and price < usual * Auctionary.Config.Get(Options.SELLING_SCAM_PERCENT) / 100 then
      return
    end
  end
  self.lowestOther = price
  self:SetUnitPrice(self:Undercut(price))
  self.quickDeadline = GetTime() + QUICK_SEARCH_LIMIT
  self.quickPrice = price
  self:SetStatus("Lowest in the scan just now: " .. Money(price) .. "   (checking ...)")
end

---- Posting

function SellingTab:GetPostDetails()
  local item = self.selected
  if item == nil then
    return nil
  end
  local stackSize = self.StackSize:GetNumber()
  local numStacks = self.NumStacks:GetNumber()
  local unitPrice = MoneyInputFrame_GetCopper(self.UnitPrice)
  if stackSize < 1 or numStacks < 1 or unitPrice < 1 then
    return nil
  end
  if stackSize > item.maxStack then
    return nil, "A stack holds at most " .. item.maxStack .. "."
  end
  if stackSize * numStacks > item.total then
    return nil, "You only have " .. item.total .. "."
  end
  return {
    stackSize = stackSize,
    numStacks = numStacks,
    unitPrice = unitPrice,
    stackPrice = unitPrice * stackSize,
    runTime = Auctionary.Constants.DurationToRunTime[self.duration],
  }
end

-- While something can be posted the Enter key presses the Post button, also
-- when no input box has the focus. (Enter opens the chat again as soon as
-- the tab is left or nothing is ready to post.)
function SellingTab:UpdateEnterBinding()
  if InCombatLockdown ~= nil and InCombatLockdown() then
    return
  end
  local enabled = self.PostButton:IsEnabled()
  local useEnter = Auctionary.Config.Get(Options.SELLING_POST_ON_ENTER) and true or false
  local wanted = useEnter and self:IsVisible() and (enabled == 1 or enabled == true) and true or false
  if self.enterLabelShown ~= useEnter then
    self.enterLabelShown = useEnter
    self.PostButton:SetText((AUCTIONARY2_L_POST or "Post") .. (useEnter and " (Enter)" or ""))
  end
  if wanted and not self.enterBound then
    SetOverrideBindingClick(self, true, "ENTER", "Auctionary2SellingPostButton")
    self.enterBound = true
  elseif not wanted and self.enterBound then
    ClearOverrideBindings(self)
    self.enterBound = false
  end
end

function SellingTab:UpdateControls()
  self:UpdateControlsInner()
  if self.PostButton ~= nil and SetOverrideBindingClick ~= nil then
    self:UpdateEnterBinding()
  end
end

function SellingTab:UpdateControlsInner()
  if self.PostButton == nil or self.DepositText == nil or self.TotalText == nil then
    return -- still being built
  end

  local details, problem = self:GetPostDetails()
  if details ~= nil and not self.posting then
    local deposit = 0
    if GetAuctionSellItemInfo() ~= nil then
      deposit = CalculateAuctionDeposit(details.runTime, details.stackSize * details.numStacks) or 0
    end
    self.DepositText:SetText(Money(deposit))
    self.TotalText:SetText(Money(details.stackPrice * details.numStacks))
    if GetMoney() < deposit then
      self.PostButton:Disable()
      self:SetStatus(ERR_NOT_ENOUGH_MONEY or "Not enough money")
    else
      self.PostButton:Enable()
    end
  else
    self.DepositText:SetText("")
    self.TotalText:SetText("")
    self.PostButton:Disable()
    if problem ~= nil then
      self:SetStatus(Auctionary.Compat.Colors.RED_FONT_COLOR:WrapTextInColorCode(problem))
    end
  end
end

function SellingTab:GetLowPriceWarning(item, unitPrice)
  local vendorPrice = select(11, GetItemInfo(item.itemLink)) or 0
  if vendorPrice > 0 and unitPrice < vendorPrice then
    return "Below the vendor price (" .. Money(vendorPrice) .. ")."
  end
  -- After the 5% fee this brings in about what a vendor pays, without the wait
  if vendorPrice > 0 and unitPrice <= vendorPrice * 1.05 then
    return "Only " .. math.floor((unitPrice / vendorPrice - 1) * 100 + 0.5)
      .. "% above the vendor price (" .. Money(vendorPrice) .. "). After the 5% fee a vendor pays about the same."
  end
  local reference = self.lowestOther
  if reference == nil then
    Auctionary.Utilities.DBKeyFromLink(item.itemLink, function(dbKeys)
      if dbKeys[1] ~= nil then
        reference = Auctionary.Database:GetScanAverage(
          dbKeys[1], Auctionary.Config.Get(Options.AUCTION_MEAN_DAYS_LIMIT)
        )
      end
    end)
  end
  if reference ~= nil and reference > 0
     and unitPrice < Auctionary.Utilities.PriceWarningThreshold(reference) then
    return "Far below the market (" .. Money(reference) .. ")."
  end
end

-- Runs inside the click on the Post button
function SellingTab:Post()
  local item = self.selected
  local details = self:GetPostDetails()
  if item == nil or details == nil or self.posting then
    return
  end
  -- Far below the market or below what a vendor pays: ask for a second click
  local protect = Auctionary.Config.Get(Options.SELLING_SCAM_PROTECTION) and self.baitLimit ~= nil
    and details.unitPrice < self.baitLimit
  if Auctionary.Config.Get(Options.SELLING_WARN_LOW_PRICE) or protect then
    local warning
    if protect then
      warning = "Scam sell protection: this is below " .. Money(self.baitLimit)
        .. ", where auctions are suspiciously cheap."
    else
      warning = self:GetLowPriceWarning(item, details.unitPrice)
    end
    local token = item.key .. ":" .. details.unitPrice
    if warning ~= nil and self.lowPriceConfirmed ~= token then
      self.lowPriceConfirmed = token
      self:SetStatus(Auctionary.Compat.Colors.RED_FONT_COLOR:WrapTextInColorCode(
        warning .. " Click Post again to post anyway."
      ))
      return
    end
  end
  self.lowPriceConfirmed = nil
  self:StopSearch()

  -- The item may have been taken out of the slot in the meantime
  local name = GetAuctionSellItemInfo()
  if name ~= item.name then
    if not self:PlaceInSellSlot(item) then
      self:SetStatus(Auctionary.Compat.Colors.RED_FONT_COLOR:WrapTextInColorCode("Could not put the item up for sale."))
      return
    end
  end

  local deposit = 0
  if CalculateAuctionDeposit ~= nil then
    deposit = CalculateAuctionDeposit(details.runTime, details.stackSize * details.numStacks) or 0
  end
  self.posting = {
    item = item,
    details = details,
    deposit = deposit,
    startTime = GetTime(),
    created = 0,
  }
  self.PostButton:Disable()
  self:SetStatus("Posting ...")
  self:RegisterEvent("AUCTION_MULTISELL_START")
  self:RegisterEvent("AUCTION_MULTISELL_UPDATE")
  self:RegisterEvent("AUCTION_MULTISELL_FAILURE")
  self:RegisterEvent("AUCTION_OWNED_LIST_UPDATE")
  self:RegisterEvent("UI_ERROR_MESSAGE")

  -- Remembered per item for the next time it is selected
  if Auctionary.SavedState ~= nil and item.key ~= nil then
    Auctionary.SavedState.LastQuantities = Auctionary.SavedState.LastQuantities or {}
    Auctionary.SavedState.LastQuantities[item.key] = { details.stackSize, details.numStacks }
  end

  -- Starting bid equal to the buyout: nobody gets it cheaper by bidding
  StartAuction(details.stackPrice, details.stackPrice, details.runTime, details.stackSize, details.numStacks)
end

function SellingTab:FinishPosting(created, message)
  local posting = self.posting
  if posting == nil then
    return
  end
  self.posting = nil
  self:UnregisterEvent("AUCTION_MULTISELL_START")
  self:UnregisterEvent("AUCTION_MULTISELL_UPDATE")
  self:UnregisterEvent("AUCTION_MULTISELL_FAILURE")
  self:UnregisterEvent("AUCTION_OWNED_LIST_UPDATE")
  self:UnregisterEvent("UI_ERROR_MESSAGE")

  local details, item = posting.details, posting.item
  if created > 0 and Auctionary.GoldLog ~= nil and (posting.deposit or 0) > 0 then
    Auctionary.GoldLog.Add("d", item.name, item.itemLink, created * details.stackSize,
      math.floor(posting.deposit * created / math.max(details.numStacks, 1)), "Selling")
  end
  if created > 0 then
    local text = ("Posted %d x %d %s at %s each"):format(
      created, details.stackSize, item.itemLink, Money(details.unitPrice)
    )
    Auctionary.Utilities.Message(text)
    Auctionary.EventBus:Fire(self, Auctionary.Selling.Events.AuctionCreated, {
      itemLink = item.itemLink,
      quantity = created * details.stackSize,
      buyoutAmount = details.unitPrice,
      bidAmount = details.unitPrice,
    })
  end

  self:ClearSelection()
  self.bagsDirty = true
  if self.repostActive then
    -- Repost round: on to the next item once the bags have caught up
    self.repostDone = self.repostDone or {}
    self.repostDone[item.key] = true
    Auctionary.Compat.After(0.6, function()
      if self.repostActive and self:IsVisible() and not self.posting and self.selected == nil then
        self:PostNext(false)
      end
    end)
  end
  if created < details.numStacks then
    self:SetStatus(Auctionary.Compat.Colors.RED_FONT_COLOR:WrapTextInColorCode(
      message or ("Only " .. created .. " of " .. details.numStacks .. " stacks were posted.")
    ))
  else
    self:SetStatus(Auctionary.Compat.Colors.GREEN_FONT_COLOR:WrapTextInColorCode(
      "Posted " .. created .. " x " .. details.stackSize .. " " .. item.name
    ))
  end
end

function SellingTab:OnEvent(eventName, arg1, arg2)
  if eventName == "BAG_UPDATE" then
    self.bagsDirty = true
    return
  elseif eventName == "NEW_AUCTION_UPDATE" then
    self:UpdateControls()
    return
  end

  local posting = self.posting
  if posting == nil then
    return
  end

  if eventName == "AUCTION_MULTISELL_START" then
    posting.multisell = true
  elseif eventName == "AUCTION_MULTISELL_UPDATE" then
    posting.multisell = true
    posting.created = arg1 or posting.created
    posting.startTime = GetTime()
    self:SetStatus("Posting " .. posting.created .. " / " .. (arg2 or posting.details.numStacks))
    if arg1 ~= nil and arg2 ~= nil and arg1 >= arg2 then
      self:FinishPosting(arg1)
    end
  elseif eventName == "AUCTION_MULTISELL_FAILURE" then
    self:FinishPosting(posting.created)
  elseif eventName == "AUCTION_OWNED_LIST_UPDATE" then
    -- A single stack has no progress events; the item leaving the sell slot
    -- and the list of own auctions changing means it is up
    if not posting.multisell and posting.details.numStacks == 1 and GetAuctionSellItemInfo() == nil then
      self:FinishPosting(1)
    end
  elseif eventName == "UI_ERROR_MESSAGE" then
    self:FinishPosting(posting.created, arg1)
  end
end

function SellingTab:IsRepostCandidate(item)
  if item.missing or self.repostDone[item.key] then
    return false
  end
  local state = Auctionary.SavedState
  return item.isFavourite == true
    or (state ~= nil and state.LastQuantities ~= nil and state.LastQuantities[item.key] ~= nil)
end

-- byClick: the button was used (skips the selected item); otherwise this
-- follows a finished post
function SellingTab:PostNext(byClick)
  if self.posting then
    return
  end
  self.repostDone = self.repostDone or {}
  if byClick and self.selected ~= nil then
    self.repostDone[self.selected.key] = true
  end
  if self.bagsDirty then
    self:RefreshBags()
  end
  for _, item in ipairs(self.bagItems) do
    if self:IsRepostCandidate(item) then
      self.repostActive = true
      self:SelectItem(item)
      return
    end
  end
  local hadRound = self.repostActive
  self.repostActive = false
  self.repostDone = {}
  self:ClearSelection()
  self:SetStatus(hadRound and "Repost round finished: nothing left to post."
    or "Nothing to repost: no favourites and no items you posted before are in your bags.")
end

-- Arrow keys: the next item in the bag grid (left/right one, up/down a row)
function SellingTab:StepItem(delta)
  if self.posting or #self.bagItems == 0 then
    return
  end
  local current
  for index, item in ipairs(self.bagItems) do
    if self.selected ~= nil and item.key == self.selected.key then
      current = index
      break
    end
  end
  local target = current == nil and 1 or current + delta
  if target < 1 or target > #self.bagItems then
    return
  end
  -- Favourites that are not in the bags cannot be posted: skipped
  local step = delta >= 0 and 1 or -1
  while self.bagItems[target] ~= nil and self.bagItems[target].missing do
    target = target + step
  end
  local item = self.bagItems[target]
  if item == nil then
    return
  end
  self.repostActive = false
  self:SelectItem(item)
  local row = math.ceil(target / BAG_COLUMNS)
  local rows = self:GetBagRows()
  local offset = FauxScrollFrame_GetOffset(self.BagScroll)
  local newOffset = offset
  if row <= offset then
    newOffset = row - 1
  elseif row > offset + rows then
    newOffset = row - rows
  end
  if newOffset ~= offset then
    FauxScrollFrame_OnVerticalScroll(self.BagScroll, newOffset * BAG_ROW_HEIGHT, BAG_ROW_HEIGHT, function()
      self:UpdateBagButtons()
    end)
  end
end

function SellingTab:OnItemDropped()
  local kind, _, itemLink = GetCursorInfo()
  if kind ~= "item" or itemLink == nil then
    return
  end
  ClearCursor()
  self.DropCatcher:Hide()
  if self.posting then
    return
  end
  local key = GroupKey(itemLink)
  for _, item in ipairs(self.bagItems) do
    if item.key == key then
      self:SelectItem(item)
      return
    end
  end
  self:SetStatus(Auctionary.Compat.Colors.RED_FONT_COLOR:WrapTextInColorCode("That item cannot be sold in the auction house."))
end

function SellingTab:OnUpdate(elapsed)
  if CursorHasItem() and not self.posting then
    self.DropCatcher:Show()
  else
    self.DropCatcher:Hide()
  end
  if self.quickDeadline ~= nil and GetTime() > self.quickDeadline then
    self.quickDeadline = nil
    if self.searching then
      self:StopSearch()
      self:SetStatus("Lowest in the scan just now: " .. Money(self.quickPrice or 0)
        .. "   (the search took too long, using the scan price)")
    end
  end
  local posting = self.posting
  if posting ~= nil and GetTime() - posting.startTime > POST_TIMEOUT then
    -- No answer: count what the client confirmed
    local created = posting.created
    if created == 0 and GetAuctionSellItemInfo() == nil then
      created = posting.details.numStacks == 1 and 1 or 0
    end
    self:FinishPosting(created, created == 0 and "No answer from the auction house." or nil)
    return
  end

  if self.bagsDirty and not posting then
    self.bagsTimer = (self.bagsTimer or 0) + elapsed
    if self.bagsTimer > 0.3 then
      self.bagsTimer = 0
      self:RefreshBags()
    end
  end
end

Auctionary.Tabs.RegisterContent("Selling", function(panel)
  local frame = CreateFrame("Frame", "Auctionary2SellingTabFrame", panel)
  frame:SetAllPoints(panel)
  Auctionary.Compat.Mixin(frame, SellingTab)
  frame:OnLoad()
  panel.Content = frame
end)

---- Buying the cheapest auction when it is a bargain
-- The square gold button next to "Post Next". After the auctions of the
-- chosen item were read, it lights up when the cheapest one (not your own)
-- costs at most the set share (70% unless changed in the options) of the
-- item's average price. A click buys
-- that auction. If it is not on the page the client has loaded, the page is
-- loaded first and the next click buys.

-- Share of the average price at or below which the cheapest auction is a
-- bargain (setting on the second options page)
local function BargainPercent()
  return Auctionary.Config.Get(Options.SELLING_BARGAIN_PERCENT) or 70
end

function SellingTab:CreateBuyCheapButton()
  local button = CreateFrame("Button", "Auctionary2SellingBuyCheapButton", self)
  button:SetWidth(22)
  button:SetHeight(22)
  button:SetPoint("RIGHT", self.PostNextButton, "LEFT", -4, 0)
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetAllPoints(button)
  button.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
  button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  -- Pressed look: the coin moves down a little
  button:SetScript("OnMouseDown", function()
    button.icon:SetTexCoord(0.12, 0.88, 0.12, 0.88)
  end)
  button:SetScript("OnMouseUp", function()
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end)
  button:SetScript("OnClick", function()
    self:BuyCheapClicked()
  end)
  button:SetScript("OnEnter", function(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Buy bargain")
    GameTooltip:AddLine("Buys the cheapest auction of this item when it costs at most "
      .. BargainPercent() .. "% of the average price.", 1, 1, 1, true)
    local deal, reason = self:GetBargain()
    if deal ~= nil then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(deal.row.stackSize .. " x for " .. Money(deal.row.stackPrice)
        .. " (" .. math.floor(deal.row.unitPrice / deal.average * 100) .. "% of " .. Money(deal.average) .. " each)", 0.2, 1, 0.2, true)
    else
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(reason or "Nothing that cheap right now.", 0.7, 0.7, 0.7, true)
    end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  self.BuyCheapButton = button

  local watcher = CreateFrame("Frame")
  watcher:SetScript("OnEvent", function(_, eventName, message)
    self:BuyCheapResult(eventName, message)
  end)
  self.buyWatcher = watcher
  self:UpdateBuyCheapButton()
end

-- { row, auction, average } of the cheapest auction when it is a bargain;
-- otherwise nil and why not
function SellingTab:GetBargain()
  local item = self.selected
  if item == nil then
    return nil, "Choose an item first."
  end
  if self.searching or self.priceRows == nil or item.key ~= self.searchKey then
    return nil, "Wait until the auctions of the item have been read."
  end
  local cheapest
  for _, row in ipairs(self.priceRows) do
    if not row.isOwned and #row.auctions > 0 then
      cheapest = row
      break
    end
  end
  if cheapest == nil then
    return nil, "No auctions of other players to buy."
  end
  local average
  Auctionary.Utilities.DBKeyFromLink(item.itemLink, function(dbKeys)
    if dbKeys[1] ~= nil then
      average = Auctionary.Database:GetScanAverage(dbKeys[1],
        Auctionary.Config.Get(Options.AUCTION_MEAN_DAYS_LIMIT))
    end
  end)
  if average == nil or average <= 0 then
    return nil, "No average price known for this item yet (needs earlier scans)."
  end
  if cheapest.unitPrice * 100 > average * BargainPercent() then
    return nil, "No bargain: the cheapest costs " .. math.floor(cheapest.unitPrice / average * 100)
      .. "% of the average (" .. Money(average) .. "). Buys at " .. BargainPercent() .. "% or less."
  end
  return { row = cheapest, auction = cheapest.auctions[1], average = average }
end

function SellingTab:UpdateBuyCheapButton()
  local button = self.BuyCheapButton
  if button == nil then
    return
  end
  -- Always gold and clickable; bright only when there is a bargain
  local active = self.buyPending == nil and self:GetBargain() ~= nil
  button.icon:SetDesaturated(false)
  button.icon:SetVertexColor(active and 1 or 0.55, active and 1 or 0.55, active and 1 or 0.55)
  button:SetAlpha(active and 1 or 0.8)
end

function SellingTab:BuyCheapClicked()
  if self.buyPending ~= nil then
    return
  end
  local deal, reason = self:GetBargain()
  if deal == nil then
    self:SetStatus(reason or "Nothing that cheap right now.")
    self:UpdateBuyCheapButton()
    return
  end
  local buyout = deal.auction.info[Auctionary.Constants.AuctionItemInfo.Buyout]
  if GetMoney() < buyout then
    self:SetStatus(ERR_NOT_ENOUGH_MONEY or "Not enough money")
    return
  end

  local index = not Auctionary.AH.IsQueryActive() and Auctionary.AH.FindAuctionIndex("list", deal.auction)
  if not index then
    -- Load the page with this auction; the next click buys
    if deal.auction.query ~= nil then
      self.buyLocating = deal
      self:SetStatus((SEARCHING or "Searching") .. " ...")
      Auctionary.AH.QueryAndFocusPage(deal.auction.query, deal.auction.page or 0)
    else
      self:SearchPrices()
    end
    return
  end

  self.buyPending = { deal = deal, moneyBefore = GetMoney() }
  self.buyWatcher:RegisterEvent("PLAYER_MONEY")
  self.buyWatcher:RegisterEvent("UI_ERROR_MESSAGE")
  self:UpdateBuyCheapButton()
  self:SetStatus((AUCTIONARY2_L_BUYING or "Buying") .. " ...")
  PlaceAuctionBid("list", index, buyout)
  -- No answer from the server: give up waiting
  local pending = self.buyPending
  Auctionary.Compat.After(5, function()
    if self.buyPending == pending then
      self:BuyCheapResult("TIMEOUT")
    end
  end)
end

function SellingTab:BuyCheapPageLoaded()
  local deal = self.buyLocating
  if deal == nil then
    return
  end
  self.buyLocating = nil
  if Auctionary.AH.FindAuctionIndex("list", deal.auction) ~= nil then
    self:SetStatus(Auctionary.Compat.Colors.GREEN_FONT_COLOR:WrapTextInColorCode(
      "Ready: " .. deal.row.stackSize .. " x for " .. Money(deal.row.stackPrice) .. ". Click the gold button to buy."))
    self:UpdateBuyCheapButton()
  else
    self:SetStatus("Already sold.")
    self:SearchPrices()
  end
end

function SellingTab:BuyCheapResult(eventName, message)
  local pending = self.buyPending
  if pending == nil then
    return
  end
  if eventName == "PLAYER_MONEY" and GetMoney() >= pending.moneyBefore then
    return
  end
  self.buyPending = nil
  self.buyWatcher:UnregisterEvent("PLAYER_MONEY")
  self.buyWatcher:UnregisterEvent("UI_ERROR_MESSAGE")
  local row = pending.deal.row
  if eventName == "PLAYER_MONEY" then
    if Auctionary.GoldLog ~= nil then
      pcall(Auctionary.GoldLog.Add, "b", self.selected and self.selected.name, row.itemLink,
        row.stackSize, row.stackPrice, "Selling")
    end
    self:SetStatus(Auctionary.Compat.Colors.GREEN_FONT_COLOR:WrapTextInColorCode(
      "Bought " .. row.stackSize .. " x for " .. Money(row.stackPrice)))
  elseif eventName == "UI_ERROR_MESSAGE" then
    self:SetStatus(Auctionary.Compat.Colors.RED_FONT_COLOR:WrapTextInColorCode(tostring(message)))
  else
    self:SetStatus("No answer from the server.")
  end
  -- Read the item's auctions again, prices have changed
  Auctionary.Compat.After(0.5, function()
    if self.selected ~= nil then
      self:SearchPrices()
    end
  end)
end
