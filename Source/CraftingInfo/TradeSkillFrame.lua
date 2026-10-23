local Auctionary = Auctionary

-- Cost and profit of the selected recipe, shown in the profession window
-- below the reagents. The numbers come straight from the open window, so
-- they also work for recipes the shipped list does not know.
local text

local function Money(amount)
  return Auctionary.Compat.GetMoneyString(math.floor(amount), true)
end

local function IDFromLink(link)
  local id = link and link:match("|Hitem:(%-?%d+)")
  return id
end

-- Cost and income of the recipe at this position of the open profession
-- window. Returns nil for headers and recipes without reagents.
local function Compute(index)
  local _, skillType = GetTradeSkillInfo(index)
  if skillType == nil or skillType == "header" then
    return nil
  end
  local result = { cost = 0, missing = 0 }
  result.numReagents = GetTradeSkillNumReagents(index) or 0
  if result.numReagents == 0 then
    return nil
  end
  for reagentIndex = 1, result.numReagents do
    local reagentID = IDFromLink(GetTradeSkillReagentItemLink(index, reagentIndex))
    local _, _, count = GetTradeSkillReagentInfo(index, reagentIndex)
    local price = reagentID and Auctionary.CraftingInfo.GetReagentPrice(reagentID)
    if price ~= nil and count ~= nil then
      result.cost = result.cost + price * count
    else
      result.missing = result.missing + 1
    end
  end
  -- Enchants have no item to sell
  result.itemID = IDFromLink(GetTradeSkillItemLink(index))
  if result.itemID ~= nil and Auctionary.Database ~= nil then
    local price = Auctionary.Database:GetPrice(result.itemID)
    if price ~= nil then
      local minMade, maxMade = GetTradeSkillNumMade(index)
      local made = math.max(((minMade or 1) + (maxMade or minMade or 1)) / 2, 1)
      result.auction = price * made
      result.profit = price * made * Auctionary.Constants.AfterAHCut - result.cost
    end
  end
  return result
end

local function ProfitText(profit)
  if profit >= 0 then
    return "|cff20ff20" .. Money(profit) .. "|r"
  end
  return "|cffff2020-" .. Money(-profit) .. "|r"
end

local function GetSelectedRecipeText()
  local index = GetTradeSkillSelectionIndex()
  if index == nil or index == 0 or index > GetNumTradeSkills() then
    return nil
  end
  local recipe = Compute(index)
  if recipe == nil then
    return nil
  end

  local Options = Auctionary.Config.Options
  local lines = {}
  local costText = Money(recipe.cost)
  if recipe.missing > 0 then
    costText = costText .. " + ?"
  end
  if Auctionary.Config.Get(Options.CRAFTING_INFO_SHOW_COST) then
    table.insert(lines, "|cffffd100Mats Cost:|r " .. costText)
  end

  if recipe.itemID ~= nil and Auctionary.Database ~= nil and Auctionary.Config.Get(Options.CRAFTING_INFO_SHOW_PROFIT) then
    if recipe.auction ~= nil then
      local profitText = ProfitText(recipe.profit)
      if recipe.missing > 0 then
        profitText = profitText .. " - ?"
      end
      table.insert(lines, "|cffffd100Auction:|r " .. Money(recipe.auction)
        .. "   |cffffd100Profit (after 5% fee):|r " .. profitText)
    else
      table.insert(lines, "|cffffd100Auction:|r unknown")
    end
  end

  if #lines == 0 then
    return nil
  end
  return table.concat(lines, "\n"), recipe.numReagents
end

---- List of all recipes of the open profession, sorted by profit

local PROFIT_LAYOUT = {
  { headerText = "Recipe", headerParameters = { "name" }, cellParameters = { "nameText" } },
  { headerText = "Mats Cost", headerParameters = { "cost" }, cellParameters = { "costText" }, width = 110 },
  { headerText = "Auction", headerParameters = { "auction" }, cellParameters = { "auctionText" }, width = 110 },
  { headerText = "Profit", headerParameters = { "profit" }, cellParameters = { "profitText" }, width = 110 },
  { headerText = "", cellParameters = { "hideText" }, width = 26 },
}
local HIDE_ICON = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14:14:0:0|t"

