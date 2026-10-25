-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- Extended search editor
-- A small window with every part of a search term: name, exact match,
-- category, level, item level, price (in gold), quality and quantity.
-- The Shopping tab uses it for "..." and for editing list entries:
--   editor:Edit(title, buttonText, term, function(newTerm) ... end)

local FRAME_NAME = "Auctionary2SearchEditor"
local LABEL_X, FIELD_X = 20, 150
local ANY = function() return AUCTIONARY2_L_ANY or "Any" end

-- Number fields: name, label, y, key(s) in the split search term, factor
-- between what is typed and what is stored (price: gold vs copper)
local RANGES = {
  { "Level", function() return AUCTIONARY2_L_LEVEL or "Level" end, -138, "minLevel", "maxLevel", 1 },
  { "ItemLevel", function() return AUCTIONARY2_L_ITEM_LEVEL or "Item Level" end, -166, "minItemLevel", "maxItemLevel", 1 },
  { "Price", function()
      return (AUCTIONARY2_L_COL_PRICE or "Price") .. " (" .. (GOLD or "Gold") .. ")"
    end, -194, "minPrice", "maxPrice", 10000 },
}

local function Text(parent, font, text)
  local label = parent:CreateFontString(nil, "OVERLAY", font)
  label:SetText(text)
  return label
end

local function Label(window, text, y)
  local label = Text(window, "GameFontNormal", text)
  label:SetPoint("TOPLEFT", window, "TOPLEFT", LABEL_X, y)
end

local function Box(window, suffix, width, numeric)
  local box = CreateFrame("EditBox", FRAME_NAME .. suffix, window, "InputBoxTemplate")
  box:SetWidth(width)
  box:SetHeight(20)
  box:SetAutoFocus(false)
  if numeric then
    box:SetNumeric(true)
    box:SetMaxLetters(7)
  else
    box:SetMaxLetters(200)
  end
  box:SetScript("OnEnterPressed", function() window.editor:Confirm() end)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  return box
end

local function Button(window, suffix, text, width)
  local button = CreateFrame("Button", FRAME_NAME .. suffix, window, "UIPanelButtonTemplate")
  button:SetWidth(width)
  button:SetHeight(22)
  button:SetText(text)
  return button
end

-- Typed number, nil when empty or 0
local function Typed(box)
  local value = box:GetNumber()
  return value ~= 0 and value or nil
end

local function Show(box, value)
  box:SetText(value and tostring(value) or "")
end

local Editor = {}
local EditorMeta = { __index = Editor }

