local Auctionator = Auctionary

-- The "Auctionator" tab: settings of the addon and a short status of the
-- price database. Everything is saved the moment it is changed.
local Options = Auctionator.Config.Options
local NAME = "AuctionaryOptions"

AuctionaryOptionsTabFrameMixin = {}

local LEFT_X, RIGHT_X = 40, 440
local DURATIONS = { 12, 24, 48 }

local function Header(parent, text, x, y)
  local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  header:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  header:SetText(text)
  return header
end

local function Text(parent, text, x, y)
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  label:SetText(text)
  return label
end

function AuctionaryOptionsTabFrameMixin:AddCheck(option, text, x, y)
  local check = CreateFrame("CheckButton", NAME .. "Check" .. option, self, "UICheckButtonTemplate")
  check:SetWidth(24)
  check:SetHeight(24)
  check:SetPoint("TOPLEFT", self, "TOPLEFT", x, y)
  local label = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("LEFT", check, "RIGHT", 2, 1)
  label:SetText(text)
  check:SetScript("OnClick", function(button)
    Auctionator.Config.Set(option, button:GetChecked() and true or false)
    if option == Options.GOLD_TRACKER_BUTTON and Auctionator.Tabs.UpdateGoldButton ~= nil then
      Auctionator.Tabs.UpdateGoldButton()
    end
  end)
  self.checks[option] = check
  return check
end

function AuctionaryOptionsTabFrameMixin:AddNumberBox(key, option, x, y, minimum, maximum)
  local box = CreateFrame("EditBox", NAME .. "Box" .. key, self, "InputBoxTemplate")
  box:SetWidth(36)
  box:SetHeight(20)
  box:SetPoint("TOPLEFT", self, "TOPLEFT", x, y)
  box:SetAutoFocus(false)
  box:SetNumeric(true)
  box:SetMaxLetters(3)
  local function save()
    local value = tonumber(box:GetText())
    if value == nil then
      return
    end
    value = math.max(minimum, math.min(maximum, value))
    Auctionator.Config.Set(option, value)
  end
  box:SetScript("OnTextChanged", function(_, userInput)
    if userInput then
      save()
    end
  end)
  local function done()
    box:ClearFocus()
    box:SetText(tostring(Auctionator.Config.Get(option)))
  end
  box:SetScript("OnEnterPressed", done)
  box:SetScript("OnEscapePressed", done)
  box:SetScript("OnEditFocusLost", function()
    box:SetText(tostring(Auctionator.Config.Get(option)))
  end)
  self.boxes[option] = box
  return box
end

function AuctionaryOptionsTabFrameMixin:AddRadio(key, x, y, text, onClick)
  local radio = CreateFrame("CheckButton", NAME .. "Radio" .. key, self, "UIRadioButtonTemplate")
  radio:SetPoint("TOPLEFT", self, "TOPLEFT", x, y)
  local label = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("LEFT", radio, "RIGHT", 3, 0)
  label:SetText(text)
  radio:SetScript("OnClick", function()
    onClick()
    self:Refresh()
  end)
  return radio
end

