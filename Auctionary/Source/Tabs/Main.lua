-- Auctionary 2.0 - Copyright (c) 2026 Feralpaw - MIT licence, see LICENSE.txt
local Auctionary = Auctionary2

-- Adds the Auctionary tabs after the tabs that are already on the auction
-- house window (Blizzard's, and those of other addons). The window itself and
-- AuctionFrameTab_OnClick are left as they are; the addon only watches which
-- tab gets selected.
local TAB_DETAILS = {
  { name = "Shopping",    label = AUCTIONARY2_L_TAB_SHOPPING,   header = AUCTIONARY2_L_TAB_SHOPPING_TITLE },
  { name = "Sniping",     label = "Sniping",                           header = "Auctionary - Sniping" },
  { name = "Selling",     label = AUCTIONARY2_L_TAB_SELLING,    header = AUCTIONARY2_L_TAB_SELLING_TITLE },
  { name = "Cancelling",  label = AUCTIONARY2_L_TAB_CANCELLING, header = AUCTIONARY2_L_TAB_CANCELLING_TITLE },
  { name = "Auctionary", label = "Settings/Info",                     header = "Auctionary - Settings/Info" },
}

local BACKGROUND = {
  AuctionFrameTopLeft  = "Interface\\AuctionFrame\\UI-AuctionFrame-Bid-TopLeft",
  AuctionFrameTop      = "Interface\\AuctionFrame\\UI-AuctionFrame-Auction-Top",
  AuctionFrameTopRight = "Interface\\AuctionFrame\\UI-AuctionFrame-Auction-TopRight",
  AuctionFrameBotLeft  = "Interface\\AuctionFrame\\UI-AuctionFrame-Bid-BotLeft",
  AuctionFrameBot      = "Interface\\AuctionFrame\\UI-AuctionFrame-Auction-Bot",
  AuctionFrameBotRight = "Interface\\AuctionFrame\\UI-AuctionFrame-Bid-BotRight",
}

local tabs = {}
-- created, selected (name of our selected tab), byName, scanButton,
-- goldButton, lastVisible, needsScroll
local state = { byName = {} }

function Auctionary.Tabs.IsCreated()
  return state.created == true
end

-- Name of the selected Auctionary tab, nil while another tab is shown
function Auctionary.Tabs.SelectedName()
  return state.selected
end
local FIRST_TAB_GAP = 14
-- Narrower tabs and a bit more overlap, so all of them fit without scrolling
local TAB_PADDING = -10
local TAB_OVERLAP_PLAIN = 14
-- Filled in at the end of the file: support for ElvUI's look
local Elv = {}
-- How far a tab reaches into its neighbour, and the gap before our first tab
local function TabOverlap()
  return Elv.active and 15 or TAB_OVERLAP_PLAIN
end
local function FirstTabGap()
  return Elv.active and 6 or FIRST_TAB_GAP
end
local contentCreators = {}

-- creator(panel) builds the content of a tab the first time it is needed
function Auctionary.Tabs.RegisterContent(name, creator)
  contentCreators[name] = creator
end

-- The auction window is a "toplevel" frame: the client moves it to the front
-- when it is clicked, and with other addons doing the same the frame levels
-- can end up squeezed together. Our frames then share a level with the
-- window's own artwork, which gets drawn over every texture below the
-- OVERLAY layer (buttons, icons, borders vanish, text stays). So the levels
-- are checked while a panel is shown and put back in order when needed.
local function FixLevels(frame, minLevel)
  if frame:GetFrameLevel() < minLevel then
    frame:SetFrameLevel(minLevel)
  end
  local nextLevel = frame:GetFrameLevel() + 1
  local children = { frame:GetChildren() }
  for _, child in ipairs(children) do
    -- (ElvUI's backdrop frames sit behind their owner on purpose)
    if child.GetFrameLevel ~= nil and child ~= frame.backdrop then
      FixLevels(child, nextLevel)
    end
  end
end

-- Cheap test first (the panel and its direct children); the whole tree is
-- only walked when something is out of order
local function CheckPanelLevels(panel, force)
  local base = AuctionFrame:GetFrameLevel()
  if base == nil then
    return
  end
  local wrong = force or panel:GetFrameLevel() <= base
  if not wrong then
    local level = panel:GetFrameLevel()
    for _, child in ipairs({ panel:GetChildren() }) do
      if child ~= panel.backdrop and child.GetFrameLevel ~= nil and child:GetFrameLevel() <= level then
        wrong = true
        break
      end
    end
  end
  if wrong then
    FixLevels(panel, base + 1)
  end
end

local function CreatePanel(details)
  local panel = CreateFrame("Frame", "Auctionary2" .. details.name .. "Frame", AuctionFrame)
  panel:SetAllPoints(AuctionFrame)
  panel:Hide()

  panel.Title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panel.Title:SetPoint("TOP", AuctionFrame, "TOP", 0, -18)
  panel.Title:SetText(details.header or details.label)

  -- Plain dark area over the artwork of the Blizzard tabs
  panel.Inset = CreateFrame("Frame", nil, panel)
  panel.Inset:SetPoint("TOPLEFT", AuctionFrame, "TOPLEFT", 14, -70)
  panel.Inset:SetPoint("BOTTOMRIGHT", AuctionFrame, "BOTTOMRIGHT", -6, 36)
  panel.Inset:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  panel.Inset:SetBackdropColor(0, 0, 0, 0.9)
  panel.Inset:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
  -- Soft colour wash over the dark area (see Tabs.ApplyBackground)
  panel.Inset.tint = panel.Inset:CreateTexture(nil, "BORDER")
  panel.Inset.tint:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
  panel.Inset.tint:SetPoint("TOPLEFT", panel.Inset, "TOPLEFT", 4, -4)
  panel.Inset.tint:SetPoint("BOTTOMRIGHT", panel.Inset, "BOTTOMRIGHT", -4, 4)
  panel.Inset.tint:Hide()

  local sinceCheck = 0
  panel:SetScript("OnShow", function()
    CheckPanelLevels(panel, true)
    if Auctionary.Tabs.AddEscapeToBoxes ~= nil then
      pcall(Auctionary.Tabs.AddEscapeToBoxes, panel)
    end
    if Elv.SkinPanel then
      Elv.SkinPanel(panel)
    end
  end)
  panel:SetScript("OnHide", function()
    if Elv.PanelHidden then
      Elv.PanelHidden(panel)
    end
  end)
  local sinceSkin = 0
  panel:SetScript("OnUpdate", function(_, elapsed)
    sinceCheck = sinceCheck + (elapsed or 0)
    sinceSkin = sinceSkin + (elapsed or 0)
    if sinceCheck >= 0.3 then
      sinceCheck = 0
      CheckPanelLevels(panel)
    end
    -- Rows and buttons made after the panel was opened
    if sinceSkin >= 1 then
      sinceSkin = 0
      if Elv.SkinPanel then
        Elv.SkinPanel(panel)
      end
    end
  end)

  panel.Placeholder = panel.Inset:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  panel.Placeholder:SetPoint("CENTER")
  panel.Placeholder:SetText(details.label)

  return panel
end

local function CreateTab(details)
  local index = AuctionFrame.numTabs + 1
  local tab = CreateFrame("Button", "AuctionFrameTab" .. index, AuctionFrame, "AuctionTabTemplate")
  tab:SetID(index)
  tab:SetText(details.label)
  -- The first of our tabs keeps a gap to the tabs before it, so it is clear
  -- where the standard auction house ends and the addon begins
  local gap = (#tabs == 0) and FIRST_TAB_GAP or -TAB_OVERLAP_PLAIN
  tab:SetPoint("TOPLEFT", _G["AuctionFrameTab" .. (index - 1)], "TOPRIGHT", gap, 0)
  PanelTemplates_TabResize(tab, TAB_PADDING)
  PanelTemplates_SetNumTabs(AuctionFrame, index)
  PanelTemplates_EnableTab(AuctionFrame, index)

  tab.auctionary2Tab = details.name
  tab.panel = CreatePanel(details)
  if contentCreators[details.name] ~= nil then
    tab.panel.Placeholder:Hide()
    contentCreators[details.name](tab.panel)
  end
  return tab
end

---- Backgrounds
-- Colours of the dark area, to tell the addon's tabs from the standard
-- auction house at a glance. top/bottom: gradient colours, border: frame line.
Auctionary.Tabs.Backgrounds = {
  { key = "black",    name = "Black (default)", tab = { 0.92, 0.96, 1.0 } },
  { key = "midnight", name = "Midnight Blue", top = { 0.05, 0.12, 0.30 }, bottom = { 0.01, 0.02, 0.07 }, border = { 0.35, 0.55, 1.0 }, tab = { 0.35, 0.6, 1.0 } },
  { key = "crimson",  name = "Crimson Gold",  top = { 0.30, 0.05, 0.03 }, bottom = { 0.07, 0.01, 0.01 }, border = { 1.0, 0.78, 0.2 }, tab = { 1.0, 0.3, 0.25 } },
  { key = "emerald",  name = "Emerald",       top = { 0.03, 0.22, 0.14 }, bottom = { 0.01, 0.05, 0.03 }, border = { 0.3, 0.9, 0.6 }, tab = { 0.3, 1.0, 0.5 } },
}

-- One more background per class, in the class colour
do
  local CLASSES = {
    { "DEATHKNIGHT", "Death Knight", 0.77, 0.12, 0.23 },
    { "DRUID", "Druid", 1.00, 0.49, 0.04 },
    { "HUNTER", "Hunter", 0.67, 0.83, 0.45 },
    { "MAGE", "Mage", 0.41, 0.80, 0.94 },
    { "PALADIN", "Paladin", 0.96, 0.55, 0.73 },
    { "PRIEST", "Priest", 1.00, 1.00, 1.00 },
    { "ROGUE", "Rogue", 1.00, 0.96, 0.41 },
    { "SHAMAN", "Shaman", 0.00, 0.44, 0.87 },
    { "WARLOCK", "Warlock", 0.58, 0.51, 0.79 },
    { "WARRIOR", "Warrior", 0.78, 0.61, 0.43 },
  }
  for _, class in ipairs(CLASSES) do
    local token, name, r, g, b = class[1], class[2], class[3], class[4], class[5]
    -- The client's own values and names win when it has them
    local colour = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    if colour ~= nil then
      r, g, b = colour.r, colour.g, colour.b
    end
    if LOCALIZED_CLASS_NAMES_MALE ~= nil and LOCALIZED_CLASS_NAMES_MALE[token] ~= nil then
      name = LOCALIZED_CLASS_NAMES_MALE[token]
    end
    table.insert(Auctionary.Tabs.Backgrounds, {
      key = "class_" .. token,
      name = name,
      top = { r * 0.32, g * 0.32, b * 0.32 },
      bottom = { r * 0.07, g * 0.07, b * 0.07 },
      border = { r, g, b },
      tab = { r, g, b },
    })
  end
end

function Auctionary.Tabs.SetBackground(key)
  Auctionary.Config.Set(Auctionary.Config.Options.TAB_BACKGROUND, key)
  Auctionary.Tabs.ApplyBackground()
  return Auctionary.Tabs.GetBackground().name
end

function Auctionary.Tabs.GetBackground()
  local key = Auctionary.Config.Get(Auctionary.Config.Options.TAB_BACKGROUND)
  for index, background in ipairs(Auctionary.Tabs.Backgrounds) do
    if background.key == key then
      return background, index
    end
  end
  return Auctionary.Tabs.Backgrounds[1], 1
end

-- Colours the artwork of a tab button at the bottom of the window
local TAB_REGIONS = { "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" }
local function TintTabButton(button, colour)
  local name = button and button:GetName()
  if name == nil then
    return
  end
  for _, suffix in ipairs(TAB_REGIONS) do
    local region = _G[name .. suffix]
    if region ~= nil and region.SetVertexColor ~= nil then
      -- Grey artwork first (silver instead of the warm brown), then the colour
      if region.SetDesaturated ~= nil then
        region:SetDesaturated(colour ~= nil)
      end
      if colour ~= nil then
        region:SetVertexColor(colour[1], colour[2], colour[3])
      else
        region:SetVertexColor(1, 1, 1)
      end
    end
  end
end

function Auctionary.Tabs.ApplyBackground()
  local background = Auctionary.Tabs.GetBackground()
  for _, tab in ipairs(tabs) do
    TintTabButton(tab, background.tab)
  end
  TintTabButton(state.scanButton, background.tab)
  TintTabButton(state.goldButton, background.tab)
  for _, tab in ipairs(tabs) do
    local inset = tab.panel.Inset
    if background.top ~= nil then
      local top, bottom = background.top, background.bottom
      inset.tint:SetVertexColor(1, 1, 1, 1)
      inset.tint:SetGradientAlpha("VERTICAL", bottom[1], bottom[2], bottom[3], 1, top[1], top[2], top[3], 1)
      inset.tint:Show()
      inset:SetBackdropBorderColor(background.border[1], background.border[2], background.border[3], 1)
    else
      inset.tint:Hide()
      inset:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    end
  end
end

-- Next background in the list; returns its name
function Auctionary.Tabs.CycleBackground()
  local _, index = Auctionary.Tabs.GetBackground()
  local nextBackground = Auctionary.Tabs.Backgrounds[index % #Auctionary.Tabs.Backgrounds + 1]
  Auctionary.Config.Set(Auctionary.Config.Options.TAB_BACKGROUND, nextBackground.key)
  Auctionary.Tabs.ApplyBackground()
  return nextBackground.name
end

---- Scrolling the tab bar
-- With tabs of other addons in the bar ours may not fit in front of the
-- Full Scan button. Then only as many as fit are shown, with two arrows
-- (and the mouse wheel) to move through them.
local firstVisible = 1
local leftArrow, rightArrow
local ARROW_SPACE = 24

local function CreateArrow(direction)
  local arrow = CreateFrame("Button", "Auctionary2TabArrow" .. direction, AuctionFrame)
  arrow:SetWidth(22)
  arrow:SetHeight(22)
  local file = direction == "Left" and "Prev" or "Next"
  arrow:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. file .. "Page-Up")
  arrow:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. file .. "Page-Down")
  arrow:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. file .. "Page-Disabled")
  arrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  arrow:SetScript("OnClick", function()
    PlaySound("igMainMenuOptionCheckBoxOn")
    Auctionary.Tabs.Scroll(direction == "Left" and -1 or 1)
  end)
  arrow:Hide()
  return arrow
end

function Auctionary.Tabs.UpdateGoldButton()
  local gold = state.goldButton
  if gold == nil then
    return
  end
  if Auctionary.Config.Get(Auctionary.Config.Options.GOLD_TRACKER_BUTTON) then
    gold:Show()
  else
    gold:Hide()
  end
  if state.created then
    Auctionary.Tabs.Layout()
  end
end

function Auctionary.Tabs.Layout()
  if #tabs == 0 then
    return
  end
  if Elv.SkinTabs then
    Elv.SkinTabs()
  end
  local previous = _G["AuctionFrameTab" .. (tabs[1]:GetID() - 1)]
  local scanButton = state.scanButton
  if previous == nil then
    return
  end
  -- The scan button and the Gold Tracker sit in the same row as the tabs,
  -- also when a skin (ElvUI) moves the tabs up or down
  local frameBottom, tabTop = AuctionFrame:GetBottom(), previous:GetTop()
  if scanButton ~= nil and frameBottom ~= nil and tabTop ~= nil then
    scanButton:ClearAllPoints()
    scanButton:SetPoint("TOPRIGHT", AuctionFrame, "BOTTOMRIGHT", -20, tabTop - frameBottom)
    local gold = state.goldButton
    if gold ~= nil then
      gold:ClearAllPoints()
      gold:SetPoint("TOPRIGHT", scanButton, "TOPLEFT", TabOverlap(), 0)
    end
  end
  if leftArrow == nil then
    leftArrow = CreateArrow("Left")
    rightArrow = CreateArrow("Right")
  end

  -- Width that is free for our tabs
  local available
  local startX = previous:GetRight()
  local goldButton = state.goldButton
  local endX = (goldButton and goldButton:IsShown() and goldButton:GetLeft()) or (scanButton and scanButton:GetLeft())
  if startX ~= nil and endX ~= nil then
    available = endX - startX - FirstTabGap() - 4
  end

  local total = 0
  for _, tab in ipairs(tabs) do
    total = total + tab:GetWidth() - TabOverlap()
  end
  local needsScroll = available ~= nil and total > available

  if not needsScroll then
    firstVisible = 1
  else
    available = available - ARROW_SPACE
  end
  firstVisible = math.max(1, math.min(firstVisible, #tabs))

  local anchor, used, lastVisible = previous, 0, firstVisible - 1
  for index, tab in ipairs(tabs) do
    local width = tab:GetWidth() - TabOverlap()
    local fits = not needsScroll or (index >= firstVisible and (used + width <= available or index == firstVisible))
    if index >= firstVisible and fits and lastVisible == index - 1 then
      tab:ClearAllPoints()
      tab:SetPoint("TOPLEFT", anchor, "TOPRIGHT", (anchor == previous) and FirstTabGap() or -TabOverlap(), 0)
      tab:Show()
      anchor = tab
      used = used + width
      lastVisible = index
    else
      tab:Hide()
    end
  end

  if needsScroll then
    leftArrow:ClearAllPoints()
    leftArrow:SetPoint("LEFT", previous, "RIGHT", 6, 2)
    leftArrow:Show()
    rightArrow:ClearAllPoints()
    rightArrow:SetPoint("LEFT", anchor, "RIGHT", -6, 2)
    rightArrow:Show()
    if firstVisible > 1 then leftArrow:Enable() else leftArrow:Disable() end
    if lastVisible < #tabs then rightArrow:Enable() else rightArrow:Disable() end
  else
    leftArrow:Hide()
    rightArrow:Hide()
  end
  state.lastVisible = lastVisible
  state.needsScroll = needsScroll
end

function Auctionary.Tabs.Scroll(delta)
  if not state.needsScroll then
    return
  end
  if delta > 0 and (state.lastVisible or #tabs) >= #tabs then
    return
  end
  firstVisible = math.max(1, math.min(firstVisible + delta, #tabs))
  Auctionary.Tabs.Layout()
end

-- Scrolls until the tab with this name can be seen
local function EnsureVisible(name)
  if not state.needsScroll then
    return
  end
  for index, tab in ipairs(tabs) do
    if tab.auctionary2Tab == name then
      local guard = 0
      while guard < #tabs and (index < firstVisible or index > (state.lastVisible or #tabs)) do
        guard = guard + 1
        firstVisible = firstVisible + ((index < firstVisible) and -1 or 1)
        Auctionary.Tabs.Layout()
      end
      return
    end
  end
end

local function OnTabSelected(selectedTab)
  local selectedID = selectedTab and selectedTab.GetID and selectedTab:GetID()
  local isOurs = false
  for _, tab in ipairs(tabs) do
    if tab:GetID() == selectedID then
      isOurs = true
      tab.panel:Show()
    else
      tab.panel:Hide()
    end
  end

  if isOurs then
    for textureName, file in pairs(BACKGROUND) do
      _G[textureName]:SetTexture(file)
    end
  end
  state.selected = isOurs and selectedTab.auctionary2Tab or nil
  -- The client redraws the tab buttons on every switch
  Auctionary.Tabs.ApplyBackground()
end

function Auctionary.Tabs.Initialize()
  if state.created then
    return
  end
  if AuctionFrame == nil or AuctionFrame.numTabs == nil then
    return
  end
  state.created = true

  -- Only tabs whose file is there (the free version has no Sniping)
  for _, details in ipairs(TAB_DETAILS) do
    if contentCreators[details.name] ~= nil then
      local tab = CreateTab(details)
      table.insert(tabs, tab)
      state.byName[details.name] = tab
    end
  end

  hooksecurefunc("AuctionFrameTab_OnClick", OnTabSelected)

  Auctionary.Tabs.CreateScanButton(tabs[#tabs])

  for _, tab in ipairs(tabs) do
    tab:EnableMouseWheel(true)
    tab:SetScript("OnMouseWheel", function(_, delta)
      Auctionary.Tabs.Scroll(delta > 0 and -1 or 1)
    end)
  end
  -- Crimson Gold is switched on once; a later choice of the user is kept
  if Auctionary.SavedState ~= nil and not Auctionary.SavedState.CrimsonBackgroundApplied then
    Auctionary.SavedState.CrimsonBackgroundApplied = true
    Auctionary.Config.Set(Auctionary.Config.Options.TAB_BACKGROUND, "crimson")
  end
  Auctionary.Tabs.ApplyBackground()
  Auctionary.Tabs.Layout()
  -- Once more when every addon has placed its tabs and sizes are known
  Auctionary.Compat.After(0.2, Auctionary.Tabs.Layout)
end

-- Looks like one more tab, but starts a full scan instead of showing a page
local SCAN_TEXT = AUCTIONARY2_L_SCAN_BUTTON or "Full Scan"

function Auctionary.Tabs.CreateScanButton(lastTab)
  local button = CreateFrame("Button", "Auctionary2ScanTabButton", AuctionFrame, "CharacterFrameTabButtonTemplate")
  button:SetText(SCAN_TEXT)
  -- At the right end of the tab bar, as far from the window's right edge as
  -- the first tab is from the left edge
  button:SetPoint("TOPRIGHT", AuctionFrame, "BOTTOMRIGHT", -20, 11)
  PanelTemplates_TabResize(button, TAB_PADDING)
  PanelTemplates_DeselectTab(button)

  button:RegisterForClicks("LeftButtonUp")
  button:SetScript("OnClick", function()
    local scanFrame = Auctionary.FullScan.Frame
    if scanFrame == nil then
      return
    end
    PlaySound("igCharacterInfoTab")
    if scanFrame:IsInProgress() then
      scanFrame:Abort()
    elseif IsShiftKeyDown() then
      scanFrame:InitiateScan("pages")
    elseif scanFrame:CanGetAll() then
      scanFrame:InitiateScan("getall")
    else
      Auctionary.Utilities.Message(scanFrame:NextScanMessage())
      Auctionary.Utilities.Message("Shift-click the button to scan page by page instead (slow).")
    end
  end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(SCAN_TEXT)
    GameTooltip:AddLine("Reads every auction and stores the lowest price of each item.", 1, 1, 1, true)
    GameTooltip:AddLine("Click: everything with one request (once every 15 minutes).", 1, 1, 1, true)
    GameTooltip:AddLine("Shift-click: page by page (always possible, slow).", 1, 1, 1, true)
    GameTooltip:AddLine("Click while scanning: stop.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  local listener = {}
  function listener:ReceiveEvent(eventName, fraction)
    if eventName == Auctionary.FullScan.Events.ScanProgress and fraction < 1 then
      button:SetText(SCAN_TEXT .. " " .. math.floor(fraction * 100) .. "%")
    elseif eventName == Auctionary.FullScan.Events.ScanStart then
      button:SetText(SCAN_TEXT .. " 0%")
    else
      button:SetText(SCAN_TEXT)
    end
    PanelTemplates_TabResize(button, TAB_PADDING)
  end
  Auctionary.EventBus:Register(listener, {
    Auctionary.FullScan.Events.ScanStart,
    Auctionary.FullScan.Events.ScanProgress,
    Auctionary.FullScan.Events.ScanComplete,
    Auctionary.FullScan.Events.ScanFailed,
  })

  -- Countdown of the quick scan cooldown on the button itself
  local elapsedTotal, shownText = 0, nil
  button:SetScript("OnUpdate", function(_, elapsed)
    elapsedTotal = elapsedTotal + elapsed
    if elapsedTotal < 0.5 then
      return
    end
    elapsedTotal = 0
    local scanFrame = Auctionary.FullScan.Frame
    if scanFrame == nil or scanFrame:IsInProgress() then
      shownText = nil
      return
    end
    local text = SCAN_TEXT
    if not scanFrame:CanGetAll() then
      local remaining = scanFrame:GetCooldownRemaining()
      if remaining > 0 then
        text = SCAN_TEXT .. " " .. string.format("%d:%02d", math.floor(remaining / 60), remaining % 60)
      end
    end
    if text ~= shownText then
      shownText = text
      button:SetText(text)
      PanelTemplates_TabResize(button, TAB_PADDING)
      Auctionary.Tabs.Layout()
    end
  end)

  state.scanButton = button

  -- Gold Tracker: a tab with a chart symbol, left of the scan button
  local gold = CreateFrame("Button", "Auctionary2GoldTrackerButton", AuctionFrame, "CharacterFrameTabButtonTemplate")
  gold:SetText("")
  PanelTemplates_TabResize(gold, 0, 44)
  PanelTemplates_DeselectTab(gold)
  gold:SetPoint("TOPRIGHT", button, "TOPLEFT", TAB_OVERLAP_PLAIN, 0)
  gold.icon = gold:CreateTexture(nil, "OVERLAY")
  gold.icon:SetTexture("Interface\\AddOns\\Auctionary\\Images\\Stats")
  gold.icon:SetWidth(18)
  gold.icon:SetHeight(18)
  gold.icon:SetPoint("CENTER", gold, "CENTER", 0, 2)
  gold:RegisterForClicks("LeftButtonUp")
  gold:SetScript("OnClick", function()
    PlaySound("igCharacterInfoTab")
    Auctionary.Components.ShowGoldTracker()
  end)
  gold:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Gold Tracker")
    GameTooltip:AddLine("What you earned, spent and paid as deposits, with a chart and the full log.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  gold:SetScript("OnLeave", function() GameTooltip:Hide() end)
  state.goldButton = gold
  Auctionary.Tabs.UpdateGoldButton()
end

function Auctionary.Tabs.Select(name)
  local tab = state.byName[name]
  if tab ~= nil then
    EnsureVisible(name)
    AuctionFrameTab_OnClick(tab)
  end
end

local listener = {}
function listener:ReceiveEvent()
  -- One frame later, so tabs of addons that react to the same event keep
  -- the positions they are used to
  Auctionary.Compat.After(0, function()
    Auctionary.Tabs.Initialize()
    if state.created then
      local function refresh()
        Auctionary.Tabs.Layout()
        Auctionary.Tabs.ApplyBackground()
      end
      refresh()
      Auctionary.Compat.After(0.2, refresh)
      Auctionary.Compat.After(1, refresh)
    end
  end)
end
Auctionary.EventBus:Register(listener, { Auctionary.AH.Events.Opened })


---- ElvUI
-- When ElvUI's auction house skin is on, our tabs, buttons, input boxes and
-- windows get the same look. Everything goes through ElvUI's own skin
-- functions and is wrapped in pcall, so another ElvUI version cannot break
-- the addon: at worst a part keeps the standard look.

local function GetElvUI()
  local E = ElvUI and ElvUI[1]
  if type(E) ~= "table" or E.private == nil or E.private.skins == nil or E.private.skins.blizzard == nil then
    return nil
  end
  if not E.private.skins.blizzard.enable or not E.private.skins.blizzard.auctionhouse then
    return nil
  end
  local S = E.GetModule and E:GetModule("Skins", true)
  if S == nil then
    return nil
  end
  return E, S
end

local elvDone = {}

local function TexturePath(texture)
  local path = texture and texture.GetTexture and texture:GetTexture()
  return type(path) == "string" and path:lower() or ""
end

local function SkinOne(S, frame)
  local objectType = frame:GetObjectType()
  if objectType == "EditBox" then
    S:HandleEditBox(frame)
  elseif objectType == "CheckButton" then
    local path = TexturePath(frame:GetNormalTexture())
    if path:find("ui%-checkbox") then
      S:HandleCheckBox(frame)
    end
  elseif objectType == "Slider" then
    if frame:GetName() ~= nil then
      S:HandleScrollBar(frame)
    end
  elseif objectType == "Button" then
    local path = TexturePath(frame:GetNormalTexture())
    if path:find("ui%-panel%-button") then
      S:HandleButton(frame)
    end
  end
end

local function SkinTree(S, frame)
  if not elvDone[frame] then
    elvDone[frame] = true
    pcall(SkinOne, S, frame)
  end
  for _, child in ipairs({ frame:GetChildren() }) do
    if child.GetObjectType ~= nil and child ~= frame.backdrop then
      SkinTree(S, child)
    end
  end
end

-- Any window of the addon (also used by the small dialogs)
function Auctionary.Tabs.SkinForElvUI(frame, isWindow)
  local E, S = GetElvUI()
  if E == nil then
    return
  end
  if isWindow and not elvDone[frame] then
    pcall(function()
      frame:SetTemplate("Transparent")
    end)
  end
  SkinTree(S, frame)
end

function Elv.SkinTabs()
  local E, S = GetElvUI()
  Elv.active = E ~= nil
  if E == nil then
    return
  end
  for _, tab in ipairs(tabs) do
    if not elvDone[tab] then
      elvDone[tab] = true
      pcall(S.HandleTab, S, tab)
    end
  end
  for _, button in ipairs({ state.scanButton, state.goldButton }) do
    if button ~= nil and not elvDone[button] then
      elvDone[button] = true
      pcall(S.HandleTab, S, button)
    end
  end
  for direction, arrow in pairs({ left = leftArrow, right = rightArrow }) do
    if arrow ~= nil and not elvDone[arrow] then
      elvDone[arrow] = true
      pcall(S.HandleNextPrevButton, S, arrow, direction)
    end
  end
end

-- ElvUI puts the gold display into the bottom left corner of the window,
-- where our tabs have buttons. While one of our tabs is open it sits in the
-- free title row instead.
local moneyMoved = false
local function PlaceMoney(ours)
  if AuctionFrameMoneyFrame == nil or ours == moneyMoved then
    return
  end
  moneyMoved = ours
  AuctionFrameMoneyFrame:ClearAllPoints()
  if ours then
    AuctionFrameMoneyFrame:SetPoint("TOPLEFT", AuctionFrame, "TOPLEFT", 24, -12)
  else
    AuctionFrameMoneyFrame:SetPoint("BOTTOMRIGHT", AuctionFrame, "BOTTOMLEFT", 181, 37)
  end
end

function Elv.SkinPanel(panel)
  local E, S = GetElvUI()
  Elv.active = E ~= nil
  if E == nil then
    return
  end
  if not elvDone[panel.Inset] then
    elvDone[panel.Inset] = true
    pcall(function()
      panel.Inset:SetTemplate("Transparent")
      -- Inside ElvUI's window, which is narrower than the standard artwork
      panel.Inset:ClearAllPoints()
      panel.Inset:SetPoint("TOPLEFT", AuctionFrame, "TOPLEFT", 19, -70)
      panel.Inset:SetPoint("BOTTOMRIGHT", AuctionFrame, "BOTTOMRIGHT", -8, 34)
    end)
  end
  SkinTree(S, panel)
  pcall(PlaceMoney, true)
end

function Elv.PanelHidden(panel)
  if not Elv.active then
    return
  end
  -- Back to ElvUI's place unless another of our tabs takes over right away
  Auctionary.Compat.After(0.05, function()
    for _, tab in ipairs(tabs) do
      if tab.panel ~= nil and tab.panel:IsShown() then
        return
      end
    end
    pcall(PlaceMoney, false)
  end)
end


---- Keyboard focus guard
-- A text box that keeps the cursor after its window was closed gets every
-- key, Escape included, so the game seems not to react any more. Text boxes
-- of the addon that are no longer visible lose the cursor here, and every
-- one of them lets go of it on Escape.

local function OwnBox(box)
  local name = box.GetName and box:GetName()
  if name ~= nil and name:find("^Auctionary2") then
    return true
  end
  local parent = box.GetParent and box:GetParent()
  while parent ~= nil do
    if parent == AuctionFrame then
      return true
    end
    local parentName = parent.GetName and parent:GetName()
    if parentName ~= nil and parentName:find("^Auctionary2") then
      return true
    end
    parent = parent:GetParent()
  end
  return false
end

local function AddEscape(frame)
  for _, child in ipairs({ frame:GetChildren() }) do
    if child.GetObjectType ~= nil then
      if child:GetObjectType() == "EditBox" and child:GetScript("OnEscapePressed") == nil then
        child:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
      end
      AddEscape(child)
    end
  end
end
Auctionary.Tabs.AddEscapeToBoxes = AddEscape

local focusGuard = CreateFrame("Frame")
local sinceFocusCheck = 0
-- Only runs while the auction house is open and a few seconds after
local guardUntil
focusGuard:RegisterEvent("AUCTION_HOUSE_SHOW")
focusGuard:RegisterEvent("AUCTION_HOUSE_CLOSED")
focusGuard:SetScript("OnEvent", function(_, eventName)
  guardUntil = eventName == "AUCTION_HOUSE_CLOSED" and (GetTime() + 3) or nil
  focusGuard:Show()
end)
focusGuard:Hide()
focusGuard:SetScript("OnUpdate", function(_, elapsed)
  sinceFocusCheck = sinceFocusCheck + (elapsed or 0)
  if sinceFocusCheck < 0.25 then
    return
  end
  sinceFocusCheck = 0
  if guardUntil ~= nil and GetTime() > guardUntil then
    focusGuard:Hide()
  end
  local box = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
  if box ~= nil and not box:IsVisible() then
    local ok, own = pcall(OwnBox, box)
    if ok and own then
      box:ClearFocus()
    end
  end
end)

---- Memory
-- After a full scan and when the auction house closes, a lot of temporary
-- data (scan pages, search results, price lists) is no longer needed. It is
-- given back right away instead of whenever the client gets around to it.
local memoryListener = {}
function memoryListener:ReceiveEvent(eventName)
  if eventName == Auctionary.AH.Events.Closed and Auctionary.Search.ClearNameIndex ~= nil then
    Auctionary.Search.ClearNameIndex()
  end
  Auctionary.Compat.After(3, function()
    if not (InCombatLockdown ~= nil and InCombatLockdown()) then
      collectgarbage("collect")
    end
  end)
end
Auctionary.EventBus:Register(memoryListener, {
  Auctionary.AH.Events.Closed,
  Auctionary.FullScan.Events.ScanComplete,
})
