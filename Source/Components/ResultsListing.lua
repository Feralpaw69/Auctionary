local Auctionator = Auctionary

-- A sortable table with a scroll bar, the 3.3.5 stand-in for the ScrollBox
-- based results listing. Shows the rows of a data provider
-- (AuctionaryDataProviderMixin).
--
-- Columns come from dataProvider:GetTableLayout():
--   headerText, headerParameters = { sortKey }, cellParameters = { field },
--   cellType = "string" | "price" | "item", width (nil = takes the free space),
--   justify = "LEFT" | "RIGHT" | "CENTER"
--
-- options: onRowClick(rowData, mouseButton), isRowSelected(rowData),
--   emptyText (shown when there are no rows),
--   noEmptyText (no "No results found." for an empty table)
AuctionaryResultsListingMixin = {}

local ROW_HEIGHT = 20
local HEADER_HEIGHT = 20
local SCROLL_BAR_WIDTH = 24
local listingCount = 0

local function QualityColorCode(quality)
  local _, _, _, hex = GetItemQualityColor(quality or 1)
  if hex == nil then
    return "|cffffffff"
  elseif string.sub(hex, 1, 2) ~= "|c" then
    return "|c" .. hex
  end
  return hex
end

-- Green dot: at least 10% below the item's average (good to buy),
-- red dot: at least 10% above it
local GOOD_DOT = "|TInterface\\FriendsFrame\\StatusIcon-Online:11:11:0:0|t "
local BAD_DOT = "|TInterface\\FriendsFrame\\StatusIcon-DND:11:11:0:0|t "
local function BuyDot(rowData, price)
  if rowData.itemLink == nil or Auctionator.Database == nil then
    return ""
  end
  if rowData.buyAverage == nil then
    rowData.buyAverage = false
    Auctionator.Utilities.DBKeyFromLink(rowData.itemLink, function(dbKeys)
      if dbKeys[1] ~= nil then
        rowData.buyAverage = Auctionator.Database:GetScanAverage(
          dbKeys[1], Auctionator.Config.Get(Auctionator.Config.Options.AUCTION_MEAN_DAYS_LIMIT)
        ) or false
      end
    end)
  end
  local average = rowData.buyAverage
  if not average or average <= 0 then
    return ""
  end
  if price <= average * 0.9 then
    return GOOD_DOT
  elseif price >= average * 1.1 then
    return BAD_DOT
  end
  return ""
end

local function FormatCell(column, rowData)
  local value = rowData[column.field]
  if column.cellType == "price" then
    if value == nil or value == 0 then
      return ""
    end
    if column.buyDot then
      local ok, dot = pcall(BuyDot, rowData, value)
      return (ok and dot or "") .. Auctionator.Compat.GetAlignedMoneyString(value)
    end
    return Auctionator.Compat.GetAlignedMoneyString(value)
  elseif column.cellType == "item" then
    local name = rowData[column.field] or ""
    if rowData.quality ~= nil then
      name = QualityColorCode(rowData.quality) .. name .. "|r"
    end
    return name
  elseif value == nil then
    return ""
  else
    return tostring(value)
  end
end

function AuctionaryResultsListingMixin:Init(dataProvider, options)
  self.dataProvider = dataProvider
  self.options = options or {}
  self.columns = {}
  self.rows = {}

  for index, entry in ipairs(dataProvider:GetTableLayout()) do
    self.columns[index] = {
      headerText = entry.headerText,
      sortKey = entry.headerParameters and entry.headerParameters[1],
      field = entry.cellParameters and entry.cellParameters[1] or (entry.headerParameters and entry.headerParameters[1]),
      cellType = entry.cellType or "string",
      width = entry.width,
      justify = entry.justify or (entry.cellType == "price" and "RIGHT" or "LEFT"),
    }
  end

  self:CreateHeaders()

  self.NoResultsText = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  self.NoResultsText:SetPoint("TOP", self, "TOP", 0, -60)
  self.NoResultsText:SetText(self.options.emptyText or AUCTIONARY_L_NO_RESULTS or "No results found.")
  self.NoResultsText:Hide()

  self.ResultsText = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  self.ResultsText:SetPoint("TOP", self, "TOP", 0, -60)
  self.ResultsText:SetText(SEARCHING or "Searching...")
  self.ResultsText:Hide()

  self.ScrollFrame:SetScript("OnVerticalScroll", function(scrollFrame, offset)
    FauxScrollFrame_OnVerticalScroll(scrollFrame, offset, ROW_HEIGHT, function()
      self:Refresh()
    end)
  end)

  self:EnableMouseWheel(true)
  self:SetScript("OnMouseWheel", function(_, delta)
    local scrollBar = _G[self.ScrollFrame:GetName() .. "ScrollBar"]
    scrollBar:SetValue(scrollBar:GetValue() - delta * ROW_HEIGHT * 3)
  end)

  self:SetScript("OnShow", function()
    self:Layout()
  end)
  self:SetScript("OnSizeChanged", function()
    self:Layout()
  end)

  dataProvider:SetOnUpdateCallback(function()
    self:Refresh()
  end)
  dataProvider:SetOnSearchStartedCallback(function()
    self.NoResultsText:Hide()
    self.ResultsText:Show()
    self.searching = true
  end)
  dataProvider:SetOnSearchEndedCallback(function()
    self.ResultsText:Hide()
    self.searching = false
    if dataProvider:GetCount() == 0 and not self.options.noEmptyText then
      self.NoResultsText:Show()
    else
      self.NoResultsText:Hide()
    end
  end)

  self:Layout()