-- Recipes hidden with the red x, per profession: SavedState.HiddenRecipes[profession][name]
local function HiddenRecipes(profession)
  local state = Auctionary.SavedState
  if state == nil then
    return {}
  end
  state.HiddenRecipes = state.HiddenRecipes or {}
  state.HiddenRecipes[profession] = state.HiddenRecipes[profession] or {}
  return state.HiddenRecipes[profession]
end
local SKILL_COLOURS = {
  optimal = "|cffff8040", medium = "|cffffff00", easy = "|cff40bf40", trivial = "|cff808080",
}
local profitDialog

local function ShowProfitList()
  if profitDialog == nil then
    local number = Auctionary.Utilities.NumberComparator
    profitDialog = Auctionary.Components.CreateDialog("AuctionaryfitDialog", 600, 420, "")
    profitDialog.provider = Auctionary.Components.CreateDataProvider({
      layout = PROFIT_LAYOUT,
      comparators = { name = Auctionary.Utilities.StringComparator, cost = number, auction = number, profit = number },
    })
    profitDialog.listing = Auctionary.Components.CreateResultsListing(profitDialog, profitDialog.provider, {
      emptyText = "No recipes with reagents in the list of the profession window.",
      onRowClick = function(rowData, _, row)
        -- The red x at the right end of the row hides the recipe
        local x = GetCursorPosition() / (row and row:GetEffectiveScale() or 1)
        if row ~= nil and row:GetRight() ~= nil and x >= row:GetRight() - 30 then
          if rowData.name ~= nil then
            HiddenRecipes(profitDialog.profession)[rowData.name] = true
            ShowProfitList()
          end
          return
        end
        -- The position may have changed since the list was made
        for index = 1, GetNumTradeSkills() do
          if GetTradeSkillInfo(index) == rowData.name then
            TradeSkillFrame_SetSelection(index)
            if TradeSkillFrame_Update ~= nil then
              TradeSkillFrame_Update()
            end
            return
          end
        end
      end,
    })
    profitDialog.listing:SetPoint("TOPLEFT", profitDialog, "TOPLEFT", 14, -36)
    profitDialog.listing:SetPoint("BOTTOMRIGHT", profitDialog, "BOTTOMRIGHT", -14, 40)
    profitDialog.summary = profitDialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    profitDialog.summary:SetPoint("BOTTOMLEFT", profitDialog, "BOTTOMLEFT", 16, 18)
    profitDialog.showHiddenButton = CreateFrame("Button", "AuctionaryfitShowHidden", profitDialog, "UIPanelButtonTemplate")
    profitDialog.showHiddenButton:SetWidth(110)
    profitDialog.showHiddenButton:SetHeight(22)
    profitDialog.showHiddenButton:SetPoint("RIGHT", profitDialog.closeButton, "LEFT", -6, 0)
    profitDialog.showHiddenButton:SetText("Show Hidden")
    profitDialog.showHiddenButton:SetScript("OnClick", function()
      local state = Auctionary.SavedState
      if state ~= nil and state.HiddenRecipes ~= nil then
        state.HiddenRecipes[profitDialog.profession] = nil
      end
      ShowProfitList()
    end)
    profitDialog.summary:SetPoint("RIGHT", profitDialog.showHiddenButton, "LEFT", -8, 0)
    profitDialog.summary:SetJustifyH("LEFT")
  end
  local dialog = profitDialog
  dialog.profession = (GetTradeSkillLine()) or "?"
  local hidden = HiddenRecipes(dialog.profession)
  local hiddenCount = 0
  local entries, profitable = {}, 0
  for index = 1, GetNumTradeSkills() do
    local name, skillType = GetTradeSkillInfo(index)
    local ok, recipe = pcall(Compute, index)
    if ok and recipe ~= nil and name ~= nil and hidden[name] then
      hiddenCount = hiddenCount + 1
    elseif ok and recipe ~= nil and name ~= nil then
      local unknown = recipe.missing > 0 and " + ?" or ""
      if recipe.profit ~= nil and recipe.profit > 0 then
        profitable = profitable + 1
      end
      table.insert(entries, {
        name = name,
        nameText = (SKILL_COLOURS[skillType] or "") .. name .. "|r",
        cost = recipe.cost,
        costText = Money(recipe.cost) .. unknown,
        -- Recipes without a known price sort below everything else
        auction = recipe.auction or -1,
        auctionText = recipe.auction and Money(recipe.auction) or "|cff808080unknown|r",
        profit = recipe.profit or -1e12,
        profitText = recipe.profit and ProfitText(recipe.profit) or "|cff808080-|r",
        hideText = HIDE_ICON,
        tooltipText = "Click: select the recipe\nClick the red x: hide it from this list",
      })
    end
  end
  table.sort(entries, function(a, b)
    return a.profit > b.profit
  end)
  dialog.title:SetText("Profit List - " .. ((GetTradeSkillLine()) or "Profession"))
  dialog.summary:SetText(#entries .. " recipes, " .. profitable .. " with a profit (after the 5% fee)."
    .. (hiddenCount > 0 and ("  " .. hiddenCount .. " hidden.") or ""))
  if hiddenCount > 0 then
    dialog.showHiddenButton:Show()
  else
    dialog.showHiddenButton:Hide()
  end
  dialog:Show()
  -- Filled after the list is visible (see the history window)
  dialog.provider:SetEntries(entries)
  Auctionary.Compat.After(0.05, function()
    if dialog.listing:IsVisible() then
      dialog.listing:Refresh()
    end
  end)
