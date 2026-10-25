-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- Tables
-- A table with a header row (click to sort, Shift-click: original order)
-- and a scroll bar, showing a row set (Components/Rows.lua). Only as many
-- row frames exist as fit into the table; scrolling fills them anew.
--
-- Columns (in the row set's definition):
--   title   header text
--   sort    row field the header sorts by (nil: not sortable)
--   field   row field that is shown (defaults to sort)
--   kind    "text" (default), "price" or "item" (icon + name in its colour)
--   width   fixed width; columns without one share the free space
--   align   "LEFT" / "RIGHT" / "CENTER" (prices default to RIGHT)
--   buyDot  prices only: green/red dot when far below/above the average
--
--   local view = Auctionary.Components.CreateTable(parent, set, {
--     onRowClick = function(row, mouseButton) end,
--     onRowEnter = function(row) end,      -- mouse moved onto a row
--     isRowSelected = function(row) end,   -- highlighted
--     emptyText = "...",                   -- shown for an empty result
--     noEmptyText = true,                  -- nothing shown when empty
--   })
--   view:Refresh(), view:ScrollTo(index), view:Step(isSelected, delta),
--   view:SetColumnTitle(index, text)

local LINE = 20          -- height of a row and of the header
local SCROLL_WIDTH = 24
local tableCount = 0
local Asc, Desc = Auctionary.Constants.SORT.ASCENDING, Auctionary.Constants.SORT.DESCENDING

local View = {}

---- Cell text

local function QualityCode(quality)
  local hex = select(4, GetItemQualityColor(quality or 1))
  if hex == nil then
    return "|cffffffff"
  end
  return hex:sub(1, 2) == "|c" and hex or ("|c" .. hex)
end

-- Green dot: at least 10% below the item's average (good to buy), red dot:
-- at least 10% above it. The average is looked up once per row.
local CHEAP = "|TInterface\\FriendsFrame\\StatusIcon-Online:11:11:0:0|t "
local DEAR = "|TInterface\\FriendsFrame\\StatusIcon-DND:11:11:0:0|t "

local function Dot(row, price)
  if row.itemLink == nil or Auctionary.Database == nil then
    return ""
  end
  if row.buyAverage == nil then
    row.buyAverage = false
    Auctionary.Utilities.DBKeyFromLink(row.itemLink, function(keys)
      if keys[1] ~= nil then
        local days = Auctionary.Config.Get(Auctionary.Config.Options.AUCTION_MEAN_DAYS_LIMIT)
        row.buyAverage = Auctionary.Database:GetScanAverage(keys[1], days) or false
      end
    end)
  end
  local average = row.buyAverage
  if not average or average <= 0 then
    return ""
  elseif price <= average * 0.9 then
    return CHEAP
  elseif price >= average * 1.1 then
    return DEAR
  end
  return ""
end

local function CellText(column, row)
  local value = row[column.field]
  if column.kind == "price" then
    if value == nil or value == 0 then
      return ""
    end
    local dot = ""
    if column.buyDot then
      local ok, result = pcall(Dot, row, value)
      dot = ok and result or ""
    end
    return dot .. Auctionary.Compat.GetAlignedMoneyString(value)
  elseif column.kind == "item" then
    local name = value or ""
    return row.quality ~= nil and (QualityCode(row.quality) .. name .. "|r") or name
  end
  return value == nil and "" or tostring(value)
end

---- Building

local function BuildHeader(view, index, column)
  local header = CreateFrame("Button", nil, view)
  header:SetHeight(LINE)
  header:SetNormalFontObject(GameFontHighlightSmall)
  header:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
  local shade = header:CreateTexture(nil, "BACKGROUND")
  shade:SetAllPoints(header)
  shade:SetTexture(0.25, 0.25, 0.25, 0.6)

  header.label = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  header.label:SetPoint("LEFT", 6, 0)
  header.label:SetPoint("RIGHT", -14, 0)
  header.label:SetJustifyH("LEFT")
  header.label:SetText(column.title or "")

  header.arrow = header:CreateTexture(nil, "OVERLAY")
  header.arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
  header.arrow:SetWidth(9)
  header.arrow:SetHeight(8)
  header.arrow:SetPoint("RIGHT", -4, 0)
  header.arrow:Hide()

  header:RegisterForClicks("LeftButtonUp")
  header:SetScript("OnClick", function() view:SortColumn(index) end)
  return header
end

local function ShowTooltip(frame, row)
  if row.itemLink ~= nil then
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(row.itemLink)
    if row.tooltipExtra ~= nil then
      GameTooltip:AddLine(row.tooltipExtra, 1, 0.3, 0.3, true)
    end
    GameTooltip:Show()
  elseif row.tooltipText ~= nil then
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetText(row.tooltipText, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end
end

local function BuildLine(view, number)
  local line = CreateFrame("Button", nil, view)
  line:SetHeight(LINE)
  line:SetPoint("TOPLEFT", 0, -LINE * number)
  line:SetPoint("RIGHT", -SCROLL_WIDTH, 0)
  line:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  line:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

  line.mark = line:CreateTexture(nil, "BACKGROUND")
  line.mark:SetAllPoints(line)
  line.mark:SetTexture(1, 0.82, 0, 0.2)
  line.mark:Hide()
  if number % 2 == 0 then
    local stripe = line:CreateTexture(nil, "BACKGROUND")
    stripe:SetAllPoints(line)
    stripe:SetTexture(1, 1, 1, 0.04)
  end

  line.texts = {}
  for index, column in ipairs(view.columns) do
    local text = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetHeight(LINE)
    text:SetJustifyH(column.align)
    line.texts[index] = text
    if column.kind == "item" then
      line.icon = line:CreateTexture(nil, "ARTWORK")
      line.icon:SetWidth(LINE - 4)
      line.icon:SetHeight(LINE - 4)
    end
  end

  line:SetScript("OnClick", function(_, mouseButton)
    local row = line.row
    if row == nil then
      return
    end
    -- Shift-click links into chat, Ctrl-click tries the item on
    if row.itemLink ~= nil then
      if IsModifiedClick("CHATLINK") and ChatEdit_InsertLink(row.itemLink) then
        return
      end
      if IsModifiedClick("DRESSUP") then
        DressUpItemLink(row.itemLink)
        return
      end
    end
    if view.options.onRowClick then
      view.options.onRowClick(row, mouseButton, line)
    end
  end)
  line:SetScript("OnEnter", function()
    local row = line.row
    if row == nil then
      return
    end
    if view.options.onRowEnter then
      view.options.onRowEnter(row, line)
    end
    ShowTooltip(line, row)
  end)
  line:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return line
end

-- Column positions and as many lines as fit
function View:Arrange()
  local width, height = self:GetWidth(), self:GetHeight()
  if width == nil or height == nil or width <= SCROLL_WIDTH or height <= 0 then
    return
  end
  width = width - SCROLL_WIDTH

  local fixed, flexible = 0, 0
  for _, column in ipairs(self.columns) do
    if column.width then
      fixed = fixed + column.width
    else
      flexible = flexible + 1
    end
  end
  local share = flexible > 0 and math.max((width - fixed) / flexible, 40) or 0
  local x = 0
  for _, column in ipairs(self.columns) do
    column.x, column.size = x, column.width or share
    column.header:ClearAllPoints()
    column.header:SetPoint("TOPLEFT", x, 0)
    column.header:SetWidth(column.size - 1)
    x = x + column.size
  end

  local fit = math.max(math.floor((height - LINE) / LINE), 1)
  for number = #self.lines + 1, fit do
    self.lines[number] = BuildLine(self, number)
  end
  for number = fit + 1, #self.lines do
    self.lines[number]:Hide()
  end
  self.fit = fit

  for number = 1, fit do
    local line = self.lines[number]
    for index, column in ipairs(self.columns) do
      local left = column.x + 6
      if column.kind == "item" then
        line.icon:ClearAllPoints()
        line.icon:SetPoint("LEFT", column.x + 4, 0)
        left = left + LINE
      end
      local text = line.texts[index]
      text:ClearAllPoints()
      text:SetPoint("LEFT", left, 0)
      text:SetWidth(math.max(column.size - (left - column.x) - 6, 5))
    end
  end
  self:Refresh()
end

---- Showing

function View:Refresh()
  if self.fit == nil then
    return
  end
  local set, options = self.set, self.options
  local count = set:Count()
  FauxScrollFrame_Update(self.scroll, count, self.fit, LINE)
  local offset = FauxScrollFrame_GetOffset(self.scroll)
  for number = 1, self.fit do
    local line = self.lines[number]
    local row = set:At(number + offset)
    line.row = row
    if row == nil then
      line:Hide()
    else
      for index, column in ipairs(self.columns) do
        line.texts[index]:SetText(CellText(column, row))
      end
      if line.icon then
        line.icon:SetTexture(row.iconTexture)
      end
      if options.isRowSelected and options.isRowSelected(row) then
        line.mark:Show()
      else
        line.mark:Hide()
      end
      line:Show()
    end
  end
  if not self.busy and count > 0 then
    self.emptyLabel:Hide()
  end
end

function View:SortColumn(index)
  local column = self.columns[index]
  if column.sort == nil then
    return
  end
  for _, other in ipairs(self.columns) do
    other.header.arrow:Hide()
  end
  if IsShiftKeyDown() then
    self.sortedBy = nil
    self.set:Unsort()
    return
  end
  if self.sortedBy == index and self.direction == Asc then
    self.direction = Desc
    column.header.arrow:SetTexCoord(0, 0.5625, 1, 0)
  else
    self.direction = Asc
    column.header.arrow:SetTexCoord(0, 0.5625, 0, 1)
  end
  self.sortedBy = index
  column.header.arrow:Show()
  self.set:KeepSorted(column.sort, self.direction)
  self.set:SortBy(column.sort, self.direction)
  PlaySound("igMainMenuOptionCheckBoxOn")
end

function View:SetColumnTitle(index, text)
  self.columns[index].header.label:SetText(text or "")
end

function View:ScrollTo(index)
  if self.fit == nil or index == nil then
    return
  end
  local offset = FauxScrollFrame_GetOffset(self.scroll)
  local wanted = offset
  if index <= offset then
    wanted = index - 1
  elseif index > offset + self.fit then
    wanted = index - self.fit
  end
  if wanted ~= offset then
    FauxScrollFrame_OnVerticalScroll(self.scroll, wanted * LINE, LINE, function() self:Refresh() end)
  end
end

-- The row `delta` places away from the selected one, in the order shown
-- (the first row when none is selected), scrolled into view
function View:Step(isSelected, delta)
  local set = self.set
  local count = set:Count()
  if count == 0 then
    return nil
  end
  local current
  for index = 1, count do
    if isSelected(set:At(index)) then
      current = index
      break
    end
  end
  local target = current and math.max(1, math.min(count, current + delta)) or 1
  self:ScrollTo(target)
  return set:At(target), target
end

---- What the row set reports

function View:RowsChanged()
  self:Refresh()
end

function View:Busy()
  self.busy = true
  self.emptyLabel:Hide()
  self.busyLabel:Show()
end

function View:Done()
  self.busy = false
  self.busyLabel:Hide()
  if self.set:Count() == 0 and not self.options.noEmptyText then
    self.emptyLabel:Show()
  else
    self.emptyLabel:Hide()
  end
end

function Auctionary.Components.CreateTable(parent, set, options)
  tableCount = tableCount + 1
  local name = "Auctionary2Table" .. tableCount
  local view = CreateFrame("Frame", name, parent)
  Auctionary.Compat.Mixin(view, View)
  view.set, view.options, view.lines = set, options or {}, {}
  set.watcher = view

  view.columns = {}
  for index, column in ipairs(set.columns) do
    local kind = column.kind or "text"
    view.columns[index] = {
      title = column.title, sort = column.sort, field = column.field or column.sort,
      kind = kind, width = column.width, buyDot = column.buyDot,
      align = column.align or (kind == "price" and "RIGHT" or "LEFT"),
    }
    view.columns[index].header = BuildHeader(view, index, view.columns[index])
  end

  view.scroll = CreateFrame("ScrollFrame", name .. "ScrollFrame", view, "FauxScrollFrameTemplate")
  view.scroll:SetPoint("TOPLEFT", 0, -LINE)
  view.scroll:SetPoint("BOTTOMRIGHT", -SCROLL_WIDTH, 0)
  view.scroll:SetScript("OnVerticalScroll", function(scroll, offset)
    FauxScrollFrame_OnVerticalScroll(scroll, offset, LINE, function() view:Refresh() end)
  end)
  view:EnableMouseWheel(true)
  view:SetScript("OnMouseWheel", function(_, delta)
    local bar = _G[name .. "ScrollFrameScrollBar"]
    bar:SetValue(bar:GetValue() - delta * LINE * 3)
  end)

  view.emptyLabel = view:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  view.emptyLabel:SetPoint("TOP", 0, -60)
  view.emptyLabel:SetText(view.options.emptyText or AUCTIONARY2_L_NO_RESULTS or "No results found.")
  view.emptyLabel:Hide()
  view.busyLabel = view:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  view.busyLabel:SetPoint("TOP", 0, -60)
  view.busyLabel:SetText(SEARCHING or "Searching...")
  view.busyLabel:Hide()

  view:SetScript("OnShow", view.Arrange)
  view:SetScript("OnSizeChanged", view.Arrange)
  view:Arrange()
  return view
end