end

function AuctionaryResultsListingMixin:CreateHeaders()
  for index, column in ipairs(self.columns) do
    local header = CreateFrame("Button", nil, self)
    header:SetHeight(HEADER_HEIGHT)
    header:SetNormalFontObject(GameFontHighlightSmall)

    local background = header:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(header)
    background:SetTexture(0.25, 0.25, 0.25, 0.6)

    header.Text = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    header.Text:SetPoint("LEFT", header, "LEFT", 6, 0)
    header.Text:SetPoint("RIGHT", header, "RIGHT", -14, 0)
    header.Text:SetJustifyH("LEFT")
    header.Text:SetText(column.headerText)

    header.Arrow = header:CreateTexture(nil, "OVERLAY")
    header.Arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
    header.Arrow:SetWidth(9)
    header.Arrow:SetHeight(8)
    header.Arrow:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    header.Arrow:Hide()

    header:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")

    header:RegisterForClicks("LeftButtonUp")
    header:SetScript("OnClick", function()
      self:SortBy(index)
    end)

    column.header = header
  end
end

function AuctionaryResultsListingMixin:SortBy(index)
  local column = self.columns[index]
  if column.sortKey == nil then
    return
  end

  for _, other in ipairs(self.columns) do
    other.header.Arrow:Hide()
  end

  if IsShiftKeyDown() then
    self.sortIndex = nil
    self.dataProvider:ClearSort()
    return
  end

  if self.sortIndex == index and self.sortDirection == Auctionator.Constants.SORT.ASCENDING then
    self.sortDirection = Auctionator.Constants.SORT.DESCENDING
    column.header.Arrow:SetTexCoord(0, 0.5625, 1, 0)
  else
    self.sortDirection = Auctionator.Constants.SORT.ASCENDING
    column.header.Arrow:SetTexCoord(0, 0.5625, 0, 1)
  end
  self.sortIndex = index
  column.header.Arrow:Show()

  self.dataProvider:SetPresetSort(column.sortKey, self.sortDirection)
  self.dataProvider:Sort(column.sortKey, self.sortDirection)
  PlaySound("igMainMenuOptionCheckBoxOn")
end

function AuctionaryResultsListingMixin:CreateRow(index)
  local row = CreateFrame("Button", nil, self)
  row:SetHeight(ROW_HEIGHT)
  row:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -HEADER_HEIGHT - (index - 1) * ROW_HEIGHT)
  row:SetPoint("RIGHT", self, "RIGHT", -SCROLL_BAR_WIDTH, 0)
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

  row.Selected = row:CreateTexture(nil, "BACKGROUND")
  row.Selected:SetAllPoints(row)
  row.Selected:SetTexture(1, 0.82, 0, 0.2)
  row.Selected:Hide()

  if index % 2 == 0 then
    local stripe = row:CreateTexture(nil, "BACKGROUND")
    stripe:SetAllPoints(row)
    stripe:SetTexture(1, 1, 1, 0.04)
  end

  row.cells = {}
  for columnIndex, column in ipairs(self.columns) do
    local cell = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cell:SetHeight(ROW_HEIGHT)
    cell:SetJustifyH(column.justify)
    row.cells[columnIndex] = cell

    if column.cellType == "item" then
      row.itemIcon = row:CreateTexture(nil, "ARTWORK")
      row.itemIcon:SetWidth(ROW_HEIGHT - 4)
      row.itemIcon:SetHeight(ROW_HEIGHT - 4)
    end
  end

  row:SetScript("OnClick", function(_, mouseButton)
    if row.rowData == nil then
      return
    end
    if IsModifiedClick("CHATLINK") and row.rowData.itemLink then
      if ChatEdit_InsertLink(row.rowData.itemLink) then
        return
      end
    end
    if IsModifiedClick("DRESSUP") and row.rowData.itemLink then
      DressUpItemLink(row.rowData.itemLink)
      return
    end
    if self.options.onRowClick then
      self.options.onRowClick(row.rowData, mouseButton, row)
    end
  end)
  row:SetScript("OnEnter", function()
    if row.rowData ~= nil and row.rowData.itemLink ~= nil then
      GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink(row.rowData.itemLink)
      if row.rowData.tooltipExtra ~= nil then
        GameTooltip:AddLine(row.rowData.tooltipExtra, 1, 0.3, 0.3, true)
      end
      GameTooltip:Show()
    elseif row.rowData ~= nil and row.rowData.tooltipText ~= nil then
      GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
      GameTooltip:SetText(row.rowData.tooltipText, 1, 1, 1, 1, true)
      GameTooltip:Show()
    end
  end)
  row:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  return row