end

local function Update()
  if text == nil or TradeSkillFrame == nil or not TradeSkillFrame:IsShown() then
    return
  end
  if not Auctionary.Config.Get(Auctionary.Config.Options.CRAFTING_INFO_SHOW) then
    text:Hide()
    return
  end
  local ok, result, numReagents = pcall(GetSelectedRecipeText)
  if not ok or result == nil then
    text:Hide()
    return
  end

  -- Below the last row of reagents (two per row)
  local lastLeft = numReagents - ((numReagents + 1) % 2)
  local anchor = _G["TradeSkillReagent" .. lastLeft] or TradeSkillReagentLabel
  text:ClearAllPoints()
  text:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
  text:SetText(result)
  text:Show()
end

local function Setup()
  if text ~= nil or TradeSkillFrame == nil or TradeSkillDetailScrollChildFrame == nil then
    return
  end
  text = TradeSkillDetailScrollChildFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  text:SetJustifyH("LEFT")
  text:SetWidth(290)
  text:Hide()

  -- Just below the window, so it cannot cover anything in it
  local button = CreateFrame("Button", "AuctionaryfitListButton", TradeSkillFrame, "UIPanelButtonTemplate")
  button:SetWidth(90)
  button:SetHeight(20)
  button:SetPoint("TOPLEFT", TradeSkillFrame, "BOTTOMLEFT", 20, 74)
  button:SetText("Profit List")
  button:SetScript("OnClick", function()
    if profitDialog ~= nil and profitDialog:IsShown() then
      profitDialog:Hide()
    else
      ShowProfitList()
    end
  end)
  TradeSkillFrame:HookScript("OnHide", function()
    if profitDialog ~= nil then
      profitDialog:Hide()
    end
  end)

  if TradeSkillFrame_SetSelection ~= nil then
    hooksecurefunc("TradeSkillFrame_SetSelection", Update)
  end
  if TradeSkillFrame_Update ~= nil then
    hooksecurefunc("TradeSkillFrame_Update", Update)
  end
  Update()
end

---- Profession window next to the auction house
-- The auction window takes the whole managed panel area, so the client
-- closes the profession window when both want to be open. While the auction
-- house is open the profession window is taken out of that management: it
-- opens as a free window beside the auction window and can be dragged.
local savedPanelInfo
local auctionOpen = false

local function PlaceBesideAuctionHouse()
  if not auctionOpen or TradeSkillFrame == nil or AuctionFrame == nil or not TradeSkillFrame:IsShown() then
    return
  end
  TradeSkillFrame:SetMovable(true)
  TradeSkillFrame:SetClampedToScreen(true)
  if not TradeSkillFrame.auctionaryDrag then
    TradeSkillFrame.auctionaryDrag = true
    TradeSkillFrame:HookScript("OnHide", function()
      Auctionary.Compat.After(0, function()
        pcall(Auctionary.CraftingInfo.ReleaseStuckPanel)
      end)
    end)
    TradeSkillFrame:EnableMouse(true)
    TradeSkillFrame:RegisterForDrag("LeftButton")
    TradeSkillFrame:HookScript("OnDragStart", function(window)
      if auctionOpen then
        window:StartMoving()
      end
    end)
    TradeSkillFrame:HookScript("OnDragStop", function(window)
      window:StopMovingOrSizing()
    end)
  end
  TradeSkillFrame:ClearAllPoints()
  TradeSkillFrame:SetPoint("TOPLEFT", AuctionFrame, "TOPRIGHT", -4, 0)
