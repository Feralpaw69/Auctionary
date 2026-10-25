-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

---- Shopping tab
--  top:    search box, Search/Cancel, refresh, "..." (extended search), status
--  left:   shopping lists (or one opened list) / recent searches
--  right:  one row per item found; a click opens its auctions to buy from
--
-- `shop` is a plain table that holds the frames; the list dialogs get it as
-- data.view and call shop:ExpandList(name) / shop:ListRenamed(old, new).

local VIEWS = Auctionary.Constants.ShoppingListViews
local ListEvents = Auctionary.Shopping.Events
local Info = Auctionary.Constants.AuctionItemInfo
local SIDE_X, SIDE_WIDTH, TOP_Y = 26, 200, -82
local CLICK_HINT = "Left click: search\nRight click: more"

local function Lists()
  return Auctionary.Shopping.ListManager
end

local function ListByName(name)
  if name ~= nil and Lists():GetIndexForName(name) ~= nil then
    return Lists():GetByName(name)
  end
end

local function Tip(frame, text, wrap)
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(type(text) == "function" and text() or text, 1, 1, 1, 1, wrap)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function PanelButton(parent, name, text, width, height, small)
  local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
  button:SetWidth(width)
  button:SetHeight(height or 22)
  button:SetText(text or "")
  if small then
    button:SetNormalFontObject(GameFontNormalSmall)
    button:SetHighlightFontObject(GameFontHighlightSmall)
    button:SetDisabledFontObject(GameFontDisableSmall)
  end
  return button
end

local shop = {}

---- Searching

function shop:SetStatus(text)
  self.status:SetText(text or "")
end

-- The box shows only the name part of an extended term; as long as it is
-- unchanged, the whole term is used
function shop:ShowTerm(term)
  local parts = Auctionary.Search.SplitAdvancedSearch(term)
  local text = parts.isExact and ("\"" .. parts.searchString .. "\"") or parts.searchString
  self.fullTerm, self.boxText = term, text
  self.box:SetText(text)
end

function shop:TermInBox()
  local text = self.box:GetText()
  if self.fullTerm ~= nil and text == self.boxText then
    return self.fullTerm
  end
  return text
end

function shop:SetRefreshable(on)
  if on then
    self.refreshButton:Enable()
    self.refreshButton.icon:SetVertexColor(1, 0.82, 0)
  else
    self.refreshButton:Disable()
    self.refreshButton.icon:SetVertexColor(0.5, 0.5, 0.5)
  end
end

-- terms: list of search terms; remember: also put the first in the recents
function shop:Run(terms, remember)
  if terms == nil or #terms == 0 then
    return
  end
  if remember then
    Auctionary.Shopping.Recents.Save(terms[1])
  end
  self.search:Stop()
  if self.buyFrame:IsShown() then
    self.buyFrame:Close()
  end
  self.lastTerms = terms
  self.termCount = #terms
  self:SetRefreshable(true)
  self.results:Clear()
  self.results:MarkBusy()
  self.searchButton:SetText(AUCTIONARY2_L_CANCEL)
  self:SetStatus(SEARCHING or "Searching")
  self.search:Start(terms)
end

function shop:RunTerm(term)
  self:ShowTerm(term)
  self:Run({ term }, true)
end

function shop:SearchOrCancel()
  if self.search:IsRunning() then
    self.search:Stop()
    return
  end
  local term = self:TermInBox()
  if term ~= "" then
    self.box:ClearFocus()
    self:Run({ term }, true)
  end
end

function shop:Refresh()
  if self.lastTerms ~= nil then
    local open = self.buyFrame:IsShown() and self.buyFrame.result
    self:Run(self.lastTerms)
    self.reopenKey = open and open.key or nil
  end
end

function shop:OnPage(progress)
  local text = (SEARCHING or "Searching") .. " " .. progress.page .. "/" .. progress.totalPages
  local number, count = self.search:GetPosition()
  if count > 1 then
    text = text .. "  (" .. number .. "/" .. count .. ")"
  end
  self:SetStatus(text)
end