end

-- Positions headers and cells for the current size
function AuctionaryResultsListingMixin:Layout()
  local width = self:GetWidth() - SCROLL_BAR_WIDTH
  local height = self:GetHeight()
  if width == nil or width <= 0 or height == nil or height <= 0 then
    return
  end

  local fixed, fillCount = 0, 0
  for _, column in ipairs(self.columns) do
    if column.width then
      fixed = fixed + column.width
    else
      fillCount = fillCount + 1
    end
  end
  local fillWidth = fillCount > 0 and math.max((width - fixed) / fillCount, 40) or 0

  local x = 0
  for _, column in ipairs(self.columns) do
    column.actualWidth = column.width or fillWidth
    column.x = x
    column.header:ClearAllPoints()
    column.header:SetPoint("TOPLEFT", self, "TOPLEFT", x, 0)
    column.header:SetWidth(column.actualWidth - 1)
    x = x + column.actualWidth
  end

  local numRows = math.max(math.floor((height - HEADER_HEIGHT) / ROW_HEIGHT), 1)
  for index = #self.rows + 1, numRows do
    self.rows[index] = self:CreateRow(index)
  end
  for index = numRows + 1, #self.rows do
    self.rows[index]:Hide()
  end
  self.numRows = numRows

  for index = 1, numRows do
    local row = self.rows[index]
    for columnIndex, column in ipairs(self.columns) do
      local cell = row.cells[columnIndex]
      local left = column.x + 6
      cell:ClearAllPoints()
      if column.cellType == "item" then
        row.itemIcon:ClearAllPoints()
        row.itemIcon:SetPoint("LEFT", row, "LEFT", column.x + 4, 0)
        left = left + ROW_HEIGHT
      end
      cell:SetPoint("LEFT", row, "LEFT", left, 0)
      cell:SetWidth(math.max(column.actualWidth - (left - column.x) - 6, 5))
    end
  end

  self:Refresh()
end

-- Scrolls so that the entry at this position can be seen
function AuctionaryResultsListingMixin:ScrollToIndex(index)
  if self.numRows == nil or index == nil then
    return
  end
  local offset = FauxScrollFrame_GetOffset(self.ScrollFrame)
  local newOffset = offset
  if index <= offset then
    newOffset = index - 1
  elseif index > offset + self.numRows then
    newOffset = index - self.numRows
  end
  if newOffset ~= offset then
    FauxScrollFrame_OnVerticalScroll(self.ScrollFrame, newOffset * ROW_HEIGHT, ROW_HEIGHT, function()
      self:Refresh()
    end)
  end
end

-- The entry delta places away from the selected one, in the order shown
-- (the first entry when nothing is selected); scrolled into view
function AuctionaryResultsListingMixin:StepSelection(isSelected, delta)
  local count = self.dataProvider:GetCount()
  if count == 0 then
    return nil
  end
  local current
  for index = 1, count do
    if isSelected(self.dataProvider:GetEntryAt(index)) then
      current = index
      break
    end
  end
  local target = current == nil and 1 or math.max(1, math.min(count, current + delta))
  self:ScrollToIndex(target)
  return self.dataProvider:GetEntryAt(target), target
end

