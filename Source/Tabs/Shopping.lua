local Auctionator = Auctionary

-- The Shopping tab: search box, recent searches, results per item and the
-- list of auctions to buy from after picking a result.
AuctionaryShoppingTabFrameMixin = {}

local SHOPPING_LIST_TABLE_LAYOUT = {
  {
    headerText = AUCTIONARY_L_RESULTS_PRICE_COLUMN,
    headerParameters = { "minPrice" }, cellParameters = { "minPrice" },
    cellType = "price", width = 140, buyDot = true,
  },
  {
    headerText = AUCTIONARY_L_RESULTS_NAME_COLUMN,
    headerParameters = { "name" }, cellParameters = { "name" },
    cellType = "item",
  },
  {
    headerText = AUCTIONARY_L_ITEM_LEVEL,
    headerParameters = { "itemLevel" }, cellParameters = { "itemLevel" },
    width = 90,
  },
  {
    headerText = AUCTIONARY_L_RESULTS_AVAILABLE_COLUMN,
    headerParameters = { "totalQuantity" }, cellParameters = { "available" },
    width = 80,
  },
}

local SIDE_TABLE_LAYOUT = {
  {
    headerText = AUCTIONARY_L_RECENT_SEARCHES or "Recent Searches",
    cellParameters = { "text" },
  },
}

function AuctionaryShoppingTabFrameMixin:OnLoad()
  Auctionator.EventBus:RegisterSource(self, "AuctionaryShoppingTabFrameMixin")

  self:CreateSearchOptions()
  self:CreateSidePanel()
  self:CreateResults()

  self.BuyFrame = Auctionator.Buying.CreateFrame(self)
  self.BuyFrame:SetPoint("TOPLEFT", self.ResultsListing, "TOPLEFT", 0, 0)
  self.BuyFrame:SetPoint("BOTTOMRIGHT", self.ResultsListing, "BOTTOMRIGHT", 0, 0)
  self.BuyFrame.onClose = function()
    self.ResultsListing:Show()
    -- Quantities changed if something was bought
    self:RefreshResults()
  end

  self.SearchProvider = Auctionator.Search.CreateLegacySearchProvider()
  self.SearchProvider:InitSearch(
    function(results)
      local wasRunning = self.searchRunning
      self.searchRunning = false
      self:SetStatus("")
      Auctionator.EventBus:Fire(self, Auctionator.Shopping.Tab.Events.SearchEnd, results)
      if self.correctionNote ~= nil then
        self:SetStatus(self.correctionNote)
        self.correctionNote = nil
      end
      -- Not after a cancelled search
      if wasRunning and #results == 0 and self:TryCorrectedSearch() then
        return
      end
      self.correcting = false
      if wasRunning then
        self:OpenBuyFrameIfObvious(results)
      else
        self.reopenKey = nil
      end
    end,
    function(current, total, partialResults)
      self.termProgress = { current = current, total = total }
      Auctionator.EventBus:Fire(self, Auctionator.Shopping.Tab.Events.SearchIncrementalUpdate, partialResults, total, current)
    end
  )
  self.SearchProvider.onPageProgress = function(progress)
    local text = (SEARCHING or "Searching") .. " " .. progress.page .. "/" .. progress.totalPages
    if self.termProgress and self.termProgress.total > 1 then
      text = text .. "  (" .. self.termProgress.current .. "/" .. self.termProgress.total .. ")"
    end
    self:SetStatus(text)
  end

  Auctionator.EventBus:Register(self, {
    Auctionator.Shopping.Tab.Events.SearchStart,
    Auctionator.Shopping.Tab.Events.SearchEnd,
    Auctionator.Shopping.Tab.Events.SearchIncrementalUpdate,
    Auctionator.Shopping.Tab.Events.UpdateSearchTerm,
    Auctionator.Shopping.Events.RecentSearchesUpdate,
    Auctionator.Shopping.Events.ListMetaChange,
    Auctionator.Shopping.Events.ListItemChange,
    Auctionator.Shopping.Events.ListImportFinished,
  })

  self:SetScript("OnShow", function()
    self:RefreshSidePanel()
    self.SearchBox:SetFocus()
  end)
  self:SetScript("OnHide", function()
    if self.searchRunning then
      self:StopSearch()
    end
  end)
