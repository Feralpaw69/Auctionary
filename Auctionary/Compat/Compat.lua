-- Auctionary2 compatibility layer for the 3.3.5a (Interface 30300) client.
-- Everything lives inside the Auctionary2 namespace: no missing modern
-- globals (Mixin, C_Timer, ...) are created, so other addons that feature-detect
-- them are not affected.
local Auctionary = Auctionary2

Auctionary.Compat = {}
local Compat = Auctionary.Compat

---------------------------------------------------------------------------
-- Mixins
---------------------------------------------------------------------------
function Compat.Mixin(object, ...)
  for i = 1, select("#", ...) do
    local mixin = select(i, ...)
    if mixin ~= nil then
      for k, v in pairs(mixin) do
        object[k] = v
      end
    end
  end
  return object
end

function Compat.CreateFromMixins(...)
  return Compat.Mixin({}, ...)
end

function Compat.CreateAndInitFromMixin(mixin, ...)
  local object = Compat.CreateFromMixins(mixin)
  object:Init(...)
  return object
end

---------------------------------------------------------------------------
-- Tables
---------------------------------------------------------------------------
function Compat.CopyTable(settings)
  local copy = {}
  for k, v in pairs(settings) do
    if type(v) == "table" then
      copy[k] = Compat.CopyTable(v)
    else
      copy[k] = v
    end
  end
  return copy
end

function Compat.tIndexOf(tbl, item)
  for i, v in ipairs(tbl) do
    if v == item then
      return i
    end
  end
  return nil
end

function Compat.tFilter(tbl, pred, isIndexTable)
  local out = {}
  if isIndexTable then
    for _, v in ipairs(tbl) do
      if pred(v) then
        table.insert(out, v)
      end
    end
  else
    for k, v in pairs(tbl) do
      if pred(v) then
        out[k] = v
      end
    end
  end
  return out
end

---------------------------------------------------------------------------
-- Timers (replacement for C_Timer)
---------------------------------------------------------------------------
local timerFrame = CreateFrame("Frame")
local timers = {}
local timerCount = 0

local function TimerOnUpdate(self, elapsed)
  -- Iterate over a snapshot so that callbacks may add new timers safely
  local due
  for index = timerCount, 1, -1 do
    local timer = timers[index]
    timer.left = timer.left - elapsed
    if timer.left <= 0 then
      table.remove(timers, index)
      timerCount = timerCount - 1
      due = due or {}
      table.insert(due, timer)
    end
  end
  if timerCount == 0 then
    self:SetScript("OnUpdate", nil)
  end
  if due then
    -- Run in the order they were scheduled (oldest first)
    for index = 1, #due do
      local timer = due[index]
      if not timer.cancelled then
        timer.callback()
      end
    end
  end
end

-- duration 0 means "next frame"
function Compat.After(duration, callback)
  local timer = { left = duration or 0, callback = callback }
  table.insert(timers, 1, timer)
  timerCount = timerCount + 1
  timerFrame:SetScript("OnUpdate", TimerOnUpdate)
  return timer
end

function Compat.CancelTimer(timer)
  if timer then
    timer.cancelled = true
  end
end

-- Repeats until the returned ticker is cancelled with ticker:Cancel()
function Compat.NewTicker(duration, callback)
  local ticker = { cancelled = false }
  function ticker:Cancel()
    self.cancelled = true
  end
  local function Tick()
    if ticker.cancelled then
      return
    end
    callback(ticker)
    if not ticker.cancelled then
      Compat.After(duration, Tick)
    end
  end
  Compat.After(duration, Tick)
  return ticker
end

-- Millisecond timer (debugprofilestop does not exist in 3.3.5)
function Compat.ProfileStop()
  return GetTime() * 1000
end

---------------------------------------------------------------------------
-- Colours (3.3.5 colour tables have no methods)
---------------------------------------------------------------------------
local ColorMixin = {}
function ColorMixin:WrapTextInColorCode(text)
  return self.code .. tostring(text) .. "|r"