function AuctionaryOptionsTabFrameMixin:OnLoad()
  self.checks = {}
  self.boxes = {}
  local SalesTypes = Auctionator.Config.SalesTypes

  ---- Selling
  local y = -84
  Header(self, "Selling", LEFT_X, y)

  y = y - 22
  Text(self, "Price suggestion: undercut the lowest auction by", LEFT_X, y)

  y = y - 20
  self.percentRadio = self:AddRadio("Percent", LEFT_X, y, "Percentage", function()
    Auctionator.Config.Set(Options.AUCTION_SALES_PREFERENCE, SalesTypes.PERCENTAGE)
  end)
  self:AddNumberBox("UndercutPercent", Options.UNDERCUT_PERCENTAGE, LEFT_X + 130, y + 2, 0, 99)
  Text(self, "%", LEFT_X + 172, y - 3)

  y = y - 24
  self.staticRadio = self:AddRadio("Static", LEFT_X, y, "Fixed amount", function()
    Auctionator.Config.Set(Options.AUCTION_SALES_PREFERENCE, SalesTypes.STATIC)
  end)
  self.staticMoney = CreateFrame("Frame", NAME .. "UndercutMoney", self, "MoneyInputFrameTemplate")
  self.staticMoney:SetPoint("TOPLEFT", self, "TOPLEFT", LEFT_X + 130, y + 2)
  MoneyInputFrame_SetOnValueChangedFunc(self.staticMoney, function()
    if self.refreshing then
      return
    end
    Auctionator.Config.Set(Options.UNDERCUT_STATIC_VALUE, MoneyInputFrame_GetCopper(self.staticMoney))
  end)

  y = y - 22
  self:AddCheck(Options.SELLING_POST_ON_ENTER, "The Enter key posts (0% undercut = 1 copper below the lowest)", LEFT_X - 4, y + 4)

  y = y - 24
  Text(self, "Default duration (hours)", LEFT_X, y)
  self.durationRadios = {}
  for index, hours in ipairs(DURATIONS) do
    self.durationRadios[hours] = self:AddRadio("Duration" .. hours, LEFT_X + 140 + (index - 1) * 50, y + 2,
      tostring(hours), function()
        Auctionator.Config.Set(Options.AUCTION_DURATION, hours)
        local selling = AuctionarySellingTabFrame
        if selling ~= nil and selling.SetDuration ~= nil then
          selling:SetDuration(hours)
        end
      end)
  end

  y = y - 26
  local quantitiesButton = CreateFrame("Button", NAME .. "QuantitiesButton", self, "UIPanelButtonTemplate")
  quantitiesButton:SetWidth(170)
  quantitiesButton:SetHeight(22)
  quantitiesButton:SetPoint("TOPLEFT", self, "TOPLEFT", LEFT_X, y + 4)
  quantitiesButton:SetText("Default stack sizes ...")
  quantitiesButton:SetScript("OnClick", function()
    Auctionator.Components.ShowDefaultQuantities()
  end)

  local backgroundButton = CreateFrame("Button", NAME .. "BackgroundButton", self, "UIPanelButtonTemplate")
  backgroundButton:SetWidth(200)
  backgroundButton:SetHeight(22)
  backgroundButton:SetPoint("LEFT", quantitiesButton, "RIGHT", 8, 0)
  backgroundButton:SetText("Background: " .. Auctionator.Tabs.GetBackground().name)
  -- All backgrounds in a menu: the three colours, black and the class colours
  local backgroundMenu = CreateFrame("Frame", NAME .. "BackgroundMenu", UIParent, "UIDropDownMenuTemplate")
  UIDropDownMenu_Initialize(backgroundMenu, function()
    local current = Auctionator.Tabs.GetBackground()
    for _, background in ipairs(Auctionator.Tabs.Backgrounds) do
      local info = UIDropDownMenu_CreateInfo()
      local colour = background.border
      if colour ~= nil then
        info.text = string.format("|cff%02x%02x%02x%s|r", colour[1] * 255, colour[2] * 255, colour[3] * 255, background.name)
      else
        info.text = background.name
      end
      info.checked = (background == current)
      info.func = function()
        backgroundButton:SetText("Background: " .. Auctionator.Tabs.SetBackground(background.key))
        CloseDropDownMenus()
      end
      UIDropDownMenu_AddButton(info, 1)
    end
  end, "MENU")
  backgroundButton:SetScript("OnClick", function(button)
    ToggleDropDownMenu(1, nil, backgroundMenu, button, 0, 0)
  end)

  ---- Scanning
  y = y - 28
  Header(self, "Scanning", LEFT_X, y)
  y = y - 20
  self:AddCheck(Options.AUTOSCAN, "Run a full scan when the auction house opens", LEFT_X - 4, y)

  ---- Status
  y = y - 24
  Header(self, "Status", LEFT_X, y)
  y = y - 20
  self.statusText = Text(self, "", LEFT_X, y)
  self.statusText:SetJustifyH("LEFT")
  self.statusText:SetWidth(360)

  self.supportText = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  self.supportText:SetPoint("TOPLEFT", self.statusText, "BOTTOMLEFT", 0, -8)
  self.supportText:SetText("If you want to support my projects, send gold to Banksty. <3")
  self.supportText:SetTextColor(1, 0.82, 0)

  -- Picture in the top right corner of the dark area
  self.madeByIcon = self:CreateTexture(nil, "ARTWORK")
  self.madeByIcon:SetTexture("Interface\\AddOns\\Auctionary\\Images\\MadeBy")
  self.madeByIcon:SetTexCoord(0, 49 / 64, 0, 39 / 64)
  self.madeByIcon:SetWidth(49)
  self.madeByIcon:SetHeight(39)
  self.madeByIcon:SetPoint("TOPRIGHT", self, "TOPRIGHT", -22, -84)

  ---- Tooltips
  y = -84
  Header(self, "Tooltips", RIGHT_X, y)
  y = y - 18
  local tooltipChecks = {
    { Options.VENDOR_TOOLTIPS,       "Vendor price" },
    { Options.AUCTION_TOOLTIPS,      "Auction price (latest scan)" },
    { Options.AUCTION_MEAN_TOOLTIPS, "Auction Average" },
    { Options.AUCTION_AGE_TOOLTIPS,  "Auction Age (days since the item was last seen)" },
    { Options.MATS_COST_TOOLTIPS,    "Mats Cost for crafted items" },
    { Options.DISENCHANT_TOOLTIPS,   "Disenchant value (hold Shift for the details)" },
    { Options.PROSPECT_TOOLTIPS,     "Prospect value of ore" },
    { Options.MILL_TOOLTIPS,         "Mill value of herbs" },
    { Options.SHIFT_STACK_TOOLTIPS,  "Hold Shift to show prices for the whole stack" },
  }
  for _, details in ipairs(tooltipChecks) do
    self:AddCheck(details[1], details[2], RIGHT_X - 4, y)
    y = y - 18
  end
  y = y - 6
  Text(self, "Auction Average covers the scans of the last", RIGHT_X, y)
  self:AddNumberBox("MeanDays", Options.AUCTION_MEAN_DAYS_LIMIT, RIGHT_X + 246, y + 5, 1, 365)
  Text(self, "days", RIGHT_X + 288, y)

  y = y - 24
  Header(self, "Warnings and behaviour", RIGHT_X, y)
  y = y - 18
  self:AddCheck(Options.SHOPPING_CONFIRM_HIGH_PRICE, "Ask again before buying far above the average price", RIGHT_X - 4, y)
  y = y - 19
  self:AddCheck(Options.SELLING_WARN_LOW_PRICE, "Ask again before posting far below the market", RIGHT_X - 4, y)
  y = y - 19
  self:AddCheck(Options.CRAFTING_INFO_SHOW, "Show mats cost and profit in the profession window", RIGHT_X - 4, y)
  y = y - 19
  self:AddCheck(Options.DOUBLE_CLICK_ACTIONS, "Double-click cancels an auction (Cancelling tab)", RIGHT_X - 4, y)

  self:CreateSecondPage()

  self.elapsed = 0
  self:SetScript("OnShow", function() self:Refresh() end)
  self:SetScript("OnUpdate", function(_, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= 1 then
      self.elapsed = 0
      self:RefreshStatus()
    end
  end)
  self:Refresh()
end

---- Second page (keyboard), reached with the arrow at the bottom right

local function Collect(frame)
  local set = {}
  for _, child in ipairs({ frame:GetChildren() }) do
    set[child] = true
  end
  for _, region in ipairs({ frame:GetRegions() }) do
    set[region] = true
  end
  return set
end

function AuctionaryOptionsTabFrameMixin:CreateSecondPage()
  local firstPage = Collect(self)

  local y = -84
  Header(self, "Keyboard", LEFT_X, y)
  y = y - 18
  Text(self, "The keys only work while that tab is open. Meanwhile the arrow keys do not", LEFT_X, y)
  y = y - 14
  Text(self, "move your character, and while you type in a box the box gets them.", LEFT_X, y)

  y = y - 26
  Header(self, "Selling", LEFT_X, y)
  y = y - 18
  self:AddCheck(Options.KEYS_SELLING, "Arrow keys pick the previous / next item of the bag grid (up / down: a row)", LEFT_X - 4, y)
  y = y - 19
  Text(self, "(Enter posting is switched on the first page, under Selling.)", LEFT_X + 24, y - 5)

  y = y - 28
  Header(self, "Shopping (buying an item)", LEFT_X, y)
  y = y - 18
  self:AddCheck(Options.KEYS_SHOPPING, "Up / down picks the previous / next auction", LEFT_X - 4, y)
  y = y - 19
  self:AddCheck(Options.SHOPPING_BUY_ON_ENTER, "Enter buys the selected auction (no extra question)", LEFT_X - 4, y)

  -- Only where the Sniping tab exists
  if AuctionarySnipingTabFrameMixin ~= nil then
    y = y - 28
    Header(self, "Sniping", LEFT_X, y)
    y = y - 18
    self:AddCheck(Options.KEYS_SNIPING, "Up / down picks the previous / next find", LEFT_X - 4, y)
    y = y - 19
    self:AddCheck(Options.SNIPING_BUY_ON_ENTER, "Enter buys the selected find (no extra question)", LEFT_X - 4, y)
    y = y - 19
    self:AddCheck(Options.SNIPING_AUTO_NEXT, "After buying, the next find is selected by itself", LEFT_X - 4, y)
  end

  -- Gold Tracker (right column)
  local ry = -84
  Header(self, "Gold Tracker", RIGHT_X, ry)
  ry = ry - 18
  self:AddCheck(Options.GOLD_TRACKER_BUTTON, "Show the Gold Tracker tab (chart symbol)", RIGHT_X - 4, ry)
  ry = ry - 19
  self:AddCheck(Options.GOLD_TRACKER_RECORD, "Record purchases, deposits and your gold", RIGHT_X - 4, ry)
  ry = ry - 19
  self:AddCheck(Options.GOLD_TRACKER_VENDOR, "Record sales to vendors", RIGHT_X - 4, ry)
  if AuctionarySnipingTabFrameMixin ~= nil then
    ry = ry - 19
    self:AddCheck(Options.GOLD_TRACKER_SNIPING, "Show the Sniping results line", RIGHT_X - 4, ry)
  end
  ry = ry - 28
  Text(self, "Sales are always read from the auction house mail.", RIGHT_X, ry)

  -- Start the Gold Tracker over; needs a second click
  ry = ry - 30
  local reset = CreateFrame("Button", NAME .. "GoldReset", self, "UIPanelButtonTemplate")
  reset:SetWidth(200)
  reset:SetHeight(22)
  reset:SetPoint("TOPLEFT", self, "TOPLEFT", RIGHT_X, ry)
  reset:SetText("Reset Gold Tracker data")
  local armed
  reset:SetScript("OnClick", function()
    if armed ~= nil and GetTime() - armed <= 5 then
      armed = nil
      Auctionator.GoldLog.Reset()
      reset:SetText("Reset Gold Tracker data")
      Auctionator.Utilities.Message("Gold Tracker data deleted. It starts again from "
        .. Auctionator.Compat.GetMoneyString(GetMoney(), true) .. " on " .. UnitName("player") .. ".")
    else
      armed = GetTime()
      reset:SetText("|cffff4040Click again to delete|r")
    end
  end)
  reset:SetScript("OnHide", function()
    armed = nil
    reset:SetText("Reset Gold Tracker data")
  end)
  reset:SetScript("OnEnter", function(button)
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText("Reset Gold Tracker data")
    GameTooltip:AddLine("Deletes all recorded sales, purchases, deposits, vendor sales and the gold history of every character, and starts again from the gold this character has now. Other characters are added when you log in with them. Cannot be undone.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  reset:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local secondPage = {}
  for object in pairs(Collect(self)) do
    if not firstPage[object] then
      table.insert(secondPage, object)
    end
  end

  local function PageArrow(direction)
    local arrow = CreateFrame("Button", NAME .. "Page" .. direction, self)
    arrow:SetWidth(26)
    arrow:SetHeight(26)
    arrow:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -16, 42)
    local file = direction == "Next" and "Next" or "Prev"
    arrow:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. file .. "Page-Up")
    arrow:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. file .. "Page-Down")
    arrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    arrow.label = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow.label:SetPoint("RIGHT", arrow, "LEFT", -2, 0)
    arrow.label:SetText(direction == "Next" and "Keyboard and tracker options" or "Back")
    return arrow
  end
  local nextArrow = PageArrow("Next")
  local backArrow = PageArrow("Back")

  local function SetShown(object, shown)
    if shown then object:Show() else object:Hide() end
  end
  local function ShowPage(second)
    for object in pairs(firstPage) do
      if second then
        object.shownOnFirstPage = object:IsShown() and true or false
        object:Hide()
      elseif object.shownOnFirstPage ~= false then
        object:Show()
      end
    end
    for _, object in ipairs(secondPage) do
      if second then object:Show() else object:Hide() end
    end
    SetShown(nextArrow, not second)
    SetShown(nextArrow.label, not second)
    SetShown(backArrow, second)
    SetShown(backArrow.label, second)
    self.onSecondPage = second
  end
  nextArrow:SetScript("OnClick", function()
    PlaySound("igMainMenuOptionCheckBoxOn")
    ShowPage(true)
  end)
  backArrow:SetScript("OnClick", function()
    PlaySound("igMainMenuOptionCheckBoxOn")
    ShowPage(false)
  end)
  -- Starts on the first page every time the tab is opened
  self:HookScript("OnHide", function()
    if self.onSecondPage then
      ShowPage(false)
    end
  end)
  ShowPage(false)