-- A single term that found nothing is tried once more with the closest
-- known item name ("etrnl life" -> "Eternal Life")
function shop:TryCloseName()
  if self.retried or self.lastTerms == nil or #self.lastTerms ~= 1 then
    return false
  end
  local term = self.lastTerms[1]
  local cut = term:find(Auctionary.Constants.AdvancedSearchDivider, 1, true)
  local name, rest = term, ""
  if cut then
    name, rest = term:sub(1, cut - 1), term:sub(cut)
  end
  if name == "" or name:sub(1, 1) == "\"" then
    return false
  end
  local close = Auctionary.Search.FindSimilarNames(name, 3)
  if #close == 0 then
    return false
  end
  local note = "Nothing found for \"" .. name .. "\". Showing \"" .. close[1] .. "\"."
  if #close > 1 then
    note = note .. "  Also close: " .. table.concat(close, ", ", 2)
  end
  self.retried = true
  self:ShowTerm(close[1] .. rest)
  self:Run({ close[1] .. rest })
  self.pendingNote = note
  return true
end

-- Straight to the auctions when there is nothing to choose, or when the
-- search refreshed an opened item
function shop:OpenIfObvious(found)
  local key = self.reopenKey
  self.reopenKey = nil
  local pick
  if key ~= nil then
    for _, result in ipairs(found) do
      if result.key == key then
        pick = result
      end
    end
  elseif #found == 1 and self.termCount == 1 then
    pick = found[1]
  end
  if pick ~= nil and #pick.auctions > 0 then
    self:OpenAuctions(pick)
  end
end

function shop:OnDone(found, stopped)
  self.results:Add(found, true)
  self.searchButton:SetText(AUCTIONARY2_L_SEARCH)
  self:SetStatus(self.pendingNote or "")
  self.pendingNote = nil
  if stopped then
    self.reopenKey = nil
    self.retried = false
    return
  end
  if #found == 0 and self:TryCloseName() then
    return
  end
  self.retried = false
  self:OpenIfObvious(found)
end

---- Results and buying

function shop:OpenAuctions(result)
  self.search:Stop()
  self.resultList:Hide()
  self.buyFrame:Open(result)
end

-- After buying: quantities and lowest prices from the auctions left
function shop:Recount()
  for index = 1, self.results:Count() do
    local result = self.results:At(index)
    local total, lowest = 0, nil
    for _, auction in ipairs(result.auctions) do
      local count, buyout = auction.info[Info.Quantity] or 0, auction.info[Info.Buyout] or 0
      total = total + count
      if count > 0 and buyout > 0 then
        lowest = math.min(lowest or math.huge, math.ceil(buyout / count))
      end
    end
    if #result.auctions > 0 or result.totalQuantity > 0 then
      result.totalQuantity, result.minPrice = total, lowest
      result.available = Auctionary.Compat.FormatLargeNumber(total)
    end
  end
  self.resultList:Refresh()
end

---- Left side

function shop:OpenedList()
  local list = ListByName(self.openList)
  if list == nil then
    self.openList = nil
  end
  return list
end

function shop:ExpandList(name)
  self.openList = name
  self.view = VIEWS.Lists
  self:RefreshSide()
end

function shop:ListRenamed(oldName, newName)
  if self.openList == oldName then
    self.openList = newName
  end
  self:RefreshSide()
end

function shop:SetView(view)
  self.view = view
  Auctionary.Config.Set(Auctionary.Config.Options.SHOPPING_LAST_CONTAINER_VIEW, view)
  self:RefreshSide()
end

function shop:SearchList(name)
  local list = ListByName(name)
  if list ~= nil and list:GetItemCount() > 0 then
    self:Run(list:GetAllItems())
  end
end

local function Named(list)
  if list:IsTemporary() then
    return list:GetName() .. " (" .. (AUCTIONARY2_L_TEMPORARY or "temporary") .. ")"
  end
  return list:GetName()
end