end
function ColorMixin:GetRGB()
  return self.r, self.g, self.b
end

local function MakeColor(r, g, b)
  local color = { r = r, g = g, b = b, a = 1 }
  color.code = string.format("|cff%02x%02x%02x", r * 255 + 0.5, g * 255 + 0.5, b * 255 + 0.5)
  return Compat.Mixin(color, ColorMixin)
end
Compat.MakeColor = MakeColor

Compat.Colors = {
  WHITE_FONT_COLOR = MakeColor(1, 1, 1),
  NORMAL_FONT_COLOR = MakeColor(1, 0.82, 0),
  HIGHLIGHT_FONT_COLOR = MakeColor(1, 1, 1),
  RED_FONT_COLOR = MakeColor(1, 0.1, 0.1),
  GREEN_FONT_COLOR = MakeColor(0.1, 1, 0.1),
  GRAY_FONT_COLOR = MakeColor(0.5, 0.5, 0.5),
  ORANGE_FONT_COLOR = MakeColor(1, 0.5, 0.25),
  LIGHTBLUE_FONT_COLOR = MakeColor(0.53, 0.67, 1),
  YELLOW_FONT_COLOR = MakeColor(1, 1, 0),
}

-- Quality colour with a WrapTextInColorCode method (quality 0-7)
local qualityColors = {}
function Compat.GetQualityColor(quality)
  quality = quality or 1
  if qualityColors[quality] == nil then
    local r, g, b = GetItemQualityColor(quality)
    qualityColors[quality] = MakeColor(r or 1, g or 1, b or 1)
  end
  return qualityColors[quality]
end

---------------------------------------------------------------------------
-- Money and number formatting
---------------------------------------------------------------------------
local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t"
local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t"
local COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t"

-- Same output shape as the modern GetMoneyString: "12g 3s 4c" using coin icons
-- For table columns: silver and copper are always written with two digits
-- once a bigger coin is shown ("16g 95s 00c", "5g 75s 00c"), so that in a
-- right-aligned column the coins of all rows stand below each other.
function Compat.GetAlignedMoneyString(amount)
  amount = math.floor((amount or 0) + 0.5)
  local negative = amount < 0
  if negative then
    amount = -amount
  end
  local gold = math.floor(amount / 10000)
  local silver = math.floor((amount % 10000) / 100)
  local copper = amount % 100
  local result
  if gold > 0 then
    result = Compat.FormatLargeNumber(gold) .. GOLD_ICON .. " "
      .. string.format("%02d", silver) .. SILVER_ICON .. " " .. string.format("%02d", copper) .. COPPER_ICON
  elseif silver > 0 then
    result = silver .. SILVER_ICON .. " " .. string.format("%02d", copper) .. COPPER_ICON
  else
    result = copper .. COPPER_ICON
  end
  if negative then
    result = "-" .. result
  end
  return result
end

function Compat.GetMoneyString(amount, separateThousands)
  amount = math.floor((amount or 0) + 0.5)
  local negative = amount < 0
  if negative then
    amount = -amount
  end
  local gold = math.floor(amount / 10000)
  local silver = math.floor((amount % 10000) / 100)
  local copper = amount % 100
  local parts = {}
  if gold > 0 then
    local goldText = tostring(gold)
    if separateThousands then
      goldText = Compat.FormatLargeNumber(gold)
    end
    table.insert(parts, goldText .. GOLD_ICON)
  end
  if silver > 0 then
    table.insert(parts, silver .. SILVER_ICON)
  end
  if copper > 0 or #parts == 0 then
    table.insert(parts, copper .. COPPER_ICON)
  end
  local result = table.concat(parts, " ")
  if negative then
    result = "-" .. result
  end
  return result
end

