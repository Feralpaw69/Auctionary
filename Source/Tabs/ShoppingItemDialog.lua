local Auctionary = Auctionary

-- The extended search options: name, category, level, item level, price,
-- quality and quantity. Used for searching and for editing list entries.
AuctionaryShoppingItemMixin = {}

local NAME = "AuctionaryShoppingItemDialog"
local LEFT = 20
local FIELD_X = 150

local function Label(parent, text, y)
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("TOPLEFT", parent, "TOPLEFT", LEFT, y)
  label:SetText(text)
  return label
end

local function NumberBox(parent, suffix, width)
  local box = CreateFrame("EditBox", NAME .. suffix, parent, "InputBoxTemplate")
  box:SetWidth(width or 60)
  box:SetHeight(20)
  box:SetAutoFocus(false)
  box:SetNumeric(true)
  box:SetMaxLetters(7)
  box:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  return box
end

-- Two number boxes "min - max"
local function Range(parent, suffix, y)
  local range = {}
  range.Min = NumberBox(parent, suffix .. "Min")
  range.Min:SetPoint("TOPLEFT", parent, "TOPLEFT", FIELD_X, y + 4)
  local dash = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  dash:SetPoint("LEFT", range.Min, "RIGHT", 6, 0)
  dash:SetText("-")
  range.Max = NumberBox(parent, suffix .. "Max")
  range.Max:SetPoint("LEFT", dash, "RIGHT", 10, 0)

  function range:Get()
    local min, max = self.Min:GetNumber(), self.Max:GetNumber()
    return min ~= 0 and min or nil, max ~= 0 and max or nil
  end
  function range:Set(min, max)
    self.Min:SetText(min and tostring(min) or "")
    self.Max:SetText(max and tostring(max) or "")
  end
  return range
end