-- A list entry with the last scan price: green at or below the entry's
-- maximum price, red above it
local function EntryText(term)
  local text = Auctionary.Search.PrettifySearchString(term)
  local tip = CLICK_HINT
  local parts = Auctionary.Search.SplitAdvancedSearch(term)
  local itemID = Auctionary.Search.GetItemIDByName(parts.searchString)
  local db = Auctionary.Database
  local price = itemID and db ~= nil and db:GetPrice(tostring(itemID))
  local limit = parts.maxPrice
  if not price then
    if limit ~= nil then
      tip = tip .. "\n\nNo scan price known for this exact name."
    end
    return text, tip
  end
  local age = db:GetPriceAge(tostring(itemID))
  local when = (age == nil and "") or (age == 0 and " (today)") or (" (" .. age .. " days ago)")
  tip = tip .. "\n\nLowest in the last scan: " .. Auctionary.Compat.GetMoneyString(price, true) .. when
  if limit ~= nil then
    local money = Auctionary.Compat.GetMoneyString(limit, true)
    if price <= limit then
      text = "|cff20ff20" .. text .. "|r"
      tip = tip .. "\n|cff20ff20At or below your maximum of " .. money .. "|r"
    else
      text = "|cffff6060" .. text .. "|r"
      tip = tip .. "\n|cffff6060Above your maximum of " .. money .. "|r"
    end
  end
  return text, tip
end