end

function AuctionaryShoppingTabFrameMixin:CreateSearchOptions()
  self.SearchBox = CreateFrame("EditBox", "AuctionaryShoppingSearchBox", self, "InputBoxTemplate")
  self.SearchBox:SetWidth(260)
  self.SearchBox:SetHeight(20)
  self.SearchBox:SetPoint("TOPLEFT", self, "TOPLEFT", 88, -44)
  self.SearchBox:SetAutoFocus(false)
  self.SearchBox:SetMaxLetters(200)
  self.SearchBox:SetScript("OnEnterPressed", function()
    self:SearchButtonClicked()
  end)
  self.SearchBox:SetScript("OnEscapePressed", function(editBox)
    editBox:ClearFocus()
  end)

  self.SearchButton = CreateFrame("Button", "AuctionaryShoppingSearchButton", self, "UIPanelButtonTemplate")
  self.SearchButton:SetWidth(100)
  self.SearchButton:SetHeight(22)
  self.SearchButton:SetPoint("LEFT", self.SearchBox, "RIGHT", 8, 0)
  self.SearchButton:SetText(AUCTIONARY_L_SEARCH)
  self.SearchButton:SetScript("OnClick", function()
    self:SearchButtonClicked()
  end)

  -- Runs the last search again
  self.RefreshButton = CreateFrame("Button", "AuctionaryShoppingRefreshButton", self, "UIPanelButtonTemplate")
  self.RefreshButton:SetWidth(28)
  self.RefreshButton:SetHeight(22)
  self.RefreshButton:SetPoint("LEFT", self.SearchButton, "RIGHT", 4, 0)
  self.RefreshButton.Icon = self.RefreshButton:CreateTexture(nil, "OVERLAY")
  self.RefreshButton.Icon:SetTexture("Interface\\AddOns\\Auctionary\\Images\\Refresh")
  self.RefreshButton.Icon:SetWidth(16)
  self.RefreshButton.Icon:SetHeight(16)
  self.RefreshButton.Icon:SetPoint("CENTER", self.RefreshButton, "CENTER", 0, 0)
  self.RefreshButton.Icon:SetVertexColor(1, 0.82, 0)
  self.RefreshButton:SetScript("OnClick", function()
    self:RefreshSearch()
  end)
  self.RefreshButton:SetScript("OnEnter", function(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(REFRESH or "Refresh")
    GameTooltip:Show()
  end)
  self.RefreshButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  self.RefreshButton:Disable()
  self.RefreshButton.Icon:SetVertexColor(0.5, 0.5, 0.5)

  -- Extended search options
  self.MoreButton = CreateFrame("Button", "AuctionaryShoppingMoreButton", self, "UIPanelButtonTemplate")
  self.MoreButton:SetWidth(28)
  self.MoreButton:SetHeight(22)
  self.MoreButton:SetPoint("LEFT", self.RefreshButton, "RIGHT", 4, 0)
  self.MoreButton:SetText("...")
  self.MoreButton:SetScript("OnClick", function()
    self:ShowItemDialog(
      AUCTIONARY_L_LIST_EXTENDED_SEARCH_HEADER or "Extended Search Options",
      AUCTIONARY_L_SEARCH,
      self:GetSearchTerm(),
      function(searchTerm)
        self:SetSearchTerm(searchTerm)
        self:DoSearch({ searchTerm })
        Auctionator.Shopping.Recents.Save(searchTerm)
      end
    )
  end)
  self.MoreButton:SetScript("OnEnter", function(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(AUCTIONARY_L_LIST_EXTENDED_SEARCH_HEADER or "Extended Search Options")
    GameTooltip:Show()
  end)
  self.MoreButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  self.Status = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  self.Status:SetPoint("LEFT", self.MoreButton, "RIGHT", 12, 0)
  self.Status:SetJustifyH("LEFT")

  -- Shift-clicking an item anywhere while the tab is open searches for it
  -- (unless the link is going into an open chat line)
  hooksecurefunc("ChatEdit_InsertLink", function(link)
    if link == nil or not self:IsVisible() then
      return
    end
    if (ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()) or
       (ChatFrameEditBox and ChatFrameEditBox:IsVisible()) then
      return
    end
    local name = Auctionator.Utilities.GetNameFromLink(link)
    if name ~= nil and name ~= "" then
      local searchTerm = "\"" .. name .. "\""
      self:SetSearchTerm(searchTerm)
      self:DoSearch({ searchTerm })
      Auctionator.Shopping.Recents.Save(searchTerm)
    end
  end)
end

---- Left side: shopping lists and recent searches

local VIEWS = Auctionator.Constants.ShoppingListViews

local function SmallButton(parent, text, width)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetWidth(width)
  button:SetHeight(20)
  button:SetText(text)
  button:SetNormalFontObject(GameFontNormalSmall)
  button:SetHighlightFontObject(GameFontHighlightSmall)
  button:SetDisabledFontObject(GameFontDisableSmall)
  return button
end

function AuctionaryShoppingTabFrameMixin:ShowItemDialog(title, finishedText, searchTerm, onFinished)
  if self.itemDialog == nil then
    self.itemDialog = Auctionator.Shopping.CreateItemDialog(self)
  end
  self.itemDialog:Init(title, finishedText)
  self.itemDialog:SetOnFinishedClicked(onFinished)
  self.itemDialog:SetItemString(searchTerm or "")
  self.itemDialog:Show()
  self.itemDialog.SearchString:SetFocus()
end

function AuctionaryShoppingTabFrameMixin:CreateSidePanel()
  local SIDE_WIDTH = 200

  self.ListsViewButton = SmallButton(self, AUCTIONARY_L_SHOPPING_LISTS or "Shopping Lists", SIDE_WIDTH / 2)
  self.ListsViewButton:SetPoint("TOPLEFT", self, "TOPLEFT", 26, -82)
  self.ListsViewButton:SetScript("OnClick", function()
    self:SetSideView(VIEWS.Lists)
  end)

  self.RecentsViewButton = SmallButton(self, AUCTIONARY_L_RECENT_SEARCHES or "Recent Searches", SIDE_WIDTH / 2)
  self.RecentsViewButton:SetPoint("LEFT", self.ListsViewButton, "RIGHT", 0, 0)
  self.RecentsViewButton:SetScript("OnClick", function()
    self:SetSideView(VIEWS.Recents)
  end)

  self.SideProvider = Auctionator.Components.CreateDataProvider({
    layout = SIDE_TABLE_LAYOUT,
  })
  self.SideListing = Auctionator.Components.CreateResultsListing(self, self.SideProvider, {
    onRowClick = function(rowData, mouseButton)
      self:SideRowClicked(rowData, mouseButton)
    end,
    isRowSelected = function(rowData)
      return rowData.kind == "back"
    end,
    noEmptyText = true,
  })
  self.SideListing:SetPoint("TOPLEFT", self.ListsViewButton, "BOTTOMLEFT", 0, -2)
  self.SideListing:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 26, 68)
  self.SideListing:SetWidth(SIDE_WIDTH)

  -- Bottom row, depends on what is shown above
  self.ImportButton = SmallButton(self, "Import", SIDE_WIDTH / 3)
  self.ImportButton:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 26 + SIDE_WIDTH * 2 / 3, 46)
  self.ImportButton:SetScript("OnClick", function()
    Auctionator.Components.ShowTextDialog(
      "Import shopping lists",
      "Paste an exported list here (one list per line: name^item^item ...). A list with the same name is replaced.",
      "", "Import",
      function(text)
        text = strtrim(text or "")
        if text ~= "" then
          Auctionator.Shopping.Lists.BatchImportFromString(text)
          self:RefreshSidePanel()
        end
      end
    )
  end)

  self.NewListButton = SmallButton(self, AUCTIONARY_L_NEW_LIST or "New List", SIDE_WIDTH * 2 / 3)
  self.NewListButton:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 26, 46)
  self.NewListButton:SetScript("OnClick", function()
    StaticPopup_Show(Auctionator.Constants.DialogNames.CreateShoppingList, nil, nil, { view = self })
  end)

  self.SearchAllButton = SmallButton(self, AUCTIONARY_L_SEARCH_ALL or "Search All", SIDE_WIDTH / 2)
  self.SearchAllButton:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 26, 46)
  self.SearchAllButton:SetScript("OnClick", function()
    self:SearchList(self.expandedListName)
  end)

  self.AddToListButton = SmallButton(self, AUCTIONARY_L_ADD_TO_LIST or "Add To List", SIDE_WIDTH / 2)
  self.AddToListButton:SetPoint("LEFT", self.SearchAllButton, "RIGHT", 0, 0)
  self.AddToListButton:SetScript("OnClick", function()
    local list = self:GetExpandedList()
    local searchTerm = self:GetSearchTerm()
    if list ~= nil and searchTerm ~= "" then
      list:InsertItem(searchTerm)
    end
  end)
  self.AddToListButton:SetScript("OnEnter", function(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText("Adds what is in the search box to this list", 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  self.AddToListButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  self.SideMenu = CreateFrame("Frame", "AuctionaryShoppingSideMenu", UIParent, "UIDropDownMenuTemplate")

  self.sideView = Auctionator.Config.Get(Auctionator.Config.Options.SHOPPING_LAST_CONTAINER_VIEW)
  if self.sideView ~= VIEWS.Recents then
    self.sideView = VIEWS.Lists
  end
end

function AuctionaryShoppingTabFrameMixin:SetSideView(view)
  self.sideView = view
  Auctionator.Config.Set(Auctionator.Config.Options.SHOPPING_LAST_CONTAINER_VIEW, view)
  self:RefreshSidePanel()
end

function AuctionaryShoppingTabFrameMixin:GetExpandedList()
  if self.expandedListName == nil then
    return nil
  end
  if Auctionator.Shopping.ListManager:GetIndexForName(self.expandedListName) == nil then
    self.expandedListName = nil
    return nil
  end
  return Auctionator.Shopping.ListManager:GetByName(self.expandedListName)
end

function AuctionaryShoppingTabFrameMixin:ExpandList(listName)
  self.expandedListName = listName
  self.sideView = VIEWS.Lists
  self:RefreshSidePanel()
end

function AuctionaryShoppingTabFrameMixin:CollapseList()
  self.expandedListName = nil
  self:RefreshSidePanel()
end

function AuctionaryShoppingTabFrameMixin:ListRenamed(oldName, newName)
  if self.expandedListName == oldName then
    self.expandedListName = newName
  end
  self:RefreshSidePanel()
end

function AuctionaryShoppingTabFrameMixin:SearchList(listName)
  local list = listName and Auctionator.Shopping.ListManager:GetIndexForName(listName) ~= nil
    and Auctionator.Shopping.ListManager:GetByName(listName)
  if list and list:GetItemCount() > 0 then
    self:DoSearch(list:GetAllItems())
  end
end

-- Text and tooltip of a list entry, with the price of the last scan: green
-- when it is at or below the entry's maximum price, red when above
local function TermDisplay(searchTerm)
  local text = Auctionator.Search.PrettifySearchString(searchTerm)
  local tooltipText = "Left click: search\nRight click: more"
  local split = Auctionator.Search.SplitAdvancedSearch(searchTerm)
  local itemID = Auctionator.Search.GetItemIDByName(split.searchString)
  local price = itemID and Auctionator.Database ~= nil and Auctionator.Database:GetPrice(tostring(itemID))
  if price then
    local priceText = Auctionator.Compat.GetMoneyString(price, true)
    local age = Auctionator.Database:GetPriceAge(tostring(itemID))
    local ageText = age == nil and "" or (age == 0 and " (today)" or (" (" .. age .. " days ago)"))
    tooltipText = tooltipText .. "\n\nLowest in the last scan: " .. priceText .. ageText
    if split.maxPrice ~= nil then
      local limit = Auctionator.Compat.GetMoneyString(split.maxPrice, true)
      if price <= split.maxPrice then
        text = "|cff20ff20" .. text .. "|r"
        tooltipText = tooltipText .. "\n|cff20ff20At or below your maximum of " .. limit .. "|r"
      else
        text = "|cffff6060" .. text .. "|r"
        tooltipText = tooltipText .. "\n|cffff6060Above your maximum of " .. limit .. "|r"
      end
    end
  elseif split.maxPrice ~= nil then
    tooltipText = tooltipText .. "\n\nNo scan price known for this exact name."
  end
  return text, tooltipText
end

local function ListDisplayName(list)
  if list:IsTemporary() then
    return list:GetName() .. " (" .. (AUCTIONARY_L_TEMPORARY_LOWER_CASE or "temporary") .. ")"
  end
  return list:GetName()
end

function AuctionaryShoppingTabFrameMixin:RefreshSidePanel()
  local entries = {}
  local header
  local expandedList = self:GetExpandedList()

  if self.sideView == VIEWS.Recents then
    header = AUCTIONARY_L_RECENT_SEARCHES or "Recent Searches"
    for _, searchTerm in ipairs(Auctionator.Shopping.Recents.GetAll()) do
      table.insert(entries, {
        kind = "recent",
        searchTerm = searchTerm,
        text = Auctionator.Search.PrettifySearchString(searchTerm),
        tooltipText = "Left click: search\nRight click: more",
      })
    end
  elseif expandedList ~= nil then
    header = ListDisplayName(expandedList)
    table.insert(entries, {
      kind = "back",
      text = "<  " .. (AUCTIONARY_L_SHOPPING_LISTS or "Shopping Lists"),
    })
    for index = 1, expandedList:GetItemCount() do
      local searchTerm = expandedList:GetItemByIndex(index)
      local ok, text, tooltipText = pcall(TermDisplay, searchTerm)
      table.insert(entries, {
        kind = "term",
        index = index,
        searchTerm = searchTerm,
        text = ok and text or Auctionator.Search.PrettifySearchString(searchTerm),
        tooltipText = ok and tooltipText or "Left click: search\nRight click: more",
      })
    end
  else
    header = AUCTIONARY_L_SHOPPING_LISTS or "Shopping Lists"
    for index = 1, Auctionator.Shopping.ListManager:GetCount() do
      local list = Auctionator.Shopping.ListManager:GetByIndex(index)
      table.insert(entries, {
        kind = "list",
        listName = list:GetName(),
        text = ListDisplayName(list) .. "  (" .. list:GetItemCount() .. ")",
        tooltipText = "Left click: open\nRight click: more",
      })
    end
  end

  self.SideListing.columns[1].header.Text:SetText(header)
  self.SideProvider:SetEntries(entries)

  local showingLists = self.sideView ~= VIEWS.Recents
  if showingLists and expandedList ~= nil then
    self.NewListButton:Hide()
    self.ImportButton:Hide()
    self.SearchAllButton:Show()
    self.AddToListButton:Show()
  elseif showingLists then
    self.NewListButton:Show()
    self.ImportButton:Show()
    self.SearchAllButton:Hide()
    self.AddToListButton:Hide()
  else
    self.NewListButton:Hide()
    self.ImportButton:Hide()
    self.SearchAllButton:Hide()
    self.AddToListButton:Hide()
  end

  if showingLists then
    self.ListsViewButton:LockHighlight()
    self.RecentsViewButton:UnlockHighlight()
  else
    self.ListsViewButton:UnlockHighlight()
    self.RecentsViewButton:LockHighlight()
  end
end

function AuctionaryShoppingTabFrameMixin:ShowSideMenu(entries)
  local menu = {}
  for _, entry in ipairs(entries) do
    table.insert(menu, { text = entry[1], func = entry[2], notCheckable = 1 })
  end
  table.insert(menu, { text = CANCEL, notCheckable = 1 })
  EasyMenu(menu, self.SideMenu, "cursor", 0, 0, "MENU")
end

function AuctionaryShoppingTabFrameMixin:SideRowClicked(rowData, mouseButton)
  local DialogNames = Auctionator.Constants.DialogNames
  local search = function()
    self:SetSearchTerm(rowData.searchTerm)
    self:DoSearch({ rowData.searchTerm })
  end

  if rowData.kind == "back" then
    self:CollapseList()

  elseif rowData.kind == "recent" then
    if mouseButton == "RightButton" then
      local entries = { { AUCTIONARY_L_SEARCH, search } }
      local list = self:GetExpandedList()
      if list ~= nil then
        table.insert(entries, {
          (AUCTIONARY_L_ADD_TO_LIST or "Add To List") .. ": " .. list:GetName(),
          function() list:InsertItem(rowData.searchTerm) end,
        })
      end
      table.insert(entries, { AUCTIONARY_L_DELETE or DELETE, function()
        Auctionator.Shopping.Recents.DeleteEntry(rowData.searchTerm)
      end })
      self:ShowSideMenu(entries)
    else
      search()
    end

  elseif rowData.kind == "list" then
    local listName = rowData.listName
    if mouseButton == "RightButton" then
      local list = Auctionator.Shopping.ListManager:GetByName(listName)
      local entries = {
        { AUCTIONARY_L_SEARCH_ALL or "Search All", function() self:SearchList(listName) end },
      }
      if list:IsTemporary() then
        table.insert(entries, { AUCTIONARY_L_MAKE_PERMANENT or "Make Permanent", function()
          StaticPopup_Show(DialogNames.MakePermanentShoppingList, listName, nil, { view = self, listName = listName })
        end })
      else
        table.insert(entries, { AUCTIONARY_L_RENAME or "Rename", function()
          StaticPopup_Show(DialogNames.RenameShoppingList, listName, nil, { view = self, listName = listName })
        end })
      end
      table.insert(entries, { "Export", function()
        Auctionator.Components.ShowTextDialog(
          "Export: " .. listName,
          "Copy this text (Ctrl+C). It can be imported again with the Import button.",
          Auctionator.Shopping.Lists.GetBatchExportString(listName)
        )
      end })
      table.insert(entries, { AUCTIONARY_L_DELETE or DELETE, function()
        StaticPopup_Show(DialogNames.DeleteShoppingList, listName, nil, { view = self, listName = listName })
      end })
      self:ShowSideMenu(entries)
    else
      self:ExpandList(listName)
    end

  elseif rowData.kind == "term" then
    if mouseButton == "RightButton" then
      self:ShowSideMenu({
        { AUCTIONARY_L_SEARCH, search },
        { AUCTIONARY_L_EDIT_ITEM or "Edit Item", function()
          local listName, index, oldTerm = self.expandedListName, rowData.index, rowData.searchTerm
          self:ShowItemDialog(
            AUCTIONARY_L_LIST_EDIT_ITEM_HEADER or "Edit Shopping List Item",
            AUCTIONARY_L_EDIT_ITEM or "Edit Item",
            oldTerm,
            function(newTerm)
              local list = Auctionator.Shopping.ListManager:GetIndexForName(listName) ~= nil
                and Auctionator.Shopping.ListManager:GetByName(listName)
              if list and list:GetItemByIndex(index) == oldTerm then
                list:AlterItem(index, newTerm)
              end
            end
          )
        end },
        { AUCTIONARY_L_DELETE or DELETE, function()
          local list = self:GetExpandedList()
          if list ~= nil and list:GetItemByIndex(rowData.index) == rowData.searchTerm then
            list:DeleteItem(rowData.index)
          end
        end },
      })
    else
      search()
    end
  end
end

function AuctionaryShoppingTabFrameMixin:CreateResults()
  self.DataProvider = Auctionator.Components.CreateDataProvider({
    layout = SHOPPING_LIST_TABLE_LAYOUT,
    uniqueKey = function(entry) return entry.key end,
    comparators = {
      minPrice = Auctionator.Utilities.NumberComparator,
      name = Auctionator.Utilities.StringComparator,
      totalQuantity = Auctionator.Utilities.NumberComparator,
      itemLevel = Auctionator.Utilities.NumberComparator,
    },
  })

  self.ResultsListing = Auctionator.Components.CreateResultsListing(self, self.DataProvider, {
    onRowClick = function(rowData, mouseButton)
      if IsShiftKeyDown() then
        self:SetSearchTerm("\"" .. rowData.plainItemName .. "\"")
      elseif #rowData.auctions > 0 then
        self:OpenBuyFrame(rowData)
      end
    end,
  })
  self.ResultsListing:SetPoint("TOPLEFT", self, "TOPLEFT", 234, -82)
  self.ResultsListing:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -14, 44)
end

-- Quantities and prices after something was bought
function AuctionaryShoppingTabFrameMixin:RefreshResults()
  local AuctionItemInfo = Auctionator.Constants.AuctionItemInfo
  for index = 1, self.DataProvider:GetCount() do
    local entry = self.DataProvider:GetEntryAt(index)
    local total, minPrice = 0, nil
    for _, auction in ipairs(entry.auctions) do
      local count = auction.info[AuctionItemInfo.Quantity] or 0
      local buyout = auction.info[AuctionItemInfo.Buyout] or 0
      total = total + count
      if buyout > 0 and count > 0 then
        local unitPrice = math.ceil(buyout / count)
        if minPrice == nil or unitPrice < minPrice then
          minPrice = unitPrice
        end
      end
    end
    if #entry.auctions > 0 or entry.totalQuantity > 0 then
      entry.totalQuantity = total
      entry.minPrice = minPrice
      entry.available = Auctionator.Compat.FormatLargeNumber(total)
    end
  end
  self.ResultsListing:Refresh()
end

function AuctionaryShoppingTabFrameMixin:SetStatus(text)
  self.Status:SetText(text or "")
end

function AuctionaryShoppingTabFrameMixin:SetSearchTerm(searchTerm)
  self.lastSearchTerm = searchTerm
  local split = Auctionator.Search.SplitAdvancedSearch(searchTerm)
  local text = split.searchString
  if split.isExact then
    text = "\"" .. text .. "\""
  end
  self.shownSearchText = text
  self.SearchBox:SetText(text)
end

-- The box only shows the name part of an extended search term
function AuctionaryShoppingTabFrameMixin:GetSearchTerm()
  local text = self.SearchBox:GetText()
  if self.lastSearchTerm ~= nil and text == self.shownSearchText then
    return self.lastSearchTerm
  end
  return text
end

function AuctionaryShoppingTabFrameMixin:SearchButtonClicked()
  if self.searchRunning then
    self:StopSearch()
    return
  end
  local searchTerm = self:GetSearchTerm()
  if searchTerm == "" then
    return
  end
  self.SearchBox:ClearFocus()
  self:DoSearch({ searchTerm })
  Auctionator.Shopping.Recents.Save(searchTerm)
end

function AuctionaryShoppingTabFrameMixin:DoSearch(terms, options)
  if #terms == 0 then
    return
  end

  self:StopSearch()
  if self.BuyFrame:IsShown() then
    self.BuyFrame:Close()
  end

  self.lastTerms = terms
  self.lastOptions = options
  self.RefreshButton:Enable()
  self.RefreshButton.Icon:SetVertexColor(1, 0.82, 0)

  self.searchRunning = true
  self.termProgress = nil
  Auctionator.EventBus:Fire(self, Auctionator.Shopping.Tab.Events.SearchStart, terms)
  self.SearchProvider:Search(terms, options or {})
end

-- A search for one term that found nothing is tried once more with the
-- closest known item name ("etrnl life" -> "Eternal Life"). Returns true
-- when such a search was started.
function AuctionaryShoppingTabFrameMixin:TryCorrectedSearch()
  if self.correcting or self.lastTerms == nil or #self.lastTerms ~= 1 then
    return false
  end
  local term = self.lastTerms[1]
  local divider = Auctionator.Constants.AdvancedSearchDivider
  local dividerAt = term:find(divider, 1, true)
  local text = dividerAt and term:sub(1, dividerAt - 1) or term
  local rest = dividerAt and term:sub(dividerAt) or ""
  if text == "" or text:sub(1, 1) == "\"" then
    return false -- nothing typed, or an exact search in quotes
  end

  local similar = Auctionator.Search.FindSimilarNames(text, 3)
  if #similar == 0 then
    return false
  end
  local note = "Nothing found for \"" .. text .. "\". Showing \"" .. similar[1] .. "\"."
  if #similar > 1 then
    note = note .. "  Also close: " .. table.concat(similar, ", ", 2)
  end

  self.correcting = true
  self:SetSearchTerm(similar[1] .. rest)
  self:DoSearch({ similar[1] .. rest }, self.lastOptions)
  self.correctionNote = note
  return true
end

-- Searches again for the same terms. With the list of auctions of an item
-- open, that list is shown again afterwards with the new auctions.
function AuctionaryShoppingTabFrameMixin:RefreshSearch()
  if self.lastTerms == nil then
    return
  end
  local reopenKey = self.BuyFrame:IsShown() and self.BuyFrame.result and self.BuyFrame.result.key
  self:DoSearch(self.lastTerms, self.lastOptions)
  self.reopenKey = reopenKey
end

function AuctionaryShoppingTabFrameMixin:OpenBuyFrame(result)
  self:StopSearch()
  self.ResultsListing:Hide()
  self.BuyFrame:Open(result)
  Auctionator.EventBus:Fire(self, Auctionator.Shopping.Tab.Events.BuyScreenShown)
end

-- After a finished search: straight to the auctions when there is nothing
-- to choose from, or when the search was a refresh of that list
function AuctionaryShoppingTabFrameMixin:OpenBuyFrameIfObvious(results)
  local reopenKey = self.reopenKey
  self.reopenKey = nil

  local target
  if reopenKey ~= nil then
    for _, result in ipairs(results) do
      if result.key == reopenKey then
        target = result
      end
    end
  elseif #results == 1 and self.lastTerms ~= nil and #self.lastTerms == 1 then
    target = results[1]
  end

  if target ~= nil and #target.auctions > 0 then
    self:OpenBuyFrame(target)
  end
end

function AuctionaryShoppingTabFrameMixin:StopSearch()
  self.searchRunning = false
  self.SearchProvider:AbortSearch()
end

function AuctionaryShoppingTabFrameMixin:ReceiveEvent(eventName, eventData)
  if eventName == Auctionator.Shopping.Tab.Events.SearchStart then
    self.DataProvider:Reset()
    self.DataProvider.onSearchStarted()
    self.SearchButton:SetText(AUCTIONARY_L_CANCEL)
    self:SetStatus(SEARCHING or "Searching")
  elseif eventName == Auctionator.Shopping.Tab.Events.SearchEnd then
    self.DataProvider:AppendEntries(eventData, true)
    self.SearchButton:SetText(AUCTIONARY_L_SEARCH)
  elseif eventName == Auctionator.Shopping.Tab.Events.SearchIncrementalUpdate then
    self.DataProvider:AppendEntries(eventData)
  elseif eventName == Auctionator.Shopping.Tab.Events.UpdateSearchTerm then
    self:SetSearchTerm(eventData)
  elseif eventName == Auctionator.Shopping.Events.RecentSearchesUpdate or
         eventName == Auctionator.Shopping.Events.ListMetaChange or
         eventName == Auctionator.Shopping.Events.ListItemChange or
         eventName == Auctionator.Shopping.Events.ListImportFinished then
    if self:IsVisible() then
      self:RefreshSidePanel()
    end
  end
end

Auctionator.Tabs.RegisterContent("Shopping", function(panel)
  local frame = CreateFrame("Frame", "AuctionaryShoppingTabFrame", panel)
  frame:SetAllPoints(panel)
  Auctionator.Compat.Mixin(frame, AuctionaryShoppingTabFrameMixin)
  frame:OnLoad()
  panel.Content = frame
end)