local function BuildWindow(editor, parent)
  local window = CreateFrame("Frame", FRAME_NAME, parent)
  window.editor = editor
  window:Hide()
  window:SetWidth(360)
  window:SetHeight(340)
  window:SetPoint("CENTER", parent, "CENTER", 0, 0)
  window:SetFrameStrata("DIALOG")
  window:SetToplevel(true)
  window:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  -- The dialog background is see-through; a dark layer keeps the tab out
  local shade = window:CreateTexture(nil, "BACKGROUND")
  shade:SetPoint("TOPLEFT", 10, -10)
  shade:SetPoint("BOTTOMRIGHT", -10, 10)
  shade:SetTexture(0, 0, 0, 0.95)

  window:EnableMouse(true)
  window:SetMovable(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)
  window:SetScript("OnHide", function() CloseDropDownMenus() end)

  editor.title = Text(window, "GameFontNormalLarge", "")
  editor.title:SetPoint("TOP", 0, -18)

  Label(window, AUCTIONARY2_L_EDITOR_NAME or "Search Term", -52)
  editor.name = Box(window, "SearchString", 180, false)
  editor.name:SetPoint("TOPLEFT", FIELD_X, -48)
  editor.name:SetScript("OnEscapePressed", function() window:Hide() end)

  editor.exact = CreateFrame("CheckButton", FRAME_NAME .. "IsExact", window, "UICheckButtonTemplate")
  editor.exact:SetWidth(24)
  editor.exact:SetHeight(24)
  editor.exact:SetPoint("TOPLEFT", FIELD_X - 4, -70)
  Text(window, "GameFontHighlightSmall", AUCTIONARY2_L_EDITOR_EXACT or "Exact Search")
    :SetPoint("LEFT", editor.exact, "RIGHT", 2, 1)

  Label(window, AUCTIONARY2_L_EDITOR_CATEGORY or "Item Class", -104)
  editor.categoryMenu = CreateFrame("Frame", FRAME_NAME .. "Category", window, "UIDropDownMenuTemplate")
  editor.categoryMenu:SetPoint("TOPLEFT", FIELD_X - 20, -96)
  UIDropDownMenu_SetWidth(editor.categoryMenu, 170)
  UIDropDownMenu_Initialize(editor.categoryMenu, function(_, level) editor:FillCategories(level or 1) end)

  editor.ranges = {}
  for _, field in ipairs(RANGES) do
    local suffix, labelText, y = field[1], field[2], field[3]
    Label(window, labelText(), y)
    local low = Box(window, suffix .. "Min", 60, true)
    low:SetPoint("TOPLEFT", FIELD_X, y + 4)
    local dash = Text(window, "GameFontHighlight", "-")
    dash:SetPoint("LEFT", low, "RIGHT", 6, 0)
    local high = Box(window, suffix .. "Max", 60, true)
    high:SetPoint("LEFT", dash, "RIGHT", 10, 0)
    editor.ranges[#editor.ranges + 1] = { low = low, high = high, field = field }
  end

  Label(window, QUALITY or RARITY or "Quality", -226)
  editor.qualityMenu = CreateFrame("Frame", FRAME_NAME .. "Quality", window, "UIDropDownMenuTemplate")
  editor.qualityMenu:SetPoint("TOPLEFT", FIELD_X - 20, -218)
  UIDropDownMenu_SetWidth(editor.qualityMenu, 170)
  UIDropDownMenu_Initialize(editor.qualityMenu, function() editor:FillQualities() end)

  Label(window, AUCTIONARY2_L_QUANTITY or "Quantity", -260)
  editor.quantity = Box(window, "Quantity", 60, true)
  editor.quantity:SetPoint("TOPLEFT", FIELD_X, -256)

  editor.confirmButton = Button(window, "Finished", "", 100)
  editor.confirmButton:SetPoint("BOTTOMRIGHT", -20, 18)
  editor.confirmButton:SetScript("OnClick", function() editor:Confirm() end)

  local cancel = Button(window, "Cancel", AUCTIONARY2_L_CANCEL or CANCEL, 90)
  cancel:SetPoint("RIGHT", editor.confirmButton, "LEFT", -6, 0)
  cancel:SetScript("OnClick", function() window:Hide() end)

  local clear = Button(window, "ResetAll", AUCTIONARY2_L_EDITOR_CLEAR or "Reset All", 90)
  clear:SetPoint("BOTTOMLEFT", 20, 18)
  clear:SetScript("OnClick", function() editor:Load("") end)

  return window
end

function Auctionary.Shopping.CreateSearchEditor(parent)
  local editor = setmetatable({ category = "", onDone = function() end }, EditorMeta)
  editor.window = BuildWindow(editor, parent)
  return editor
end

---- Drop-down menus

local function MenuEntry(text, onPick, value, hasArrow, level)
  local entry = UIDropDownMenu_CreateInfo()
  entry.text, entry.value, entry.hasArrow = text, value, hasArrow
  entry.notCheckable = 1
  entry.func = onPick
  UIDropDownMenu_AddButton(entry, level)
end

function Editor:SetCategory(key)
  self.category = key or ""
  UIDropDownMenu_SetText(self.categoryMenu, self.category == "" and ANY() or self.category)
end

function Editor:FillCategories(level)
  local list
  if level == 1 then
    MenuEntry(ANY(), function() self:SetCategory(""); CloseDropDownMenus() end, nil, false, level)
    list = Auctionary.Search.GetLegacyCategoryTree()
  else
    local opened = Auctionary.Search.GetLegacyCategory(UIDROPDOWNMENU_MENU_VALUE)
    list = opened and opened.subCategories or {}
  end
  for _, category in ipairs(list) do
    local key = category.key
    local deeper = category.subCategories ~= nil and #category.subCategories > 0
    MenuEntry(category.name, function() self:SetCategory(key); CloseDropDownMenus() end, key, deeper, level)
  end
end

function Editor:SetQuality(quality)
  self.qualityValue = quality
  UIDropDownMenu_SetText(self.qualityMenu,
    quality == nil and ANY() or Auctionary.Utilities.CreateColoredQuality(quality))
end

function Editor:FillQualities()
  MenuEntry(ANY(), function() self:SetQuality(nil) end)
  for _, quality in ipairs(Auctionary.Constants.QualityIDs) do
    MenuEntry(Auctionary.Utilities.CreateColoredQuality(quality), function() self:SetQuality(quality) end)
  end
end

---- Term <-> fields

function Editor:Load(term)
  local parts = Auctionary.Search.SplitAdvancedSearch(term or "")
  self.name:SetText(parts.searchString or "")
  self.exact:SetChecked(parts.isExact)
  self:SetCategory(parts.categoryKey)
  for _, range in ipairs(self.ranges) do
    local lowKey, highKey, factor = range.field[4], range.field[5], range.field[6]
    Show(range.low, parts[lowKey] and parts[lowKey] / factor)
    Show(range.high, parts[highKey] and parts[highKey] / factor)
  end
  self:SetQuality(parts.quality)
  Show(self.quantity, parts.quantity)
end

function Editor:Read()
  local parts = {
    searchString = strtrim(self.name:GetText()),
    isExact = self.exact:GetChecked() and true or false,
    categoryKey = self.category,
    quality = self.qualityValue,
    quantity = self.quantity:GetNumber(),
  }
  for _, range in ipairs(self.ranges) do
    local lowKey, highKey, factor = range.field[4], range.field[5], range.field[6]
    local low, high = Typed(range.low), Typed(range.high)
    parts[lowKey] = low and low * factor
    parts[highKey] = high and high * factor
  end
  return Auctionary.Search.ReconstituteAdvancedSearch(parts)
end

function Editor:Edit(title, buttonText, term, onDone)
  self.title:SetText(title)
  self.confirmButton:SetText(buttonText)
  self.onDone = onDone or function() end
  self:Load(term)
  self.window:Show()
  self.name:SetFocus()
end

function Editor:IsShown()
  return self.window:IsShown()
end

function Editor:Confirm()
  local term = self:Read()
  self.window:Hide()
  -- Something besides dividers, quotes and empty fields has to be set
  local filled = term:gsub(Auctionary.Constants.AdvancedSearchDivider, ""):gsub("[\"#]", "")
  if filled == "" then
    Auctionary.Utilities.Message(AUCTIONARY2_L_EDITOR_EMPTY or "No item info was specified.")
    return
  end
  self.onDone(term)
end