local function SideRows(self)
  local rows, title = {}, nil
  local opened = self:OpenedList()
  if self.view == VIEWS.Recents then
    title = AUCTIONARY2_L_RECENTS or "Recent Searches"
    for _, term in ipairs(Auctionary.Shopping.Recents.GetAll()) do
      rows[#rows + 1] = { kind = "recent", searchTerm = term,
        text = Auctionary.Search.PrettifySearchString(term), tooltipText = CLICK_HINT }
    end
  elseif opened ~= nil then
    title = Named(opened)
    rows[1] = { kind = "back", text = "<  " .. (AUCTIONARY2_L_LISTS or "Shopping Lists") }
    for index = 1, opened:GetItemCount() do
      local term = opened:GetItemByIndex(index)
      local ok, text, tip = pcall(EntryText, term)
      if not ok then
        text, tip = Auctionary.Search.PrettifySearchString(term), CLICK_HINT
      end
      rows[#rows + 1] = { kind = "term", index = index, searchTerm = term, text = text, tooltipText = tip }
    end
  else
    title = AUCTIONARY2_L_LISTS or "Shopping Lists"
    for index = 1, Lists():GetCount() do
      local list = Lists():GetByIndex(index)
      rows[#rows + 1] = { kind = "list", listName = list:GetName(),
        text = Named(list) .. "  (" .. list:GetItemCount() .. ")", tooltipText = "Left click: open\nRight click: more" }
    end
  end
  return rows, title, opened
end

function shop:RefreshSide()
  local rows, title, opened = SideRows(self)
  self.sideList:SetColumnTitle(1, title)
  self.side:Replace(rows)

  local lists = self.view ~= VIEWS.Recents
  local shown = {
    [self.newListButton] = lists and opened == nil,
    [self.importButton] = lists and opened == nil,
    [self.searchAllButton] = lists and opened ~= nil,
    [self.addButton] = lists and opened ~= nil,
  }
  for button, on in pairs(shown) do
    if on then button:Show() else button:Hide() end
  end
  if lists then
    self.listsButton:LockHighlight()
    self.recentsButton:UnlockHighlight()
  else
    self.listsButton:UnlockHighlight()
    self.recentsButton:LockHighlight()
  end
end

function shop:Menu(entries)
  local menu = {}
  for _, entry in ipairs(entries) do
    menu[#menu + 1] = { text = entry[1], func = entry[2], notCheckable = 1 }
  end
  menu[#menu + 1] = { text = CANCEL, notCheckable = 1 }
  EasyMenu(menu, self.menuFrame, "cursor", 0, 0, "MENU")
end

function shop:EditTerm(title, buttonText, term, onDone)
  if self.editor == nil then
    self.editor = Auctionary.Shopping.CreateSearchEditor(self.frame)
  end
  self.editor:Edit(title, buttonText, term or "", onDone)
end

local Dialog = Auctionary.Constants.DialogNames
local DELETE_TEXT = function() return AUCTIONARY2_L_DELETE or DELETE end

local function ListMenu(self, name)
  local list = Lists():GetByName(name)
  local data = { view = self, listName = name }
  local entries = { { AUCTIONARY2_L_LIST_SEARCH_ALL or "Search All", function() self:SearchList(name) end } }
  if list:IsTemporary() then
    entries[#entries + 1] = { AUCTIONARY2_L_LIST_KEEP or "Make Permanent",
      function() StaticPopup_Show(Dialog.MakePermanentShoppingList, name, nil, data) end }
  else
    entries[#entries + 1] = { AUCTIONARY2_L_RENAME or "Rename",
      function() StaticPopup_Show(Dialog.RenameShoppingList, name, nil, data) end }
  end
  entries[#entries + 1] = { "Export", function()
    Auctionary.Components.ShowTextDialog("Export: " .. name,
      "Copy this text (Ctrl+C). It can be imported again with the Import button.",
      Auctionary.Shopping.Lists.GetBatchExportString(name))
  end }
  entries[#entries + 1] = { DELETE_TEXT(),
    function() StaticPopup_Show(Dialog.DeleteShoppingList, name, nil, data) end }
  return entries
end

local function TermMenu(self, row)
  local name, index, term = self.openList, row.index, row.searchTerm
  local edit = AUCTIONARY2_L_EDIT or "Edit Item"
  return {
    { AUCTIONARY2_L_SEARCH, function() self:RunTerm(term) end },
    { edit, function()
      self:EditTerm(AUCTIONARY2_L_EDITOR_EDIT_TITLE or "Edit Shopping List Item", edit, term, function(newTerm)
        local list = ListByName(name)
        -- Only if the entry was not changed or moved meanwhile
        if list ~= nil and list:GetItemByIndex(index) == term then
          list:AlterItem(index, newTerm)
        end
      end)
    end },
    { DELETE_TEXT(), function()
      local list = self:OpenedList()
      if list ~= nil and list:GetItemByIndex(index) == term then
        list:DeleteItem(index)
      end
    end },
  }
end

local function RecentMenu(self, row)
  local term = row.searchTerm
  local entries = { { AUCTIONARY2_L_SEARCH, function() self:RunTerm(term) end } }
  local list = self:OpenedList()
  if list ~= nil then
    entries[#entries + 1] = { (AUCTIONARY2_L_LIST_ADD or "Add To List") .. ": " .. list:GetName(),
      function() list:InsertItem(term) end }
  end
  entries[#entries + 1] = { DELETE_TEXT(), function() Auctionary.Shopping.Recents.DeleteEntry(term) end }
  return entries
end

function shop:SideClicked(row, mouseButton)
  local right = mouseButton == "RightButton"
  if row.kind == "back" then
    self.openList = nil
    self:RefreshSide()
  elseif row.kind == "list" then
    if right then self:Menu(ListMenu(self, row.listName)) else self:ExpandList(row.listName) end
  elseif row.kind == "term" then
    if right then self:Menu(TermMenu(self, row)) else self:RunTerm(row.searchTerm) end
  elseif row.kind == "recent" then
    if right then self:Menu(RecentMenu(self, row)) else self:RunTerm(row.searchTerm) end
  end
end

---- Building the tab

local RESULT_COLUMNS = {
  { title = AUCTIONARY2_L_COL_PRICE, sort = "minPrice",
    field = "minPrice", kind = "price", width = 140, buyDot = true },
  { title = AUCTIONARY2_L_COL_NAME, sort = "name",
    field = "name", kind = "item" },
  { title = AUCTIONARY2_L_ITEM_LEVEL, sort = "itemLevel",
    field = "itemLevel", width = 90 },
  { title = AUCTIONARY2_L_COL_AVAILABLE, sort = "totalQuantity",
    field = "available", width = 80 },
}

local function BuildTop(self, frame)
  self.box = CreateFrame("EditBox", "Auctionary2ShoppingSearchBox", frame, "InputBoxTemplate")
  self.box:SetWidth(260)
  self.box:SetHeight(20)
  self.box:SetPoint("TOPLEFT", frame, "TOPLEFT", 88, -44)
  self.box:SetAutoFocus(false)
  self.box:SetMaxLetters(200)
  self.box:SetScript("OnEnterPressed", function() self:SearchOrCancel() end)
  self.box:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)

  self.searchButton = PanelButton(frame, "Auctionary2ShoppingSearchButton", AUCTIONARY2_L_SEARCH, 100)
  self.searchButton:SetPoint("LEFT", self.box, "RIGHT", 8, 0)
  self.searchButton:SetScript("OnClick", function() self:SearchOrCancel() end)

  -- Same search again
  self.refreshButton = PanelButton(frame, "Auctionary2ShoppingRefreshButton", nil, 28)
  self.refreshButton:SetPoint("LEFT", self.searchButton, "RIGHT", 4, 0)
  local icon = self.refreshButton:CreateTexture(nil, "OVERLAY")
  icon:SetTexture("Interface\\AddOns\\Auctionary\\Images\\Refresh")
  icon:SetWidth(16)
  icon:SetHeight(16)
  icon:SetPoint("CENTER", 0, 0)
  self.refreshButton.icon = icon
  self.refreshButton:SetScript("OnClick", function() self:Refresh() end)
  Tip(self.refreshButton, REFRESH or "Refresh")
  self:SetRefreshable(false)

  local extended = AUCTIONARY2_L_EDITOR_SEARCH_TITLE or "Extended Search Options"
  local more = PanelButton(frame, "Auctionary2ShoppingMoreButton", "...", 28)
  self.moreButton = more
  more:SetPoint("LEFT", self.refreshButton, "RIGHT", 4, 0)
  more:SetScript("OnClick", function()
    self:EditTerm(extended, AUCTIONARY2_L_SEARCH, self:TermInBox(), function(term) self:RunTerm(term) end)
  end)
  Tip(more, extended)

  self.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  self.status:SetPoint("LEFT", more, "RIGHT", 12, 0)
  self.status:SetJustifyH("LEFT")

  -- Shift-click on an item anywhere searches for it while the tab is open,
  -- unless the link goes into a chat line
  hooksecurefunc("ChatEdit_InsertLink", function(link)
    if link == nil or not frame:IsVisible() then
      return
    end
    local typing = (ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow())
      or (ChatFrameEditBox and ChatFrameEditBox:IsVisible())
    local name = not typing and Auctionary.Utilities.GetNameFromLink(link)
    if name and name ~= "" then
      self:RunTerm("\"" .. name .. "\"")
    end
  end)
end

local function BuildSide(self, frame)
  local half = SIDE_WIDTH / 2
  self.listsButton = PanelButton(frame, nil, AUCTIONARY2_L_LISTS or "Shopping Lists", half, 20, true)
  self.listsButton:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDE_X, TOP_Y)
  self.listsButton:SetScript("OnClick", function() self:SetView(VIEWS.Lists) end)

  self.recentsButton = PanelButton(frame, nil, AUCTIONARY2_L_RECENTS or "Recent Searches", half, 20, true)
  self.recentsButton:SetPoint("LEFT", self.listsButton, "RIGHT", 0, 0)
  self.recentsButton:SetScript("OnClick", function() self:SetView(VIEWS.Recents) end)

  self.side = Auctionary.Components.CreateRowSet({
    columns = { { title = AUCTIONARY2_L_RECENTS or "Recent Searches", field = "text" } },
  })
  self.sideList = Auctionary.Components.CreateTable(frame, self.side, {
    onRowClick = function(row, mouseButton) self:SideClicked(row, mouseButton) end,
    isRowSelected = function(row) return row.kind == "back" end,
    noEmptyText = true,
  })
  self.sideList:SetPoint("TOPLEFT", self.listsButton, "BOTTOMLEFT", 0, -2)
  self.sideList:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", SIDE_X, 68)
  self.sideList:SetWidth(SIDE_WIDTH)

  -- Bottom row: New List + Import for all lists, Search All + Add To List
  -- for an opened list
  local third = SIDE_WIDTH / 3
  self.newListButton = PanelButton(frame, nil, AUCTIONARY2_L_LIST_NEW or "New List", third * 2, 20, true)
  self.newListButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", SIDE_X, 46)
  self.newListButton:SetScript("OnClick", function()
    StaticPopup_Show(Dialog.CreateShoppingList, nil, nil, { view = self })
  end)

  self.importButton = PanelButton(frame, nil, "Import", third, 20, true)
  self.importButton:SetPoint("LEFT", self.newListButton, "RIGHT", 0, 0)
  self.importButton:SetScript("OnClick", function()
    Auctionary.Components.ShowTextDialog("Import shopping lists",
      "Paste an exported list here (one list per line: name^item^item ...). A list with the same name is replaced.",
      "", "Import",
      function(text)
        text = strtrim(text or "")
        if text ~= "" then
          Auctionary.Shopping.Lists.BatchImportFromString(text)
          self:RefreshSide()
        end
      end)
  end)

  self.searchAllButton = PanelButton(frame, nil, AUCTIONARY2_L_LIST_SEARCH_ALL or "Search All", half, 20, true)
  self.searchAllButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", SIDE_X, 46)
  self.searchAllButton:SetScript("OnClick", function() self:SearchList(self.openList) end)

  self.addButton = PanelButton(frame, nil, AUCTIONARY2_L_LIST_ADD or "Add To List", half, 20, true)
  self.addButton:SetPoint("LEFT", self.searchAllButton, "RIGHT", 0, 0)
  self.addButton:SetScript("OnClick", function()
    local list, term = self:OpenedList(), self:TermInBox()
    if list ~= nil and term ~= "" then
      list:InsertItem(term)
    end
  end)
  Tip(self.addButton, "Adds what is in the search box to this list", true)

  self.menuFrame = CreateFrame("Frame", "Auctionary2ShoppingSideMenu", UIParent, "UIDropDownMenuTemplate")
  local saved = Auctionary.Config.Get(Auctionary.Config.Options.SHOPPING_LAST_CONTAINER_VIEW)
  self.view = saved == VIEWS.Recents and VIEWS.Recents or VIEWS.Lists
end

local function BuildResults(self, frame)
  local U = Auctionary.Utilities
  self.results = Auctionary.Components.CreateRowSet({
    columns = RESULT_COLUMNS,
    rowKey = function(result) return result.key end,
    sorters = {
      minPrice = U.NumberComparator, totalQuantity = U.NumberComparator,
      itemLevel = U.NumberComparator, name = U.StringComparator,
    },
  })
  self.resultList = Auctionary.Components.CreateTable(frame, self.results, {
    onRowClick = function(result)
      if IsShiftKeyDown() then
        self:ShowTerm("\"" .. result.plainItemName .. "\"")
      elseif #result.auctions > 0 then
        self:OpenAuctions(result)
      end
    end,
  })
  self.resultList:SetPoint("TOPLEFT", frame, "TOPLEFT", 234, TOP_Y)
  self.resultList:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 44)

  self.buyFrame = Auctionary.Buying.CreateFrame(frame)
  self.buyFrame:SetPoint("TOPLEFT", self.resultList, "TOPLEFT", 0, 0)
  self.buyFrame:SetPoint("BOTTOMRIGHT", self.resultList, "BOTTOMRIGHT", 0, 0)
  self.buyFrame.onClose = function()
    self.resultList:Show()
    self:Recount()
  end
end

-- Lists and recents changed somewhere
function shop:ReceiveEvent()
  if self.frame:IsVisible() then
    self:RefreshSide()
  end
end

Auctionary.Tabs.RegisterContent("Shopping", function(panel)
  local frame = CreateFrame("Frame", "Auctionary2ShoppingTabFrame", panel)
  frame:SetAllPoints(panel)
  shop.frame = frame
  Auctionary.Shopping.Tab = shop
  BuildTop(shop, frame)
  BuildSide(shop, frame)
  BuildResults(shop, frame)

  shop.search = Auctionary.Search.CreateShoppingSearch({
    onTerm = function(_, _, previous) shop.results:Add(previous) end,
    onPage = function(progress) shop:OnPage(progress) end,
    onDone = function(found, stopped) shop:OnDone(found, stopped) end,
  })

  Auctionary.EventBus:Register(shop, {
    ListEvents.ListsChanged, ListEvents.ListItemsChanged,
    ListEvents.ListsImported, ListEvents.RecentsChanged,
  })
  frame:SetScript("OnShow", function()
    shop:RefreshSide()
    shop.box:SetFocus()
  end)
  frame:SetScript("OnHide", function() shop.search:Stop() end)
  panel.Content = frame
end)