function Compat.FormatLargeNumber(amount)
  local text = tostring(math.floor(amount or 0))
  local separator = LARGE_NUMBER_SEPERATOR or ","
  if separator == "" then
    return text
  end
  local formatted = text
  while true do
    local replaced
    formatted, replaced = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1" .. separator .. "%2")
    if replaced == 0 then
      break
    end
  end
  return formatted
end

---------------------------------------------------------------------------
-- Frame events
---------------------------------------------------------------------------
function Compat.RegisterFrameForEvents(frame, events)
  for _, event in ipairs(events) do
    frame:RegisterEvent(event)
  end
end

function Compat.UnregisterFrameForEvents(frame, events)
  for _, event in ipairs(events) do
    frame:UnregisterEvent(event)
  end
end

---------------------------------------------------------------------------
-- Callback registry (replacement for CallbackRegistryMixin)
---------------------------------------------------------------------------
Compat.CallbackRegistryMixin = {}

function Compat.CallbackRegistryMixin:OnLoad()
  self.callbacks = {}
end

function Compat.CallbackRegistryMixin:GenerateCallbackEvents(events)
  for _, event in ipairs(events) do
    self.callbacks[event] = self.callbacks[event] or {}
  end
end

function Compat.CallbackRegistryMixin:RegisterCallback(event, func, owner)
  if self.callbacks[event] == nil then
    self.callbacks[event] = {}
  end
  -- One callback per owner and event, like the modern implementation
  owner = owner or func
  for _, entry in ipairs(self.callbacks[event]) do
    if entry.owner == owner then
      entry.func = func
      return
    end
  end
  table.insert(self.callbacks[event], { func = func, owner = owner })
end

function Compat.CallbackRegistryMixin:UnregisterCallback(event, owner)
  local entries = self.callbacks[event]
  if entries == nil then
    return
  end
  for index = #entries, 1, -1 do
    if entries[index].owner == owner then
      table.remove(entries, index)
    end
  end
end

function Compat.CallbackRegistryMixin:TriggerEvent(event, ...)
  local entries = self.callbacks[event]
  if entries == nil then
    return
  end
  local snapshot = {}
  for index, entry in ipairs(entries) do
    snapshot[index] = entry
  end
  for _, entry in ipairs(snapshot) do
    entry.func(entry.owner, ...)
  end
end

---------------------------------------------------------------------------
-- Hidden scan tooltip
-- The Whitemane/Frostmourne client adds FrameXML hooks (for example
-- GameTooltip_AddItemLevel) to OnTooltipSetItem. They error on tooltips that
-- are not real game tooltips, so the script is removed.
---------------------------------------------------------------------------
local scanTooltip
function Compat.GetScanTooltip()
  if scanTooltip == nil then
    scanTooltip = CreateFrame("GameTooltip", "Auctionary2ScanTooltip", nil, "GameTooltipTemplate")
    scanTooltip:SetScript("OnTooltipSetItem", nil)
    scanTooltip:SetScript("OnTooltipAddMoney", nil)
    scanTooltip:SetScript("OnTooltipCleared", nil)
    scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
  end
  if not scanTooltip:IsOwned(WorldFrame) then
    scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
  end
  scanTooltip:ClearLines()
  return scanTooltip
end

-- Returns true if any left-hand line of the scan tooltip equals one of the
-- supplied texts
function Compat.ScanTooltipHasLine(tooltip, texts)
  for line = 1, tooltip:NumLines() do
    local fontString = _G["Auctionary2ScanTooltipTextLeft" .. line]
    local text = fontString and fontString:GetText()
    if text ~= nil then
      for _, wanted in ipairs(texts) do
        if text == wanted then
          return true
        end
      end
    end
  end
  return false
end

---------------------------------------------------------------------------
-- Item information
-- 3.3.5 GetItemInfo returns:
--   name, link, quality, itemLevel, requiredLevel, type, subType, maxStack,
--   equipSlot, texture, vendorPrice
-- and returns nil for items that are not in the local cache yet.
---------------------------------------------------------------------------
function Compat.GetItemIDFromLink(itemLink)
  if type(itemLink) == "number" then
    return itemLink
  elseif type(itemLink) == "string" then
    return tonumber(itemLink:match("item:(%d+)")) or tonumber(itemLink)
  end
  return nil