end

function AuctionaryOptionsTabFrameMixin:Refresh()
  local SalesTypes = Auctionator.Config.SalesTypes
  for option, check in pairs(self.checks) do
    check:SetChecked(Auctionator.Config.Get(option) and true or false)
  end
  for option, box in pairs(self.boxes) do
    if not box:HasFocus() then
      box:SetText(tostring(Auctionator.Config.Get(option) or 0))
    end
  end

  local isStatic = Auctionator.Config.Get(Options.AUCTION_SALES_PREFERENCE) == SalesTypes.STATIC
  self.percentRadio:SetChecked(not isStatic)
  self.staticRadio:SetChecked(isStatic)
  self.refreshing = true
  MoneyInputFrame_SetCopper(self.staticMoney, Auctionator.Config.Get(Options.UNDERCUT_STATIC_VALUE) or 0)
  self.refreshing = false

  local duration = Auctionator.Config.Get(Options.AUCTION_DURATION)
  for hours, radio in pairs(self.durationRadios) do
    radio:SetChecked(hours == duration)
  end

  self:RefreshStatus()
end

function AuctionaryOptionsTabFrameMixin:RefreshStatus()
  local lines = {}
  local version = GetAddOnMetadata("Auctionary", "Version")
  if version ~= nil then
    table.insert(lines, "Version " .. version)
  end
  if Auctionator.Database ~= nil and Auctionator.Database.GetItemCount ~= nil then
    table.insert(lines, "Items with a saved price: " .. tostring(Auctionator.Database:GetItemCount()))
  end
  local scanFrame = Auctionator.FullScan and Auctionator.FullScan.Frame
  if scanFrame ~= nil and scanFrame.NextScanMessage ~= nil then
    if scanFrame.CanGetAll ~= nil and scanFrame:CanGetAll() then
      table.insert(lines, "A quick full scan is available now.")
    else
      table.insert(lines, scanFrame:NextScanMessage())
    end
  end
  self.statusText:SetText(table.concat(lines, "\n"))
end

Auctionator.Tabs.RegisterContent("Auctionator", function(panel)
  local frame = CreateFrame("Frame", "AuctionaryOptionsTabFrame", panel)
  frame:SetAllPoints(panel)
  Auctionator.Compat.Mixin(frame, AuctionaryOptionsTabFrameMixin)
  frame:OnLoad()
  panel.Content = frame
end)