function AuctionaryShoppingItemMixin:OnLoad()
  self:SetWidth(360)
  self:SetHeight(340)
  self:SetFrameStrata("DIALOG")
  self:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  -- The dialog background texture is see-through; keep what is behind out
  local solid = self:CreateTexture(nil, "BACKGROUND")
  solid:SetPoint("TOPLEFT", self, "TOPLEFT", 10, -10)
  solid:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -10, 10)
  solid:SetTexture(0, 0, 0, 0.95)
  self:SetToplevel(true)

  self:EnableMouse(true)
  self:SetMovable(true)
  self:RegisterForDrag("LeftButton")
  self:SetScript("OnDragStart", self.StartMoving)
  self:SetScript("OnDragStop", self.StopMovingOrSizing)

  self.Title = self:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  self.Title:SetPoint("TOP", self, "TOP", 0, -18)

  local onEnter = function()
    self:OnFinishedClicked()
  end

  -- Name
  Label(self, AUCTIONARY_L_SEARCH_TERM or "Search Term", -52)
  self.SearchString = CreateFrame("EditBox", NAME .. "SearchString", self, "InputBoxTemplate")
  self.SearchString:SetWidth(180)
  self.SearchString:SetHeight(20)
  self.SearchString:SetPoint("TOPLEFT", self, "TOPLEFT", FIELD_X, -48)
  self.SearchString:SetAutoFocus(false)
  self.SearchString:SetMaxLetters(200)
  self.SearchString:SetScript("OnEnterPressed", onEnter)
  self.SearchString:SetScript("OnEscapePressed", function()
    self:Hide()
  end)

  self.IsExact = CreateFrame("CheckButton", NAME .. "IsExact", self, "UICheckButtonTemplate")
  self.IsExact:SetWidth(24)
  self.IsExact:SetHeight(24)
  self.IsExact:SetPoint("TOPLEFT", self, "TOPLEFT", FIELD_X - 4, -70)
  local exactLabel = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  exactLabel:SetPoint("LEFT", self.IsExact, "RIGHT", 2, 1)
  exactLabel:SetText(AUCTIONARY_L_EXACT_SEARCH or "Exact Search")

  -- Category
  Label(self, AUCTIONARY_L_ITEM_CLASS or "Item Class", -104)
  self.CategoryDropDown = CreateFrame("Frame", NAME .. "Category", self, "UIDropDownMenuTemplate")
  self.CategoryDropDown:SetPoint("TOPLEFT", self, "TOPLEFT", FIELD_X - 20, -96)
  UIDropDownMenu_SetWidth(self.CategoryDropDown, 170)
  UIDropDownMenu_Initialize(self.CategoryDropDown, function(_, level)
    self:InitializeCategoryMenu(level)
  end)

  -- Ranges
  Label(self, AUCTIONARY_L_LEVEL or "Level", -138)
  self.LevelRange = Range(self, "Level", -138)
  Label(self, AUCTIONARY_L_ITEM_LEVEL or "Item Level", -166)
  self.ItemLevelRange = Range(self, "ItemLevel", -166)
  Label(self, (AUCTIONARY_L_RESULTS_PRICE_COLUMN or "Price") .. " (" .. (GOLD or "Gold") .. ")", -194)
  self.PriceRange = Range(self, "Price", -194)

  -- Quality
  Label(self, QUALITY or RARITY or "Quality", -226)
  self.QualityDropDown = CreateFrame("Frame", NAME .. "Quality", self, "UIDropDownMenuTemplate")
  self.QualityDropDown:SetPoint("TOPLEFT", self, "TOPLEFT", FIELD_X - 20, -218)
  UIDropDownMenu_SetWidth(self.QualityDropDown, 170)
  UIDropDownMenu_Initialize(self.QualityDropDown, function()
    self:InitializeQualityMenu()
  end)

  -- Quantity
  Label(self, AUCTIONARY_L_QUANTITY or "Quantity", -260)
  self.PurchaseQuantity = NumberBox(self, "Quantity")
  self.PurchaseQuantity:SetPoint("TOPLEFT", self, "TOPLEFT", FIELD_X, -256)

  for _, box in ipairs({
    self.LevelRange.Min, self.LevelRange.Max, self.ItemLevelRange.Min, self.ItemLevelRange.Max,
    self.PriceRange.Min, self.PriceRange.Max, self.PurchaseQuantity,
  }) do
    box:SetScript("OnEnterPressed", onEnter)
  end

  -- Buttons
  self.Finished = CreateFrame("Button", NAME .. "Finished", self, "UIPanelButtonTemplate")
  self.Finished:SetWidth(100)
  self.Finished:SetHeight(22)
  self.Finished:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -20, 18)
  self.Finished:SetScript("OnClick", onEnter)

  self.Cancel = CreateFrame("Button", NAME .. "Cancel", self, "UIPanelButtonTemplate")
  self.Cancel:SetWidth(90)
  self.Cancel:SetHeight(22)
  self.Cancel:SetPoint("RIGHT", self.Finished, "LEFT", -6, 0)
  self.Cancel:SetText(AUCTIONARY_L_CANCEL or CANCEL)
  self.Cancel:SetScript("OnClick", function()
    self:Hide()
  end)

  self.ResetAllButton = CreateFrame("Button", NAME .. "ResetAll", self, "UIPanelButtonTemplate")
  self.ResetAllButton:SetWidth(90)
  self.ResetAllButton:SetHeight(22)
  self.ResetAllButton:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 20, 18)
  self.ResetAllButton:SetText(AUCTIONARY_L_RESET_ALL or "Reset All")
  self.ResetAllButton:SetScript("OnClick", function()
    self:ResetAll()
  end)

  self.onFinishedClicked = function() end
  self.categoryKey = ""
  self.quality = nil

  self:SetScript("OnHide", function()
    CloseDropDownMenus()
  end)
end

function AuctionaryShoppingItemMixin:SetCategory(categoryKey)
  self.categoryKey = categoryKey or ""
  if self.categoryKey == "" then
    UIDropDownMenu_SetText(self.CategoryDropDown, AUCTIONARY_L_ANY_UPPER or "Any")
  else
    UIDropDownMenu_SetText(self.CategoryDropDown, self.categoryKey)
  end
end

function AuctionaryShoppingItemMixin:InitializeCategoryMenu(level)
  level = level or 1
  local entries
  if level == 1 then
    local info = UIDropDownMenu_CreateInfo()
    info.text = AUCTIONARY_L_ANY_UPPER or "Any"
    info.notCheckable = 1
    info.func = function()
      self:SetCategory("")
      CloseDropDownMenus()
    end
    UIDropDownMenu_AddButton(info, level)
    entries = Auctionary.Search.GetLegacyCategoryTree()
  else
    local parent = Auctionary.Search.GetLegacyCategory(UIDROPDOWNMENU_MENU_VALUE)
    entries = parent and parent.subCategories or {}
  end

  for _, entry in ipairs(entries) do
    local info = UIDropDownMenu_CreateInfo()
    info.text = entry.name
    info.value = entry.key
    info.notCheckable = 1
    info.hasArrow = entry.subCategories ~= nil and #entry.subCategories > 0
    info.func = function()
      self:SetCategory(entry.key)
      CloseDropDownMenus()
    end
    UIDropDownMenu_AddButton(info, level)
  end