end

local pendingItems = {}
local pendingCount = 0
local loaderFrame = CreateFrame("Frame")
local LOAD_INTERVAL = 0.25
local LOAD_MAX_TRIES = 20
loaderFrame.elapsed = 0

local function RequestItem(itemID)
  -- Setting a hyperlink on a tooltip makes the client ask the server for the
  -- item data.
  local tooltip = Compat.GetScanTooltip()
  tooltip:SetHyperlink("item:" .. itemID .. ":0:0:0:0:0:0:0")
end

local function LoaderOnUpdate(self, elapsed)
  self.elapsed = self.elapsed + elapsed
  if self.elapsed < LOAD_INTERVAL then
    return
  end
  self.elapsed = 0
  local finished = {}
  for itemID, details in pairs(pendingItems) do
    if GetItemInfo(itemID) ~= nil then
      table.insert(finished, { itemID = itemID, callbacks = details.callbacks, success = true })
    else
      details.tries = details.tries + 1
      if details.tries >= LOAD_MAX_TRIES then
        table.insert(finished, { itemID = itemID, callbacks = details.callbacks, success = false })
      elseif details.tries % 4 == 0 then
        RequestItem(itemID)
      end
    end
  end
  for _, entry in ipairs(finished) do
    pendingItems[entry.itemID] = nil
    pendingCount = pendingCount - 1
  end
  if pendingCount <= 0 then
    pendingCount = 0
    self:SetScript("OnUpdate", nil)
  end
  for _, entry in ipairs(finished) do
    for _, callback in ipairs(entry.callbacks) do
      callback(entry.success)
    end
  end
end

-- Calls callback(true) once GetItemInfo has data for the item, or
-- callback(false) if the server never supplied it. The callback is called
-- immediately when the item is already cached.
function Compat.LoadItem(itemLinkOrID, callback)
  local itemID = Compat.GetItemIDFromLink(itemLinkOrID)
  if itemID == nil or itemID <= 0 then
    callback(false)
    return
  end
  if GetItemInfo(itemID) ~= nil then
    callback(true)
    return
  end
  if pendingItems[itemID] == nil then
    pendingItems[itemID] = { tries = 0, callbacks = {} }
    pendingCount = pendingCount + 1
    RequestItem(itemID)
  end
  table.insert(pendingItems[itemID].callbacks, callback)
  loaderFrame:SetScript("OnUpdate", LoaderOnUpdate)
end

function Compat.IsItemCached(itemLinkOrID)
  local itemID = Compat.GetItemIDFromLink(itemLinkOrID)
  return itemID ~= nil and GetItemInfo(itemID) ~= nil
end

---------------------------------------------------------------------------
-- Auction house item classes
-- The localized item type returned by GetItemInfo is mapped to its index in
-- GetAuctionItemClasses(); this index is also what QueryAuctionItems expects.
---------------------------------------------------------------------------
local classByName

local function BuildClassLookup()
  classByName = {}
  local classes = { GetAuctionItemClasses() }
  for index, name in ipairs(classes) do
    classByName[name] = index
  end
  return #classes > 0
end

function Compat.GetAuctionClassID(localizedType)
  if localizedType == nil then
    return nil
  end
  if classByName == nil or next(classByName) == nil then
    BuildClassLookup()
  end
  return classByName[localizedType]
end

function Compat.GetAuctionClassName(classID)
  return (select(classID, GetAuctionItemClasses()))
end

-- Returns the auction house class index for an item, nil if unknown/uncached
function Compat.GetItemClassID(itemLinkOrID)
  local _, _, _, _, _, itemType = GetItemInfo(itemLinkOrID)
  return Compat.GetAuctionClassID(itemType)
end