end

-- The client copies a window's panel settings onto the window the first time
-- it is shown and reads only that copy afterwards. So besides the entry in
-- the list, the mark that says "copy made" has to go as well.
local wasDefined
local function ReleaseFromPanels()
  if TradeSkillFrame ~= nil and TradeSkillFrame:GetAttribute("UIPanelLayout-defined") then
    wasDefined = true
    TradeSkillFrame:SetAttribute("UIPanelLayout-defined", nil)
  end
end

local addedSpecial = false
local function AuctionHouseOpened()
  auctionOpen = true
  if UIPanelWindows ~= nil and UIPanelWindows["TradeSkillFrame"] ~= nil then
    savedPanelInfo = UIPanelWindows["TradeSkillFrame"]
    UIPanelWindows["TradeSkillFrame"] = nil
  end
  ReleaseFromPanels()
  -- Out of the panel management Escape would not close it any more
  if UISpecialFrames ~= nil then
    local listed = false
    for _, name in ipairs(UISpecialFrames) do
      if name == "TradeSkillFrame" then
        listed = true
      end
    end
    if not listed then
      table.insert(UISpecialFrames, "TradeSkillFrame")
      addedSpecial = true
    end
  end
end

-- The client keeps a list of which window sits on the left, in the middle
-- and so on. A window that was hidden while it was not managed by the client
-- (while the auction house was open) can stay in that list although it is
-- closed. Escape then keeps "closing" that invisible window and the game menu
-- never opens. Hiding it the client's way takes it out of the list again.
local PANEL_AREAS = { "left", "center", "right", "doublewide", "fullscreen" }
local function ReleaseStuckPanel()
  if auctionOpen or TradeSkillFrame == nil or GetUIPanel == nil or HideUIPanel == nil then
    return
  end
  if TradeSkillFrame:IsShown() or UIPanelWindows == nil or UIPanelWindows["TradeSkillFrame"] == nil then
    return
  end
  for _, area in ipairs(PANEL_AREAS) do
    if GetUIPanel(area) == TradeSkillFrame then
      HideUIPanel(TradeSkillFrame)
      return
    end
  end
end
Auctionary.CraftingInfo.ReleaseStuckPanel = ReleaseStuckPanel

local function AuctionHouseClosed()
  auctionOpen = false
  if savedPanelInfo ~= nil and UIPanelWindows ~= nil then
    UIPanelWindows["TradeSkillFrame"] = savedPanelInfo
    savedPanelInfo = nil
  end
  if addedSpecial and UISpecialFrames ~= nil then
    for index = #UISpecialFrames, 1, -1 do
      if UISpecialFrames[index] == "TradeSkillFrame" then
        table.remove(UISpecialFrames, index)
      end
    end
    addedSpecial = false
  end
  if wasDefined and TradeSkillFrame ~= nil then
    -- The copy on the window (with any changes by ElvUI) counts again
    TradeSkillFrame:SetAttribute("UIPanelLayout-defined", true)
  end
  wasDefined = nil
  -- Closed together with the auction house, the client's way, so the
  -- client's panel list starts clean
  if TradeSkillFrame ~= nil and TradeSkillFrame:IsShown() and HideUIPanel ~= nil then
    HideUIPanel(TradeSkillFrame)
  end
  ReleaseStuckPanel()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")
frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
frame:SetScript("OnEvent", function(_, eventName, addonName)
  if eventName == "AUCTION_HOUSE_SHOW" then
    pcall(AuctionHouseOpened)
    return
  elseif eventName == "AUCTION_HOUSE_CLOSED" then
    pcall(AuctionHouseClosed)
    return
  end
  if eventName == "TRADE_SKILL_SHOW" then
    pcall(PlaceBesideAuctionHouse)
  end
  if eventName == "TRADE_SKILL_SHOW" or addonName == "Blizzard_TradeSkillUI" then
    Setup()
    Update()
  end
end)