function AuctionaryResultsListingMixin:Refresh()
  if self.numRows == nil then
    return
  end

  local count = self.dataProvider:GetCount()
  FauxScrollFrame_Update(self.ScrollFrame, count, self.numRows, ROW_HEIGHT)
  local offset = FauxScrollFrame_GetOffset(self.ScrollFrame)

  for index = 1, self.numRows do
    local row = self.rows[index]
    local rowData = self.dataProvider:GetEntryAt(index + offset)
    row.rowData = rowData
    if rowData == nil then
      row:Hide()
    else
      for columnIndex, column in ipairs(self.columns) do
        row.cells[columnIndex]:SetText(FormatCell(column, rowData))
      end
      if row.itemIcon then
        row.itemIcon:SetTexture(rowData.iconTexture)
      end
      if self.options.isRowSelected and self.options.isRowSelected(rowData) then
        row.Selected:Show()
      else
        row.Selected:Hide()
      end
      row:Show()
    end
  end

  if not self.searching then
    if count == 0 and self.showEmptyText then
      self.NoResultsText:Show()
    elseif count > 0 then
      self.NoResultsText:Hide()
    end
  end
end

function Auctionator.Components.CreateResultsListing(parent, dataProvider, options)
  listingCount = listingCount + 1
  local name = "AuctionaryResultsListing" .. listingCount

  local listing = CreateFrame("Frame", name, parent)
  Auctionator.Compat.Mixin(listing, AuctionaryResultsListingMixin)

  listing.ScrollFrame = CreateFrame("ScrollFrame", name .. "ScrollFrame", listing, "FauxScrollFrameTemplate")
  listing.ScrollFrame:SetPoint("TOPLEFT", listing, "TOPLEFT", 0, -HEADER_HEIGHT)
  listing.ScrollFrame:SetPoint("BOTTOMRIGHT", listing, "BOTTOMRIGHT", -SCROLL_BAR_WIDTH, 0)

  listing:Init(dataProvider, options)
  return listing
end

-- A data provider frame with the given columns.
-- definition = { layout = {...}, uniqueKey = function(entry), comparators = { field = comparatorFactory } }
function Auctionator.Components.CreateDataProvider(definition)
  local provider = CreateFrame("Frame")
  Auctionator.Compat.Mixin(provider, AuctionaryDataProviderMixin)
  provider:OnLoad()
  provider.processingIndex = 0
  provider.cacheUsedCount = 0

  local counter = 0
  function provider:GetTableLayout()
    return definition.layout
  end
  function provider:UniqueKey(entry)
    if definition.uniqueKey then
      return definition.uniqueKey(entry)
    end
    counter = counter + 1
    return counter
  end
  function provider:Sort(fieldName, sortDirection)
    local factory = (definition.comparators and definition.comparators[fieldName])
      or Auctionator.Utilities.StringComparator
    local comparator = factory(sortDirection, fieldName)
    table.sort(self.results, function(left, right)
      return comparator(left, right)
    end)
    self:SetDirty()
  end
  -- Replaces everything that is shown
  function provider:SetEntries(entries)
    self:Reset()
    self:AppendEntries(entries, true)
  end

  provider:SetScript("OnUpdate", provider.OnUpdate)
  return provider
end

-- Keyboard shortcuts of the tabs (arrow keys, Enter). Each key is bound to a
-- hidden button while it is wanted, so the action runs as a real key press
-- (buying and posting are only allowed then). Text boxes with the cursor in
-- them still get their keys first.
Auctionator.Keys = {}

local count = 0

-- handlers: { UP = function() end, ... }; isWanted(key) says per key whether
-- it should be bound right now
function Auctionator.Keys.Create(handlers, isWanted)
  count = count + 1
  local owner = CreateFrame("Frame", nil, UIParent)
  local buttons, bound = {}, {}
  for key, handler in pairs(handlers) do
    local name = "AuctionaryKey" .. count .. key
    local button = CreateFrame("Button", name, owner)
    button:Hide()
    button:SetScript("OnClick", function()
      pcall(handler)
    end)
    buttons[key] = name
  end

  local function Update()
    if InCombatLockdown ~= nil and InCombatLockdown() then
      return
    end
    for key, name in pairs(buttons) do
      local ok, wanted = pcall(isWanted, key)
      wanted = ok and wanted and true or false
      if wanted ~= (bound[key] == true) then
        if wanted then
          SetOverrideBindingClick(owner, true, key, name)
        else
          SetOverrideBinding(owner, true, key, nil)
        end
        bound[key] = wanted
      end
    end
  end

  -- Checked only while the auction house is open; on closing, the keys
  -- are released once and the checks stop
  local elapsed = 0
  owner:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + (delta or 0)
    if elapsed >= 0.15 then
      elapsed = 0
      Update()
      if AuctionFrame == nil or not AuctionFrame:IsShown() then
        owner:Hide()
      end
    end
  end)
  owner:RegisterEvent("AUCTION_HOUSE_SHOW")
  owner:SetScript("OnEvent", function()
    owner:Show()
  end)
  return { Update = Update }
end