end

function AuctionaryShoppingItemMixin:SetQuality(quality)
  self.quality = quality
  if quality == nil then
    UIDropDownMenu_SetText(self.QualityDropDown, AUCTIONARY_L_ANY_UPPER or "Any")
  else
    UIDropDownMenu_SetText(self.QualityDropDown, Auctionary.Utilities.CreateColoredQuality(quality))
  end
end

function AuctionaryShoppingItemMixin:InitializeQualityMenu()
  local info = UIDropDownMenu_CreateInfo()
  info.text = AUCTIONARY_L_ANY_UPPER or "Any"
  info.notCheckable = 1
  info.func = function()
    self:SetQuality(nil)
  end
  UIDropDownMenu_AddButton(info)

  for _, quality in ipairs(Auctionary.Constants.QualityIDs) do
    info = UIDropDownMenu_CreateInfo()
    info.text = Auctionary.Utilities.CreateColoredQuality(quality)
    info.notCheckable = 1
    info.func = function()
      self:SetQuality(quality)
    end
    UIDropDownMenu_AddButton(info)
  end
end

function AuctionaryShoppingItemMixin:Init(title, finishedButtonText)
  self.Title:SetText(title)
  self.Finished:SetText(finishedButtonText)
end

function AuctionaryShoppingItemMixin:SetOnFinishedClicked(callback)
  self.onFinishedClicked = callback
end

function AuctionaryShoppingItemMixin:OnFinishedClicked()
  local itemString = self:GetItemString()
  self:Hide()

  local hasInfo = itemString:gsub(Auctionary.Constants.AdvancedSearchDivider, ""):gsub("\"", ""):gsub("#", ""):len() > 0
  if hasInfo then
    self.onFinishedClicked(itemString)
  else
    Auctionary.Utilities.Message(AUCTIONARY_L_NO_ITEM_INFO_SPECIFIED or "No item info was specified.")
  end
end

function AuctionaryShoppingItemMixin:GetItemString()
  local minLevel, maxLevel = self.LevelRange:Get()
  local minItemLevel, maxItemLevel = self.ItemLevelRange:Get()
  local minPrice, maxPrice = self.PriceRange:Get()

  return Auctionary.Search.ReconstituteAdvancedSearch({
    searchString = strtrim(self.SearchString:GetText()),
    isExact = self.IsExact:GetChecked() and true or false,
    categoryKey = self.categoryKey,
    minLevel = minLevel,
    maxLevel = maxLevel,
    minItemLevel = minItemLevel,
    maxItemLevel = maxItemLevel,
    minPrice = minPrice and minPrice * 10000,
    maxPrice = maxPrice and maxPrice * 10000,
    quality = self.quality,
    quantity = self.PurchaseQuantity:GetNumber(),
  })
end

function AuctionaryShoppingItemMixin:SetItemString(itemString)
  local search = Auctionary.Search.SplitAdvancedSearch(itemString or "")

  self.SearchString:SetText(search.searchString or "")
  self.IsExact:SetChecked(search.isExact)
  self:SetCategory(search.categoryKey)
  self.LevelRange:Set(search.minLevel, search.maxLevel)
  self.ItemLevelRange:Set(search.minItemLevel, search.maxItemLevel)
  self.PriceRange:Set(search.minPrice and search.minPrice / 10000, search.maxPrice and search.maxPrice / 10000)
  self:SetQuality(search.quality)
  self.PurchaseQuantity:SetText(search.quantity and tostring(search.quantity) or "")
end

function AuctionaryShoppingItemMixin:ResetAll()
  self:SetItemString("")
end

function Auctionary.Shopping.CreateItemDialog(parent)
  local dialog = CreateFrame("Frame", NAME, parent)
  Auctionary.Compat.Mixin(dialog, AuctionaryShoppingItemMixin)
  dialog:Hide()
  dialog:OnLoad()
  dialog:SetPoint("CENTER", parent, "CENTER", 0, 0)
  return dialog
end
